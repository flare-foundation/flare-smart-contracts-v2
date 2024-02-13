// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../userInterfaces/IPollingFtso.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../protocol/interface/IIVoterRegistry.sol";
import "../../protocol/interface/IIFlareSystemsManager.sol";
import "../../utils/lib/SafePct.sol";
import "./Governed.sol";

/**
 * @title Polling FTSO
 * A contract enables registered voters to create proposals and vote on them.
 */
//solhint-disable-next-line max-states-count
contract PollingFtso is IPollingFtso, AddressUpdatable, Governed {
    using SafePct for uint256;

    uint256 internal constant MAX_BIPS = 1e4;
    address payable constant internal BURN_ADDRESS = payable(0x000000000000000000000000000000000000dEaD);

    mapping(uint256 proposalId => Proposal) internal proposals;
    mapping(uint256 proposalId => ProposalVoting) internal proposalVotings;
    mapping(address voter => address proxy) public voterToProxy;
    mapping(address proxy => address voter) public proxyToVoter;

    // address of voter registry contract
    IIVoterRegistry public voterRegistry;
    // address of flare systems manager contract
    IIFlareSystemsManager public flareSystemsManager;

    //// voting parameters
    // period between proposal creation and start of the vote, in seconds
    uint256 public votingDelaySeconds;
    // length of voting period in seconds
    uint256 public votingPeriodSeconds;
    // share of total vote power (in BIPS) required to participate in vote for proposal to pass
    uint256 public thresholdConditionBIPS;
    // share of participating vote power (in BIPS) required to vote in favor for proposal to pass
    uint256 public majorityConditionBIPS;
    // fee value (in wei) that proposer must pay to submit a proposal
    uint256 public proposalFeeValueWei;

    // number of created proposals
    uint256 public idCounter = 0;
    // maintainer of this contract; can change parameters and create proposals
    address public maintainer;

    modifier onlyMaintainer {
        require(msg.sender == maintainer, "only maintainer");
        _;
    }

    /**
     * Initializes the contract with default parameters
     * @param _governanceSettings           The address of the GovernanceSettings contract
     * @param _initialGovernance            The initial governance address
     * @param _addressUpdater               Address identifying the address updater contract
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        Governed(_governanceSettings, _initialGovernance)
        AddressUpdatable(_addressUpdater)
    {
    }

    /**
     * Sets maintainer of this contract
     * @param _newMaintainer                Address identifying the maintainer address
     * @dev Only governance can call this
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
     * Sets (or changes) contract's parameters. It is called after deployment of the contract
     * and every time one of the parameters changes
     * @dev Only maintainer can call this
     */
    function setParameters(
        uint256 _votingDelaySeconds,
        uint256 _votingPeriodSeconds,
        uint256 _thresholdConditionBIPS,
        uint256 _majorityConditionBIPS,
        uint256 _proposalFeeValueWei
    )
        external override onlyMaintainer
    {
        require(
            _votingPeriodSeconds > 0 &&
            _thresholdConditionBIPS <= MAX_BIPS &&
            _majorityConditionBIPS <= MAX_BIPS &&
            _majorityConditionBIPS >= 5000,
            "invalid parameters"
        );

        votingDelaySeconds = _votingDelaySeconds;
        votingPeriodSeconds = _votingPeriodSeconds;
        thresholdConditionBIPS = _thresholdConditionBIPS;
        majorityConditionBIPS = _majorityConditionBIPS;
        proposalFeeValueWei = _proposalFeeValueWei;

        emit ParametersSet(
            _votingDelaySeconds,
            _votingPeriodSeconds,
            _thresholdConditionBIPS,
            _majorityConditionBIPS,
            _proposalFeeValueWei
        );
    }

    /**
     * Creates a new proposal
     * @param _description          String description of the proposal
     * @return _proposalId          Unique identifier of the proposal
     * Emits a FtsoProposalCreated event
     * @dev Can only be called by currently registered voters, their proxies or the maintainer of the contract
     * @dev Caller needs to pay a `proposalFeeValueWei` fee to create a proposal
     */
    function propose(
        string memory _description
    )
        external payable override returns (uint256 _proposalId)
    {
        uint256 currentRewardEpochId = _getCurrentRewardEpochId();

        // registered voter (or its proxy address) and maintainer can submit a proposal
        (address proposerAccount, bool registered) = _getOperatingAccount(msg.sender, currentRewardEpochId);
        require(_canPropose(msg.sender, registered), "submitter is not eligible to submit a proposal");

        require(proposalFeeValueWei == msg.value, "proposal fee invalid");

        idCounter += 1;
        _proposalId = idCounter;
        Proposal storage proposal = proposals[_proposalId];

        // store proposal
        proposal.rewardEpochId = currentRewardEpochId;
        proposal.description = _description;
        proposal.proposer = proposerAccount;
        proposal.voteStartTime = block.timestamp + votingDelaySeconds;
        proposal.voteEndTime = proposal.voteStartTime + votingPeriodSeconds;
        proposal.thresholdConditionBIPS = thresholdConditionBIPS;
        proposal.majorityConditionBIPS = majorityConditionBIPS;
        (proposal.totalWeight, , ) = voterRegistry.getWeightsSums(currentRewardEpochId);

        emit FtsoProposalCreated(
            _proposalId,
            currentRewardEpochId,
            proposal.proposer,
            _description,
            proposal.voteStartTime,
            proposal.voteEndTime,
            proposal.thresholdConditionBIPS,
            proposal.majorityConditionBIPS,
            proposal.totalWeight
        );

        //slither-disable-next-line arbitrary-send-eth
        BURN_ADDRESS.transfer(msg.value);
    }

    /**
     * Cancels an existing proposal
     * @param _proposalId           Unique identifier of a proposal
     * Emits a ProposalCanceled event
     * @dev Can be called by proposer of the proposal or its proxy only before voting starts
     */
    function cancel(uint256 _proposalId) external override {
        Proposal storage proposal = proposals[_proposalId];

        require(!proposal.canceled, "proposal is already canceled");
        (address operatingAccount, ) = _getOperatingAccount(msg.sender, proposal.rewardEpochId);
        require(proposal.proposer == operatingAccount,
            "proposal can only be canceled by its proposer or his proxy address");
        require(block.timestamp < proposal.voteStartTime, "proposal can only be canceled before voting starts");

        proposal.canceled = true;

        emit ProposalCanceled(_proposalId);
    }

    /**
     * Casts a vote on a proposal
     * @param _proposalId           Id of the proposal
     * @param _support              A value indicating vote type (against, for)
     * Emits a VoteCast event
     * @dev Can only be called for active proposals by registered voters at the time that proposal was created
     and their proxies
     */
    function castVote(
        uint256 _proposalId,
        uint8 _support
    )
        external override
    {
        Proposal storage proposal = proposals[_proposalId];
        require(_state(_proposalId, proposal) == ProposalState.Active, "proposal not active");

        (address voterAccount, bool registered) = _getOperatingAccount(msg.sender, proposal.rewardEpochId);

        // check if an account is eligible to cast a vote (voter needs to be registered)
        require(registered, "address is not eligible to cast a vote");

        ProposalVoting storage voting = _storeVote(_proposalId, voterAccount, _support, proposal.rewardEpochId);

        emit VoteCast(voterAccount, _proposalId, _support, voting.forVotePower, voting.againstVotePower);
    }

    /**
     * Sets a proxy voter for a voter (i.e. address that can vote in its name)
     * @param _proxyVoter           Address to register as a proxy (use address(0) to remove proxy)
     * Emits a ProxyVoterSet event
     * @dev An address can be proxy only for a single address (member)
     */
    function setProxyVoter(
        address _proxyVoter
    )
        external override
    {
        address currentProxy = voterToProxy[msg.sender];
        delete proxyToVoter[currentProxy];
        if (_proxyVoter != address(0)) { // update only if not removing proxy
            require(proxyToVoter[_proxyVoter] == address(0),
                "address is already a proxy of some voter");
            proxyToVoter[_proxyVoter] = msg.sender;
        }
        voterToProxy[msg.sender] = _proxyVoter;
        emit ProxyVoterSet(msg.sender, _proxyVoter);
    }

    /**
     * Returns information about the specified proposal
     * @param _proposalId               Id of the proposal
     * @return _rewardEpochId           Reward epoch id
     * @return _description             Description of the proposal
     * @return _proposer                Address of the proposal submitter
     * @return _voteStartTime           Start time (in seconds from epoch) of the proposal voting
     * @return _voteEndTime             End time (in seconds from epoch) of the proposal voting
     * @return _thresholdConditionBIPS  Number of votes (voter power) cast required for the proposal to pass
     * @return _majorityConditionBIPS   Number of FOR votes, as a percentage in BIPS of the
     *                                  total cast votes, required for the proposal to pass
     * @return _totalWeight             Total weight of all eligible voters
     */
    function getProposalInfo(
        uint256 _proposalId
    )
        external view override
        returns (
            uint256 _rewardEpochId,
            string memory _description,
            address _proposer,
            uint256 _voteStartTime,
            uint256 _voteEndTime,
            uint256 _thresholdConditionBIPS,
            uint256 _majorityConditionBIPS,
            uint256 _totalWeight
        )
    {
        Proposal storage proposal = proposals[_proposalId];
        _rewardEpochId = proposal.rewardEpochId;
        _description = proposal.description;
        _proposer = proposal.proposer;
        _voteStartTime = proposal.voteStartTime;
        _voteEndTime = proposal.voteEndTime;
        _thresholdConditionBIPS = proposal.thresholdConditionBIPS;
        _majorityConditionBIPS = proposal.majorityConditionBIPS;
        _totalWeight = proposal.totalWeight;
    }

    /**
     * Returns the description string that was provided when the specified proposal was created
     * @param _proposalId               Id of the proposal
     * @return _description             Description of the proposal
     */
    function getProposalDescription(
        uint256 _proposalId
    )
        external view override
        returns (
            string memory _description
        )
    {
        Proposal storage proposal = proposals[_proposalId];
        _description = proposal.description;
    }

    /**
     * Returns id and description of the last created proposal
     * @return _proposalId              Id of the last proposal
     * @return _description             Description of the last proposal
     */
    function getLastProposal() external view override
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
     * Returns whether an account can create proposals
     * An address can make proposals if it is registered voter,
     * its proxy or the maintainer of the contract
     * @param _account              Address of the queried account
     * @return True if the queried account can create a proposal, false otherwise
     */
    function canPropose(address _account) external view override returns (bool) {
        (, bool registered) = _getOperatingAccount(_account, _getCurrentRewardEpochId());
        return _canPropose(_account, registered);
    }

    /**
     * Returns whether an account can vote for a given proposal
     * @param _account              Address of the queried account
     * @param _proposalId           Id of the queried proposal
     * @return True if account is eligible to vote, false otherwise
     */
    function canVote(address _account, uint256 _proposalId) external view override returns (bool) {
        Proposal storage proposal = proposals[_proposalId];
        (, bool registered) = _getOperatingAccount(_account, proposal.rewardEpochId);
        return registered;
    }

    /**
     * Returns the current state of a proposal
     * @param _proposalId           Id of the proposal
     * @return ProposalState enum
     */
    function state(uint256 _proposalId) public view override returns (ProposalState) {
        return _state(_proposalId, proposals[_proposalId]);
    }

    /**
     * Returns whether a voter has cast a vote on a specific proposal
     * @param _proposalId           Id of the proposal
     * @param _voter                Address of the voter
     * @return True if the voter has cast a vote on the proposal, false otherwise
     */
    function hasVoted(uint256 _proposalId, address _voter) public view override returns (bool) {
        return proposalVotings[_proposalId].hasVoted[_voter];
    }

    /**
     * Returns number of votes for and against the specified proposal
     * @param _proposalId           Id of the proposal
     * @return _for                 Accumulated vote power for the proposal
     * @return _against             Accumulated vote power against the proposal
     */
    function getProposalVotes(
        uint256 _proposalId
    )
        public view override
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
     * Stores a proposal vote
     * @param _proposalId           Id of the proposal
     * @param _voter                Address of the voter
     * @param _support              Parameter indicating the vote type
     */
    function _storeVote(
        uint256 _proposalId,
        address _voter,
        uint8 _support,
        uint256 _rewardEpochId
    )
        internal returns (ProposalVoting storage _voting)
    {
        _voting = proposalVotings[_proposalId];

        require(!_voting.hasVoted[_voter], "vote already cast");
        _voting.hasVoted[_voter] = true;

        if (_support == uint8(VoteType.Against)) {
            _voting.againstVotePower += voterRegistry.getVoterRegistrationWeight(_voter, _rewardEpochId);
        } else if (_support == uint8(VoteType.For)) {
            _voting.forVotePower += voterRegistry.getVoterRegistrationWeight(_voter, _rewardEpochId);
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
    }

    /**
     * Determines operating account and whether it is a registered voter
     * @param _account              Address of a queried account
     * @return Address of a queried account or its voter if queried account is a proxy
     * @return True if voter is registered, false otherwise
     */
    function _getOperatingAccount(address _account, uint256 _rewardEpochId) internal view returns (address, bool) {
        if (_account == maintainer) {
            return (_account, false);
        }
        // account is registered voter
        if (_isVoterRegistered(_account, _rewardEpochId)) {
            return (_account, true);
        }
        // account is proxy voter for a voter
        address voter = proxyToVoter[_account];
        if (voter != address(0)) {
            return _isVoterRegistered(voter, _rewardEpochId) ? (voter, true) : (voter, false);
        }
        // account is not a proxy and is not a registered voter
        return (_account, false);
    }

    /**
     * Determines if an account can create a proposal
     * @param _account              Address of a queried account
     * @return True if a queried account can propose, false otherwise
     */
    function _canPropose(address _account, bool _registered) internal view returns (bool) {
        return  _registered || _account == maintainer;
    }

    /**
     * Returns the current state of a proposal
     * @param _proposalId           Id of the proposal
     * @param _proposal             Proposal object
     * @return ProposalState enum
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
     * Determines if a proposal has been successful
     * @param _proposalId           Id of the proposal
     * @param _proposal             Proposal
     * @return True if proposal succeeded, false otherwise
     */
    function _proposalSucceeded(uint256 _proposalId, Proposal storage _proposal) internal view virtual returns (bool) {
        ProposalVoting storage voting = proposalVotings[_proposalId];

        if (voting.forVotePower + voting.againstVotePower <
            _proposal.thresholdConditionBIPS.mulDivRoundUp(_proposal.totalWeight, MAX_BIPS)) {
            return false;
        }

        if (voting.forVotePower <=
            _proposal.majorityConditionBIPS.mulDiv(voting.forVotePower + voting.againstVotePower, MAX_BIPS)) {
            return false;
        }

        return true;
    }

    /**
     * Returns current reward epoch id.
     */
    function _getCurrentRewardEpochId() internal view returns (uint24) {
        return flareSystemsManager.getCurrentRewardEpochId();
    }

    /**
     * Determines if a voter is registered for a specific reward epoch
     * @param _voter                Address of the voter
     * @param _rewardEpochId        Reward epoch id
     * @return True if the voter is registered, and false otherwise
     */
    function _isVoterRegistered(address _voter, uint256 _rewardEpochId) internal view returns(bool) {
        return voterRegistry.isVoterRegistered(_voter, _rewardEpochId);
    }

}
