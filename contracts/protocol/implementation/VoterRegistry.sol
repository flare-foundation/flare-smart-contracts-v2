// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/userInterfaces/IPChainStakeMirror.sol";
import "../interface/IWNat.sol";
import "../interface/ICChainStake.sol";
import "./EntityManager.sol";
import "./FlareSystemManager.sol";
import "../../governance/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * Only addresses registered in this contract can vote.
 */
contract VoterRegistry is Governed, AddressUpdatable {

    struct VotersAndWeights {
        address[] voters;
        mapping (address => uint256) weights;
        uint128 weightsSum;
        uint16 normalisedWeightsSum;
    }

    struct VoterData {
        uint256 weight;
        uint256 wNatWeight;
        uint256 cChainStakeWeight;
        bytes20[] nodeIds;
        uint256[] nodeWeights;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    uint256 internal constant UINT16_MAX = type(uint16).max;
    uint256 internal constant UINT256_MAX = type(uint256).max;

    /// Maximum number of voters in the register.
    uint256 public maxVoters;

    /// In case of providing bad votes (e.g. ftso collusion), the voter can be chilled for a few reward epochs.
    /// A voter can register again from a returned reward epoch onwards.
    mapping(address => uint256) public chilledUntilRewardEpochId;

    // mapping: rewardEpochId => list of registered voters and their weights
    mapping(uint256 => VotersAndWeights) internal register;

    // mapping: rewardEpochId => block number of new signing policy initialisation start
    mapping(uint256 => uint256) public newSigningPolicyInitializationStartBlockNumber;

    // Addresses of the external contracts.
    FlareSystemManager public flareSystemManager;
    EntityManager public entityManager;
    IPChainStakeMirror public pChainStakeMirror;
    IWNat public wNat;
    ICChainStake public cChainStake;
    bool public cChainStakeEnabled;

    event VoterChilled(address voter, uint256 untilRewardEpochId);
    event VoterRemoved(address voter, uint256 rewardEpochId);
    event VoterRegistered(
        address voter,
        uint256 rewardEpochId,
        address signingPolicyAddress,
        address delegationAddress,
        address submitAddress,
        address submitSignaturesAddress,
        uint256 weight,
        uint256 wNatWeight,
        uint256 cChainStakeWeight,
        bytes20[] nodeIds,
        uint256[] nodeWeights
    );

    /// Only FlareSystemManager contract can call this method.
    modifier onlyFlareSystemManager {
        require(msg.sender == address(flareSystemManager), "only flare system manager");
        _;
    }

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint256 _maxVoters,
        uint256 _firstRewardEpochId,
        address[] memory _initialVoters,
        uint16[] memory _initialNormalisedWeights
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        require(_maxVoters <= UINT16_MAX, "_maxVoters too high");
        maxVoters = _maxVoters;

        uint256 length = _initialVoters.length;
        require(length > 0 && length <= _maxVoters, "_initialVoters length invalid");
        require(length == _initialNormalisedWeights.length, "array lengths do not match");
        VotersAndWeights storage votersAndWeights = register[_firstRewardEpochId];
        uint16 weightsSum = 0;
        for (uint256 i = 0; i < length; i++) {
            votersAndWeights.voters.push(_initialVoters[i]);
            votersAndWeights.weights[_initialVoters[i]] = _initialNormalisedWeights[i];
            weightsSum += _initialNormalisedWeights[i];
        }
        votersAndWeights.weightsSum = weightsSum;
        votersAndWeights.normalisedWeightsSum = weightsSum;
    }

    /**
     * Register voter
     */
    function registerVoter(address _voter, Signature calldata _signature) external {
        uint256 untilRewardEpochId = chilledUntilRewardEpochId[_voter];
        uint32 nextRewardEpochId = flareSystemManager.getCurrentRewardEpochId() + 1;
        require(untilRewardEpochId == 0 || untilRewardEpochId <= nextRewardEpochId, "voter chilled");
        bytes32 messageHash = keccak256(abi.encode(nextRewardEpochId, _voter));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address signingPolicyAddress = ECDSA.recover(signedMessageHash, _signature.v, _signature.r, _signature.s);
        uint256 initBlock = newSigningPolicyInitializationStartBlockNumber[nextRewardEpochId];
        EntityManager.VoterAddresses memory voterAddresses = entityManager.getVoterAddresses(_voter, initBlock);
        require(signingPolicyAddress == voterAddresses.signingPolicyAddress, "invalid signature");
        bool success = _registerVoter(_voter, voterAddresses, nextRewardEpochId);
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
        uint256 currentRewardEpochId = flareSystemManager.getCurrentRewardEpochId();
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
        require(_maxVoters <= UINT16_MAX, "_maxVoters too high");
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
     * Sets new signing policy initialisation start block number
     */
    function setNewSigningPolicyInitializationStartBlockNumber(uint256 _rewardEpochId)
        external onlyFlareSystemManager
    {
        // this is only called once from FlareSystemManager
        assert(newSigningPolicyInitializationStartBlockNumber[_rewardEpochId] == 0);
        newSigningPolicyInitializationStartBlockNumber[_rewardEpochId] = block.number;
    }

    /**
     * Creates signing policy snapshot and returns the list of registered signing policy addresses
     * and normalised weights for a given reward epoch
     */
    function createSigningPolicySnapshot(uint256 _rewardEpochId)
        external onlyFlareSystemManager
        returns (
            address[] memory _signingPolicyAddresses,
            uint16[] memory _normalisedWeights,
            uint16 _normalisedWeightsSum
        )
    {
        VotersAndWeights storage votersAndWeights = register[_rewardEpochId];
        uint256 length = votersAndWeights.voters.length;
        assert(length > 0);
        address[] memory voters = new address[](length);
        uint256[] memory weights = new uint256[](length);
        uint256 weightsSum = 0;
        for (uint256 i = 0; i < length; i++) {
            voters[i] = votersAndWeights.voters[i];
            weights[i] = votersAndWeights.weights[voters[i]];
            weightsSum += weights[i];
        }

        // get signing policy addresses
        _signingPolicyAddresses = entityManager.getSigningPolicyAddresses(voters,
            newSigningPolicyInitializationStartBlockNumber[_rewardEpochId]);

        _normalisedWeights = new uint16[](length);
        // normalisation of weights
        for (uint256 i = 0; i < length; i++) {
            _normalisedWeights[i] = uint16(weights[i] * UINT16_MAX / weightsSum); // weights[i] <= weightsSum
            _normalisedWeightsSum += _normalisedWeights[i];
        }

        votersAndWeights.weightsSum = uint128(weightsSum);
        votersAndWeights.normalisedWeightsSum = _normalisedWeightsSum;
    }

    /**
     * Returns the list of registered voters for a given reward epoch
     */
    function getRegisteredVoters(uint256 _rewardEpochId) external view returns (address[] memory) {
        return register[_rewardEpochId].voters;
    }

    /**
     * Returns the list of registered voters' data provider addresses for a given reward epoch
     */
    function getRegisteredSubmitAddresses(
        uint256 _rewardEpochId
    )
        external view
        returns (address[] memory)
    {
        return entityManager.getSubmitAddresses(register[_rewardEpochId].voters,
            newSigningPolicyInitializationStartBlockNumber[_rewardEpochId]);
    }

    /**
     * Returns the list of registered voters' deposit signatures addresses for a given reward epoch
     */
    function getRegisteredSubmitSignaturesAddresses(
        uint256 _rewardEpochId
    )
        external view
        returns (address[] memory _signingPolicyAddresses)
    {
        return entityManager.getSubmitSignaturesAddresses(register[_rewardEpochId].voters,
            newSigningPolicyInitializationStartBlockNumber[_rewardEpochId]);
    }

    /**
     * Returns the list of registered voters' signing policy addresses for a given reward epoch
     */
    function getRegisteredSigningPolicyAddresses(
        uint256 _rewardEpochId
    )
        external view
        returns (address[] memory _signingPolicyAddresses)
    {
        return entityManager.getSigningPolicyAddresses(register[_rewardEpochId].voters,
            newSigningPolicyInitializationStartBlockNumber[_rewardEpochId]);
    }

    /**
     * Returns the number of registered voters for a given reward epoch
     */
    function getNumberOfRegisteredVoters(uint256 _rewardEpochId) external view returns (uint256) {
        return register[_rewardEpochId].voters.length;
    }

    /**
     * Returns voter's address and normalised weight for a given reward epoch and signing policy address
     */
    function getVoterWithNormalisedWeight(
        uint256 _rewardEpochId,
        address _signingPolicyAddress
    )
        external view
        returns (
            address _voter,
            uint16 _normalisedWeight
        )
    {
        uint256 weightsSum = register[_rewardEpochId].weightsSum;
        require(weightsSum > 0, "reward epoch id not supported");
        _voter = entityManager.getVoterForSigningPolicyAddress(_signingPolicyAddress,
            newSigningPolicyInitializationStartBlockNumber[_rewardEpochId]);
        uint256 weight = register[_rewardEpochId].weights[_voter];
        require(weight > 0, "voter not registered");
        _normalisedWeight = uint16(weight * UINT16_MAX / weightsSum);
    }

    function isVoterRegistered(address _voter, uint256 _rewardEpochId) external view returns(bool) {
        return register[_rewardEpochId].weights[_voter] > 0;
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
        flareSystemManager = FlareSystemManager(_getContractAddress(
            _contractNameHashes, _contractAddresses, "FlareSystemManager"));
        entityManager = EntityManager(_getContractAddress(_contractNameHashes, _contractAddresses, "EntityManager"));
        pChainStakeMirror = IPChainStakeMirror(_getContractAddress(
            _contractNameHashes, _contractAddresses, "PChainStakeMirror"));
        if (cChainStakeEnabled) {
            cChainStake = ICChainStake(_getContractAddress(_contractNameHashes, _contractAddresses, "CChainStake"));
        }
        wNat = IWNat(_getContractAddress(_contractNameHashes, _contractAddresses, "WNat"));
    }

    /**
     * Request to register `_voter` account - implementation.
     */
    function _registerVoter(
        address _voter,
        EntityManager.VoterAddresses memory _voterAddresses,
        uint256 _rewardEpochId
    )
        internal returns(bool)
    {

        (uint256 votePowerBlock, bool enabled) = flareSystemManager.getVoterRegistrationData(_rewardEpochId);
        require(votePowerBlock != 0, "vote power block zero");
        require(enabled, "voter registration phase ended");
        VoterData memory voterData = _getVoterData(_voter, _voterAddresses.delegationAddress, votePowerBlock);
        require(voterData.weight > 0, "voter weight zero");

        VotersAndWeights storage votersAndWeights = register[_rewardEpochId];

        // check if _voter already registered
        if (votersAndWeights.weights[_voter] > 0) {
            return true;
        }


        uint256 length = votersAndWeights.voters.length;

        if (length < maxVoters) {
            // we can just add a new one
            votersAndWeights.voters.push(_voter);
            votersAndWeights.weights[_voter] = voterData.weight;
        } else {
            // find minimum to kick out (if needed)
            uint256 minIndex = 0;
            uint256 minIndexWeight = UINT256_MAX;

            for (uint256 i = 0; i < length; i++) {
                address voter = votersAndWeights.voters[i];
                uint256 voterWeight = votersAndWeights.weights[voter];
                if (minIndexWeight > voterWeight) {
                    minIndexWeight = voterWeight;
                    minIndex = i;
                }
            }

            if (minIndexWeight >= voterData.weight) {
                // _voter has the lowest weight among all
                return false;
            }

            // kick the minIndex out and replace it with _voter
            address removedVoter = votersAndWeights.voters[minIndex];
            delete votersAndWeights.weights[removedVoter];
            votersAndWeights.voters[minIndex] = _voter;
            votersAndWeights.weights[_voter] = voterData.weight;
            emit VoterRemoved(removedVoter, _rewardEpochId);
        }

        emit VoterRegistered(
            _voter,
            _rewardEpochId,
            _voterAddresses.signingPolicyAddress,
            _voterAddresses.delegationAddress,
            _voterAddresses.submitAddress,
            _voterAddresses.submitSignaturesAddress,
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
        address _wNatDelegationAddress,
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


        _data.wNatWeight = wNat.votePowerOfAt(_wNatDelegationAddress, _votePowerBlock);

        // staking is required to get additional WNat weight
        if (_data.weight > 0) {
            uint256 totalWNatVotePower = wNat.totalVotePowerAt(_votePowerBlock); // TODO cap?
            _data.weight += _data.wNatWeight / 4; // TODO final factor and cap?
        }
    }
}
