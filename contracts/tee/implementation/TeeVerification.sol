// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./TeeBase.sol";
import "../interface/IITeeSystemStateVerifier.sol";
import "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import "../../userInterfaces/tee/ITeeVerification.sol";
import "../../userInterfaces/tee/ITeeMachineRegistry.sol";
import "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../../userInterfaces/tee/ITeeWalletKeyManager.sol";
import "../../userInterfaces/tee/ITeeReplication.sol";
import "../../userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import "../../userInterfaces/ftdc/IFtdcHub.sol";
import "../../userInterfaces/ftdc/IFtdcVerification.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../userInterfaces/IRelay.sol";
import "../../utils/lib/AddressSet.sol";

/**
 * TeeVerification is used for challenges and availability checks of TEE machines.
 */
contract TeeVerification is ITeeVerification, TeeBase {
    using AddressSet for AddressSet.State;

    struct AvailabilityCheckValidity {
        uint64 endTs;
        uint32 lastSigningPolicyId;
    }

    bytes32 public constant TEE_SOURCE_ID = bytes32("TEE");
    bytes32 public constant REG_OP_TYPE = bytes32("F_REG");
    bytes32 public constant TEE_ATTESTATION = bytes32("TEE_ATTESTATION");

    /// TEE extension registry contract.
    ITeeExtensionRegistry public teeExtensionRegistry;
    /// TEE machine registry contract.
    ITeeMachineRegistry public teeMachineRegistry;
    /// TEE wallet project manager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// TEE wallet manager contract.
    ITeeWalletManager public teeWalletManager;
    /// TEE wallet key manager contract.
    ITeeWalletKeyManager public teeWalletKeyManager;
    /// TEE system state verifier contract.
    IITeeSystemStateVerifier public teeSystemStateVerifier;
    /// TEE replication contract.
    ITeeReplication public teeReplication;
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
    uint64 private availabilityCheckValidityDurationSeconds;
    /// The signing policy validity duration, in reward epochs.
    /// Used when extending availability or putting tee machine into production:
    /// - in case of registration, the check is done for the initial signing policy,
    /// - in other cases, the check is done for the last confirmed signing policy.
    uint64 private signingPolicyValidityDurationInRewardEpochs;
    /// Challenge (also availability check proof) validity duration, in seconds.
    /// New challenge can be requested only if the previous one has expired.
    uint64 private challengeValidityDurationSeconds;

    /// registration availability check cosigners and their threshold
    AddressSet.State private cosigners;
    uint64 private cosignersThreshold;

    mapping(address teeId => AvailabilityCheckValidity) private availabilityCheckValidity;
    mapping(address teeId => bytes32) private challenges;
    mapping(address teeId => uint256) private challengeTs;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() TeeBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint64 _availabilityCheckValidityDurationSeconds,
        uint24 _signingPolicyValidityDurationInRewardEpochs,
        uint64 _challengeValidityDurationSeconds
    )
        external
    {
        TeeBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
        _updateSettings(
            _availabilityCheckValidityDurationSeconds,
            _signingPolicyValidityDurationInRewardEpochs,
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
        bytes32 challenge;
        if (challengeTs[_teeId] + challengeValidityDurationSeconds > block.timestamp) {
            challenge = challenges[_teeId];
        } else {
            (uint256 randomNumber,,) = relay.getRandomNumber();
            challenge = keccak256(abi.encode(_teeId, block.timestamp, randomNumber));
            challenges[_teeId] = challenge;
            challengeTs[_teeId] = block.timestamp;
        }

        address attestingTeeId = _getAttestingTeeId(_teeId);

        ITeeMachineRegistry.TeeMachineWithAttestationData memory teeMachine =
            teeMachineRegistry.getTeeMachineWithAttestationData(attestingTeeId);
        // set the TEE id to the one we are requesting attestation for, can only differ in case of active replication
        teeMachine.teeId = _teeId;

        TeeAttestation memory message = TeeAttestation({
            teeMachine: teeMachine,
            challenge: challenge
        });
        bytes32 instructionId = keccak256(abi.encode(
            REG_OP_TYPE, TEE_ATTESTATION, _teeId, challenge
        ));
        address[] memory teeIds = new address[](1);
        teeIds[0] = attestingTeeId;
        teeExtensionRegistry.sendInstructions{value: msg.value}(
            instructionId,
            teeIds,
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
        require(challengeTs[_teeId] + challengeValidityDurationSeconds > block.timestamp,
            ChallengeExpired(challengeTs[_teeId]));
        require(teeMachineRegistry.getExtensionId(_testOnTeeId) == 0, InvalidExtension());
        address attestingTeeId = _getAttestingTeeId(_teeId);
        ITeeMachineRegistry.TeeMachine memory teeMachine = teeMachineRegistry.getTeeMachine(attestingTeeId);
        ITeeAvailabilityCheck.RequestBody memory requestBody = ITeeAvailabilityCheck.RequestBody({
            teeId: _teeId,
            url: teeMachine.url,
            challenge: challenges[_teeId]
        });

        address[] memory registrationCosigners = new address[](0);
        uint64 registrationCosignersThreshold = 0;
        if (teeMachineRegistry.getTeeMachineStatus(_teeId) == ITeeMachineRegistry.TeeStatus.INITIALIZED) {
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
            TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE,
            TEE_SOURCE_ID,
            abi.encode(requestBody)
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
        address teeId = _proof.requestBody.teeId;
        ITeeMachineRegistry.TeeStatus status = teeMachineRegistry.getTeeMachineStatus(teeId);
        require(status == ITeeMachineRegistry.TeeStatus.PRODUCTION,
            TeeMachineNotAvailable());

        require(
            _proof.responseBody.status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            InvalidAvailabilityCheckStatus()
        );

        // if called from the registry, checks were already done
        // otherwise, we need to verify the proof and check the TEE version and platform
        if (msg.sender != address(teeMachineRegistry)) {
            uint256 extensionId = teeMachineRegistry.getExtensionId(teeId);
            ITeeMachineRegistry.TeeMachineWithAttestationData memory teeMachine =
                teeMachineRegistry.getTeeMachineWithAttestationData(teeId);
            require(
                teeExtensionRegistry.isCodeHashPlatformSupported(
                    extensionId, teeMachine.codeHash, teeMachine.platform),
                VersionNotSupported()
            );
            require(
                _verifyAvailabilityCheckProof(teeMachine, status, _proof),
                InvalidResponseData()
            );
        }

        // extend the availability check validity
        uint64 endTs = _proof.header.timestamp + availabilityCheckValidityDurationSeconds;
        AvailabilityCheckValidity storage validity = availabilityCheckValidity[teeId];
        if (endTs > validity.endTs) {
            validity.endTs = endTs;
            validity.lastSigningPolicyId = _proof.responseBody.lastSigningPolicyId;
            address owner = teeMachineRegistry.getTeeMachineOwner(teeId);
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
        returns(bool)
    {
        address teeId = _proof.requestBody.teeId;
        ITeeMachineRegistry.TeeStatus status = teeMachineRegistry.getTeeMachineStatus(teeId);
        ITeeMachineRegistry.TeeMachineWithAttestationData memory teeMachine =
            teeMachineRegistry.getTeeMachineWithAttestationData(teeId);
        return _verifyAvailabilityCheckProof(teeMachine, status, _proof);
    }

    /**
     * @inheritdoc ITeeVerification
     */
    function requestPMWMultisigAccountConfiguredAttestation(
        bytes32 _walletId,
        string calldata _walletAddress,
        address _testOnTeeId,
        bytes32 _sourceId
    )
        external payable
    {
        require(bytes(_walletAddress).length > 0, WalletAddressZero());
        ITeeWalletManager.WalletStatus walletStatus = teeWalletManager.getWalletStatus(_walletId);
        require(
            walletStatus == ITeeWalletManager.WalletStatus.PRODUCTION ||
            walletStatus == ITeeWalletManager.WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );
        (uint64 multisigThreshold, uint64[] memory keyIds, ) = teeWalletKeyManager.getWalletKeysInfo(_walletId);
        IPMWMultisigAccountConfigured.RequestBody memory requestBody = IPMWMultisigAccountConfigured.RequestBody({
            walletAddress: _walletAddress,
            publicKeys: new bytes[](keyIds.length),
            threshold: multisigThreshold,
            opType: teeWalletProjectManager.getOpType(teeWalletManager.getWalletProjectId(_walletId))
        });
        for (uint256 i = 0; i < keyIds.length; i++) {
            requestBody.publicKeys[i] = teeWalletKeyManager.getWalletKeyPublicKey(_walletId, keyIds[i]);
        }
        address[] memory teeIds = new address[](1);
        teeIds[0] = _testOnTeeId;
        ftdcHub.requestAttestation{value: msg.value}(
            0,
            0,
            teeIds,
            cosigners.list,
            cosignersThreshold,
            PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE,
            _sourceId,
            abi.encode(requestBody)
        );
    }

    /**
     * @inheritdoc ITeeVerification
     */
    function verifyPMWMultisigAccountConfiguredProof(
        bytes32 _walletId,
        bytes32 _sourceId,
        IPMWMultisigAccountConfigured.Proof calldata _proof
    )
        external
        returns(bool)
    {
        IFtdcHub.FtdcResponseHeader calldata header = _proof.header;
        require(
            header.thresholdBIPS == 0 &&
            header.attestationType == PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE &&
            header.sourceId == _sourceId,
            InvalidAttestation()
        );
        IPMWMultisigAccountConfigured.RequestBody calldata requestBody = _proof.requestBody;
        (uint64 multisigThreshold, uint64[] memory keyIds, ) = teeWalletKeyManager.getWalletKeysInfo(_walletId);
        require(
            multisigThreshold == requestBody.threshold &&
            keyIds.length == requestBody.publicKeys.length &&
            teeWalletProjectManager.getOpType(teeWalletManager.getWalletProjectId(_walletId)) == requestBody.opType,
            InvalidRequestBody()
        );
        for (uint256 i = 0; i < keyIds.length; i++) {
            bytes memory publicKey = teeWalletKeyManager.getWalletKeyPublicKey(_walletId, keyIds[i]);
            require(
                keccak256(requestBody.publicKeys[i]) == keccak256(publicKey),
                InvalidRequestBody()
            );
        }

        bytes32 messageHash = keccak256(abi.encode(
            keccak256(abi.encode(header)),
            keccak256(abi.encode(requestBody)),
            keccak256(abi.encode(_proof.responseBody))
        ));

        uint256 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        // check signing policy signatures
        _checkSigningPolicySignatures(currentRewardEpochId, messageHash, _proof.signatures.signingPolicySignatures);
        // check cosigners
        _checkCosignerSignatures(messageHash, _proof.signatures.cosignerSignatures);

        return _proof.responseBody.status == IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.OK;
    }

    /**
     * Sets the FTDC cosigners and their threshold used for the TEE machine registration.
     * Emits CosignersSet event.
     * @param _cosigners The cosigners.
     * @param _cosignersThreshold The cosigners threshold.
     * Can only be called by the governance.
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
            require(_cosigners[i] != address(0), InvalidCosigner(_cosigners[i]));
            // check for duplicates
            for (uint256 j = 0; j < i; j++) {
                require(_cosigners[j] != _cosigners[i], DuplicatedCosigner(_cosigners[i]));
            }
        }
        cosigners.replaceAll(_cosigners);
        cosignersThreshold = _cosignersThreshold;
        emit CosignersSet(_cosigners, _cosignersThreshold);
    }

    /**
     * Update the settings of the TeeAvailability contract.
     * Emits SettingsUpdated event.
     * @param _availabilityCheckValidityDurationSeconds The TEE availability check validity duration, in seconds.
     * In order to receive rewards, TEE must be checked for availability at least once in this period.
     * @param _signingPolicyValidityDurationInRewardEpochs The signing policy validity duration, in reward epochs.
     * @param _challengeValidityDurationSeconds Challenge validity duration, in seconds.
     * Can only be called by the governance.
     */
    function updateSettings(
        uint64 _availabilityCheckValidityDurationSeconds,
        uint24 _signingPolicyValidityDurationInRewardEpochs,
        uint64 _challengeValidityDurationSeconds
    )
        external onlyGovernance
    {
        _updateSettings(
            _availabilityCheckValidityDurationSeconds,
            _signingPolicyValidityDurationInRewardEpochs,
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

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        teeExtensionRegistry = ITeeExtensionRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeExtensionRegistry"));
        teeMachineRegistry = ITeeMachineRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeMachineRegistry"));
        teeWalletProjectManager = ITeeWalletProjectManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletProjectManager"));
        teeWalletManager = ITeeWalletManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletManager"));
        teeWalletKeyManager = ITeeWalletKeyManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletKeyManager"));
        teeSystemStateVerifier = IITeeSystemStateVerifier(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeSystemStateVerifier"));
        teeReplication = ITeeReplication(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeReplication"));
        ftdcHub = IFtdcHub(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtdcHub"));
        ftdcVerification = IFtdcVerification(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtdcVerification"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }

    function _updateSettings(
        uint64 _availabilityCheckValidityDurationSeconds,
        uint24 _signingPolicyValidityDurationInRewardEpochs,
        uint64 _challengeValidityDurationSeconds
    )
        internal
    {
        _validateDuration(_availabilityCheckValidityDurationSeconds, 1 hours, 365 days);
        _validateDuration(_signingPolicyValidityDurationInRewardEpochs, 1, 100);
        _validateDuration(_challengeValidityDurationSeconds, 1 minutes, 1 days);
        availabilityCheckValidityDurationSeconds = _availabilityCheckValidityDurationSeconds;
        signingPolicyValidityDurationInRewardEpochs = _signingPolicyValidityDurationInRewardEpochs;
        challengeValidityDurationSeconds = _challengeValidityDurationSeconds;
        emit SettingsUpdated(
            _availabilityCheckValidityDurationSeconds,
            _signingPolicyValidityDurationInRewardEpochs,
            _challengeValidityDurationSeconds
        );
    }

    function _verifyAvailabilityCheckProof(
        ITeeMachineRegistry.TeeMachineWithAttestationData memory _teeMachine,
        ITeeMachineRegistry.TeeStatus _status,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        internal
        returns(bool)
    {
        IFtdcHub.FtdcResponseHeader calldata header = _proof.header;
        require(
            header.thresholdBIPS == 0 &&
            header.attestationType == TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE &&
            header.sourceId == TEE_SOURCE_ID,
            InvalidAttestation()
        );
        ITeeAvailabilityCheck.RequestBody calldata requestBody = _proof.requestBody;
        address teeId = requestBody.teeId;
        require(header.timestamp < block.timestamp && header.timestamp >= challengeTs[teeId],
            AvailabilityCheckTimestampInvalid(challengeTs[teeId]));
        require(challengeTs[teeId] + challengeValidityDurationSeconds > block.timestamp,
            ChallengeExpired(challengeTs[teeId]));
        require(
            keccak256(bytes(requestBody.url)) == keccak256(bytes(_teeMachine.url)) &&
            requestBody.challenge == challenges[teeId],
            InvalidRequestBody()
        );
        bytes32 messageHash = keccak256(abi.encode(
            keccak256(abi.encode(header)),
            keccak256(abi.encode(requestBody)),
            keccak256(abi.encode(_proof.responseBody))
        ));
        uint256 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        // check signing policy signatures
        _checkSigningPolicySignatures(currentRewardEpochId, messageHash, _proof.signatures.signingPolicySignatures);
        if (_status == ITeeMachineRegistry.TeeStatus.INITIALIZED) {
            // additionally check cosigners in case of initial availability check
            _checkCosignerSignatures(messageHash, _proof.signatures.cosignerSignatures);
            // check initial signing policy
            require(
                _proof.responseBody.initialSigningPolicyId <= currentRewardEpochId &&
                _isSigningPolicyValid(_proof.responseBody.initialSigningPolicyId, currentRewardEpochId),
                InvalidInitialSigningPolicy()
            );
        } else {
            // for other statuses, we check the initial and last availability check signing policy
            require(
                _proof.responseBody.initialSigningPolicyId == teeMachineRegistry.getInitialSigningPolicyId(teeId),
                InvalidInitialSigningPolicy()
            );
            require(
                _isSigningPolicyValid(availabilityCheckValidity[teeId].lastSigningPolicyId, currentRewardEpochId),
                AvailabilityCheckValidityExpired(availabilityCheckValidity[teeId].lastSigningPolicyId)
            );
        }
        // check response body data validity
        ITeeAvailabilityCheck.ResponseBody calldata responseBody = _proof.responseBody;
        uint256 lastSigningPolicyId = responseBody.lastSigningPolicyId;
        uint256 extensionId = teeMachineRegistry.getExtensionId(teeId);
        ITeeExtensionStateVerifier teeStateVerifier = teeExtensionRegistry.getTeeExtensionStateVerifier(extensionId);
        ITeeAvailabilityCheck.TeeState calldata state = responseBody.state;
        return responseBody.codeHash == _teeMachine.codeHash &&
            responseBody.platform == _teeMachine.platform &&
            (lastSigningPolicyId == currentRewardEpochId || lastSigningPolicyId == currentRewardEpochId + 1) &&
            teeSystemStateVerifier.verifyTeeSystemState(teeId, state.systemStateVersion, state.systemState) &&
            (address(teeStateVerifier) == address(0) && state.stateVersion == bytes32(0) && state.state.length == 0 ||
                teeStateVerifier.verifyTeeState(teeId, state.stateVersion, state.state));
    }

    function _isSigningPolicyValid(
        uint256 _signingPolicyId,
        uint256 _currentRewardEpochId
    )
        internal view
        returns(bool)
    {
        return _signingPolicyId + signingPolicyValidityDurationInRewardEpochs >= _currentRewardEpochId;
    }

    function _getAttestingTeeId(address _teeId)
        internal view
        returns(address _attestingTeeId)
    {
        // TEE machines in status PAUSED_FOR_UPGRADE does not require attestation
        _attestingTeeId = teeReplication.getReplicatingTeeId(_teeId);
        if (_attestingTeeId == address(0)) {
            // if no replication, use the original TEE id for attestation
            _attestingTeeId = _teeId;
        }
    }

    function _checkSigningPolicySignatures(
        uint256 _currentRewardEpochId,
        bytes32 _messageHash,
        bytes calldata _signatures
    )
        internal
    {
        uint256 rewardEpochId = ftdcVerification.verifySigningPolicySignatures(_signatures, _messageHash);
        require(
            rewardEpochId == _currentRewardEpochId || rewardEpochId + 1 == _currentRewardEpochId,
            InvalidSigningPolicy()
        );
    }

    function _checkCosignerSignatures(
        bytes32 _messageHash,
        Signature[] calldata _signatures
    )
        internal view
    {
        if (cosignersThreshold == 0) {
            return; // no cosigners, nothing to check
        }
        address[] memory cosignersList = ftdcVerification.verifyCosignerSignatures(_signatures, _messageHash);
        require(cosignersList.length >= cosignersThreshold, CosignersThresholdNotMet());
        for (uint256 i = 0; i < cosignersList.length; i++) {
            require(cosigners.index[cosignersList[i]] != 0, InvalidCosigner(cosignersList[i]));
        }
    }

    function _validateDuration(
        uint256 _duration,
        uint256 _minDuration,
        uint256 _maxDuration
    )
        internal pure
    {
        require(_minDuration <= _duration && _duration <= _maxDuration, InvalidDuration());
    }
}
