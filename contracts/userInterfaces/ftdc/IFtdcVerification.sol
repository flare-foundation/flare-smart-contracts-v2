// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../ISignature.sol";

/**
 * FtdcVerification interface.
 */
interface IFtdcVerification {

    /**
     * @dev Verifies the signing policy signatures.
     * @param _relayMessage The relay message to verify.
     * @param _messageHash The message hash to verify.
     * @return _rewardEpochId The reward epoch id of the signing policy.
     */
    function verifySigningPolicySignatures(
        bytes calldata _relayMessage,
        bytes32 _messageHash
    )
        external returns (uint256 _rewardEpochId);

    /**
     * @dev Verifies the TEE signatures.
     * @param _signatures The TEE signatures to verify.
     * @param _messageHash The message hash to verify.
     * @return _signingTeeIds The TEE ids of the signing TEE machines.
     */
    function verifyTeeSignatures(
        Signature[] calldata _signatures,
        bytes32 _messageHash
    )
        external view returns (address[] memory _signingTeeIds);
}
