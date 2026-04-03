// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeMachineRegistryFacet } from "../../userInterfaces/tee/ITeeMachineRegistryFacet.sol";
import { ITeeVerificationFacet, TEE_SOURCE_ID } from "../../userInterfaces/tee/ITeeVerificationFacet.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { ITeeExtensionStateVerifier } from "../../userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { ITeeAvailabilityCheck, TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE }
    from "../../userInterfaces/fdc2/ITeeAvailabilityCheck.sol";
import { IFdc2Hub } from "../../userInterfaces/fdc2/IFdc2Hub.sol";
import { IFdc2Verification } from "../../userInterfaces/fdc2/IFdc2Verification.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { TeeMachineRegistry } from "./TeeMachineRegistry.sol";
import { TeeExtensionRegistry } from "./TeeExtensionRegistry.sol";
import { TeeSystemStateVerifier } from "./TeeSystemStateVerifier.sol";
import { TeeExternalAddresses } from "./TeeExternalAddresses.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title TeeVerification
 * @notice Library for TEE machine verification, challenges, and availability checks.
 * @dev Uses ERC-7201 namespaced storage. Contains methods reused by TeeVerificationFacet,
 *      TeeWalletVerificationFacet, and TeeMachineRegistryFacet.
 */
library TeeVerification {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct AvailabilityCheckValidity {
        uint64 endTs;
        uint32 lastSigningPolicyId;
    }

    /// @custom:storage-location erc7201:tee.TeeVerification.State
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

    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("tee.TeeVerification.State")) - 1)
    ) & ~bytes32(uint256(0xff));

    // =========================================================================
    // Methods reused by other facets
    // =========================================================================

    /**
     * Verifies an availability check proof.
     * _proof.responseBody.status must be checked by the caller.
     */
    function verifyAvailabilityCheckProof(
        ITeeMachineRegistryFacet.TeeMachineWithAttestationData memory _teeMachineWithAttestationData,
        ITeeMachineRegistryFacet.TeeStatus _status,
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
                ITeeVerificationFacet.InvalidAttestation()
            );
            require(
                header.timestamp < block.timestamp && header.timestamp >= s.challengeTs[teeId],
                ITeeCommonErrors.AvailabilityCheckTimestampInvalid()
            );
            require(
                s.challengeTs[teeId] + s.challengeValidityDurationSeconds > block.timestamp,
                ITeeVerificationFacet.ChallengeExpired(s.challengeTs[teeId])
            );
        }

        // Validate request body
        {
            ITeeMachineRegistryFacet.TeeMachine memory teeMachine = TeeMachineRegistry.getTeeMachine(teeId);
            require(
                keccak256(bytes(_proof.requestBody.url)) == keccak256(bytes(teeMachine.url)) &&
                _proof.requestBody.teeProxyId == teeMachine.teeProxyId &&
                _proof.requestBody.challenge == s.challenges[teeId],
                ITeeVerificationFacet.InvalidRequestBody()
            );
        }

        // Verify signatures
        bytes32 messageHash = keccak256(abi.encode(
            keccak256(abi.encode(_proof.header)),
            keccak256(abi.encode(_proof.requestBody)),
            keccak256(abi.encode(_proof.responseBody))
        ));

        TeeExternalAddresses.State storage ext = TeeExternalAddresses.getState();
        uint256 currentRewardEpochId = IFlareSystemsManager(ext.flareSystemsManager).getCurrentRewardEpochId();

        if (_proof.signatures.teeSignatures.length > 0) {
            IFdc2Verification(ext.fdc2Verification).verifyTeeSignatures(
                _proof.signatures.teeSignatures, messageHash
            );
        } else {
            checkSigningPolicySignatures(currentRewardEpochId, messageHash, _proof.signatures.signingPolicySignatures);
        }

        // Cosigner check for initial availability check or active replication
        if (_status == ITeeMachineRegistryFacet.TeeStatus.INITIALIZED ||
            _status == ITeeMachineRegistryFacet.TeeStatus.REPLICATING)
        {
            checkCosignerSignatures(toCosignersMessageHash(messageHash), _proof.signatures.cosignerSignatures);
        }

        // Validate response body data
        return _validateResponseBody(
            _teeMachineWithAttestationData, _status, teeId, currentRewardEpochId, _proof.responseBody
        );
    }

    /**
     * Extends the availability check validity for a TEE machine.
     * Called internally from TeeMachineRegistryFacet (trusted) and TeeVerificationFacet.
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
            address owner = TeeMachineRegistry.getTeeMachineOwner(teeId);
            emit ITeeVerificationFacet.AvailabilityCheckValidityExtended(teeId, owner, endTs);
        }
    }

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

    function checkSigningPolicySignatures(
        uint256 _currentRewardEpochId,
        bytes32 _messageHash,
        bytes calldata _signatures
    )
        internal
    {
        TeeExternalAddresses.State storage ext = TeeExternalAddresses.getState();
        uint256 rewardEpochId = IFdc2Verification(ext.fdc2Verification)
            .verifySigningPolicySignatures(_signatures, _messageHash);
        require(
            rewardEpochId == _currentRewardEpochId || rewardEpochId + 1 == _currentRewardEpochId,
            ITeeVerificationFacet.InvalidSigningPolicy()
        );
    }

    function checkCosignerSignatures(
        bytes32 _messageHash,
        Signature[] calldata _signatures
    )
        internal view
    {
        State storage s = getState();
        if (s.cosignersThreshold == 0) {
            return;
        }
        TeeExternalAddresses.State storage ext = TeeExternalAddresses.getState();
        address[] memory cosignersList = IFdc2Verification(ext.fdc2Verification)
            .verifyCosignerSignatures(_signatures, _messageHash);
        require(cosignersList.length >= s.cosignersThreshold, ITeeVerificationFacet.CosignersThresholdNotMet());
        for (uint256 i = 0; i < cosignersList.length; i++) {
            require(s.cosigners.contains(cosignersList[i]), ITeeCommonErrors.InvalidCosigner(cosignersList[i]));
        }
    }

    function toCosignersMessageHash(
        bytes32 _messageHash
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(bytes.concat(hex"010000000000", _messageHash));
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
        IFdc2Hub(TeeExternalAddresses.getState().fdc2Hub).requestAttestation{value: msg.value}(
            attestationRequest,
            numberOfTees,
            teeIds,
            _cosigners,
            _cosignersThreshold,
            _claimBackAddress
        );
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
        ITeeMachineRegistryFacet.TeeMachineWithAttestationData memory _teeMachineWithAttestationData,
        ITeeMachineRegistryFacet.TeeStatus _status,
        address _teeId,
        uint256 _currentRewardEpochId,
        ITeeAvailabilityCheck.ResponseBody calldata _responseBody
    )
        private
        returns (bool)
    {
        // Check signing policy validity
        if (_status == ITeeMachineRegistryFacet.TeeStatus.INITIALIZED ||
            _status == ITeeMachineRegistryFacet.TeeStatus.REPLICATING)
        {
            if (_responseBody.initialSigningPolicyId > _currentRewardEpochId ||
                !isSigningPolicyValid(_responseBody.initialSigningPolicyId, _currentRewardEpochId))
            {
                return false;
            }
        } else {
            if (_responseBody.initialSigningPolicyId != TeeMachineRegistry.getInitialSigningPolicyId(_teeId)) {
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

        if (_responseBody.codeHash != _teeMachineWithAttestationData.codeHash) return false;
        if (_responseBody.platform != _teeMachineWithAttestationData.platform) return false;

        uint256 lastSigningPolicyId = _responseBody.lastSigningPolicyId;
        if (lastSigningPolicyId != _currentRewardEpochId && lastSigningPolicyId != _currentRewardEpochId + 1) {
            return false;
        }

        // Verify system state
        ITeeAvailabilityCheck.TeeState calldata teeState = _responseBody.state;
        if (!TeeSystemStateVerifier.verifyTeeSystemState(_teeId, teeState.systemStateVersion, teeState.systemState)) {
            return false;
        }

        // Verify extension state
        uint256 extensionId = TeeMachineRegistry.getExtensionId(_teeId);
        ITeeExtensionStateVerifier teeStateVerifier = TeeExtensionRegistry.getTeeExtensionStateVerifier(extensionId);
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
