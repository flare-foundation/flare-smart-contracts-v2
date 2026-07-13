// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IFdc2Hub } from "../fdc2/IFdc2Hub.sol";
import { IFdc2Verification } from "../fdc2/IFdc2Verification.sol";

bytes32 constant PMW_PAYMENT_STATUS_ATTESTATION_TYPE = bytes32("PMWPaymentStatus");

/**
 * Attestation proving the on-chain outcome of a single payment made by a TeePayments wallet. The
 * same interface serves both payment models:
 * - account-based wallets (`ITeePayments`): one payment per transaction;
 * - UTXO / anchor-based wallets (`ITeePaymentsUtxo`): many payments per batch transaction.
 * A payment is identified solely by its per-account paymentId; the response reports the payment's
 * instructed terms (from the C-chain instruction) alongside what actually happened on the source
 * chain.
 */
interface IPMWPaymentStatus {

    /**
     * Proof for PMWPaymentStatus attestation type
     */
    struct Proof {
        IFdc2Verification.Fdc2Signatures signatures;
        IFdc2Hub.Fdc2ResponseHeader header;
        RequestBody requestBody;
        ResponseBody responseBody;
    }

    /**
     * Request body for PMWPaymentStatus attestation type
     * @param opType Source operation type of the payment pipeline (the sourceOpType registered
     * for the proof's sourceId); binds the proof to a specific wallet operation.
     * @param senderAddress The wallet's account identifier on the source chain (the sender
     * account address for account-based wallets, the account address for UTXO wallets). Together
     * with the header's sourceId it resolves the walletId.
     * @param paymentId Per-account payment id (starting at 1) of the payment to prove. It is
     * unique within the account, so it identifies the payment on its own: for account-based
     * wallets it maps one-to-one to the settling transaction; for UTXO wallets it is monotonic
     * across all anchor chains and does not reset per batch, pinpointing the payment within its
     * batch. The settling transaction's anchor index and nonce are recovered off-chain from the
     * on-chain payment instruction, so they are not part of the request.
     */
    struct RequestBody {
        bytes32 opType;
        string senderAddress;
        uint64 paymentId;
    }

    /**
     * Response body for PMWPaymentStatus attestation type. The instructed terms (recipientAddress,
     * tokenId, amount, maxFee, paymentReference) come from the C-chain payment instruction; the
     * settlement fields (transactionStatus onward) come from the confirmed source-chain transaction.
     * @param recipientAddress Recipient address.
     * @param tokenId Token ID (e.g. address) for the payment, bytes(0) means native token.
     * @param amount Amount in minimal units that should be sent.
     * @param maxFee Maximum fee in minimal units that can be paid for the transaction.
     * @param paymentReference Payment reference of the transaction.
     * @param transactionStatus Success status of the transaction: 0 - success, 1 - reverted.
     * @param revertReason Revert reason from the blockchain, if transaction status is not success.
     * @param receivedAmount Amount in minimal units received by the receiving address.
     * @param transactionFee Total fee in minimal units used for the (whole) transaction. For UTXO
     * wallets a transaction settles a whole batch, so proofs for different paymentIds in the same
     * batch all report the same transactionFee value.
     * @param transactionId ID of the payment transaction.
     * @param blockNumber Number of the block in which the transaction is included.
     * @param blockTimestamp The timestamp of the block in which the transaction is included.
     */
    struct ResponseBody {
        string recipientAddress;
        bytes tokenId;
        uint256 amount;
        uint256 maxFee;
        bytes32 paymentReference;
        uint8 transactionStatus;
        string revertReason;
        uint256 receivedAmount;
        uint256 transactionFee;
        bytes32 transactionId;
        uint64 blockNumber;
        uint64 blockTimestamp;
    }
}
