// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeePayments } from "./ITeePayments.sol";
import { TeeIdKeyIdPair } from "./ITeeIdKeyIdPair.sol";

/**
 * ITeePaymentsLimitsManager interface.
 *
 * Shared entry point for setting per-account payment limits. Resolves the right
 * TeePayments instance via the TeePaymentsRegistry (keyed on sourceId) and forwards
 * SET_PAYMENT_LIMITS instructions to the wallet's TEE admins.
 */
interface ITeePaymentsLimitsManager {

    /// Message encoded and forwarded to the TEE as SET_PAYMENT_LIMITS payload.
    struct SetPaymentLimitsMessage {
        bytes32 walletId;
        bytes32 sourceId;
        string accountAddress;
        uint256 nonce;
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        uint256 transactionLimit;
        uint256 dailyLimit;
    }

    event PaymentLimitsSet(
        bytes32 indexed walletId,
        bytes32 sourceId,
        string accountAddress,
        uint256 transactionLimit,
        uint256 dailyLimit
    );

    error OnlyWalletOwner();
    error DailyLimitBelowTransactionLimit();
    error AccountNotRegistered();
    error UnsupportedSourceId();

    /**
     * Sends SET_PAYMENT_LIMITS instructions for the given account.
     * Emits PaymentLimitsSet event.
     * @param _account The PMW multisig account.
     * @param _transactionLimit The transaction limit.
     * @param _dailyLimit The daily limit.
     * @param _claimBackAddress An address that can claim back the fee if the instructions are not executed (optional).
     * Can only be called by the account owner (= project owner).
     */
    function setPaymentLimits(
        ITeePayments.PMWMultisigAccount calldata _account,
        uint256 _transactionLimit,
        uint256 _dailyLimit,
        address _claimBackAddress
    )
        external payable;

    /**
     * Returns the current SET_PAYMENT_LIMITS nonce for the given account.
     * @param _account The PMW multisig account.
     * @return _nonce The current nonce.
     */
    function getPaymentLimitsNonce(
        ITeePayments.PMWMultisigAccount calldata _account
    )
        external view
        returns (uint256 _nonce);
}
