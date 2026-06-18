// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IMachineManager, REG_OP_TYPE } from "../../userInterfaces/tee/IMachineManager.sol";
import { IVerification, TEE_SOURCE_ID } from "../../userInterfaces/tee/IVerification.sol";
import { IInstructions } from "../../userInterfaces/tee/IInstructions.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { ITeeExtensionStateVerifier } from "../../userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { ITeeAvailabilityCheck, TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE }
    from "../../userInterfaces/fdc2/ITeeAvailabilityCheck.sol";
import { IFdc2Hub } from "../../userInterfaces/fdc2/IFdc2Hub.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { IRelay } from "../../userInterfaces/IRelay.sol";
import { MachineEmergencyPause } from "../library/MachineEmergencyPause.sol";
import { Fdc2ProofVerification } from "../../fdc2/library/Fdc2ProofVerification.sol";
import { MachineManager } from "./MachineManager.sol";
import { ExtensionManager } from "./ExtensionManager.sol";
import { SystemStateVerifier } from "./SystemStateVerifier.sol";
import { ExternalAddresses } from "./ExternalAddresses.sol";
import { Instructions } from "./Instructions.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Verification
 * @notice Library for TEE machine verification, challenges, and availability checks.
 * @dev Uses ERC-7201 namespaced storage. Contains methods reused by VerificationFacet,
 *      and MachineManagerFacet.
 */
