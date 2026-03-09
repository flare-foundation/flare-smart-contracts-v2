// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeBase } from "./TeeBase.sol";
import { IITeeExtensionRegistry } from "../interface/IITeeExtensionRegistry.sol";
import { IITeeSystemStateVerifier } from "../interface/IITeeSystemStateVerifier.sol";
import { ITeeVerification } from "../../userInterfaces/tee/ITeeVerification.sol";
import { ITeeMachineRegistry } from "../../userInterfaces/tee/ITeeMachineRegistry.sol";
import { ITeeWalletProjectManager } from "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import { ITeeWalletManager } from "../../userInterfaces/tee/ITeeWalletManager.sol";
import { ITeeWalletKeyManager } from "../../userInterfaces/tee/ITeeWalletKeyManager.sol";
import { ITeeReplication } from "../../userInterfaces/tee/ITeeReplication.sol";
import { ITeeExtensionStateVerifier } from "../../userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { IFtdcHub } from "../../userInterfaces/ftdc/IFtdcHub.sol";
import { IFtdcVerification } from "../../userInterfaces/ftdc/IFtdcVerification.sol";
import { IPMWMultisigAccountConfigured, PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE }
    from "../../userInterfaces/ftdc/IPMWMultisigAccountConfigured.sol";
import { ITeeAvailabilityCheck, TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE }
    from "../../userInterfaces/ftdc/ITeeAvailabilityCheck.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { IRelay } from "../../userInterfaces/IRelay.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";

/**
 * TeeVerification is used for challenges and availability checks of TEE machines.
 */
