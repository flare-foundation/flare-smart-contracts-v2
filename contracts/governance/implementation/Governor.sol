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

    /// The Submission contract.
    ISubmission public submission;
    /// The FlareSystemsManager contract.
    IIFlareSystemsManager public flareSystemsManager;
    /// The Supply contract.
    IISupply public supply;

    /// The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support)");

    /**
     * Initializes the contract with default parameters
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
     * @inheritdoc IGovernor
     */
    function cancel(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];

        require(!proposal.canceled, "proposal is already canceled");
        require(proposal.proposer == msg.sender, "proposal can only be canceled by its proposer");
        require(block.timestamp < proposal.voteStartTime, "proposal can only be canceled before voting starts");

        proposal.canceled = true;

        emit ProposalCanceled(_proposalId);
    }

    /**
     * @inheritdoc IGovernor
     */
    function castVote(
        uint256 _proposalId,
        uint8 _support
    ) external returns (uint256) {
        return _castVote(_proposalId, msg.sender, _support, "");
    }

    /**
     * @inheritdoc IGovernor
     */
    function castVoteWithReason(
        uint256 _proposalId,
        uint8 _support,
        string calldata _reason
    ) external returns (uint256) {
        return _castVote(_proposalId, msg.sender, _support, _reason);
    }

    /**
     * @inheritdoc IGovernor
     */
    function castVoteBySig(
        uint256 _proposalId,
        uint8 _support,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (uint256) {
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
     * @inheritdoc IGovernor
     */
    function execute(uint256 _proposalId) external {
        _execute(_proposalId, new address[](0), new uint256[](0), new bytes[](0));
    }

    /**
     * @inheritdoc IGovernor
     */
    function execute(
        uint256 _proposalId,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas
    ) external payable {
        _execute(_proposalId, _targets, _values, _calldatas);
    }

    /**
     * @inheritdoc IGovernor
     */
    function state(uint256 _proposalId) external view returns (ProposalState) {
        return _state(_proposalId, proposals[_proposalId]);
    }

    /**
     * @inheritdoc IGovernor
     */
    function getVotes(address _voter, uint256 _blockNumber) external view returns (uint256) {
        return votePowerOfAt(_voter, _blockNumber);
    }

    /**
     * @inheritdoc IGovernor
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
     * @inheritdoc IGovernor
     */
    function getProposalIds() external view returns (uint256[] memory) {
        return proposalIds;
    }

    /**
     * @inheritdoc IGovernor
     */
    function getProposalInfo(
        uint256 _proposalId
    )
        external view
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
            uint256 _circulatingSupply,
            string memory _description
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
        _description = proposal.description;
    }

    /**
     * @inheritdoc IGovernor
     */
    function getProposalVotes(
        uint256 _proposalId
    )
        external view
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
     * @inheritdoc IGovernor
     */
    function hasVoted(uint256 _proposalId, address _voter) external view returns (bool) {
        return proposalVotings[_proposalId].hasVoted[_voter];
    }

    /**
     * Returns the name of the governor contract
     * @return String representing the name
     */
    function name() public pure virtual returns (string memory);

    /**
     * Returns the version of the governor contract
     * @return String representing the version
     */
    function version() public pure virtual returns (string memory);

    /**
     * Creates a new proposal
     * @param _targets              Array of target addresses on which the calls are to be invoked
     * @param _values               Array of values with which the calls are to be invoked
     * @param _calldatas            Array of call data to be invoked
     * @param _description          String description of the proposal
     * @param _settings             Settings of the poposal
     * @return Proposal id (unique identifier obtained by hashing proposal data)
     * Emits a ProposalCreated event
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
     * Casts a vote on a proposal
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
     * Executes a successful proposal
     * @param _proposalId           Id of the proposal
     * @param _targets              Array of target addresses on which the calls are to be invoked
     * @param _values               Array of values with which the calls are to be invoked
     * @param _calldatas            Array of call data to be invoked
     * Emits a ProposalExecuted event
     */
    function _execute(
        uint256 _proposalId,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas
    )
        internal
    {
        Proposal storage proposal = proposals[_proposalId];
        require(
            _proposalId == _getProposalId(_targets, _values, _calldatas, _getDescriptionHash(proposal.description)),
            "execution parameters do not match proposal");

        require(!proposal.executed, "proposal already executed");
        require(proposal.proposer == msg.sender, "proposal can only be executed by its proposer");

        ProposalState proposalState = _state(_proposalId, proposal);
        require(proposalState == ProposalState.Queued, "proposal not in execution state");

        proposal.executed = true;
        _executeProposal(_targets, _values, _calldatas);
        emit ProposalExecuted(_proposalId);
    }

    /**
     * Implementation of the AddressUpdatable abstract method.
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
     * Calculates a vote power block for proposal
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
     * Returns the current state of a proposal
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

    /**
     * Returns the start and end voting times of a proposal
     */
    function _getVoteTimes(Proposal storage proposal) internal view returns (uint256[2] memory _voteTimes) {
        _voteTimes[0] = proposal.voteStartTime;
        _voteTimes[1] = proposal.voteEndTime;
    }

    /**
     * Returns the start and end execution times of a proposal
     */
    function _getExecTimes(Proposal storage proposal) internal view returns (uint256[2] memory _execTimes) {
        _execTimes[0] = proposal.execStartTime;
        _execTimes[1] = proposal.execEndTime;
    }

    /**
     * Determines if a proposal has been successful
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
     * Determines if the submitter of a proposal is a valid proposer
     * @param _proposer             Address of the submitter
     * @param _votePowerBlock       Number representing the vote power block for which the validity is checked
     * @return True if the submitter is valid, and false otherwise
     */
    function _isValidProposer(address _proposer, uint256 _votePowerBlock) internal virtual view returns (bool);
}
