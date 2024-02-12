// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/inflation/interface/IISupply.sol";
import "../../userInterfaces/IGovernor.sol";
import "../../userInterfaces/ISubmission.sol";
import "./GovernorProposals.sol";
import "./GovernorVotes.sol";
import "./GovernorVotePower.sol";
import "../../protocol/interface/IIFlareSystemsManager.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../utils/lib/SafePct.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

abstract contract Governor is IGovernor, EIP712, GovernorVotePower, GovernorProposals, GovernorVotes, AddressUpdatable
{
    using SafePct for uint256;

    uint256 internal constant MAX_BIPS = 1e4;

    ISubmission public submission;
    IIFlareSystemsManager public flareSystemsManager;
    IISupply public supply;

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support)");

    /**
     * @notice Initializes the contract with default parameters
     * @param _addressUpdater               Address identifying the address updater contract
     */
    constructor(
        address _addressUpdater
    )
        EIP712(name(), version())
        GovernorProposals()
        GovernorVotes()
        AddressUpdatable(_addressUpdater)
    {
    }

    /**
     * @notice Cancels a proposal
     * @param _proposalId       Unique identifier obtained by hashing proposal data
     * @notice Emits a ProposalCanceled event
     */
    function cancel(uint256 _proposalId) external override {
        Proposal storage proposal = proposals[_proposalId];

        require(!proposal.canceled, "proposal is already canceled");
        require(proposal.proposer == msg.sender, "proposal can only be canceled by its proposer");
        require(block.timestamp < proposal.voteStartTime, "proposal can only be canceled before voting starts");

        proposal.canceled = true;

        emit ProposalCanceled(_proposalId);
    }

    /**
     * @notice Casts a vote on a proposal
     * @param _proposalId           Id of the proposal
     * @param _support              A value indicating vote type (against, for)
     * @return Vote power of the cast vote
     * @notice Emits a VoteCast event
     */
    function castVote(
        uint256 _proposalId,
        uint8 _support
    ) external override returns (uint256) {
        return _castVote(_proposalId, msg.sender, _support, "");
    }

    /**
     * @notice Casts a vote on a proposal with a reason
     * @param _proposalId           Id of the proposal
     * @param _support              A value indicating vote type (against, for)
     * @param _reason               Vote reason
     * @return Vote power of the cast vote
     * @notice Emits a VoteCast event
     */
    function castVoteWithReason(
        uint256 _proposalId,
        uint8 _support,
        string calldata _reason
    ) external override returns (uint256) {
        return _castVote(_proposalId, msg.sender, _support, _reason);
    }

    /**
     * @notice Casts a vote on a proposal using the user cryptographic signature
     * @param _proposalId           Id of the proposal
     * @param _support              A value indicating vote type (against, for)
     * @param _v                    v part of the signature
     * @param _r                    r part of the signature
     * @param _s                    s part of the signature
     * @notice Emits a VoteCast event
     */
    function castVoteBySig(
        uint256 _proposalId,
        uint8 _support,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external override returns (uint256) {
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(
            _hashTypedDataV4(keccak256(abi.encode(BALLOT_TYPEHASH, _proposalId, _support)))
        );
        address voter = ECDSA.recover(
            messageHash,
            _v,
            _r,
            _s
        );
        require(voter != address(0), "invalid vote signature");

        return _castVote(_proposalId, voter, _support, "");
    }

    /**
     * @notice Executes a successful proposal without execution parameters
     * @param _description          String description of the proposal
     * @notice Emits a ProposalExecuted event
     */
    function execute(string memory _description) external override returns (uint256) {
        return _execute(new address[](0), new uint256[](0), new bytes[](0), _getDescriptionHash(_description));
    }

    /**
     * @notice Executes a successful proposal
     * @param _targets              Array of target addresses on which the calls are to be invoked
     * @param _values               Array of values with which the calls are to be invoked
     * @param _calldatas            Array of call data to be invoked
     * @param _description          String description of the proposal
     * @notice Emits a ProposalExecuted event
     */
    function execute(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) external payable override returns (uint256 proposalId) {
        return _execute(_targets, _values, _calldatas, _getDescriptionHash(_description));
    }

    /**
     * @notice Returns the current state of a proposal
     * @param _proposalId           Id of the proposal
     * @return ProposalState enum
     */
    function state(uint256 _proposalId) external view override returns (ProposalState) {
        return _state(_proposalId, proposals[_proposalId]);
    }    

    /**
     * @notice Returns the vote power of a voter at a specific block number
     * @param _voter                Address of the voter
     * @param _blockNumber          The block number
     * @return Vote power of the voter at the block number
     */
    function getVotes(address _voter, uint256 _blockNumber) external view override returns (uint256) {
        return votePowerOfAt(_voter, _blockNumber);
    }

    /**
     * @notice Returns proposal id determined by hashing proposal data
     * @param _targets              Array of target addresses on which the calls are to be invoked
     * @param _values               Array of values with which the calls are to be invoked
     * @param _calldatas            Array of call data to be invoked
     * @param _description          Description of the proposal
     * @return Proposal id
     */
    function getProposalId(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) external view returns (uint256) {
        return _getProposalId(_targets, _values, _calldatas, _getDescriptionHash(_description));
    }

    /**
     * @notice Returns information of the specified proposal
     * @param _proposalId               Id of the proposal
     * @return _proposer                Address of the proposal submitter
     * @return _accept                  Type of the proposal - accept or reject
     * @return _votePowerBlock          Block number used to determine the vote powers in voting process
     * @return _voteStartTime           Start time (in seconds from epoch) of the proposal voting
     * @return _voteEndTime             End time (in seconds from epoch) of the proposal voting
     * @return _execStartTime           Start time (in seconds from epoch) of the proposal execution window
     * @return _execEndTime             End time (in seconds from epoch) of the proposal exectuion window
     * @return _thresholdConditionBIPS  Percentage in BIPS of the total vote power required for proposal "quorum"
     * @return _majorityConditionBIPS   Percentage in BIPS of the proper relation between FOR and AGAINST votes
     * @return _circulatingSupply       Circulating supply at votePowerBlock
     */
    function getProposalInfo(
        uint256 _proposalId
    )
        external view override
        returns (
            address _proposer,
            bool _accept,
            uint256 _votePowerBlock,
            uint256 _voteStartTime,
            uint256 _voteEndTime,
            uint256 _execStartTime,
            uint256 _execEndTime,
            uint256 _thresholdConditionBIPS,
            uint256 _majorityConditionBIPS,
            uint256 _circulatingSupply
        ) 
    {
        Proposal storage proposal = proposals[_proposalId];
        _proposer = proposal.proposer;
        _accept = proposal.accept;
        _votePowerBlock = proposal.votePowerBlock;
        _voteStartTime = proposal.voteStartTime;
        _voteEndTime = proposal.voteEndTime;
        _execStartTime = proposal.execStartTime;
        _execEndTime = proposal.execEndTime;
        _thresholdConditionBIPS = proposal.thresholdConditionBIPS;
        _majorityConditionBIPS = proposal.majorityConditionBIPS;
        _circulatingSupply = proposal.circulatingSupply;
    }

    /**
     * @notice Returns votes (for, against) of the specified proposal 
     * @param _proposalId           Id of the proposal
     * @return _for                 Accumulated vote power for the proposal
     * @return _against             Accumulated vote power against the proposal
     */
    function getProposalVotes(
        uint256 _proposalId
    )
        external view override
        returns (
            uint256 _for,
            uint256 _against
        ) 
    {
        ProposalVoting storage voting = proposalVotings[_proposalId];
        _for = voting.forVotePower;
        _against = voting.againstVotePower;
    }

    /**
     * @notice Returns information if a voter has cast a vote on a specific proposal
     * @param _proposalId           Id of the proposal
     * @param _voter                Address of the voter
     * @return True if the voter has cast a vote on the proposal, and false otherwise
     */
    function hasVoted(uint256 _proposalId, address _voter) external view override returns (bool) {
        return proposalVotings[_proposalId].hasVoted[_voter];
    }

    /**
     * @notice Returns the name of the governor contract
     * @return String representing the name
     */
    function name() public pure virtual returns (string memory);

    /**
     * @notice Returns the version of the governor contract
     * @return String representing the version
     */
    function version() public pure virtual returns (string memory);

    /**
     * @notice Creates a new proposal
     * @param _targets              Array of target addresses on which the calls are to be invoked
     * @param _values               Array of values with which the calls are to be invoked
     * @param _calldatas            Array of call data to be invoked
     * @param _description          String description of the proposal
     * @param _settings             Settings of the poposal
     * @return Proposal id (unique identifier obtained by hashing proposal data)
     * @notice Emits a ProposalCreated event
     */
    function _propose(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description,
        GovernorSettings memory _settings
    ) internal returns (uint256) {
        (uint256 votePowerBlock, uint256 rewardEpochTimestamp) =
            _calculateVotePowerBlock(_settings.vpBlockPeriodSeconds);

        require(_isValidProposer(msg.sender, votePowerBlock), "submitter is not eligible to submit a proposal");
        require(_settings.votingPeriodSeconds > 0, "voting period too low");
        require(_settings.executionPeriodSeconds > 0, "execution period too low");
        require(_settings.thresholdConditionBIPS <= MAX_BIPS, "invalid thresholdConditionBIPS");
        require(_settings.majorityConditionBIPS >= 5000 && _settings.majorityConditionBIPS <= MAX_BIPS,
            "invalid majorityConditionBIPS");

        uint256 totalCirculatingSupply = supply.getCirculatingSupplyAt(votePowerBlock);
        uint256 rewardExpiryOffsetSeconds = flareSystemsManager.rewardExpiryOffsetSeconds();

        (uint256 proposalId, Proposal storage proposal) = _storeProposal(
            msg.sender,
            _targets,
            _values,
            _calldatas,
            _description,
            votePowerBlock,
            rewardEpochTimestamp,
            _settings,
            totalCirculatingSupply,
            rewardExpiryOffsetSeconds
        );

        emit ProposalCreated(
            proposalId,
            msg.sender,
            _targets,
            _values,
            _calldatas,
            _description,
            proposal.accept,
            _getVoteTimes(proposal),
            _getExecTimes(proposal),
            proposal.votePowerBlock,
            proposal.thresholdConditionBIPS,
            proposal.majorityConditionBIPS,
            proposal.circulatingSupply
        );

        return proposalId;
    }

    /**
     * @notice Casts a vote on a proposal
     * @param _proposalId           Id of the proposal
     * @param _voter                Address of the voter
     * @param _support              A value indicating vote type (against, for)
     * @param _reason               Vote reason
     */
    function _castVote(
        uint256 _proposalId,
        address _voter,
        uint8 _support,
        string memory _reason
    ) internal returns (uint256) {
        Proposal storage proposal = proposals[_proposalId];
        require(_state(_proposalId, proposal) == ProposalState.Active, "proposal not active");

        uint256 votePower = votePowerOfAt(_voter, proposal.votePowerBlock);
        ProposalVoting storage voting = _storeVote(_proposalId, _voter, _support, votePower);

        emit VoteCast(_voter, _proposalId, _support, votePower, _reason, voting.forVotePower, voting.againstVotePower);

        return votePower;
    }

    /**
     * @notice Executes a successful proposal
     * @param _targets              Array of target addresses on which the calls are to be invoked
     * @param _values               Array of values with which the calls are to be invoked
     * @param _calldatas            Array of call data to be invoked
     * @param _descriptionHash      Hashed description of the proposal
     * @notice Emits a ProposalExecuted event
     */
    function _execute(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) internal returns (uint256 proposalId) {
        proposalId = _getProposalId(_targets, _values, _calldatas, _descriptionHash);
        Proposal storage proposal = proposals[proposalId];

        require(!proposal.executed, "proposal already executed");
        require(proposal.proposer == msg.sender, "proposal can only be executed by its proposer");

        ProposalState proposalState = _state(proposalId, proposal);
        require(proposalState == ProposalState.Queued, "proposal not in execution state");

        proposal.executed = true;
        _executeProposal(_targets, _values, _calldatas);
        emit ProposalExecuted(proposalId);

        return proposalId;
    }

    /**
     * @notice Implementation of the AddressUpdatable abstract method.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal virtual override
    {
        flareSystemsManager = IIFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));

        supply = IISupply(
            _getContractAddress(_contractNameHashes, _contractAddresses, "Supply"));

        submission = ISubmission(
            _getContractAddress(_contractNameHashes, _contractAddresses, "Submission"));

        IIGovernanceVotePower vpContract = IIGovernanceVotePower(
            _getContractAddress(_contractNameHashes, _contractAddresses, "GovernanceVotePower"));

        setVotePowerContract(vpContract);
    }

    /**
     * @notice Calculates a vote power block for proposal
     * @return Vote power block number
     */
    function _calculateVotePowerBlock(uint256 _vpBlockPeriodSeconds) internal view returns (uint256, uint256) {
        uint24 rewardEpochId = flareSystemsManager.getCurrentRewardEpochId();

        (uint256 rewardEpochStartTs, uint256 rewardEpochStartBlock) =
            flareSystemsManager.getRewardEpochStartInfo(rewardEpochId);

        uint256 cleanupBlock = votePower.getCleanupBlockNumber();

        while (rewardEpochId > 0 && block.timestamp - rewardEpochStartTs < _vpBlockPeriodSeconds) {
            (uint256 prevRewardEpochStartTs, uint256 prevRewardEpochStartBlock) =
                flareSystemsManager.getRewardEpochStartInfo(rewardEpochId - 1);
            if (prevRewardEpochStartBlock < cleanupBlock) {
                break;
            }
            rewardEpochId -= 1;
            rewardEpochStartTs = prevRewardEpochStartTs;
            rewardEpochStartBlock = prevRewardEpochStartBlock;
        }

        assert(rewardEpochStartBlock < block.number);

        //slither-disable-next-line weak-prng
        uint256 blocksBack = submission.getCurrentRandom() % (block.number - rewardEpochStartBlock);

        return (block.number - blocksBack, rewardEpochStartTs);
    }

    /**
     * @notice Returns the current state of a proposal
     * @param _proposalId           Id of the proposal
     * @param _proposal             Proposal object
     * @return ProposalState enum
     */
    function _state(uint256 _proposalId, Proposal storage _proposal) internal view returns (ProposalState) {
        if (_proposal.canceled) {
            return ProposalState.Canceled;
        }

        if (_proposal.executed) {
            return ProposalState.Executed;
        }

        if (_proposal.voteStartTime == 0) {
            revert("unknown proposal id");
        }

        if (_proposal.voteStartTime > block.timestamp) {
            return ProposalState.Pending;
        }

        if (_proposal.voteEndTime > block.timestamp) {
            return ProposalState.Active;
        }

        if (_proposalSucceeded(_proposalId, _proposal)) {
            if (!_proposal.executableOnChain) {
                return ProposalState.Queued;
            }
            if (_proposal.execStartTime > block.timestamp) {
                return ProposalState.Succeeded;
            }
            if (_proposal.execEndTime > block.timestamp) {
                return ProposalState.Queued;
            }
            return ProposalState.Expired;
        }

        return ProposalState.Defeated;
    }

    function _getVoteTimes(Proposal storage proposal) internal view returns (uint256[2] memory _voteTimes) {
        _voteTimes[0] = proposal.voteStartTime;
        _voteTimes[1] = proposal.voteEndTime;
    }

    function _getExecTimes(Proposal storage proposal) internal view returns (uint256[2] memory _execTimes) {
        _execTimes[0] = proposal.execStartTime;
        _execTimes[1] = proposal.execEndTime;
    }

    /**
     * @notice Determines if a proposal has been successful
     * @param _proposalId           Id of the proposal
     * @param _proposal             Proposal
     * @return True if proposal succeeded and false otherwise
     */
    function _proposalSucceeded(uint256 _proposalId, Proposal storage _proposal) internal view virtual returns (bool) {
        ProposalVoting storage voting = proposalVotings[_proposalId];

        if (voting.forVotePower + voting.againstVotePower <
            _proposal.thresholdConditionBIPS.mulDiv(_proposal.circulatingSupply, MAX_BIPS)) {
            return !_proposal.accept;
        }

        if ((_proposal.accept ? voting.forVotePower : voting.againstVotePower) <=
            _proposal.majorityConditionBIPS.mulDiv(voting.forVotePower + voting.againstVotePower, MAX_BIPS)) {
            return !_proposal.accept;
        }

        return _proposal.accept;
    }

    /**
     * @notice Determines if the submitter of a proposal is a valid proposer
     * @param _proposer             Address of the submitter
     * @param _votePowerBlock       Number representing the vote power block for which the validity is checked
     * @return True if the submitter is valid, and false otherwise
     */
    function _isValidProposer(address _proposer, uint256 _votePowerBlock) internal virtual view returns (bool);
}
