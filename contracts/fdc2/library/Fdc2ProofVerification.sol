// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Signature } from "../../userInterfaces/ISignature.sol";
import { IFdc2Verification } from "../../userInterfaces/fdc2/IFdc2Verification.sol";
import { FDC2 } from "../../userInterfaces/fdc2/IFdc2Hub.sol";
import { SignedPayload } from "../../utils/lib/SignedPayload.sol";

/**
 * @title Fdc2ProofVerification
 * @notice Stateless helpers for verifying FDC2 attestation-proof signatures. The cosigner set + threshold
 *         are passed in by the caller, so this library is storage-agnostic and shared by the TEE Diamond's
 *         own attestation flows and by the TeePayments contracts (which read the cosigner set via the
 *         Diamond's `getCosigners()`).
 * @dev The real signature cryptography lives in the `Fdc2Verification` contract (`verifyTeeSignatures`,
 *      `verifySigningPolicySignatures`, `recoverCosigners`); these helpers only add the reward-epoch window
 *      and the cosigner membership/threshold check over a caller-supplied set. Callers verify the primary
 *      signatures via `verifyTeeSignatures` when TEE signatures are present, otherwise
 *      `verifySigningPolicySignatures`.
 */
library Fdc2ProofVerification {

    /**
     * Verifies the signing-policy signatures and bounds the recovered reward epoch to the current or
     * previous one. Reverts on failure.
     * @param _fdc2Verification The Fdc2Verification contract address.
     * @param _currentRewardEpochId The current reward epoch id.
     * @param _signingPolicySignatures The signing-policy signatures ("relay message" format).
     * @param _messageHash The signed-payload message hash (see `messageHash`).
     */
    function verifySigningPolicySignatures(
        address _fdc2Verification,
        uint256 _currentRewardEpochId,
        bytes calldata _signingPolicySignatures,
        bytes32 _messageHash
    )
        internal
    {
        uint256 rewardEpochId = IFdc2Verification(_fdc2Verification)
            .verifySigningPolicySignatures(_signingPolicySignatures, _messageHash);
        require(
            rewardEpochId == _currentRewardEpochId || rewardEpochId + 1 == _currentRewardEpochId,
            IFdc2Verification.InvalidSigningPolicy()
        );
    }

    /**
     * Verifies the TEE signatures and returns the recovered signing TEE ids. Reverts on failure.
     * @param _fdc2Verification The Fdc2Verification contract address.
     * @param _teeSignatures The TEE signatures.
     * @param _messageHash The signed-payload message hash (see `messageHash`).
     * @return _signingTeeIds The TEE ids that signed (callers may apply their own threshold if desired).
     */
    function verifyTeeSignatures(
        address _fdc2Verification,
        Signature[] calldata _teeSignatures,
        bytes32 _messageHash
    )
        internal view
        returns (address[] memory _signingTeeIds)
    {
        return IFdc2Verification(_fdc2Verification).verifyTeeSignatures(_teeSignatures, _messageHash);
    }

    /**
     * Canonical FDC2 signed-payload message hash for a proof's data hash. The caller computes
     * `_dataHash = keccak256(abi.encode(header, requestBody, responseBody))`.
     * @param _dataHash The proof data hash.
     * @return The signed-payload message hash.
     */
    function messageHash(
        bytes32 _dataHash
    )
        internal view
        returns (bytes32)
    {
        return SignedPayload.messageHash(FDC2, _dataHash);
    }

    /**
     * Verifies cosigner signatures against a caller-supplied cosigner set + threshold. No-op when
     * `_cosignersThreshold == 0`. Reverts if the threshold is not met or a recovered signer is not in the set.
     * @param _fdc2Verification The Fdc2Verification contract address.
     * @param _messageHash The signed-payload message hash (wrapped internally for the cosigner preimage).
     * @param _cosignerSignatures The cosigner signatures.
     * @param _cosigners The valid cosigner set.
     * @param _cosignersThreshold The minimum number of valid cosigner signatures required.
     */
    function verifyCosignerSignatures(
        address _fdc2Verification,
        bytes32 _messageHash,
        Signature[] calldata _cosignerSignatures,
        address[] memory _cosigners,
        uint64 _cosignersThreshold
    )
        internal view
    {
        if (_cosignersThreshold == 0) {
            return;
        }
        address[] memory recovered = IFdc2Verification(_fdc2Verification)
            .recoverCosigners(_cosignerSignatures, toCosignersMessageHash(_messageHash));
        require(recovered.length >= _cosignersThreshold, IFdc2Verification.CosignersThresholdNotMet());
        for (uint256 i = 0; i < recovered.length; i++) {
            require(_contains(_cosigners, recovered[i]), IFdc2Verification.InvalidCosigner(recovered[i]));
        }
    }

    /**
     * Cosigner-signature preimage wrap. The 6-byte prefix is the Relay protocol-message wire format
     * (protocol id 1, zero-padded), distinguishing cosigner signatures from the primary signed payload.
     * @param _messageHash The signed-payload message hash.
     * @return The cosigner preimage hash.
     */
    function toCosignersMessageHash(
        bytes32 _messageHash
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(bytes.concat(hex"010000000000", _messageHash));
    }

    function _contains(
        address[] memory _set,
        address _address
    )
        private pure
        returns (bool)
    {
        for (uint256 i = 0; i < _set.length; i++) {
            if (_set[i] == _address) {
                return true;
            }
        }
        return false;
    }
}
