// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

import { Signature } from "../ISignature.sol";

/**
 * Fdc2Verification interface.
 */
interface IFdc2Verification {

    /**
     * Fdc2 signatures.
     * @param signingPolicySignatures Signatures of signing policy in a format as used on the relay contract.
     * @param teeSignatures Signatures of the TEEs.
     * @param cosignerSignatures Signatures of the cosigners.
     */
    struct Fdc2Signatures {
        bytes signingPolicySignatures;
        Signature[] teeSignatures;
        Signature[] cosignerSignatures;
    }

    error TeeMachineNotAvailable();
    error InvalidTeeMachineExtensionId();
    error DuplicatedTeeId(address teeId);
    error DuplicatedCosigner(address cosigner);
    error InvalidSigningPolicy();
    error CosignersThresholdNotMet();
    error InvalidCosigner(address cosigner);
    error SystemExtensionEmergencyPaused();
    error ExtensionEmergencyPaused(uint256 extensionId);
    error NoTeeSignatures();

    /**
     * Verifies the signing policy signatures using the signing policy threshold.
     * @param _signingPolicySignatures The signing policy signatures to verify ("relay message" format).
     * @param _messageHash The message hash to verify.
     * @return _rewardEpochId The reward epoch id of the signing policy.
     */
    function verifySigningPolicySignatures(
        bytes calldata _signingPolicySignatures,
        bytes32 _messageHash
    )
        external
        returns (uint256 _rewardEpochId);

    /**
     * Verifies the signing policy signatures against a caller-chosen signature-weight threshold
     * instead of the signing policy's own (see `IRelay.verifyCustomSignatureWithThreshold`).
     * NOTE: a threshold below the signing policy's only weakens THIS check's acceptance rule —
     * success then means "more than the requested fraction of the weight signed", not that the
     * protocol's quorum was reached.
     * @param _signingPolicySignatures The signing policy signatures to verify ("relay message" format).
     * @param _messageHash The message hash to verify.
     * @param _thresholdBIPS The threshold in BIPS of the signing policy's total normalized weight,
     * as in `Fdc2RequestHeader.thresholdBIPS`; 0 uses the signing policy's own threshold.
     * A nonzero value requires
     * `signedWeight * 10000 > totalWeight * _thresholdBIPS`; equivalently, the fractional
     * threshold is rounded down and compared with strict inequality. Thus 5000 (50%) requires
     * strictly more than 50% of the weight. Values of 10000 and above are unsatisfiable and
     * revert with `IRelay.ThresholdTooHigh`.
     * @return _rewardEpochId The reward epoch id of the signing policy.
     */
    function verifySigningPolicySignaturesWithThreshold(
        bytes calldata _signingPolicySignatures,
        bytes32 _messageHash,
        uint16 _thresholdBIPS
    )
        external
        returns (uint256 _rewardEpochId);

    /**
     * Verifies the TEE signature.
     * @param _signature The TEE signature to verify.
     * @param _messageHash The message hash to verify.
     * @return _signingTeeId The TEE id of the signing TEE machine.
     */
    function verifyTeeSignature(
        Signature calldata _signature,
        bytes32 _messageHash
    )
        external view
        returns (address _signingTeeId);

    /**
     * Verifies a TEE signature for a caller-chosen extension.
     * Same acceptance rule as the two-argument overload, but the recovered signer must be a
     * PRODUCTION-status TEE machine on the given extension instead of the system extension (id 0).
     * Reverts with ExtensionEmergencyPaused if that extension is emergency paused, and with
     * InvalidTeeMachineExtensionId or TeeMachineNotAvailable if the signer does not qualify.
     * @param _extensionId The extension id the signing TEE machine must belong to.
     * @param _signature The TEE signature to verify.
     * @param _messageHash The message hash to verify.
     * @return _signingTeeId The TEE id of the signing TEE machine.
     */
    function verifyTeeSignature(
        uint256 _extensionId,
        Signature calldata _signature,
        bytes32 _messageHash
    )
        external view
        returns (address _signingTeeId);

    /**
     * Verifies the TEE signatures.
     * Reverts with NoTeeSignatures if the array is empty (guarantees at least one verified signer on return).
     * Does not enforce any threshold beyond non-emptiness - callers must check that the number of signatures
     * meets their own threshold.
     * Each recovered signer must be a PRODUCTION-status TEE machine on the system extension (id 0); reverts with
     * InvalidTeeMachineExtensionId, TeeMachineNotAvailable or DuplicatedTeeId otherwise.
     * Reverts with SystemExtensionEmergencyPaused if the system extension is emergency paused.
     * @param _signatures The TEE signatures to verify.
     * @param _messageHash The message hash to verify.
     * @return _signingTeeIds The TEE ids of the signing TEE machines.
     */
    function verifyTeeSignatures(
        Signature[] calldata _signatures,
        bytes32 _messageHash
    )
        external view
        returns (address[] memory _signingTeeIds);

    /**
     * Verifies the TEE signatures for a caller-chosen extension.
     * Same acceptance rule as the two-argument overload, but each recovered signer must be a
     * PRODUCTION-status TEE machine on the given extension instead of the system extension (id 0),
     * and the emergency-pause check applies to that extension (ExtensionEmergencyPaused).
     * @param _extensionId The extension id the signing TEE machines must belong to.
     * @param _signatures The TEE signatures to verify.
     * @param _messageHash The message hash to verify.
     * @return _signingTeeIds The TEE ids of the signing TEE machines.
     */
    function verifyTeeSignatures(
        uint256 _extensionId,
        Signature[] calldata _signatures,
        bytes32 _messageHash
    )
        external view
        returns (address[] memory _signingTeeIds);

    /**
     * Recovers the cosigner addresses from the given signatures and checks for duplicates.
     * Does not perform any identity or policy validation — callers must validate the returned
     * addresses against their own cosigner set.
     * @param _signatures The cosigner signatures.
     * @param _messageHash The signed message hash.
     * @return _cosigners The recovered (unique) cosigner addresses.
     */
    function recoverCosigners(
        Signature[] calldata _signatures,
        bytes32 _messageHash
    )
        external view
        returns (address[] memory _cosigners);
}
