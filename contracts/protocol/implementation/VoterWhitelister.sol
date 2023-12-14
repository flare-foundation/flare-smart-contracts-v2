// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/userInterfaces/IPChainStakeMirror.sol";
import "../interface/IWNat.sol";
import "../interface/ICChainStake.sol";
import "./EntityManager.sol";
import "./Finalisation.sol";
import "../../governance/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";

/**
 * Only addresses registered in this contract can vote.
 */
contract VoterWhitelister is Governed, AddressUpdatable {

    struct VoterInfo {
        address voter; // entity
        address signingAddress;
        address dataProviderAddress;
        uint256 weight;
    }

    struct VoterWithNormalisedWeight {
        address voter; // entity
        uint16 weight;
    }

    struct VoterData {
        uint256 weight;
        uint256 wNatWeight;
        uint256 cChainStakeWeight;
        bytes20[] nodeIds;
        uint256[] nodeWeights;
    }

    uint256 internal constant UINT16_MAX = type(uint16).max;
    uint256 internal constant UINT256_MAX = type(uint256).max;

    /// Maximum number of voters in the whitelist.
    uint256 public maxVoters;

    /// In case of providing bad votes (e.g. ftso collusion), the voter can be chilled for a few reward epochs.
    /// A voter can whitelist again from a returned reward epoch onwards.
    mapping(address => uint256) public chilledUntilRewardEpochId;

    // mapping: rewardEpochId => list of whitelisted voters for each reward epoch
    mapping(uint256 => VoterInfo[]) internal whitelist;

    // mapping: rewardEpochId => mapping: signing address => voter with normalised weight
    mapping(uint256 => mapping(address => VoterWithNormalisedWeight)) internal epochSigningAddressToVoter;
    mapping(uint256 => mapping(address => address)) internal epochVoterToSigningAddress;

    // Addresses of the external contracts.
    Finalisation public finalisation;
    EntityManager public entityManager;
    IPChainStakeMirror public pChainStakeMirror;
    IWNat public wNat;
    ICChainStake public cChainStake;
    bool public cChainStakeEnabled;

    event VoterChilled(address voter, uint256 untilRewardEpochId);
    event VoterRemoved(address voter, uint256 rewardEpochId);
    event VoterWhitelisted(
        address voter,
        uint256 rewardEpochId,
        address signingAddress,
        address dataProviderAddress,
        uint256 weight,
        uint256 wNatWeight,
        uint256 cChainStakeWeight,
        bytes20[] nodeIds,
        uint256[] nodeWeights
    );

    /// Only Finalisation contract can call this method.
    modifier onlyFinalisation {
        require (msg.sender == address(finalisation), "only finalisation");
        _;
    }

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint256 _maxVoters,
        uint256 _firstRewardEpochId,
        address[] memory _initialVoters
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        maxVoters = _maxVoters;

        uint256 length = _initialVoters.length;
        uint16 normalisedWeight = uint16(UINT16_MAX / length);
        for (uint256 i = 0; i < length; i++) {
            address voter = _initialVoters[i];
            epochSigningAddressToVoter[_firstRewardEpochId][voter] =
                VoterWithNormalisedWeight(voter, normalisedWeight);
            epochVoterToSigningAddress[_firstRewardEpochId][voter] = voter;
        }
    }

    /**
     * Request to whitelist voter
     */
    function requestWhitelisting(address _voter) external {
        address signingAddress = entityManager.getSigningAddress(_voter);
        require (signingAddress == msg.sender, "invalid signing address for voter");
        uint256 untilRewardEpochId = chilledUntilRewardEpochId[_voter];
        uint256 nextRewardEpochId = finalisation.getCurrentRewardEpochId() + 1;
        require(untilRewardEpochId == 0 || untilRewardEpochId <= nextRewardEpochId, "voter chilled");
        bool success = _requestWhitelistingVoter(_voter, signingAddress, nextRewardEpochId);
        require(success, "vote power too low");
    }

    /**
     * @dev Only governance can call this method.
     */
    function chillVoter(
        address _voter,
        uint256 _noOfRewardEpochIds
    )
        external onlyGovernance
        returns(
            uint256 _untilRewardEpochId
        )
    {
        uint256 currentRewardEpochId = finalisation.getCurrentRewardEpochId();
        _untilRewardEpochId = currentRewardEpochId + _noOfRewardEpochIds;
        chilledUntilRewardEpochId[_voter] = _untilRewardEpochId;
        emit VoterChilled(_voter, _untilRewardEpochId);
    }

    /**
     * Sets the max number of voters.
     * @dev Only governance can call this method.
     */
    function setMaxVoters(
        uint256 _maxVoters
    )
        external onlyGovernance
    {
        maxVoters = _maxVoters;
    }

    /**
     * Enables C-Chain stakes.
     * @dev Only governance can call this method.
     */
    function enableCChainStake() external onlyGovernance {
        cChainStakeEnabled = true;
    }

    /**
     * Creates signing policy snapshot and returns the list of whitelisted signing addresses
       and normalised weights for a given reward epoch
     */
    function createSigningPolicySnapshot(uint256 _rewardEpochId)
        external onlyFinalisation
        returns (
            address[] memory _signingAddresses,
            uint16[] memory _normalisedWeights,
            uint16 _normalisedWeightsSum
        )
    {
        VoterInfo[] storage voters = whitelist[_rewardEpochId];
        uint256 length = voters.length;
        assert(length > 0);
        _signingAddresses = new address[](length);
        _normalisedWeights = new uint16[](length);
        uint256[] memory weights = new uint256[](length);
        uint256 weightsSum = 0;
        for (uint256 i = 0; i < length; i++) {
            VoterInfo storage voter = voters[i];
            _signingAddresses[i] = voter.signingAddress;
            weights[i] = voter.weight;
            weightsSum += weights[i];
        }

        // normalisation of weights
        for (uint256 i = 0; i < length; i++) {
            _normalisedWeights[i] = uint16(weights[i] * UINT16_MAX / weightsSum); // weights[i] <= weightsSum
            _normalisedWeightsSum += _normalisedWeights[i];
            address voter = voters[i].voter;
            epochVoterToSigningAddress[_rewardEpochId][_signingAddresses[i]] = voter;
            epochSigningAddressToVoter[_rewardEpochId][_signingAddresses[i]] =
                VoterWithNormalisedWeight(voter, _normalisedWeights[i]);
        }
    }

    /**
     * Returns the list of whitelisted voters for a given reward epoch
     */
    function getWhitelistedVoters(uint256 _rewardEpochId) external view returns (VoterInfo[] memory) {
        return whitelist[_rewardEpochId];
    }

    /**
     * Returns the list of whitelisted data provider addresses for a given reward epoch
     */
    function getWhitelistedDataProviderAddresses(
        uint256 _rewardEpochId
    )
        external view
        returns (address[] memory _dataProviderAddresses)
    {
        VoterInfo[] storage voters = whitelist[_rewardEpochId];
        uint256 length = voters.length;
        _dataProviderAddresses = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            _dataProviderAddresses[i] = voters[i].dataProviderAddress;
        }
    }

    /**
     * Returns the list of whitelisted signing addresses for a given reward epoch
     */
    function getWhitelistedSigningAddresses(
        uint256 _rewardEpochId
    )
        external view
        returns (address[] memory _signingAddresses)
    {
        VoterInfo[] storage voters = whitelist[_rewardEpochId];
        uint256 length = voters.length;
        _signingAddresses = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            _signingAddresses[i] = voters[i].signingAddress;
        }
    }

    /**
     * Returns the number of whitelisted voters for a given reward epoch
     */
    function getNumberOfWhitelistedVoters(uint256 _rewardEpochId) external view returns (uint256) {
        return whitelist[_rewardEpochId].length;
    }

    /**
     * Returns voter's address and normalised weight for a given reward epoch and signing address
     */
    function getVoterWithNormalisedWeight(
        uint256 _rewardEpochId,
        address _signingAddress
    )
        external view
        returns (
            address _voter,
            uint16 _normalisedWeight
        )
    {
        VoterWithNormalisedWeight storage data = epochSigningAddressToVoter[_rewardEpochId][_signingAddress];
        _voter = data.voter;
        _normalisedWeight = data.weight;
    }

    /**
     * Returns voter's signing address
     */
    function getVoterSigningAddress(
        uint256 _rewardEpochId,
        address _voter
    )
        external view
        returns (
            address _signingAddress
        )
    {
        return epochVoterToSigningAddress[_rewardEpochId][_voter];
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        finalisation = Finalisation(_getContractAddress(_contractNameHashes, _contractAddresses, "Finalisation"));
        entityManager = EntityManager(_getContractAddress(_contractNameHashes, _contractAddresses, "EntityManager"));
        pChainStakeMirror = IPChainStakeMirror(_getContractAddress(
            _contractNameHashes, _contractAddresses, "PChainStakeMirror"));
        if (cChainStakeEnabled) {
            cChainStake = ICChainStake(_getContractAddress(_contractNameHashes, _contractAddresses, "CChainStake"));
        }
        wNat = IWNat(_getContractAddress(_contractNameHashes, _contractAddresses, "WNat"));
    }

    /**
     * Request to whitelist `_voter` account - implementation.
     */
    function _requestWhitelistingVoter(
        address _voter,
        address _signingAddress,
        uint256 _rewardEpochId
    )
        internal returns(bool)
    {

        (uint256 votePowerBlock, bool enabled) = finalisation.getVoterRegistrationData(_rewardEpochId);
        require (votePowerBlock != 0, "vote power block zero");
        require (enabled, "voter registration phase ended");
        VoterData memory voterData = _getVoterData(_voter, votePowerBlock);
        require (voterData.weight > 0, "voter weight zero");

        VoterInfo[] storage addressesForRewardEpochId = whitelist[_rewardEpochId];
        uint256 length = addressesForRewardEpochId.length;

        bool isListFull = length >= maxVoters; // length > maxVoters could happen if maxVoters value was reduced
        uint256 minIndex = 0;
        uint256 minIndexWeight = UINT256_MAX;

        // check if it contains _voter and find minimum to kick out (if needed)
        for (uint256 i = 0; i < length; i++) {
            VoterInfo storage voter = addressesForRewardEpochId[i];
            if (voter.voter == _voter) {
                // _voter is already whitelisted, return
                return true;
            } else if (isListFull && minIndexWeight > voter.weight) { // TODO optimize reading?
                minIndexWeight = voter.weight;
                minIndex = i;
            }
        }

        if (isListFull && minIndexWeight >= voterData.weight) {
            // _voter has the lowest weight among all
            return false;
        }

        address dataProviderAddress = entityManager.getDataProviderAddress(_voter);
        if (isListFull) {
            // kick the minIndex out and replace it with _voter
            address removedVoter = addressesForRewardEpochId[minIndex].voter;
            addressesForRewardEpochId[minIndex] =
                VoterInfo(_voter, _signingAddress, dataProviderAddress, voterData.weight);
            emit VoterRemoved(removedVoter, _rewardEpochId);
        } else {
            // we can just add a new one
            addressesForRewardEpochId.push(VoterInfo(_voter, _signingAddress, dataProviderAddress, voterData.weight));
        }

        emit VoterWhitelisted(
            _voter,
            _rewardEpochId,
            _signingAddress,
            dataProviderAddress,
            voterData.weight,
            voterData.wNatWeight,
            voterData.cChainStakeWeight,
            voterData.nodeIds,
            voterData.nodeWeights
        );

        return true;
    }

    function _getVoterData(
        address _voter,
        uint256 _votePowerBlock
    )
        private view
        returns (VoterData memory _data)
    {
        _data.nodeIds = entityManager.getNodeIdsOfAt(_voter, _votePowerBlock);
        uint256 length = _data.nodeIds.length;
        _data.nodeWeights = new uint256[](length);
        uint256[] memory votePowers = pChainStakeMirror.batchVotePowerOfAt(_data.nodeIds, _votePowerBlock);
        for (uint256 i = 0; i < length; i++) {
            _data.nodeWeights[i] = votePowers[i];
            _data.weight += votePowers[i];
        }

        uint256 totalPChainStakeVotePower = pChainStakeMirror.totalVotePowerAt(_votePowerBlock); // TODO cap?

        if (address(cChainStake) != address(0)) {
            _data.cChainStakeWeight = cChainStake.votePowerOfAt(_voter, _votePowerBlock);
            uint256 totalCChainStakeVotePower = cChainStake.totalVotePowerAt(_votePowerBlock); // TODO cap?
            _data.weight += _data.cChainStakeWeight;
        }


        _data.wNatWeight = wNat.votePowerOfAt(_voter, _votePowerBlock);

        // staking is required to get additinal WNat weight
        if (_data.weight > 0) {
            uint256 totalWNatVotePower = wNat.totalVotePowerAt(_votePowerBlock); // TODO cap?
            _data.weight += _data.wNatWeight / 4; // TODO final factor and cap?
        }
    }
}