library Verification {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct AvailabilityCheckValidity {
        uint64 endTs;
        uint32 lastSigningPolicyId;
    }

    /// @custom:storage-location erc7201:tee.Verification.State
    struct State {
        uint64 availabilityCheckValidityDurationSeconds;
        uint64 signingPolicyValidityDurationInRewardEpochs;
        uint64 challengeValidityDurationSeconds;
        EnumerableSet.AddressSet cosigners;
        uint64 cosignersThreshold;
        mapping(address teeId => AvailabilityCheckValidity) availabilityCheckValidity;
        mapping(address teeId => bytes32) challenges;
        mapping(address teeId => uint256) challengeTs;
    }

    // erc7201 builtin not recognized by slither's parser; the constant is initialized at declaration
    //slither-disable-next-line uninitialized-state
    bytes32 internal constant STATE_POSITION = bytes32(erc7201("tee.Verification.State"));

    /// Op command of the TEE machine registration-attestation instruction.
    bytes32 internal constant TEE_ATTESTATION = bytes32("TEE_ATTESTATION");

    // =========================================================================
    // Methods reused by other facets (non-view / non-pure first)
    // =========================================================================

    /**
     * Verifies an availability check proof.
     * _proof.responseBody.status must be checked by the caller.
     */
    function verifyAvailabilityCheckProof(
        IMachineManager.TeeMachineWithAttestationData memory _teeMachineWithAttestationData,
        IMachineManager.TeeStatus _status,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        internal
        returns (bool)
    {
        State storage s = getState();

        address teeId = _proof.requestBody.teeId;

        // Validate header
        {
            IFdc2Hub.Fdc2ResponseHeader calldata header = _proof.header;
            require(
                header.thresholdBIPS == 0 &&
                header.attestationType == TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE &&
                header.sourceId == TEE_SOURCE_ID,
                IVerification.InvalidAttestation()
            );
            require(
                header.timestamp < block.timestamp && header.timestamp >= s.challengeTs[teeId],
                ITeeCommonErrors.AvailabilityCheckTimestampInvalid()
            );
            require(
                s.challengeTs[teeId] + s.challengeValidityDurationSeconds > block.timestamp,
                IVerification.ChallengeExpired(s.challengeTs[teeId])
            );
        }

        // Validate request body
        {
            IMachineManager.TeeMachine memory teeMachine = MachineManager.getTeeMachine(teeId);
            require(
                keccak256(bytes(_proof.requestBody.url)) == keccak256(bytes(teeMachine.url)) &&
                _proof.requestBody.teeProxyId == teeMachine.teeProxyId &&
                _proof.requestBody.challenge == s.challenges[teeId],
                IVerification.InvalidRequestBody()
            );
        }

        // The outer SignedPayload envelope binds chainid and the FDC2 domain prefix; the inner
        // dataHash is the keccak256 of the three per-struct hashes of (header, requestBody,
        // responseBody) — including attestationType and sourceId — so signatures cannot be
        // replayed across chains, FDC2 attestation types, sources, or requests. The
        // three-hashes-of-structs layout matches the off-chain FDC2 components.
        bytes32 messageHash = Fdc2ProofVerification.messageHash(
            keccak256(abi.encode(
                keccak256(abi.encode(_proof.header)),
                keccak256(abi.encode(_proof.requestBody)),
                keccak256(abi.encode(_proof.responseBody))
            ))
        );

        ExternalAddresses.State storage ext = ExternalAddresses.getState();
        uint256 currentRewardEpochId = IFlareSystemsManager(ext.flareSystemsManager).getCurrentRewardEpochId();

        if (!MachineEmergencyPause.isExtensionEmergencyPaused(0) && _proof.signatures.teeSignatures.length > 0) {
            Fdc2ProofVerification.verifyTeeSignatures(
                ext.fdc2Verification, _proof.signatures.teeSignatures, messageHash
            );
        } else {
            Fdc2ProofVerification.verifySigningPolicySignatures(
                ext.fdc2Verification, currentRewardEpochId, _proof.signatures.signingPolicySignatures, messageHash
            );
        }

        // Cosigner check for initial availability check
        if (_status == IMachineManager.TeeStatus.INITIALIZED) {
            Fdc2ProofVerification.verifyCosignerSignatures(
                ext.fdc2Verification,
                messageHash,
                _proof.signatures.cosignerSignatures,
                s.cosigners.values(),
                s.cosignersThreshold
            );
        }

        // Validate response body data
        return _validateResponseBody(
            _teeMachineWithAttestationData, _status, teeId, currentRewardEpochId, _proof.responseBody
        );
    }

    /**
     * Extends the availability check validity for a TEE machine.
     * Called internally from MachineManagerFacet (trusted) and VerificationFacet.
     */
    function extendAvailability(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        internal
    {
        State storage s = getState();
        address teeId = _proof.requestBody.teeId;
        uint64 endTs = _proof.header.timestamp + s.availabilityCheckValidityDurationSeconds;
        AvailabilityCheckValidity storage validity = s.availabilityCheckValidity[teeId];
        if (endTs > validity.endTs) {
            validity.endTs = endTs;
            validity.lastSigningPolicyId = _proof.responseBody.lastSigningPolicyId;
            address owner = MachineManager.getTeeMachineOwner(teeId);
            emit IVerification.AvailabilityCheckValidityExtended(teeId, owner, endTs);
        }
    }

    /**
     * Reuses a still-valid challenge for `_teeId` or generates a fresh one, builds the
     * `TEE_ATTESTATION` registration message from `_teeId`'s machine data, dispatches the
     * instruction, and emits `TeeAttestationRequested`.
     * @dev At registration no challenge exists yet (`challengeTs == 0`), so on a real chain —
     *      where `block.timestamp` far exceeds `challengeValidityDurationSeconds` — a fresh
     *      challenge is always generated. Auth (who may request) is the caller's responsibility.
     */
    function requestTeeAttestation(
        address _teeId,
        address _claimBackAddress
    )
        internal
    {
        State storage s = getState();
        bytes32 challenge;
        if (s.challengeTs[_teeId] + s.challengeValidityDurationSeconds > block.timestamp) {
            challenge = s.challenges[_teeId];
        } else {
            (uint256 randomNumber,,) = IRelay(ExternalAddresses.getState().relay).getRandomNumber();
            challenge = keccak256(abi.encode(_teeId, block.timestamp, randomNumber));
            s.challenges[_teeId] = challenge;
            s.challengeTs[_teeId] = block.timestamp;
        }

        IMachineManager.TeeMachineWithAttestationData memory teeMachineWithAttestationData =
            MachineManager.getTeeMachineWithAttestationData(_teeId);

        IVerification.TeeAttestation memory message = IVerification.TeeAttestation({
            teeMachine: teeMachineWithAttestationData,
            challenge: challenge
        });
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;

        Instructions.sendInstructions(
            bytes32(0),
            teeIds,
            IInstructions.TeeInstructionParams(
                REG_OP_TYPE,
                TEE_ATTESTATION,
                abi.encode(message),
                new address[](0),
                0,
                _claimBackAddress
            )
        );
        emit IVerification.TeeAttestationRequested(_teeId, challenge);
    }

    function requestFdc2Attestation(
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
            numberOfTees = 1;
        }
        IFdc2Hub.Fdc2AttestationRequest memory attestationRequest = IFdc2Hub.Fdc2AttestationRequest({
            header: IFdc2Hub.Fdc2RequestHeader({
                attestationType: _attestationType,
                sourceId: _sourceId,
                thresholdBIPS: 0,
                proofOwner: _proofOwner
            }),
            requestBody: _requestBody
        });
        IFdc2Hub(ExternalAddresses.getState().fdc2Hub).requestAttestation{value: msg.value}(
            attestationRequest,
            numberOfTees,
            teeIds,
            _cosigners,
            _cosignersThreshold,
            _claimBackAddress
        );
    }

    function updateSettings(
        uint64 _availabilityCheckValidityDurationSeconds,
        uint64 _signingPolicyValidityDurationInRewardEpochs,
        uint64 _challengeValidityDurationSeconds
    )
        internal
    {
        validateDuration(_availabilityCheckValidityDurationSeconds, 1 hours, 365 days);
        validateDuration(_signingPolicyValidityDurationInRewardEpochs, 1, 100);
        validateDuration(_challengeValidityDurationSeconds, 1 minutes, 1 days);
        State storage s = getState();
        s.availabilityCheckValidityDurationSeconds = _availabilityCheckValidityDurationSeconds;
        s.signingPolicyValidityDurationInRewardEpochs = _signingPolicyValidityDurationInRewardEpochs;
        s.challengeValidityDurationSeconds = _challengeValidityDurationSeconds;
        emit IVerification.SettingsUpdated(
            _availabilityCheckValidityDurationSeconds,
            _signingPolicyValidityDurationInRewardEpochs,
            _challengeValidityDurationSeconds
        );
    }

    // =========================================================================
    // Methods reused by other facets (view / pure)
    // =========================================================================

    function getAvailabilityCheckValidity(
        address _teeId
    )
        internal view
        returns (uint64 _endTs, uint32 _lastSigningPolicyId)
    {
        AvailabilityCheckValidity storage validity = getState().availabilityCheckValidity[_teeId];
        _endTs = validity.endTs;
        _lastSigningPolicyId = validity.lastSigningPolicyId;
    }

    function isSigningPolicyValid(
        uint256 _signingPolicyId,
        uint256 _currentRewardEpochId
    )
        internal view
        returns (bool)
    {
        return _signingPolicyId + getState().signingPolicyValidityDurationInRewardEpochs >= _currentRewardEpochId;
    }

    function validateDuration(
        uint256 _duration,
        uint256 _minDuration,
        uint256 _maxDuration
    )
        internal pure
    {
        require(
            _minDuration <= _duration && _duration <= _maxDuration,
            ITeeCommonErrors.InvalidDuration()
        );
    }

    function getState()
        internal pure
        returns (State storage _state)
    {
        bytes32 position = STATE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _state.slot := position
        }
    }

    // =========================================================================
    // Internal helpers
    // =========================================================================

    function _validateResponseBody(
        IMachineManager.TeeMachineWithAttestationData memory _teeMachineWithAttestationData,
        IMachineManager.TeeStatus _status,
        address _teeId,
        uint256 _currentRewardEpochId,
        ITeeAvailabilityCheck.ResponseBody calldata _responseBody
    )
        private
        returns (bool)
    {
        // Check signing policy validity
        if (_status == IMachineManager.TeeStatus.INITIALIZED) {
            if (_responseBody.initialSigningPolicyId > _currentRewardEpochId ||
                !isSigningPolicyValid(_responseBody.initialSigningPolicyId, _currentRewardEpochId))
            {
                return false;
            }
        } else {
            if (_responseBody.initialSigningPolicyId != MachineManager.getInitialSigningPolicyId(_teeId)) {
                return false;
            }
            State storage s = getState();
            if (!isSigningPolicyValid(
                s.availabilityCheckValidity[_teeId].lastSigningPolicyId,
                _currentRewardEpochId
            )) {
                return false;
            }
        }

        if (_responseBody.codeHash != _teeMachineWithAttestationData.codeHash) {
            return false;
        }

        if (_responseBody.platform != _teeMachineWithAttestationData.platform) {
            return false;
        }

        uint256 lastSigningPolicyId = _responseBody.lastSigningPolicyId;
        if (lastSigningPolicyId != _currentRewardEpochId && lastSigningPolicyId != _currentRewardEpochId + 1) {
            return false;
        }

        // Verify system state
        ITeeAvailabilityCheck.TeeState calldata teeState = _responseBody.state;
        if (!SystemStateVerifier.verifyTeeSystemState(_teeId, teeState.systemStateVersion, teeState.systemState)) {
            return false;
        }

        // Verify extension state
        uint256 extensionId = MachineManager.getExtensionId(_teeId);
        ITeeExtensionStateVerifier teeStateVerifier = ExtensionManager.getTeeExtensionStateVerifier(extensionId);
        if (address(teeStateVerifier) == address(0)) {
            if (teeState.stateVersion != bytes32(0) || teeState.state.length != 0) {
                return false;
            }
        } else {
            if (!teeStateVerifier.verifyTeeState(_teeId, teeState.stateVersion, teeState.state)) {
                return false;
            }
        }

        return true;
    }
}
