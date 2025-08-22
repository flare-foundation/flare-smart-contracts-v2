// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IFtdcHub } from "../ftdc/IFtdcHub.sol";
import { IFtdcVerification } from "../ftdc/IFtdcVerification.sol";

bytes32 constant PMW_PAYMENT_STATUS_ATTESTATION_TYPE = bytes32("PMWPaymentStatus");

interface IPMWPaymentStatus {

    /**
     * Proof for PMWPaymentStatus attestation type
     */
    struct Proof {
        IFtdcVerification.FtdcSignatures signatures;
        IFtdcHub.FtdcResponseHeader header;
        RequestBody requestBody;
        ResponseBody responseBody;
    }

    /**
     * Request body for PMWPaymentStatus attestation type
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
     * Response body for PMWPaymentStatus attestation type
     * @param senderAddress Sender address.
     * @param recipientAddress Recipient address.
     * @param amount Amount in minimal units that should be send.
     * @param fee Fee in minimal units that should be paid for the transaction.
     * @param paymentInstruction Payment instruction message as emitted on-chain.
     * @param transactionStatus Success status of the transaction: 0 - success, 1 - failed by sender's fault,
     * 2 - failed by receiver's fault.
     * @param revertReason Revert reason from the blockchain, if transaction status is not success.
     * @param receivedAmount Amount in minimal units received by the receiving address.
     * @param transactionFee Total fee in minimal units used for the transaction.
     * In the case of batch payments, all proofs for different sub-nonces would have the same transaction fee value.
     * @param transactionId ID of the payment transaction.
     * @param blockNumber Number of the block in which the transaction is included.
     * @param blockTimestamp The timestamp of the block in which the transaction is included.
     */
    struct ResponseBody {
        string senderAddress;
        string recipientAddress;
        uint256 amount;
        uint256 fee;
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
