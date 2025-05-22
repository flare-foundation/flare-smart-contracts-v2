// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeVersionManager.sol";
import "../../userInterfaces/tee/ITeeVerification.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/ftdc/IFtdcHub.sol";
import "../../userInterfaces/ftdc/IFtdcVerification.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../userInterfaces/IRelay.sol";
import "../../utils/lib/AddressSet.sol";
import "../../governance/implementation/GovernedProxyImplementation.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * TeeVerification is used for challenges and availability checks of TEE machines.
 */
contract TeeVerification is ITeeVerification, GovernedProxyImplementation, AddressUpdatable, UUPSUpgradeable {
    using AddressSet for AddressSet.State;


    bytes32 public constant TEE_SOURCE_ID = bytes32("TEE");
    bytes32 public constant REG_OP_TYPE = bytes32("REG");
    bytes32 public constant TEE_ATTESTATION = bytes32("TEE_ATTESTATION");

    /// TEE version manager contract.
    ITeeVersionManager public teeVersionManager;
    /// TEE registry contract.
    ITeeRegistry public teeRegistry;
    /// TEE fee calculator contract.
    ITeeFeeCalculator public teeFeeCalculator;
    /// TEE instructions contract.
    ITeeInstructions public teeInstructions;
    /// Flare TEE data connector contract.
    IFtdcHub public ftdcHub;
    /// FTDC verification contract.
    IFtdcVerification public ftdcVerification;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// Relay contract.
    IRelay public relay;

    /// The TEE availability check validity duration, in seconds.
    /// In order to receive rewards, TEE must be checked for availability at least once in this period.
    uint256 private availabilityCheckValidityDurationSeconds;
    /// Challenge (also availability check proof) validity duration, in seconds.
    /// New challenge can be requested only if the previous one has expired.
    uint256 private challengeValidityDurationSeconds;

    /// registration availability check cosigners and their threshold
    AddressSet.State private cosigners;
    uint64 private cosignersThreshold;

    mapping(address teeId => uint256) private availabilityCheckValidityEndTs;
    mapping(address teeId => uint256) private challenges;
    mapping(address teeId => uint256) private challengeTs;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor()
        GovernedProxyImplementation() AddressUpdatable(address(0))
    { }

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint256 _availabilityCheckValidityDurationSeconds,
        uint256 _challengeValidityDurationSeconds
    )
        external
    {
        GovernedBase.initialise(_governanceSettings, _initialGovernance);
        AddressUpdatable.setAddressUpdaterValue(_addressUpdater);
        _updateSettings(
            _availabilityCheckValidityDurationSeconds,
            _challengeValidityDurationSeconds
        );
    }

    /**
     * @inheritdoc ITeeVerification
     */
    function requestTeeAttestation(
        address _teeId
    )
        external payable
    {
        // check fee
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        require(
            msg.value >= teeFeeCalculator.calculateFeeByTeeIds(REG_OP_TYPE, TEE_ATTESTATION, teeIds),
            "fee too low"
        );

        // get or update the challenge
        uint256 challenge;
        if (challengeTs[_teeId] + challengeValidityDurationSeconds > block.timestamp) {
            challenge = challenges[_teeId];
        } else {
            (uint256 randomNumber,,) = relay.getRandomNumber();
            challenge = uint256(keccak256(abi.encode(_teeId, block.timestamp, randomNumber)));
            challenges[_teeId] = challenge;
            challengeTs[_teeId] = block.timestamp;
        }

        TeeAttestation memory message = TeeAttestation({
            teeMachine: teeRegistry.getTeeMachineWithAttestationData(_teeId),
            challenge: challenge
        });
        bytes32 instructionId = keccak256(abi.encode(
            REG_OP_TYPE, TEE_ATTESTATION, _teeId, challenge
        ));
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = teeRegistry.getTeeMachine(_teeId);
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
            REG_OP_TYPE,
            TEE_ATTESTATION,
            abi.encode(message)
        );
        emit TeeAttestationRequested(_teeId, challenge);
    }

    /**
     * @inheritdoc ITeeVerification
     */
    function requestAvailabilityCheckAttestation(
        address _teeId,
        address _testOnTeeId
    )
        external payable
    {
        require(challengeTs[_teeId] + challengeValidityDurationSeconds > block.timestamp, "challenge expired");
        ITeeRegistry.TeeMachineWithAttestationData memory teeMachine =
            teeRegistry.getTeeMachineWithAttestationData(_teeId);
        ITeeAvailabilityCheck.RequestBody memory requestBody = ITeeAvailabilityCheck.RequestBody({
            teeId: _teeId,
            initialTeeId: teeMachine.initialTeeId,
            url: teeMachine.url,
            platform: teeMachine.platform,
            codeHash: teeMachine.codeHash,
            teeGovernanceHash: teeVersionManager.getTeeGovernanceHash(teeMachine.codeHash),
            rewardEpochId: flareSystemsManager.getCurrentRewardEpochId(),
            challenge: challenges[_teeId]
        });

        address[] memory registrationCosigners = new address[](0);
        uint64 registrationCosignersThreshold = 0;
        if (teeRegistry.getTeeMachineStatus(_teeId) == ITeeRegistry.TeeStatus.INITIALIZED) {
            registrationCosigners = cosigners.list;
            registrationCosignersThreshold = cosignersThreshold;
        }

        address[] memory teeIds = new address[](1);
        teeIds[0] = _testOnTeeId;
        ftdcHub.requestAttestation{value: msg.value}(
            0,
            0,
            teeIds,
            registrationCosigners,
            registrationCosignersThreshold,
            bytes.concat(TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE, TEE_SOURCE_ID, abi.encode(requestBody))
        );
    }

    /**
     * @inheritdoc ITeeVerification
     */
    function confirmAvailability(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
         external
    {
        ITeeAvailabilityCheck.Response calldata data = _proof.data;
        address teeId = data.requestBody.teeId;
        ITeeRegistry.TeeStatus status = teeRegistry.getTeeMachineStatus(teeId);
        require(status == ITeeRegistry.TeeStatus.PRODUCTION, "tee machine not available");

        ITeeRegistry.TeeMachineWithAttestationData memory teeMachine =
            teeRegistry.getTeeMachineWithAttestationData(teeId);
        require(
            teeVersionManager.isCodeHashPlatformSupported(teeMachine.codeHash, teeMachine.platform),
            "version not supported"
        );
        require(
            data.responseBody.status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK &&
            data.responseBody.machineStatus == ITeeAvailabilityCheck.TeeMachineStatus.ACTIVE,
            "AC status invalid"
        );
        _verifyAvailabilityCheckProof(teeMachine, status, _proof);

        // extend the availability check validity
        uint256 endTs = data.timestamp + availabilityCheckValidityDurationSeconds;
        if (endTs > availabilityCheckValidityEndTs[teeId]) {
            availabilityCheckValidityEndTs[teeId] = endTs;
            address owner = teeRegistry.getTeeMachineOwner(teeId);
            emit AvailabilityCheckValidityExtended(teeId, owner, endTs);
        }
    }

    /**
     * @inheritdoc ITeeVerification
     */
    function verifyAvailabilityCheckProof(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
    {
        address teeId = _proof.data.requestBody.teeId;
        ITeeRegistry.TeeStatus status = teeRegistry.getTeeMachineStatus(teeId);
        ITeeRegistry.TeeMachineWithAttestationData memory teeMachine =
            teeRegistry.getTeeMachineWithAttestationData(teeId);
        _verifyAvailabilityCheckProof(teeMachine, status, _proof);
    }

    /**
     * Sets the FTDC cosigners and their threshold used for the TEE machine registration.
     * @param _cosigners The cosigners.
     * @param _cosignersThreshold The cosigners threshold.
     */
    function setCosigners(
        address[] calldata _cosigners,
        uint64 _cosignersThreshold
    )
        external onlyGovernance
    {
        require(
            _cosigners.length >= _cosignersThreshold && (_cosigners.length == 0 || _cosignersThreshold > 0),
            "invalid threshold"
        );
        for (uint256 i = 0; i < _cosigners.length; i++) {
            require(_cosigners[i] != address(0), "invalid cosigner");
            // check for duplicates
            for (uint256 j = 0; j < i; j++) {
                require(_cosigners[j] != _cosigners[i], "duplicated cosigner");
            }
        }
        cosigners.replaceAll(_cosigners);
        cosignersThreshold = _cosignersThreshold;
        emit CosignersSet(_cosigners, _cosignersThreshold);
    }

    /**
     * Update the settings of the TeeAvailability contract.
     * @param _availabilityCheckValidityDurationSeconds The TEE availability check validity duration, in seconds.
     * In order to receive rewards, TEE must be checked for availability at least once in this period.
     * @param _challengeValidityDurationSeconds Challenge validity duration, in seconds.
     */
    function updateSettings(
        uint256 _availabilityCheckValidityDurationSeconds,
        uint256 _challengeValidityDurationSeconds
    )
        external onlyGovernance
    {
        _updateSettings(
            _availabilityCheckValidityDurationSeconds,
            _challengeValidityDurationSeconds
        );
    }

    /**
     * @inheritdoc ITeeVerification
     */
    function getCosigners()
        external view
        returns(address[] memory _cosigners, uint64 _cosignersThreshold)
    {
        _cosigners = cosigners.list;
        _cosignersThreshold = cosignersThreshold;
    }

    /**
     * @inheritdoc ITeeVerification
     */
    function getSettings()
        external view
        returns(
            uint256 _availabilityCheckValidityDurationSeconds,
            uint256 _challengeValidityDurationSeconds
        )
    {
        _availabilityCheckValidityDurationSeconds = availabilityCheckValidityDurationSeconds;
        _challengeValidityDurationSeconds = challengeValidityDurationSeconds;
    }

    /////////////////////////////// UUPS UPGRADABLE ///////////////////////////////

    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Only governance can call this method.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data)
        public payable override
        onlyGovernance
        onlyProxy
    {
        super.upgradeToAndCall(newImplementation, data);
    }

    /**
     * Unused. Present just to satisfy UUPSUpgradeable requirement.
     * The real check is in onlyGovernance modifier on upgradeToAndCall.
     */
    function _authorizeUpgrade(address newImplementation) internal override {}

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        teeVersionManager = ITeeVersionManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeVersionManager"));
        teeRegistry = ITeeRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeRegistry"));
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
        ftdcHub = IFtdcHub(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtdcHub"));
        ftdcVerification = IFtdcVerification(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtdcVerification"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }

    function _updateSettings(
        uint256 _availabilityCheckValidityDurationSeconds,
        uint256 _challengeValidityDurationSeconds
    )
        internal
    {
        _validateDuration(_availabilityCheckValidityDurationSeconds, 1 hours, 365 days);
        _validateDuration(_challengeValidityDurationSeconds, 1 minutes, 1 days);
        availabilityCheckValidityDurationSeconds = _availabilityCheckValidityDurationSeconds;
        challengeValidityDurationSeconds = _challengeValidityDurationSeconds;
        emit SettingsUpdated(
            _availabilityCheckValidityDurationSeconds,
            _challengeValidityDurationSeconds
        );
    }

    function _verifyAvailabilityCheckProof(
        ITeeRegistry.TeeMachineWithAttestationData memory _teeMachine,
        ITeeRegistry.TeeStatus _status,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        internal
    {
        ITeeAvailabilityCheck.Response calldata data = _proof.data;
        require(
            data.thresholdBIPS == 0 &&
            data.attestationType == TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE &&
            data.sourceId == TEE_SOURCE_ID,
            "invalid attestation"
        );
        ITeeAvailabilityCheck.RequestBody calldata requestBody = data.requestBody;
        address teeId = requestBody.teeId;
        require(data.timestamp < block.timestamp && data.timestamp >= challengeTs[teeId], "AC timestamp invalid");
        require(challengeTs[teeId] + challengeValidityDurationSeconds > block.timestamp, "challenge expired");
        require(
            keccak256(bytes(requestBody.url)) == keccak256(bytes(_teeMachine.url)) &&
            requestBody.codeHash == _teeMachine.codeHash &&
            requestBody.platform == _teeMachine.platform &&
            requestBody.initialTeeId == _teeMachine.initialTeeId &&
            requestBody.teeGovernanceHash == teeVersionManager.getTeeGovernanceHash(_teeMachine.codeHash) &&
            requestBody.challenge == challenges[teeId],
            "invalid request body"
        );
        bytes32 messageHash = keccak256(abi.encode(data));
        uint256 rewardEpochId = ftdcVerification.verifySigningPolicySignatures(_proof.relayMessage, messageHash);
        uint256 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        require(
            requestBody.rewardEpochId == rewardEpochId &&
            (rewardEpochId == currentRewardEpochId || rewardEpochId + 1 == currentRewardEpochId),
            "too old signing policy"
        );
        // additionally check cosigners in case of initial availability check
        if (_status == ITeeRegistry.TeeStatus.INITIALIZED && cosignersThreshold > 0) {
            address[] memory registrationCosigners =
                ftdcVerification.verifyCosignerSignatures(_proof.cosignerSignatures, messageHash);
            require(registrationCosigners.length >= cosignersThreshold, "cosigners threshold not met");
            for (uint256 i = 0; i < registrationCosigners.length; i++) {
                require(cosigners.index[registrationCosigners[i]] != 0, "invalid cosigner");
            }
        }
    }

    function _validateDuration(
        uint256 _duration,
        uint256 _minDuration,
        uint256 _maxDuration
    )
        internal pure
    {
        require(_minDuration <= _duration && _duration <= _maxDuration, "invalid duration");
    }
}
