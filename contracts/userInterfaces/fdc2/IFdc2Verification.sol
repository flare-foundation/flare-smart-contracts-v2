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
