// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../ISignature.sol";
import "../tee/ITeePayments.sol";

bytes32 constant PMW_PAYMENT_STATUS_ATTESTATION_TYPE = bytes32("PMWPaymentStatus");

interface IPMWPaymentStatus {

    /**
     * @notice Toplevel request
     * @param attestationType ID of the attestation type.
     * @param sourceId Id of the data source.
     * @param requestBody Data defining the request. Type and interpretation is determined by the `attestationType`.
     */
    struct Request {
        bytes32 attestationType;
        bytes32 sourceId;
        RequestBody requestBody;
    }

    /**
     * @notice Toplevel response
     * @param attestationType Extracted from the request.
     * @param sourceId Extracted from the request.
     * @param thresholdBIPS Extracted from the request (event).
     * @param timestamp Extracted from the request (block timestamp).
     * @param cosigners Extracted from the request (event).
     * @param cosignersThreshold Extracted from the request (event).
     * @param requestBody Extracted from the request.
     * @param responseBody Data defining the response. The verification rules for the construction of the
     * response body and the type are defined per specific `attestationType`.
     */
    struct Response {
        bytes32 attestationType;
        bytes32 sourceId;
        uint16 thresholdBIPS;
        uint64 timestamp;
        address[] cosigners;
        uint64 cosignersThreshold;
        RequestBody requestBody;
        ResponseBody responseBody;
    }

    /**
     * @notice Toplevel proof
     * @param relayMessage Relay message used for verification on the relay contract - signatures of data providers.
     * @param teeSignatures Signatures of the TEEs.
     * @param cosignerSignatures Signatures of the cosigners.
     * @param data Attestation response.
     */
    struct Proof {
        bytes relayMessage;
        Signature[] teeSignatures;
        Signature[] cosignerSignatures;
        Response data;
    }

    /**
     * @notice Request body for PMWPaymentStatus attestation type
     * @param walletId Wallet ID for which the payment status is requested.
     * @param nonce Nonce of the payment instruction (batch).
     * @param subNonce Sub-nonce of the payment instruction.
     */
    struct RequestBody {
        bytes32 walletId;
        uint64 nonce;
        uint64 subNonce;
    }

    /**
     * @notice Response body for PMWPaymentStatus attestation type
     * @param senderAddress Sender address.
     * @param recipientAddress Recipient address.
     * @param amount Amount in minimal units that should be send.
     * @param fee Fee in minimal units that should be paid for the transaction.
     * @param paymentInstruction Payment instruction message as emitted on-chain.
     * @param status Success status of the transaction: 0 - success, 1 - failed by sender's fault,
     * 2 - failed by receiver's fault.
     * @param blockchainRevertStatus Revert reason from the blockchain, if available.
     * @param receivedAmount Amount in minimal units received by the receiving address.
     * @param spentAmount Amount in minimal units spent by the source address.
     * @param blockNumber Number of the block in which the transaction is included.
     * @param blockTimestamp The timestamp of the block in which the transaction is included.
     */
    struct ResponseBody {
        string senderAddress;
        string recipientAddress;
        uint256 amount;
        uint256 fee;
        bytes32 paymentReference;
        uint8 status;
        string blockchainRevertStatus;
        int256 receivedAmount;
        int256 spentAmount;
        uint64 blockNumber;
        uint64 blockTimestamp;
    }
}
