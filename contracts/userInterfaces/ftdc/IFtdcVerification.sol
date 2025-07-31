// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../ISignature.sol";

/**
 * FtdcVerification interface.
 */
interface IFtdcVerification {

    /**
     * Ftdc signatures.
     * @param signingPolicySignatures Signatures of signing policy in a format as used on the relay contract.
     * @param teeSignatures Signatures of the TEEs.
     * @param cosignerSignatures Signatures of the cosigners.
     */
    struct FtdcSignatures {
        bytes signingPolicySignatures;
        Signature[] teeSignatures;
        Signature[] cosignerSignatures;
    }

    error TeeMachineNotAvailable();
    error DuplicatedTeeId(address teeId);
    error DuplicatedCosigner(address cosigner);

    /**
     * Verifies the signing policy signatures.
     * @param _signingPolicySignatures The signing policy signatures to verify ("relay message" format).
     * @param _messageHash The message hash to verify.
     * @return _rewardEpochId The reward epoch id of the signing policy.
     */
    function verifySigningPolicySignatures(
        bytes calldata _signingPolicySignatures,
        bytes32 _messageHash
    )
        external returns (uint256 _rewardEpochId);

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
        external view returns (address _signingTeeId);

    /**
     * Verifies the TEE signatures.
     * @param _signatures The TEE signatures to verify.
     * @param _messageHash The message hash to verify.
     * @return _signingTeeIds The TEE ids of the signing TEE machines.
     */
    function verifyTeeSignatures(
        Signature[] calldata _signatures,
        bytes32 _messageHash
    )
        external view returns (address[] memory _signingTeeIds);

    /**
     * Verifies the cosigner signatures.
     * @param _signatures The cosigner signatures to verify.
     * @param _messageHash The message hash to verify.
     * @return _cosigners The cosigner addresses.
     */
    function verifyCosignerSignatures(
        Signature[] calldata _signatures,
        bytes32 _messageHash
    )
        external view returns(address[] memory _cosigners);
}
