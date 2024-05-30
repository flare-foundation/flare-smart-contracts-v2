// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IIEntityManager.sol";
import "../interface/IIFlareSystemsCalculator.sol";
import "../interface/IIVoterRegistry.sol";
import "../interface/IIFlareSystemsManager.sol";
import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../utils/lib/SafePct.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * VoterRegistry contract.
 * Only addresses registered in this contract can vote.
 */
contract VoterRegistry is Governed, AddressUpdatable, IIVoterRegistry {
    using SafePct for uint256;

    /// Voter registration data.
    struct VotersAndWeights {
        address[] voters;
        mapping (address voter => uint256) weights;
        uint128 weightsSum;
        uint16 normalisedWeightsSum;
        uint16 normalisedWeightsSumOfVotersWithPublicKeys;
    }

    uint256 internal constant UINT16_MAX = type(uint16).max;
    uint256 internal constant UINT256_MAX = type(uint256).max;

    /// Maximum number of voters in one reward epoch.
    uint256 public maxVoters;

    /// In case of providing bad votes (e.g. ftso collusion), the beneficiary can be chilled for a few reward epochs.
    /// If beneficiary is chilled, the vote power assigned to it is zero.
    mapping(bytes20 beneficiary => uint256) public chilledUntilRewardEpochId;

    // mapping: rewardEpochId => list of registered voters and their weights
    mapping(uint256 rewardEpochId => VotersAndWeights) internal register;

    // mapping: rewardEpochId => block number of new signing policy initialisation start
    /// Snapshot of the voters' addresses for a given reward epoch.
    mapping(uint256 rewardEpochId => uint256) public newSigningPolicyInitializationStartBlockNumber;

    // Addresses of the external contracts.
    /// The FlareSystemsManager contract.
    IIFlareSystemsManager public flareSystemsManager;
    /// The EntityManager contract.
    IIEntityManager public entityManager;
    /// The FlareSystemsCalculator contract.
    IIFlareSystemsCalculator public flareSystemsCalculator;

    /// The address of the system registration contract.
    address public systemRegistrationContractAddress;
    /// Indicates if the voter must have the public key set when registering.
    bool public publicKeyRequired;

    /// Only FlareSystemsManager contract can call this method.
    modifier onlyFlareSystemsManager {
        require(msg.sender == address(flareSystemsManager), "only flare system manager");
        _;
    }

    /// Only system registration contract can call this method.
    modifier onlySystemRegistrationContract {
        require(msg.sender == systemRegistrationContractAddress, "only system registration contract");
        _;
    }

    /**
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     * @param _maxVoters The maximum number of voters in one reward epoch.
     * @param _initialRewardEpochId The initial reward epoch id.
     * @param _initialVoters The initial voters' addresses.
     * @param _initialRegistrationWeights The initial voters' registration weights.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint256 _maxVoters,
        uint256 _initialRewardEpochId,
        uint256 _intitialNewSigningPolicyInitializationStartBlockNumber,
        uint16 _initialNormalisedWeightsSumOfVotersWithPublicKeys,
        address[] memory _initialVoters,
        uint256[] memory _initialRegistrationWeights
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        require(_maxVoters <= UINT16_MAX, "_maxVoters too high");
        maxVoters = _maxVoters;

        uint256 length = _initialVoters.length;
        require(length > 0 && length <= _maxVoters, "_initialVoters length invalid");
        require(length == _initialRegistrationWeights.length, "array lengths do not match");
        require(_intitialNewSigningPolicyInitializationStartBlockNumber < block.number,
            "_intitialNewSigningPolicyInitializationStartBlockNumber invalid");
        newSigningPolicyInitializationStartBlockNumber[_initialRewardEpochId] =
            _intitialNewSigningPolicyInitializationStartBlockNumber;
        VotersAndWeights storage votersAndWeights = register[_initialRewardEpochId];
        uint256 weightsSum = 0;
        uint16 normalisedWeightsSum = 0;
        for (uint256 i = 0; i < length; i++) {
            votersAndWeights.voters.push(_initialVoters[i]);
            votersAndWeights.weights[_initialVoters[i]] = _initialRegistrationWeights[i];
            weightsSum += _initialRegistrationWeights[i];
        }
        for (uint256 i = 0; i < length; i++) {
            // _initialRegistrationWeights[i] <= weightsSum
            normalisedWeightsSum += uint16((_initialRegistrationWeights[i] * UINT16_MAX) / weightsSum);
        }

        require(_initialNormalisedWeightsSumOfVotersWithPublicKeys <= normalisedWeightsSum,
            "_initialNormalisedWeightsSumOfVotersWithPublicKeys invalid");
        votersAndWeights.weightsSum = uint128(weightsSum);
        votersAndWeights.normalisedWeightsSum = normalisedWeightsSum;
        votersAndWeights.normalisedWeightsSumOfVotersWithPublicKeys =
            _initialNormalisedWeightsSumOfVotersWithPublicKeys;
    }

    /**
     * @inheritdoc IVoterRegistry
     */
    function registerVoter(address _voter, Signature calldata _signature) external {
        (uint24 rewardEpochId, IIEntityManager.VoterAddresses memory voterAddresses) = _getRegistrationData(_voter);
        // check signature
        bytes32 messageHash = keccak256(abi.encode(rewardEpochId, _voter));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address signingPolicyAddress = ECDSA.recover(signedMessageHash, _signature.v, _signature.r, _signature.s);
        require(signingPolicyAddress == voterAddresses.signingPolicyAddress, "invalid signature");
        // register voter
        _registerVoter(_voter, rewardEpochId, voterAddresses);
    }

    /**
     * @inheritdoc IIVoterRegistry
     */
    function systemRegistration(address _voter) external onlySystemRegistrationContract {
        (uint24 rewardEpochId, IIEntityManager.VoterAddresses memory voterAddresses) = _getRegistrationData(_voter);
        // register voter
        _registerVoter(_voter, rewardEpochId, voterAddresses);
    }

    /**
     * Chills beneficiaries for a given number of reward epochs.
     * @param _beneficiaryList The list of beneficiaries to chill.
     * @param _noOfRewardEpochs The number of reward epochs to chill the voter for.
     * @dev Only governance can call this method.
     */
    function chill(
        bytes20[] calldata _beneficiaryList,
        uint256 _noOfRewardEpochs
    )
        external onlyGovernance
        returns(
            uint256 _untilRewardEpochId
        )
    {
        uint256 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        _untilRewardEpochId = currentRewardEpochId + _noOfRewardEpochs + 1;
        for(uint256 i = 0; i < _beneficiaryList.length; i++) {
            chilledUntilRewardEpochId[_beneficiaryList[i]] = _untilRewardEpochId;
            emit BeneficiaryChilled(_beneficiaryList[i], _untilRewardEpochId);
        }
    }

    /**
     * Sets the max number of voters.
     * @dev Only governance can call this method.
     */
    function setMaxVoters(uint256 _maxVoters) external onlyGovernance {
        require(_maxVoters <= UINT16_MAX, "_maxVoters too high");
        require(_maxVoters >= flareSystemsManager.signingPolicyMinNumberOfVoters(), "_maxVoters too low");
        maxVoters = _maxVoters;
    }

    /**
     * Sets system registration contract.
     * @dev Only governance can call this method.
     */
    function setSystemRegistrationContractAddress(address _systemRegistrationContractAddress) external onlyGovernance {
        systemRegistrationContractAddress = _systemRegistrationContractAddress;
    }

    /**
     * Sets if the voter must have the public key set when registering.
     * @dev Only governance can call this method.
     */
    function setPublicKeyRequired(bool _publicKeyRequired) external onlyGovernance {
        publicKeyRequired = _publicKeyRequired;
    }

    /**
     * @inheritdoc IIVoterRegistry
     */
    function setNewSigningPolicyInitializationStartBlockNumber(uint256 _rewardEpochId)
        external onlyFlareSystemsManager
    {
        // this is only called once from FlareSystemsManager
        assert(newSigningPolicyInitializationStartBlockNumber[_rewardEpochId] == 0);
        newSigningPolicyInitializationStartBlockNumber[_rewardEpochId] = block.number;
    }

    /**
     * @inheritdoc IIVoterRegistry
     */
    function createSigningPolicySnapshot(uint256 _rewardEpochId)
        external onlyFlareSystemsManager
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

        // get public keys of voters
        (bytes32[] memory parts1, bytes32[] memory parts2) = entityManager.getPublicKeys(voters,
            newSigningPolicyInitializationStartBlockNumber[_rewardEpochId]);

        _normalisedWeights = new uint16[](length);
        uint16 normalisedWeightsSumOfVotersWithPublicKeys = 0;
        // normalisation of weights
        for (uint256 i = 0; i < length; i++) {
            _normalisedWeights[i] = uint16((weights[i] * UINT16_MAX) / weightsSum); // weights[i] <= weightsSum
            _normalisedWeightsSum += _normalisedWeights[i];
            if (parts1[i] != bytes32(0) || parts2[i] != bytes32(0)) {
                normalisedWeightsSumOfVotersWithPublicKeys += _normalisedWeights[i];
            }
        }

        votersAndWeights.weightsSum = uint128(weightsSum);
        votersAndWeights.normalisedWeightsSum = _normalisedWeightsSum;
        votersAndWeights.normalisedWeightsSumOfVotersWithPublicKeys = normalisedWeightsSumOfVotersWithPublicKeys;
    }

    /**
     * @inheritdoc IVoterRegistry
     */
    function getRegisteredVoters(uint256 _rewardEpochId) external view returns (address[] memory) {
        return register[_rewardEpochId].voters;
    }

    /**
     * @inheritdoc IVoterRegistry
     */
    function getNumberOfRegisteredVoters(uint256 _rewardEpochId) external view returns (uint256) {
        return register[_rewardEpochId].voters.length;
    }

    /**
     * @inheritdoc IIVoterRegistry
     */
    function getRegisteredDelegationAddresses(
        uint256 _rewardEpochId
    )
        external view
        returns (address[] memory _delegationAddresses)
    {
        require(register[_rewardEpochId].weightsSum > 0, "reward epoch id not supported");
        return entityManager.getDelegationAddresses(register[_rewardEpochId].voters,
            flareSystemsManager.getVotePowerBlock(_rewardEpochId));
    }

    /**
     * @inheritdoc IIVoterRegistry
     */
    function getRegisteredSubmitAddresses(
        uint256 _rewardEpochId
    )
        external view
        returns (address[] memory)
    {
        require(register[_rewardEpochId].weightsSum > 0, "reward epoch id not supported");
        return entityManager.getSubmitAddresses(register[_rewardEpochId].voters,
            newSigningPolicyInitializationStartBlockNumber[_rewardEpochId]);
    }

    /**
     * @inheritdoc IIVoterRegistry
     */
    function getRegisteredSubmitSignaturesAddresses(
        uint256 _rewardEpochId
    )
        external view
        returns (address[] memory _signingPolicyAddresses)
    {
        require(register[_rewardEpochId].weightsSum > 0, "reward epoch id not supported");
        return entityManager.getSubmitSignaturesAddresses(register[_rewardEpochId].voters,
            newSigningPolicyInitializationStartBlockNumber[_rewardEpochId]);
    }

    /**
     * @inheritdoc IIVoterRegistry
     */
    function getRegisteredSigningPolicyAddresses(
        uint256 _rewardEpochId
    )
        external view
        returns (address[] memory _signingPolicyAddresses)
    {
        require(register[_rewardEpochId].weightsSum > 0, "reward epoch id not supported");
        return entityManager.getSigningPolicyAddresses(register[_rewardEpochId].voters,
            newSigningPolicyInitializationStartBlockNumber[_rewardEpochId]);
    }

    /**
     * @inheritdoc IIVoterRegistry
     */
    function getRegisteredPublicKeys(
        uint256 _rewardEpochId
    )
        external view
        returns (bytes32[] memory _parts1, bytes32[] memory _parts2)
    {
        require(register[_rewardEpochId].weightsSum > 0, "reward epoch id not supported");
        return entityManager.getPublicKeys(register[_rewardEpochId].voters,
            newSigningPolicyInitializationStartBlockNumber[_rewardEpochId]);
    }

    /**
     * @inheritdoc IIVoterRegistry
     */
    function getRegisteredNodeIds(
        uint256 _rewardEpochId
    )
        external view
        returns (bytes20[][] memory _nodeIds)
    {
        require(register[_rewardEpochId].weightsSum > 0, "reward epoch id not supported");
        return entityManager.getNodeIds(register[_rewardEpochId].voters,
            flareSystemsManager.getVotePowerBlock(_rewardEpochId));
    }

    /**
     * @inheritdoc IIVoterRegistry
     */
    function getRegisteredVotersAndRegistrationWeights(
        uint256 _rewardEpochId
    )
        external view
        returns (
            address[] memory _voters,
            uint256[] memory _registrationWeights
        )
    {
        VotersAndWeights storage votersAndWeights = register[_rewardEpochId];
        _voters = votersAndWeights.voters;
        uint256 length = _voters.length;
        _registrationWeights = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            _registrationWeights[i] = votersAndWeights.weights[_voters[i]];
        }
    }

    /**
     * @inheritdoc IIVoterRegistry
     */
    function getRegisteredVotersAndNormalisedWeights(
        uint256 _rewardEpochId
    )
        external view
        returns (
            address[] memory _voters,
            uint16[] memory _normalisedWeights
        )
    {
        VotersAndWeights storage votersAndWeights = register[_rewardEpochId];
        uint256 weightsSum = votersAndWeights.weightsSum;
        require(weightsSum > 0, "reward epoch id not supported");
        _voters = votersAndWeights.voters;
        uint256 length = _voters.length;
        _normalisedWeights = new uint16[](length);
        for (uint256 i = 0; i < length; i++) {
            _normalisedWeights[i] = uint16((votersAndWeights.weights[_voters[i]] * UINT16_MAX) / weightsSum);
        }
    }

    /**
     * @inheritdoc IIVoterRegistry
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
        VotersAndWeights storage votersAndWeights = register[_rewardEpochId];
        uint256 weightsSum = votersAndWeights.weightsSum;
        require(weightsSum > 0, "reward epoch id not supported");
        _voter = entityManager.getVoterForSigningPolicyAddress(_signingPolicyAddress,
            newSigningPolicyInitializationStartBlockNumber[_rewardEpochId]);
        require(_voter != _signingPolicyAddress, "invalid signing policy address");
        uint256 weight = votersAndWeights.weights[_voter];
        require(weight > 0, "voter not registered");
        _normalisedWeight = uint16((weight * UINT16_MAX) / weightsSum);
    }

    /**
     * @inheritdoc IIVoterRegistry
     */
    function getPublicKeyAndNormalisedWeight(
        uint256 _rewardEpochId,
        address _signingPolicyAddress
    )
        external view
        returns (
            bytes32 _publicKeyPart1,
            bytes32 _publicKeyPart2,
            uint16 _normalisedWeight,
            uint16 _normalisedWeightsSumOfVotersWithPublicKeys
        )
    {
        VotersAndWeights storage votersAndWeights = register[_rewardEpochId];
        uint256 weightsSum = votersAndWeights.weightsSum;
        require(weightsSum > 0, "reward epoch id not supported");
        uint256 initBlock = newSigningPolicyInitializationStartBlockNumber[_rewardEpochId];
        address voter = entityManager.getVoterForSigningPolicyAddress(_signingPolicyAddress, initBlock);
        require(voter != _signingPolicyAddress, "invalid signing policy address");
        uint256 weight = votersAndWeights.weights[voter];
        require(weight > 0, "voter not registered");
        _normalisedWeight = uint16((weight * UINT16_MAX) / weightsSum);
        (_publicKeyPart1, _publicKeyPart2) = entityManager.getPublicKeyOfAt(voter, initBlock);
        _normalisedWeightsSumOfVotersWithPublicKeys = votersAndWeights.normalisedWeightsSumOfVotersWithPublicKeys;
    }

    /**
     * @inheritdoc IIVoterRegistry
     */
    function getVoterRegistrationWeight(
        address _voter,
        uint256 _rewardEpochId
    )
        external view returns (uint256 _registrationWeight)
    {
        _registrationWeight = register[_rewardEpochId].weights[_voter];
        require(_registrationWeight > 0, "voter not registered");
    }

    /**
     * @inheritdoc IIVoterRegistry
     */
    function getVoterNormalisedWeight(
        address _voter,
        uint256 _rewardEpochId
    )
        external view returns (uint16 _normalisedWeight)
    {
        VotersAndWeights storage votersAndWeights = register[_rewardEpochId];
        uint256 weightsSum = votersAndWeights.weightsSum;
        require(weightsSum > 0, "reward epoch id not supported");
        uint256 weight = votersAndWeights.weights[_voter];
        require(weight > 0, "voter not registered");
        _normalisedWeight = uint16((weight * UINT16_MAX) / weightsSum);
    }

    /**
     * @inheritdoc IIVoterRegistry
     */
    function getWeightsSums(uint256 _rewardEpochId)
        external view
        returns (
            uint128 _weightsSum,
            uint16 _normalisedWeightsSum,
            uint16 _normalisedWeightsSumOfVotersWithPublicKeys
        )
    {
        VotersAndWeights storage votersAndWeights = register[_rewardEpochId];
        _weightsSum = votersAndWeights.weightsSum;
        _normalisedWeightsSum = votersAndWeights.normalisedWeightsSum;
        _normalisedWeightsSumOfVotersWithPublicKeys = votersAndWeights.normalisedWeightsSumOfVotersWithPublicKeys;
        require(_weightsSum > 0, "reward epoch id not supported");
    }

    /**
     * @inheritdoc IVoterRegistry
     */
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
        flareSystemsManager = IIFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        entityManager = IIEntityManager(_getContractAddress(_contractNameHashes, _contractAddresses, "EntityManager"));
        flareSystemsCalculator = IIFlareSystemsCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsCalculator"));
    }

    /**
     * Request to register `_voter` account - implementation.
     * @param _voter The voter address.
     * @param _rewardEpochId The reward epoch id.
     * @param _voterAddresses The voter's addresses.
     */
    function _registerVoter(
        address _voter,
        uint24 _rewardEpochId,
        IIEntityManager.VoterAddresses memory _voterAddresses
    )
        internal
    {
        (uint256 votePowerBlock, bool enabled) = flareSystemsManager.getVoterRegistrationData(_rewardEpochId);
        require(votePowerBlock != 0, "vote power block zero");
        require(enabled, "voter registration not enabled");
        require(entityManager.getDelegationAddressOfAt(_voter, votePowerBlock) != _voter,
            "delegation address not set");
        uint256 weight = flareSystemsCalculator.calculateRegistrationWeight(_voter, _rewardEpochId, votePowerBlock);
        require(weight > 0, "voter weight zero");

        (bytes32 publicKeyPart1, bytes32 publicKeyPart2) =
            entityManager.getPublicKeyOfAt(_voter, newSigningPolicyInitializationStartBlockNumber[_rewardEpochId]);
        if (publicKeyRequired && publicKeyPart1 == bytes32(0) && publicKeyPart2 == bytes32(0)) {
            revert("public key required");
        }

        VotersAndWeights storage votersAndWeights = register[_rewardEpochId];

        // check if _voter already registered
        if (votersAndWeights.weights[_voter] > 0) {
            revert("already registered");
        }

        uint256 length = votersAndWeights.voters.length;

        if (length < maxVoters) {
            // we can just add a new one
            votersAndWeights.voters.push(_voter);
            votersAndWeights.weights[_voter] = weight;
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

            if (minIndexWeight >= weight) {
                // _voter has the lowest weight among all
                revert("vote power too low");
            }

            // kick the minIndex out and replace it with _voter
            address removedVoter = votersAndWeights.voters[minIndex];
            delete votersAndWeights.weights[removedVoter];
            votersAndWeights.voters[minIndex] = _voter;
            votersAndWeights.weights[_voter] = weight;
            emit VoterRemoved(removedVoter, _rewardEpochId);
        }

        emit VoterRegistered(
            _voter,
            _rewardEpochId,
            _voterAddresses.signingPolicyAddress,
            _voterAddresses.submitAddress,
            _voterAddresses.submitSignaturesAddress,
            publicKeyPart1,
            publicKeyPart2,
            weight
        );
    }

    /**
     * Returns registration data for a given voter.
     * @param _voter The voter address.
     * @return _rewardEpochId The reward epoch id.
     * @return _voterAddresses The voter's addresses.
     */
    function _getRegistrationData(address _voter)
        internal view
        returns(
            uint24 _rewardEpochId,
            IIEntityManager.VoterAddresses memory _voterAddresses
        )
    {
        _rewardEpochId = flareSystemsManager.getCurrentRewardEpochId() + 1;
        uint256 initBlock = newSigningPolicyInitializationStartBlockNumber[_rewardEpochId];
        require(initBlock != 0, "registration not available yet");
        _voterAddresses = entityManager.getVoterAddressesAt(_voter, initBlock);
        require(_voterAddresses.signingPolicyAddress != _voter, "signing policy address not set");
        require(_voterAddresses.submitAddress != _voter, "submit address not set");
        require(_voterAddresses.submitSignaturesAddress != _voter, "submit signatures address not set");
    }
}
