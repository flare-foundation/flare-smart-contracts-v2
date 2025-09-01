// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IIPollingManagementGroup.sol";
import "../../userInterfaces/IRewardManager.sol";
import "../../userInterfaces/IEntityManager.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../protocol/interface/IIVoterRegistry.sol";
import "../../protocol/interface/IIFlareSystemsManager.sol";
import "../../utils/lib/SafePct.sol";
import "./Governed.sol";
import "../../utils/lib/AddressSet.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Polling Management Group
 * A contract manages membership of the Management Group,
 * enables users of the group to create proposals and vote on them.
 */
//solhint-disable-next-line max-states-count
contract PollingManagementGroup is IIPollingManagementGroup, AddressUpdatable, Governed {
    using SafePct for uint256;
    using AddressSet for AddressSet.State;

    uint256 internal constant MAX_BIPS = 1e4;
    address payable constant internal BURN_ADDRESS = payable(0x000000000000000000000000000000000000dEaD);
    uint256 internal constant DAY_TO_SECOND = 1 days;

    mapping(uint256 proposalId => Proposal) internal proposals;
    mapping(uint256 proposalId => ProposalVoting) internal proposalVotings;
    /// Voter to proxy address mapping
    mapping(address voter => address proxy) public voterToProxy;
    /// Proxy to voter address mapping
    mapping(address proxy => address voter) public proxyToVoter;
    /// Timestamp at which member was removed from the management group
    mapping(address voter => uint256 timestamp) public memberRemovedAtTs;
    /// Id of the last created proposal at the moment member was added to the management group
    mapping (address voter => uint256 proposalId) public memberAddedAtProposal;
    /// Epoch in which member was added
    mapping (address voter => uint256 rewardEpochId) public memberAddedAtRewardEpoch;

    // voters eligible to participate (create proposals and vote)
    AddressSet.State private managementGroupMembers;
    /// Address of voter registry contract.
    IIVoterRegistry public voterRegistry;
    /// Address of flare systems manager contract.
    IIFlareSystemsManager public flareSystemsManager;
    /// Address of the reward manager contract
    IRewardManager public rewardManager;
    /// Address of the entity manager contract
    IEntityManager public entityManager;

    // voting parameters
    /// Period between proposal creation and start of the vote, in seconds.
    uint256 public votingDelaySeconds;
    /// Length of voting period, in seconds.
    uint256 public votingPeriodSeconds;
    /// Share of total vote power (in BIPS) required to participate in vote for proposal to pass or to be rejected.
    uint256 public thresholdConditionBIPS;
    /// Share of participating vote power (in BIPS) required to vote in favor for proposal to pass or to be rejected.
    uint256 public majorityConditionBIPS;
    /// Fee value (in wei) that proposer must pay to submit a proposal.
    uint256 public proposalFeeValueWei;

    /// Number of created proposals.
    uint256 public idCounter = 0;
    /// Maintainer of this contract; can change parameters and create proposals.
    address public maintainer;

    // parameters for adding and removing members
    /// Number of last initialised epochs with earned rewards to be added
    uint256 public addAfterRewardedEpochs;
    /// Number of last consecutive epochs without chill to be added
    uint256 public addAfterNotChilledEpochs;
    /// Number of last initialised epochs without reward to be removed
    uint256 public removeAfterNotRewardedEpochs;
    /// Number of last proposals to check for not voting
    uint256 public removeAfterEligibleProposals;
    /// In how many of removeAfterEligibleProposals
    /// should member not participate in vote in order to be removed from the management group
    uint256 public removeAfterNonParticipatingProposals;
    /// Number of days for which member is removed from the management group
    uint256 public removeForDays;

    /// Modifier for allowing only maintainer to call the method.
    modifier onlyMaintainer {
        require(msg.sender == maintainer, "only maintainer");
        _;
    }

    /**
     * Initializes the contract with default parameters.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        Governed(_governanceSettings, _initialGovernance)
        AddressUpdatable(_addressUpdater)
    { }

    /**
     * Sets maintainer of this contract.
     * @param _newMaintainer Address identifying the maintainer address.
     * @dev Only governance can call this.
     */
    function setMaintainer(
        address _newMaintainer
    )
        external onlyGovernance
    {
        require(_newMaintainer != address(0), "zero address");
        maintainer = _newMaintainer;
        emit MaintainerSet(_newMaintainer);
    }

    /**
     @inheritdoc IIPollingManagementGroup
     * @dev Only maintainer can call this.
     */
    function setParameters(
        uint256 _votingDelaySeconds,
        uint256 _votingPeriodSeconds,
        uint256 _thresholdConditionBIPS,
        uint256 _majorityConditionBIPS,
        uint256 _proposalFeeValueWei,
        uint256 _addAfterRewardedEpochs,
        uint256 _addAfterNotChilledEpochs,
        uint256 _removeAfterNotRewardedEpochs,
        uint256 _removeAfterEligibleProposals,
        uint256 _removeAfterNonParticipatingProposals,
        uint256 _removeForDays
    )
        external onlyMaintainer
    {
        require(
            _votingPeriodSeconds > 0 &&
            _thresholdConditionBIPS <= MAX_BIPS &&
            _majorityConditionBIPS <= MAX_BIPS &&
            _majorityConditionBIPS >= 5000 &&
            _addAfterRewardedEpochs > _removeAfterNotRewardedEpochs &&
            _proposalFeeValueWei > 0,
            "invalid parameters"
        );

        votingDelaySeconds = _votingDelaySeconds;
        votingPeriodSeconds = _votingPeriodSeconds;
        thresholdConditionBIPS = _thresholdConditionBIPS;
        majorityConditionBIPS = _majorityConditionBIPS;
        proposalFeeValueWei = _proposalFeeValueWei;
        addAfterRewardedEpochs = _addAfterRewardedEpochs;
        addAfterNotChilledEpochs = _addAfterNotChilledEpochs;
        removeAfterNotRewardedEpochs = _removeAfterNotRewardedEpochs;
        removeAfterEligibleProposals = _removeAfterEligibleProposals;
        removeAfterNonParticipatingProposals = _removeAfterNonParticipatingProposals;
        removeForDays = _removeForDays;

        emit ParametersSet(
            _votingDelaySeconds,
            _votingPeriodSeconds,
            _thresholdConditionBIPS,
            _majorityConditionBIPS,
            _proposalFeeValueWei,
            _addAfterRewardedEpochs,
            _addAfterNotChilledEpochs,
            _removeAfterNotRewardedEpochs,
            _removeAfterEligibleProposals,
            _removeAfterNonParticipatingProposals,
            _removeForDays
        );
    }

    /**
     * @inheritdoc IIPollingManagementGroup
     * @dev This operation can only be performed through a maintainer
     * (mostly used for manually adding KYCed voters).
     */
    function changeManagementGroupMembers(
        address[] memory _votersToAdd,
        address[] memory _votersToRemove
    )
        external onlyMaintainer
    {
        for (uint256 i = 0; i < _votersToRemove.length; i++) {
            address voterToRemove = _votersToRemove[i];
            require(managementGroupMembers.index[voterToRemove] != 0,
                "voter is not a member of the management group");
            _removeMember(voterToRemove);
        }
        uint24 currentRewardEpoch = flareSystemsManager.getCurrentRewardEpochId();
        for (uint256 i = 0; i < _votersToAdd.length; i++) {
            address voterToAdd = _votersToAdd[i];
            require(managementGroupMembers.index[voterToAdd] == 0,
                "voter is already a member of the management group");
            _addMember(voterToAdd, currentRewardEpoch);
        }
    }

    /**
     * @inheritdoc IIPollingManagementGroup
     * @dev Can only be called by maintainer.
     */
    function proposeWithSettings(
        string memory _description,
        ProposalSettings memory _settings
    )
        external onlyMaintainer
        returns (uint256 _proposalId)
    {
        require(
            _settings.votingPeriodSeconds > 0 &&
            _settings.thresholdConditionBIPS <= MAX_BIPS &&
            _settings.majorityConditionBIPS <= MAX_BIPS &&
            _settings.majorityConditionBIPS >= 5000,
            "invalid parameters"
        );
        _proposalId = _createProposal(_description, msg.sender, _settings);
    }

    /**
     * @inheritdoc IPollingManagementGroup
     * @dev Can only be called by members of the management group or their proxies.
     * @dev Caller needs to pay a `proposalFeeValueWei` fee to create a proposal.
     */
    function propose(
        string memory _description
    )
        external payable returns (uint256 _proposalId)
    {
        // only management group member (or his proxy address) can submit a proposal
        address proposer = _getOperatingAccount(msg.sender);
        require(_canPropose(proposer), "submitter is not eligible to submit a proposal");

        require(proposalFeeValueWei == msg.value, "proposal fee invalid");

        ProposalSettings memory settings = ProposalSettings({
            accept: true,
            votingStartTs: block.timestamp + votingDelaySeconds,
            votingPeriodSeconds: votingPeriodSeconds,
            thresholdConditionBIPS: thresholdConditionBIPS,
            majorityConditionBIPS: majorityConditionBIPS
        });

        _proposalId = _createProposal(_description, proposer, settings);

        //slither-disable-next-line arbitrary-send-eth
        BURN_ADDRESS.transfer(msg.value);
    }

    /**
     * @inheritdoc IPollingManagementGroup
     * @dev Can be called by proposer of the proposal or its proxy only before voting starts.
     */
    function cancel(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];

        require(!proposal.canceled, "proposal is already canceled");
        require(proposal.proposer == _getOperatingAccount(msg.sender),
            "proposal can only be canceled by its proposer or his proxy address");
        require(block.timestamp < proposal.voteStartTime, "proposal can only be canceled before voting starts");

        proposal.canceled = true;

        emit ProposalCanceled(_proposalId);
    }

    /**
     * @inheritdoc IPollingManagementGroup
     * @dev Can only be called by members of the management group and their proxies for active proposals.
     */
    function castVote(
        uint256 _proposalId,
        uint8 _support
    )
        external
    {
        Proposal storage proposal = proposals[_proposalId];
        require(_state(_proposalId, proposal) == ProposalState.Active, "proposal not active");

        address voterAccount = _getOperatingAccount(msg.sender);

        // check if a voter is eligible to cast a vote
        require(_canVote(voterAccount, _proposalId), "address is not eligible to cast a vote");

        ProposalVoting storage voting = _storeVote(_proposalId, voterAccount, _support);

        emit VoteCast(voterAccount, _proposalId, _support, voting.forVotePower, voting.againstVotePower);
    }

    /**
     * @inheritdoc IPollingManagementGroup
     * @dev An address can be proxy only for a single address (voter).
     */
    function setProxyVoter(
        address _proxyVoter
    )
        external
    {
        address currentProxy = voterToProxy[msg.sender];
        delete proxyToVoter[currentProxy];
        if (_proxyVoter != address(0)) { // update only if not removing proxy
            require(proxyToVoter[_proxyVoter] == address(0), "address is already a proxy of some voter");
            proxyToVoter[_proxyVoter] = msg.sender;
        }
        voterToProxy[msg.sender] = _proxyVoter;
        emit ProxyVoterSet(msg.sender, _proxyVoter);
    }

    /**
     * @inheritdoc IPollingManagementGroup
     */
    function addMember() external {
        // if msg.sender is proxy and is not member of the group, he is adding his voter
        address voter = _getOperatingAccount(msg.sender);
        require(managementGroupMembers.index[voter] == 0, "voter is already a member of the management group");

        uint24 currentRewardEpoch = flareSystemsManager.getCurrentRewardEpochId();

        // check if voter was removed from the management group in the last days
        if (block.timestamp < memberRemovedAtTs[voter] + removeForDays * DAY_TO_SECOND) {
            revert("recently removed");
        }

        // check if voter was chilled in last reward epochs
        if (voterRegistry.chilledUntilRewardEpochId(bytes20(voter)) + addAfterNotChilledEpochs >= currentRewardEpoch) {
            revert("recently chilled");
        }

        // check if voter was receiving rewards in all of the last initialised reward epochs
        uint24 epoch = currentRewardEpoch;
        uint256 initialisedEpochs = 0;
        while (epoch > 0 && initialisedEpochs < addAfterRewardedEpochs) {
            epoch--;
            address delegationAddress = _getDelegationAddress(voter, epoch);
            require(delegationAddress != voter, "delegation address not set");
            // check if voter received rewards in the epoch and if it was initialised
            (bool rewardsZero, bool initialised) = _rewardsZero(delegationAddress, epoch);
            if (rewardsZero && initialised) {
                // voter didn't receive rewards
                revert("no rewards");
            } else if (initialised) {
                // count initialised epochs
                initialisedEpochs++;
            }
        }
        // not enough initialised epochs to add a voter
        if (initialisedEpochs < addAfterRewardedEpochs) {
            revert("not enough initialised epochs");
        }

        _addMember(voter, currentRewardEpoch);
    }

    /**
     * @inheritdoc IPollingManagementGroup
     */
    function removeMember(address _voter) external {
        require(managementGroupMembers.index[_voter] != 0, "voter is not a member of the management group");

        uint24 currentRewardEpoch = flareSystemsManager.getCurrentRewardEpochId();

        //// check if voter was chilled in last reward epochs
        if (voterRegistry.chilledUntilRewardEpochId(bytes20(_voter)) + addAfterNotChilledEpochs >=
            currentRewardEpoch) {
            _removeMember(_voter);
            return;
        }

        //// check if voter didn't receive rewards in the last initialised reward epochs
        if (currentRewardEpoch > memberAddedAtRewardEpoch[_voter] + removeAfterNotRewardedEpochs) {
            bool removeVoter = true;
            uint24 epoch = currentRewardEpoch;
            uint256 initialisedEpochs = 0;
            while (epoch > 0 && initialisedEpochs < removeAfterNotRewardedEpochs) {
                epoch--;
                // only check back to the epoch when voter was added
                if (epoch < memberAddedAtRewardEpoch[_voter]) {
                    removeVoter = false;
                    break;
                }
                address delegationAddress = _getDelegationAddress(_voter, epoch);
                // no check that delegationAddress != _voter - if updated, we should still be able to remove a member
                // check if voter received rewards in the epoch and if it was initialised
                (bool rewardsZero, bool initialised) = _rewardsZero(delegationAddress, epoch);
                if (!rewardsZero) { // initialised = true
                    // voter received rewards
                    removeVoter = false;
                    break;
                } else if (initialised) {
                    // count initialised epochs
                    initialisedEpochs++;
                }
            }
            // not enough initialised epochs to remove voter
            if (initialisedEpochs < removeAfterNotRewardedEpochs) {
                removeVoter = false;
            }
            // voter didn't receive any rewards
            if (removeVoter) {
                _removeMember(_voter);
                return;
            }
        }

        //// check if voter didn't participate in past proposals
        uint256 lastProposalId = idCounter;
        uint256 firstProposalId = memberAddedAtProposal[_voter];
        uint256 didNotVote = 0;         // number of proposals in which voter didn't participate
        uint256 relevantProposals = 0;  // finished proposals where quorum was met

        // check if there are enough proposals to remove member
        if (lastProposalId - firstProposalId >= removeAfterEligibleProposals) {
            for (uint256 id = lastProposalId; id > firstProposalId; id--) {
                // enough relevant proposals have already been found
                if (relevantProposals == removeAfterEligibleProposals) {
                    break;
                }

                // check if vote for proposal ended and if quorum was met
                Proposal storage proposal = proposals[id];
                ProposalState proposalState = _state(id, proposal);
                if (_quorum(id, proposal) && (proposalState == ProposalState.Defeated ||
                    proposalState == ProposalState.Succeeded)) {
                    relevantProposals += 1;
                    if (!hasVoted(id, _voter)) {
                        didNotVote += 1;
                    }
                    if (didNotVote >= removeAfterNonParticipatingProposals) {
                        _removeMember(_voter);
                        return;
                    }
                }
            }
        }
        revert("cannot remove member");
    }

    /**
     * @inheritdoc IPollingManagementGroup
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
        )
    {
        Proposal storage proposal = proposals[_proposalId];
        _description = proposal.description;
        _proposer = proposal.proposer;
        _accept = proposal.accept;
        _voteStartTime = proposal.voteStartTime;
        _voteEndTime = proposal.voteEndTime;
        _thresholdConditionBIPS = proposal.thresholdConditionBIPS;
        _majorityConditionBIPS = proposal.majorityConditionBIPS;
        _noOfEligibleMembers = proposal.noOfEligibleMembers;
    }

    /**
     * @inheritdoc IPollingManagementGroup
     */
    function getProposalDescription(
        uint256 _proposalId
    )
        external view
        returns (
            string memory _description
        )
    {
        Proposal storage proposal = proposals[_proposalId];
        _description = proposal.description;
    }

    /**
     * @inheritdoc IPollingManagementGroup
     */
    function getLastProposal() external view
        returns (
            uint256 _proposalId,
            string memory _description
        )
    {
        _proposalId = idCounter;
        Proposal storage proposal = proposals[_proposalId];
        _description = proposal.description;
    }

    /**
     * Returns list of current management group members.
     * @return _list List of management group members.
     */
    function getManagementGroupMembers() external view returns (address[] memory _list) {
        _list = managementGroupMembers.list;
    }

    /**
     * @inheritdoc IPollingManagementGroup
     */
    function canPropose(address _voter) external view returns (bool) {
        return _canPropose(_getOperatingAccount(_voter));
    }

    /**
     * @inheritdoc IPollingManagementGroup
     */
    function isMember(address _voter) external view returns (bool) {
        return managementGroupMembers.index[_getOperatingAccount(_voter)] != 0;
    }

    /**
     * @inheritdoc IPollingManagementGroup
     */
    function canVote(address _voter, uint256 _proposalId) external view returns (bool) {
        return _canVote(_getOperatingAccount(_voter), _proposalId);
    }

    /**
     * @inheritdoc IPollingManagementGroup
     */
    function state(uint256 _proposalId) public view returns (ProposalState) {
        return _state(_proposalId, proposals[_proposalId]);
    }

    /**
     * @inheritdoc IPollingManagementGroup
     */
    function hasVoted(uint256 _proposalId, address _voter) public view returns (bool) {
        return proposalVotings[_proposalId].hasVoted[_getOperatingAccount(_voter)];
    }

    /**
     * @inheritdoc IPollingManagementGroup
     */
    function getProposalVotes(
        uint256 _proposalId
    )
        public view
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
     * Creates a new proposal with the given description and settings.
     * @param _description String description of the proposal.
     * @param _proposer Address of the proposer.
     * @param _settings Settings of the proposal.
     * @return _proposalId Unique identifier of the proposal.
     */
    function _createProposal(
        string memory _description,
        address _proposer,
        ProposalSettings memory _settings
    )
        internal
        returns (uint256 _proposalId)
    {
        idCounter += 1;
        _proposalId = idCounter;
        Proposal storage proposal = proposals[_proposalId];

        // store proposal
        proposal.proposer = _proposer;
        proposal.voteStartTime = Math.max(block.timestamp, _settings.votingStartTs);
        proposal.voteEndTime = proposal.voteStartTime + _settings.votingPeriodSeconds;
        proposal.thresholdConditionBIPS = _settings.thresholdConditionBIPS;
        proposal.majorityConditionBIPS = _settings.majorityConditionBIPS;
        proposal.description = _description;
        address[] memory members = managementGroupMembers.list;
        proposal.noOfEligibleMembers = members.length;
        proposal.accept = _settings.accept;

        for (uint256 i = 0; i < members.length ; i++) {
            proposal.isEligible[members[i]] = true;
        }

        emit ManagementGroupProposalCreated(
            _proposalId,
            proposal.proposer,
            _description,
            proposal.voteStartTime,
            proposal.voteEndTime,
            _settings.thresholdConditionBIPS,
            _settings.majorityConditionBIPS,
            members,
            _settings.accept
        );
    }

    /**
     * Adds a voter to the list of the management group members.
     * @param _voterToAdd Address to add to the list.
     * @param _currentRewardEpoch Current reward epoch.
     * Emits a ManagementGroupMemberAdded event
     */
    function _addMember(
        address _voterToAdd,
        uint256 _currentRewardEpoch
    )
        internal
    {
        managementGroupMembers.add(_voterToAdd);
        // id of the last created proposal
        memberAddedAtProposal[_voterToAdd] = idCounter;
        memberAddedAtRewardEpoch[_voterToAdd] = _currentRewardEpoch;
        delete memberRemovedAtTs[_voterToAdd];
        emit ManagementGroupMemberAdded(_voterToAdd);
    }

    /**
     * Removes a voter from the list of the management group members.
     * @param _voterToRemove Address to remove from the list.
     * Emits a ManagementGroupMemberRemoved event.
     */
    function _removeMember(
        address _voterToRemove
    )
        internal
    {
        managementGroupMembers.remove(_voterToRemove);
        delete memberAddedAtProposal[_voterToRemove];
        delete memberAddedAtRewardEpoch[_voterToRemove];
        memberRemovedAtTs[_voterToRemove] = block.timestamp;
        emit ManagementGroupMemberRemoved(_voterToRemove);
    }


    /**
     * Stores a proposal vote.
     * @param _proposalId Id of the proposal.
     * @param _voter Address of the voter.
     * @param _support Parameter indicating the vote type.
     */
    function _storeVote(
        uint256 _proposalId,
        address _voter,
        uint8 _support
    )
        internal returns (ProposalVoting storage _voting)
    {
        _voting = proposalVotings[_proposalId];

        require(!_voting.hasVoted[_voter], "vote already cast");
        _voting.hasVoted[_voter] = true;

        if (_support == uint8(VoteType.Against)) {
            _voting.againstVotePower += 1;
        } else if (_support == uint8(VoteType.For)) {
            _voting.forVotePower += 1;
        } else {
            revert("invalid value for enum VoteType");
        }
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
        voterRegistry = IIVoterRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "VoterRegistry"));
        flareSystemsManager = IIFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        rewardManager = IRewardManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
        entityManager = IEntityManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "EntityManager"));
    }

    /**
     * Determines if a quorum has been reached.
     * @param _proposalId Id of a proposal.
     * @return True if quorum has been reached, false otherwise.
     */
    function _quorum(uint256 _proposalId, Proposal storage _proposal) internal view returns(bool) {
        (uint256 forVotes, uint256 againstVotes) = getProposalVotes(_proposalId);
        return forVotes + againstVotes >=
            _proposal.thresholdConditionBIPS.mulDivRoundUp(_proposal.noOfEligibleMembers, MAX_BIPS);
    }

    /**
     * Determines operating account.
     * @param _account Address of a queried account.
     * @return Address of a queried account or its voter if queried account is proxy.
     */
    function _getOperatingAccount(address _account) internal view returns (address) {
        if (_account == maintainer) {
            return _account;
        }
        // _account is member of the management group
        if (managementGroupMembers.index[_account] != 0) {
            return _account;
        }
        // _account is proxy voter for a management group member
        address voter = proxyToVoter[_account];
        if (voter != address(0)) {
            return voter;
        }
        return _account;
    }

    /**
     * Determines if a voter can create a proposal.
     * @param _voter Address of a queried voter.
     * @return True if a queried voter can propose, false otherwise.
     */
    function _canPropose(address _voter) internal view returns (bool) {
        return managementGroupMembers.index[_voter] != 0;
    }

    /**
     * Determines if a voter can vote for a given proposal.
     * @param _voter Address of a queried voter.
     * @param _proposalId Id of a queried proposal.
     * @return True if a voter is eligible to vote, and false otherwise.
     */
    function _canVote(address _voter, uint256 _proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[_proposalId];
        return proposal.isEligible[_voter];
    }

    /**
     * Returns the current state of a proposal.
     * @param _proposalId Id of the proposal.
     * @param _proposal Proposal object.
     * @return ProposalState enum.
     */
    function _state(
        uint256 _proposalId,
        Proposal storage _proposal
    )
        internal view returns (ProposalState)
    {
        if (_proposal.canceled) {
            return ProposalState.Canceled;
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
            return ProposalState.Succeeded;
        }
        return ProposalState.Defeated;
    }

    /**
     * Determines if a proposal has been successful.
     * @param _proposalId Id of the proposal.
     * @param _proposal Proposal object.
     * @return True if proposal succeeded and false otherwise.
     */
    function _proposalSucceeded(uint256 _proposalId, Proposal storage _proposal) internal view virtual returns (bool) {
        ProposalVoting storage voting = proposalVotings[_proposalId];

        if (voting.forVotePower + voting.againstVotePower <
            _proposal.thresholdConditionBIPS.mulDivRoundUp(_proposal.noOfEligibleMembers, MAX_BIPS)) {
            return !_proposal.accept;
        }

        if ((_proposal.accept ? voting.forVotePower : voting.againstVotePower) <=
            _proposal.majorityConditionBIPS.mulDiv(voting.forVotePower + voting.againstVotePower, MAX_BIPS)) {
            return !_proposal.accept;
        }
        return _proposal.accept;
    }

    /**
     * Determines if rewards are zero for a given voter's delegation address and reward epoch.
     * @param _delegationAddress Voter's delegation address.
     * @param _rewardEpochId Id of a queried reward epoch.
     * @return _zero False if rewards are not zero, true otherwise, even if rewards are not initialised.
     * @return _initialised True if rewards are initialised, false otherwise.
     */
    function _rewardsZero(address _delegationAddress, uint24 _rewardEpochId)
        internal view
        returns (bool _zero, bool _initialised)
    {
        IRewardManager.UnclaimedRewardState memory rewardState = rewardManager.getUnclaimedRewardState(
            _delegationAddress, _rewardEpochId, RewardsV2Interface.ClaimType.WNAT);
        if (rewardState.initialised) {
            return (false, true);
        } else {
            _zero = true;
            uint256 noOfWeightBasedClaims = flareSystemsManager.noOfWeightBasedClaims(
                _rewardEpochId, rewardManager.rewardManagerId());
            if (noOfWeightBasedClaims == 0) {
                _initialised = flareSystemsManager.rewardsHash(_rewardEpochId) != bytes32(0);
            } else {
                _initialised = rewardManager.noOfInitialisedWeightBasedClaims(_rewardEpochId) >= noOfWeightBasedClaims;

            }
        }
    }

    /**
     * Returns delegation address of a voter for a given epoch.
     * @param _voter Address of the voter.
     * @param _epoch Epoch id.
     * @return Delegation address of the voter for the given epoch.
     */
    function _getDelegationAddress(address _voter, uint24 _epoch)
        internal view returns (address)
    {
        uint256 votePowerBlock = flareSystemsManager.getVotePowerBlock(_epoch);
        return entityManager.getDelegationAddressOfAt(_voter, votePowerBlock);
    }
}