contract TeeVerification is ITeeVerification, TeeBase {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct AvailabilityCheckValidity {
        uint64 endTs;
        uint32 lastSigningPolicyId;
    }

    bytes32 public constant TEE_SOURCE_ID = bytes32("TEE");
    bytes32 public constant REG_OP_TYPE = bytes32("F_REG");
    bytes32 public constant TEE_ATTESTATION = bytes32("TEE_ATTESTATION");

    /// TEE extension registry contract.
    IITeeExtensionRegistry public teeExtensionRegistry;
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
    EnumerableSet.AddressSet private cosigners;
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
        address _teeId,
        address _claimBackAddress
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

        ITeeMachineRegistry.TeeMachineWithAttestationData memory teeMachineWithAttestationData =
            teeMachineRegistry.getTeeMachineWithAttestationData(attestingTeeId);
        ITeeMachineRegistry.TeeMachine memory teeMachine = teeMachineRegistry.getTeeMachine(attestingTeeId);
        // set the TEE id to the one we are requesting attestation for, can only differ in case of active replication
        // machine in status PAUSED_FOR_UPGRADE does not need TEE attestation
        teeMachineWithAttestationData.teeId = _teeId;
        teeMachine.teeId = _teeId;

        TeeAttestation memory message = TeeAttestation({
            teeMachine: teeMachineWithAttestationData,
            challenge: challenge
        });
        ITeeMachineRegistry.TeeMachine[] memory teeMachines = new ITeeMachineRegistry.TeeMachine[](1);
        teeMachines[0] = teeMachine;

        _sendInstructions(
             teeMachines,
            abi.encode(message),
            _claimBackAddress
        );
        emit TeeAttestationRequested(_teeId, challenge);
    }

    /**
     * @inheritdoc ITeeVerification
     */
    function requestAvailabilityCheckAttestation(
        address _teeId,
        bytes32 _instructionId,
        address _testOnTeeId,
        address _proofOwner,
        address _claimBackAddress
    )
        external payable
    {
        require(
            challengeTs[_teeId] + challengeValidityDurationSeconds > block.timestamp,
            ChallengeExpired(challengeTs[_teeId])
        );
        address attestingTeeId = _getAttestingTeeId(_teeId);
        ITeeMachineRegistry.TeeMachine memory teeMachine = teeMachineRegistry.getTeeMachine(attestingTeeId);
        ITeeAvailabilityCheck.RequestBody memory requestBody = ITeeAvailabilityCheck.RequestBody({
            teeId: _teeId,
            teeProxyId: teeMachine.teeProxyId,
            url: teeMachine.url,
            challenge: challenges[_teeId],
            instructionId: _instructionId
        });

        address[] memory registrationCosigners = new address[](0);
        uint64 registrationCosignersThreshold = 0;
        ITeeMachineRegistry.TeeStatus status = teeMachineRegistry.getTeeMachineStatus(attestingTeeId);
        // initial state or active replication
        if (status == ITeeMachineRegistry.TeeStatus.INITIALIZED ||
            status == ITeeMachineRegistry.TeeStatus.REPLICATING)
        {
            registrationCosigners = cosigners.values();
            registrationCosignersThreshold = cosignersThreshold;
        }

        _requestFtdcAttestation(
            _testOnTeeId,
            registrationCosigners,
            registrationCosignersThreshold,
            TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE,
            TEE_SOURCE_ID,
            abi.encode(requestBody),
            _proofOwner,
            _claimBackAddress
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

        // if called from the tee machine registry, checks were already done there,
        // otherwise, we need to verify the proof and check the TEE status, version and platform
        if (msg.sender != address(teeMachineRegistry)) {
            ITeeMachineRegistry.TeeStatus status = teeMachineRegistry.getTeeMachineStatus(teeId);
            require(status == ITeeMachineRegistry.TeeStatus.PRODUCTION, TeeMachineNotAvailable());
            require(
                _proof.responseBody.status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
                InvalidAvailabilityCheckStatus()
            );
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
        bytes32 _sourceId,
        string calldata _accountAddress,
        address _testOnTeeId,
        address _proofOwner,
        address _claimBackAddress
    )
        external payable
    {
        require(bytes(_accountAddress).length > 0, AccountAddressZero());
        ITeeWalletManager.WalletStatus walletStatus = teeWalletManager.getWalletStatus(_walletId);
        require(
            walletStatus == ITeeWalletManager.WalletStatus.PRODUCTION ||
            walletStatus == ITeeWalletManager.WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );

        (uint64 multisigThreshold, uint64[] memory keyIds, ) = teeWalletKeyManager.getWalletKeysInfo(_walletId);
        IPMWMultisigAccountConfigured.RequestBody memory requestBody = IPMWMultisigAccountConfigured.RequestBody({
            accountAddress: _accountAddress,
            publicKeys: new bytes[](keyIds.length),
            threshold: multisigThreshold
        });
        for (uint256 i = 0; i < keyIds.length; i++) {
            requestBody.publicKeys[i] = teeWalletKeyManager.getWalletKeyPublicKey(_walletId, keyIds[i]);
        }

        _requestFtdcAttestation(
            _testOnTeeId,
            cosigners.values(),
            cosignersThreshold,
            PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE,
            _sourceId,
            abi.encode(requestBody),
            _proofOwner,
            _claimBackAddress
        );
    }

    /**
     * @inheritdoc ITeeVerification
     */
    function verifyPMWMultisigAccountConfiguredProof(
        bytes32 _walletId,
        IPMWMultisigAccountConfigured.Proof calldata _proof
    )
        external
        returns(bool)
    {
        IFtdcHub.FtdcResponseHeader calldata header = _proof.header;
        require(
            header.thresholdBIPS == 0 &&
            header.attestationType == PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE,
            InvalidAttestation()
        );
        IPMWMultisigAccountConfigured.RequestBody calldata requestBody = _proof.requestBody;
        (uint64 multisigThreshold, uint64[] memory keyIds, ) = teeWalletKeyManager.getWalletKeysInfo(_walletId);
        require(
            multisigThreshold == requestBody.threshold &&
            keyIds.length == requestBody.publicKeys.length,
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
        _checkCosignerSignatures(_toCosignersMessageHash(messageHash), _proof.signatures.cosignerSignatures);

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
            InvalidThreshold()
        );
        address[] memory currentCosigners = cosigners.values();
        // optimization: clear the set by removing last element each time
        for (uint256 i = currentCosigners.length; i > 0; i--) {
            cosigners.remove(currentCosigners[i - 1]);
        }
        for (uint256 i = 0; i < _cosigners.length; i++) {
            require(_cosigners[i] != address(0), InvalidCosigner(_cosigners[i]));
            // check for duplicates
            require(cosigners.add(_cosigners[i]), DuplicatedCosigner(_cosigners[i]));
        }
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
        _cosigners = cosigners.values();
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
     * @inheritdoc ITeeVerification
     */
    function getAvailabilityCheckValidity(address _teeId)
        external view
        returns(uint64 _endTs, uint32 _lastSigningPolicyId)
    {
        AvailabilityCheckValidity memory validity = availabilityCheckValidity[_teeId];
        _endTs = validity.endTs;
        _lastSigningPolicyId = validity.lastSigningPolicyId;
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
        teeExtensionRegistry = IITeeExtensionRegistry(
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

    /// _proof.responseBody.status must be checked elsewhere
    function _verifyAvailabilityCheckProof(
        ITeeMachineRegistry.TeeMachineWithAttestationData memory _teeMachineWithAttestationData,
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
        ITeeMachineRegistry.TeeMachine memory teeMachine = teeMachineRegistry.getTeeMachine(teeId);
        require(
            keccak256(bytes(requestBody.url)) == keccak256(bytes(teeMachine.url)) &&
            requestBody.teeProxyId == teeMachine.teeProxyId &&
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
        // additionally check cosigners in case of initial availability check or active replication
        if (_status == ITeeMachineRegistry.TeeStatus.INITIALIZED ||
            _status == ITeeMachineRegistry.TeeStatus.REPLICATING)
        {
            _checkCosignerSignatures(_toCosignersMessageHash(messageHash), _proof.signatures.cosignerSignatures);
        }

        // check response body data validity - except for status, which must be checked elsewhere
        ITeeAvailabilityCheck.ResponseBody calldata responseBody = _proof.responseBody;
        if (_status == ITeeMachineRegistry.TeeStatus.INITIALIZED ||
            _status == ITeeMachineRegistry.TeeStatus.REPLICATING)
        {
            // check initial signing policy
            if (responseBody.initialSigningPolicyId > currentRewardEpochId ||
                !_isSigningPolicyValid(responseBody.initialSigningPolicyId, currentRewardEpochId))
            {
                return false;
            }
        } else {
            // for other statuses, we check the initial and last availability check signing policy
            if (responseBody.initialSigningPolicyId != teeMachineRegistry.getInitialSigningPolicyId(teeId)) {
                return false;
            }
            if (!_isSigningPolicyValid(availabilityCheckValidity[teeId].lastSigningPolicyId, currentRewardEpochId)) {
                return false;
            }
        }
        if (responseBody.codeHash != _teeMachineWithAttestationData.codeHash) {
            return false;
        }
        if (responseBody.platform != _teeMachineWithAttestationData.platform) {
            return false;
        }
        uint256 lastSigningPolicyId = responseBody.lastSigningPolicyId;
        if (lastSigningPolicyId != currentRewardEpochId && lastSigningPolicyId != currentRewardEpochId + 1) {
            return false;
        }
        ITeeAvailabilityCheck.TeeState calldata state = responseBody.state;
        if (!teeSystemStateVerifier.verifyTeeSystemState(teeId, state.systemStateVersion, state.systemState)) {
            return false;
        }
        uint256 extensionId = teeMachineRegistry.getExtensionId(teeId);
        ITeeExtensionStateVerifier teeStateVerifier = teeExtensionRegistry.getTeeExtensionStateVerifier(extensionId);
        if (address(teeStateVerifier) == address(0)) {
            if (state.stateVersion != bytes32(0) || state.state.length != 0) {
                return false;
            }
        } else {
            if (!teeStateVerifier.verifyTeeState(teeId, state.stateVersion, state.state)) {
                return false;
            }
        }
        return true;
    }

    function _sendInstructions(
        ITeeMachineRegistry.TeeMachine[] memory _teeMachines,
        bytes memory _message,
        address _claimBackAddress
    )
        internal
    {
        teeExtensionRegistry.sendSystemInstructions{value: msg.value}(
            bytes32(0),
            _teeMachines,
            REG_OP_TYPE,
            TEE_ATTESTATION,
            _message,
            new address[](0),
            0,
            _claimBackAddress
        );
    }

    function _requestFtdcAttestation(
        address _testOnTeeId,
        address[] memory _cosigners,
        uint64 _cosignersThreshold,
        bytes32 _attestationType,
        bytes32 _sourceId,
        bytes memory _requestBody,
        address _proofOwner,
        address _claimBackAddress
    )
        internal
    {
        uint256 numberOfTees;
        address[] memory teeIds;
        if (_testOnTeeId != address(0)) {
            teeIds = new address[](1);
            teeIds[0] = _testOnTeeId;
        } else {
            numberOfTees = 1; // request on a random active TEE machine
        }
        IFtdcHub.FtdcAttestationRequest memory attestationRequest = IFtdcHub.FtdcAttestationRequest({
            header: IFtdcHub.FtdcRequestHeader({
                attestationType: _attestationType,
                sourceId: _sourceId,
                thresholdBIPS: 0,
                proofOwner: _proofOwner
            }),
            requestBody: _requestBody
        });
        ftdcHub.requestAttestation{value: msg.value}(
            attestationRequest,
            numberOfTees,
            teeIds,
            _cosigners,
            _cosignersThreshold,
            _claimBackAddress
        );
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
            require(cosigners.contains(cosignersList[i]), InvalidCosigner(cosignersList[i]));
        }
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

    function _validateDuration(
        uint256 _duration,
        uint256 _minDuration,
        uint256 _maxDuration
    )
        internal pure
    {
        require(_minDuration <= _duration && _duration <= _maxDuration, InvalidDuration());
    }

    function _toCosignersMessageHash(bytes32 _messageHash)
        internal pure
        returns(bytes32)
    {
        return keccak256(bytes.concat(hex"010000000000", _messageHash));
    }
}
