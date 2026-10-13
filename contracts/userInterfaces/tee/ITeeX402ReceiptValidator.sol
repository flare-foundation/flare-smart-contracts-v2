// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

/**
 * @title ITeeX402ReceiptValidator
 * @notice Validates x402 Execution Evidence receipts bound to Flare TEE payments.
 */
interface ITeeX402ReceiptValidator {

    struct X402Receipt {
        bytes32 evidenceRef;      // SHA-256 hash of the off-chain execution delivery event
        bytes32 fingerprint;      // RFC 8785 canonical digest (join key)
        bytes32 sourceId;         // Registered TeePayments sourceId
        address payer;            // Agent or user funding the execution
        uint256 amount;           // Settled payment amount (FLR / native asset)
        uint64 timestamp;         // Unix timestamp of execution
        bytes signature;          // Enclave Attestation Key (AK) or facilitator signature
    }

    event X402ReceiptSettled(
        bytes32 indexed evidenceRef,
        bytes32 indexed fingerprint,
        bytes32 indexed sourceId,
        address payer,
        uint256 amount
    );

    error InvalidEvidenceRef(bytes32 evidenceRef);
    error ReceiptAlreadySpent(bytes32 fingerprint);
    error InvalidEnclaveSignature(bytes32 fingerprint);
    error SourceNotActive(bytes32 sourceId);

    /**
     * @notice Verifies an x402 execution receipt and binds it to a TEE payment source.
     * @param _receipt The x402 receipt struct.
     * @return _success True if valid and recorded.
     */
    function verifyAndRecordReceipt(
        X402Receipt calldata _receipt
    )
        external
        returns (bool _success);

    /**
     * @notice Checks if a receipt fingerprint has already been settled.
     * @param _fingerprint The receipt join key.
     * @return _settled True if previously settled.
     */
    function isReceiptSettled(
        bytes32 _fingerprint
    )
        external view
        returns (bool _settled);
}
