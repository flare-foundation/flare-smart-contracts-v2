// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * Governor interface.
 */
interface IGovernor {

    struct GovernorSettings {
        bool accept;
        uint256 votingStartTs;
        uint256 votingPeriodSeconds;
        uint256 vpBlockPeriodSeconds;
        uint256 thresholdConditionBIPS;
        uint256 majorityConditionBIPS;
        uint256 executionDelaySeconds;
        uint256 executionPeriodSeconds;
    }

    /**
     * Enum describing a proposal state.

     * A proposal is:
     * * `Pending` when first created,
     * * `Active` when it’s being voted on,
     * * `Defeated` or `Succeeded` as a result of the vote,
     * * `Queued` when in the process of executing,
     * * `Expired` when it times out or fails to execute upon a certain date, and
     * * `Executed` when it goes live.
     */
    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed,
        Canceled
    }

    /**
     * Event emitted when a proposal is created.
     */
    event ProposalCreated(
        uint256 indexed proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        bytes[] calldatas,
        string description,
        bool accept,
        uint256[2] voteTimes,
        uint256[2] executionTimes,
        uint256 votePowerBlock,
        uint256 thresholdConditionBIPS,
        uint256 majorityConditionBIPS,
        uint256 circulatingSupply
    );

    /**
     * Event emitted when a proposal is canceled.
     */
    event ProposalCanceled(uint256 indexed proposalId);

    /**
     * Event emitted when a proposal is executed.
     */
    event ProposalExecuted(uint256 indexed proposalId);

    /**
     * Event emitted when a vote is cast.
     */
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 votePower,
        string reason,
        uint256 forVotePower,
        uint256 againstVotePower
    );

    /**
     * Cancels a proposal.
     * @param _proposalId Unique identifier obtained by hashing proposal data.
     * Emits a ProposalCanceled event
     */
    function cancel(uint256 _proposalId) external;

    /**
     * Casts a vote on a proposal.
     * @param _proposalId Id of the proposal.
     * @param _support A value indicating vote type (against, for).
     * @return Vote power of the cast vote.
     * Emits a VoteCast event.
     */
    function castVote(uint256 _proposalId, uint8 _support) external returns (uint256);

    /**
     * Casts a vote on a proposal with a reason.
     * @param _proposalId Id of the proposal.
     * @param _support A value indicating vote type (against, for).
     * @param _reason Vote reason.
     * @return Vote power of the cast vote.
     * Emits a VoteCast event.
     */
    function castVoteWithReason(
        uint256 _proposalId,
        uint8 _support,
        string calldata _reason
    ) external returns (uint256);

    /**
     * Casts a vote on a proposal using the user cryptographic signature.
     * @param _proposalId Id of the proposal.
     * @param _support A value indicating vote type (against, for).
     * @param _v v part of the signature.
     * @param _r r part of the signature.
     * @param _s s part of the signature.
     * Emits a VoteCast event.
     */
    function castVoteBySig(
        uint256 _proposalId,
        uint8 _support,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (uint256);

    /**
     * Executes a successful proposal without execution parameters.
     * @param _proposalId Id of the proposal.
     * Emits a ProposalExecuted event.
     */
    function execute(uint256 _proposalId) external;

    /**
     * Executes a successful proposal.
     * @param _proposalId Id of the proposal.
     * @param _targets Array of target addresses on which the calls are to be invoked.
     * @param _values Array of values with which the calls are to be invoked.
     * @param _calldatas Array of call data to be invoked.
     * Emits a ProposalExecuted event.
     */
    function execute(
        uint256 _proposalId,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas
    ) external payable;

    /**
     * Returns the current state of a proposal.
     * @param _proposalId Id of the proposal.
     * @return ProposalState enum.
     */
    function state(uint256 _proposalId) external view returns (ProposalState);

    /**
     * Returns the vote power of a voter at a specific block number.
     * @param _voter Address of the voter.
     * @param _blockNumber The block number.
     * @return Vote power of the voter at the block number.
     */
    function getVotes(address _voter, uint256 _blockNumber) external view returns (uint256);

    /**
     * Returns information if a voter has cast a vote on a specific proposal.
     * @param _proposalId Id of the proposal.
     * @param _voter Address of the voter.
     * @return True if the voter has cast a vote on the proposal, and false otherwise.
     */
    function hasVoted(uint256 _proposalId, address _voter) external view returns (bool);

    /**
     * Returns proposal id determined by hashing proposal data.
     * @param _targets Array of target addresses on which the calls are to be invoked.
     * @param _values Array of values with which the calls are to be invoked.
     * @param _calldatas Array of call data to be invoked.
     * @param _description Description of the proposal.
     * @return Proposal id.
     */
    function getProposalId(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) external view returns (uint256);

    /**
     * Returns the list of proposal ids.
     */
    function getProposalIds() external view returns (uint256[] memory);

    /**
     * Returns information of the specified proposal.
     * @param _proposalId Id of the proposal.
     * @return _proposer Address of the proposal submitter.
     * @return _accept Type of the proposal - accept or reject.
     * @return _votePowerBlock Block number used to determine the vote powers in voting process.
     * @return _voteStartTime Start time (in seconds from epoch) of the proposal voting.
     * @return _voteEndTime End time (in seconds from epoch) of the proposal voting.
     * @return _execStartTime Start time (in seconds from epoch) of the proposal execution window.
     * @return _execEndTime End time (in seconds from epoch) of the proposal exectuion window.
     * @return _thresholdConditionBIPS Percentage in BIPS of the total vote power required for proposal "quorum".
     * @return _majorityConditionBIPS Percentage in BIPS of the proper relation between FOR and AGAINST votes.
     * @return _circulatingSupply Circulating supply at votePowerBlock.
     * @return _description Description of the proposal.
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
        );

    /**
     * Returns votes (for, against) of the specified proposal.
     * @param _proposalId Id of the proposal.
     * @return _for Accumulated vote power for the proposal.
     * @return _against Accumulated vote power against the proposal.
     */
    function getProposalVotes(
        uint256 _proposalId
    )
        external view
        returns (
            uint256 _for,
            uint256 _against
        );
}
