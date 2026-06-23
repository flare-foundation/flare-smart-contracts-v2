// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IFdc2Hub } from "../fdc2/IFdc2Hub.sol";
import { IFdc2Verification } from "../fdc2/IFdc2Verification.sol";

bytes32 constant PMW_FEE_PROOF_ATTESTATION_TYPE = bytes32("PMWFeeProof");

/**
 * Attestation proving aggregate fee accounting over a contiguous range of payments made by a
 * TeePayments wallet. The same interface serves both payment models:
 * - account-based wallets (`ITeePayments`): one payment per transaction, so the range is a span
 *   of individual payments;
 * - UTXO / anchor-based wallets (`ITeePaymentsUtxo`): payments are grouped into batches and each
 *   batch is settled in a single transaction, so the range is a span of whole batches.
 * The request's `opType` and the proof header's `sourceId` select which wallet and model the
 * range belongs to. Fees are inherently per-transaction; the range is therefore expressed in
 * batches (a single payment in the account-based model is just a batch of one) so the proven
 * sums always align to transaction boundaries.
 */
interface IPMWFeeProof {

    /**
     * Proof for PMWFeeProof attestation type
     */
    struct Proof {
        IFdc2Verification.Fdc2Signatures signatures;
        IFdc2Hub.Fdc2ResponseHeader header;
        RequestBody requestBody;
        ResponseBody responseBody;
    }

    /**
     * Request body for PMWFeeProof attestation type
     * @param opType Source operation type of the payment pipeline (the sourceOpType registered
     * for the proof's sourceId); binds the proof to a specific wallet operation.
     * @param senderAddress The wallet's account identifier on the source chain (the sender
     * account address for account-based wallets, the account address for UTXO wallets). Together
     * with the header's sourceId it resolves the walletId the range is accounted under.
     * @param firstPaymentId Payment id (per account, starting at 1) of the first payment in the
     * range. Because fees are accounted per transaction, for UTXO wallets this must be the first
     * payment id of a batch (its batchPaymentId) - a firstPaymentId that falls inside a batch is
     * rejected. For account-based wallets every payment starts its own (single-payment) batch.
     * @param batchCount Number of batches to include, counting forward from the batch that starts
     * at firstPaymentId. For UTXO wallets this counts whole batches (whole transactions); for
     * account-based wallets, where each payment is a batch of one, it is simply the number of
     * payments.
     * @param untilTimestamp Cutoff timestamp for including reissue events in the estimated fee.
     * Reissue events after this timestamp are ignored, so an in-flight reissue cannot change the
     * proven estimate.
     */
    struct RequestBody {
        bytes32 opType;
        string senderAddress;
        uint64 firstPaymentId;
        uint64 batchCount;
        uint64 untilTimestamp;
    }

    /**
     * Response body for PMWFeeProof attestation type
     * @param lastPaymentId Payment id of the last payment included in the range (inclusive). It is
     * returned because for UTXO wallets it is not derivable from the request (batch sizes vary):
     * it is the last payment id of the batchCount-th batch. For account-based wallets it equals
     * firstPaymentId + batchCount - 1.
     * @param actualFee Sum, in the source chain's minimal units, of the actual transaction fees
     * paid for the transactions covering payment ids [firstPaymentId, lastPaymentId].
     * @param estimatedFee Sum, in the source chain's minimal units, of the estimated fees for the
     * same range, derived from the maxFee values in the pay and (up to untilTimestamp) reissue
     * instructions.
     */
    struct ResponseBody {
        uint64 lastPaymentId;
        uint256 actualFee;
        uint256 estimatedFee;
    }
}
