// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


interface IPollingManagementGroup {

    /**
     * Struct holding the information about proposal properties.
     */
    struct Proposal {
        uint256 rewardEpochId;              // reward epoch id in which the proposal was created
        string description;                 // description of the proposal
        address proposer;                   // address of the proposer
        bool canceled;                      // flag indicating if proposal has been canceled
        uint256 voteStartTime;              // start time of voting window (in seconds from epoch)
        uint256 voteEndTime;                // end time of voting window (in seconds from epoch)
        uint256 thresholdConditionBIPS;     // percentage in BIPS of the total vote power required for proposal quorum
        uint256 majorityConditionBIPS;      // percentage in BIPS of the proper relation between FOR and AGAINST votes
        mapping(address => bool) isEligible;// flag if an address is eligible to cast a vote in a proposal
        uint256 noOfEligibleMembers;        // number of addresses that can vote in the proposal
        bool accept;                        // if true proposal is of the acceptance type
                                            // otherwise it is of the rejection type
    }

    /**
     * Struct holding the information about proposal voting.
     */
    struct ProposalVoting {
        uint256 againstVotePower;           // accumulated vote power against the proposal
        uint256 forVotePower;               // accumulated vote power for the proposal
        mapping(address => bool) hasVoted;  // flag if a voter has cast a vote
    }

    /**
     * Enum describing a proposal state.
     */
    enum ProposalState {
        Canceled,
        Pending,
        Active,
        Defeated,
        Succeeded
    }

    /**
     * Enum that determines vote (support) type.
     * 0 = Against, 1 = For.
     */
    enum VoteType {
        Against,
        For
    }

    /**
     * Event emitted when a proposal is created.
     */
    event ManagementGroupProposalCreated(
        uint256 indexed proposalId,
        address proposer,
        string description,
        uint256 voteStartTime,
        uint256 voteEndTime,
        uint256 thresholdConditionBIPS,
        uint256 majorityConditionBIPS,
        address[] eligibleMembers,
        bool accept
    );

    /**
     * Event emitted when a vote is cast.
     */
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 forVotePower,
        uint256 againstVotePower
    );

    /**
     * Event emitted when a proposal is canceled.
     */
    event ProposalCanceled(uint256 indexed proposalId);

    /**
     * Event emitted when parameters are set.
     */
    event ParametersSet(
        uint256 votingDelaySeconds,
        uint256 votingPeriodSeconds,
        uint256 thresholdConditionBIPS,
        uint256 majorityConditionBIPS,
        uint256 proposalFeeValueWei,
        uint256 addAfterRewardedEpochs,
        uint256 addAfterNotChilledEpochs,
        uint256 removeAfterNotRewardedEpochs,
        uint256 removeAfterEligibleProposals,
        uint256 removeAfterNonParticipatingProposals,
        uint256 removeForDays
    );

    /**
     * @notice Event emitted when management group member is added
     */
    event ManagementGroupMemberAdded(address addedMember);

    /**
     * @notice Event emitted when management group member is removed
     */
    event ManagementGroupMemberRemoved(address removedMember);


    /**
     * Event emitted when maintainer is set.
     */
    event MaintainerSet(address newMaintainer);

    /**
     * Event emitted when proxy voter is set.
     */
    event ProxyVoterSet(address account, address proxyVoter);

    /**
     * Cancels an existing proposal.
     * @param _proposalId Unique identifier of a proposal.
     * Emits a ProposalCanceled event.
     */
    function cancel(uint256 _proposalId) external;

    /**
     * Creates a new proposal.
     * @param _description String description of the proposal.
     * @return _proposalId Unique identifier of the proposal.
     * Emits a ManagementGroupProposalCreated event.
     */
    function propose(
        string memory _description
    ) external payable returns (uint256);

    /**
     * Casts a vote on a proposal.
     * @param _proposalId Id of the proposal.
     * @param _support A value indicating vote type (against, for).
     * Emits a VoteCast event.
     */
    function castVote(uint256 _proposalId, uint8 _support) external;

    /**
     * Sets a proxy voter for a voter (i.e. address that can vote in its name).
     * @param _proxyVoter Address to register as a proxy (use address(0) to remove proxy).
     * Emits a ProxyVoterSet event.
     */
    function setProxyVoter(address _proxyVoter) external;

    /**
     * Adds `msg.sender` to the management group if voter fulfills all conditions and is not already a member.
     * If `msg.sender` is proxy of some voter (and is not a member of the group), adding voter.
     */
    function addMember() external;

    /**
     * Removes a member from the management group who no longer fulfills the conditions.
     * @param _voter Voter to be remove from the management group.
     */
    function removeMember(address _voter) external;

    /**
     * Returns the current state of a proposal.
     * @param _proposalId Id of the proposal.
     * @return ProposalState enum.
     */
    function state(uint256 _proposalId) external view returns (ProposalState);

    /**
     * Returns whether a voter has cast a vote on a specific proposal.
     * @param _proposalId Id of the proposal.
     * @param _voter Address of the voter.
     * @return True if the voter has cast a vote on the proposal, and false otherwise.
     */
    function hasVoted(uint256 _proposalId, address _voter) external view returns (bool);

    /**
     * Returns information about the specified proposal.
     * @param _proposalId Id of the proposal.
     * @return _description Description of the proposal.
     * @return _proposer Address of the proposal submitter.
     * @return _accept True if the proposal is acceptance based, false if rejection based.
     * @return _voteStartTime Start time (in seconds from epoch) of the proposal voting.
     * @return _voteEndTime End time (in seconds from epoch) of the proposal voting.
     * @return _thresholdConditionBIPS Number of votes (voter power) cast required for the proposal to pass.
     * @return _majorityConditionBIPS Number of FOR votes, as a percentage in BIPS of the.
     * @return _noOfEligibleMembers Number of eligible voters.
     */
    function getProposalInfo(
        uint256 _proposalId
    )
        external view
        returns (
            string memory _description,
            address _proposer,
            bool _accept,
            uint256 _voteStartTime,
            uint256 _voteEndTime,
            uint256 _thresholdConditionBIPS,
            uint256 _majorityConditionBIPS,
            uint256 _noOfEligibleMembers
        );

    /**
     * Returns the description string that was supplied when the specified proposal was created.
     * @param _proposalId Id of the proposal.
     * @return _description Description of the proposal.
     */
    function getProposalDescription(uint256 _proposalId) external view
        returns (string memory _description);

    /**
     * Returns id and description of the last created proposal.
     * @return _proposalId Id of the last proposal.
     * @return _description Description of the last proposal.
     */
    function getLastProposal() external view
        returns ( uint256 _proposalId, string memory _description);

    /**
     * Returns number of votes for and against the specified proposal.
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

    /**
     * Returns whether an account can create proposals.
     * An address can make proposals if it is registered voter,
     * its proxy or the maintainer of the contract.
     * @param _account Address of the queried account.
     * @return True if the queried account can create a proposal, false otherwise.
     */
    function canPropose(address _account) external view returns (bool);

    /**
     * Returns whether an account can vote for a given proposal.
     * @param _account Address of the queried account.
     * @param _proposalId Id of the queried proposal.
     * @return True if account is eligible to vote, false otherwise.
     */
    function canVote(address _account, uint256 _proposalId) external view returns (bool);

    /**
     * Returns whether a voter is member of the management group.
     * @param _voter Address of the queried voter.
     * @return True if the queried voter is member, false otherwise.
     */
    function isMember(address _voter) external view returns (bool);
}
