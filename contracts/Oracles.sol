pragma solidity ^0.4.22;

import "./openzeppelin/contracts/lifecycle/Pausable.sol";
import "./openzeppelin/contracts/math/SafeMath.sol";
import "./EtherBank.sol";


/**
 * @title EtherBank's Oracles contract.
 */
contract Oracles is Pausable {
    using SafeMath for uint256;

    EtherBank internal bank;

    address public owner;

    bool public recruitingFinished = false;

    uint256 private totalScore;

    struct Vote {
        uint256 value;
        uint256 votingNo;
    }

    struct Voting {
        uint256 sum;
        uint256 sumScores;
        uint256 No;
    }

    struct Oracle {
        address account;
        uint64 score;
        bool isActive;
    }

    mapping(bytes32 => Vote) private votes;
    mapping(uint8 => Voting) private votings;
    mapping(address => Oracle) private oracles;

    event EditOracles(address oracle, uint256 score);
    event FinishRecruiting();
    event SetVote(address oracle, uint8 _type, uint256 _value);
    event Update(uint8 indexed _type, uint256 _value);

    string private constant INVALID_ADDRESS = "INVALID_ADDRESS";
    string private constant RECRUITING_FINISHED = "RECRUITING_FINISHED";

    constructor(address _etherBankAddr)
        public {
            owner = msg.sender;
            totalScore = 0;
            bank = EtherBank(_etherBankAddr);
        }

    /**
     * @notice Set EtherBank smart contract.
     * @param _etherBankAddr The EtherBank smart contract address.
     */
    function setEtherBank(address _etherBankAddr)
        external
        onlyOwner
        whenNotPaused
    {
        require(_etherBankAddr != address(0), INVALID_ADDRESS);

        bank = EtherBank(_etherBankAddr);
    }

    /**
     * @notice Sign a ballot.
     * @param _value The value of a variable.
     * @param _type The variable code.
     */
    function vote(uint8 _type, uint256 _value)
        external
        whenNotPaused
    {
        address oracle = msg.sender;
        uint256 score = oracles[oracle].score;
        bytes32 votesKey = keccak256(abi.encodePacked(oracle,_type));
        if (votings[_type].No == 0) {
            votings[_type].No++;
        }
        if (votes[votesKey].votingNo == votings[_type].No) {
            votings[_type].sum -= votes[votesKey].value * score;
            votings[_type].sumScores -= score;
        }
        votes[votesKey].value = _value;
        votes[votesKey].votingNo = votings[_type].No;
        votings[_type].sum += (_value.mul(score));
        votings[_type].sumScores += score;
        emit SetVote(oracle, _type, _value);
        if ((totalScore / votings[_type].sumScores) < 2) {
            updateEtherBank(_type);
        }
    }

    /**
     * @notice Update the EtherBank variable.
     * @param _type The variable code.
     */
    function updateEtherBank(uint8 _type)
        internal
    {
        uint256 _value = votings[_type].sum / votings[_type].sumScores;
        bank.setVariable(_type, _value);
        votings[_type].sum = 0;
        votings[_type].sumScores = 0;
        votings[_type].No++;
        emit Update(_type, _value);
    }

    /**
     * @notice Manipulate (add/remove/edit score) member of oracles.
     * @param _account The oracle account.
     * @param _score The score of oracle.
     */
    function setScore(address _account, uint64 _score)
        external
        onlyOwner
        canRecruiting
        whenNotPaused
    {
        require(_account != address(0), INVALID_ADDRESS);
        if (_score != 0 && !oracles[_account].isActive) {
            oracles[_account].isActive = true;
            oracles[_account].score = _score;
            oracles[_account].account = _account;
            totalScore += _score;
        } else if (_score != 0 && oracles[_account].isActive) {
            totalScore -= oracles[_account].score;
            totalScore += _score;
            oracles[_account].score = _score;
        } else if (_score == 0 && oracles[_account].isActive) {
            oracles[_account].isActive = false;
            totalScore -= oracles[_account].score;
            oracles[_account].score = _score;
        }
        emit EditOracles(_account, _score);
    }

    /**
    * @notice Function to stop recruiting new oracle.
    */
    function finishRecruiting()
        external
        onlyOwner
        canRecruiting
        returns (bool)
    {
        recruitingFinished = true;
        emit FinishRecruiting();
    }

    /**
     * @dev Throws if recruiting finished.
     */
    modifier canRecruiting() {
        require(!recruitingFinished, RECRUITING_FINISHED);
        _;
    }
}
