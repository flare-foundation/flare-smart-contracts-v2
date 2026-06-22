// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeePaymentsModel } from "./ITeePaymentsModel.sol";

/// @dev Operation command for a payment instruction; pass to `getPaymentFee`.
bytes32 constant PAY = bytes32("PAY");
/// @dev Operation command for a payment reissuance; pass to `getPaymentFee`.
bytes32 constant REISSUE = bytes32("REISSUE");

/**
 * Shared TeePayments interface.
 */
interface ITeePaymentsBase is ITeePaymentsModel {

    struct PMWMultisigAccount {
        bytes32 sourceId;
        string accountAddress;
    }

    /// Payment instruction structure.
    struct PaymentInstruction {
        string recipientAddress;
        bytes tokenId;
        uint256 amount;
        uint256 maxFee;
        bytes32 paymentReference;
    }

    /**
     * Reissue fee parameters structure.
     * @param maxFeePerPayment The max fee per payment instruction.
     * @param factorsBIPSPerPayment The factor schedule per payment instruction (in BIPS). Part of max fee.
     * @param delaysSeconds The shared time schedule for all payment instructions (in seconds from the start,
     * ordered ascending).
     */
    struct ReissueFeeParams {
        uint256[] maxFeePerPayment;
        int16[][] factorsBIPSPerPayment;
        uint16[] delaysSeconds;
    }

    error OnlyWalletOwner();
    error OnlySystemExtensionId();
    error OnlyAuthorizationAddress();
    error WrongKeyType();
    error WalletNotInProduction();
    error LengthsMismatch();
    error PaymentHashMismatch();
    error PMWMultisigAccountAddressAlreadySet();
    error PMWMultisigAccountNotRegistered();
    error OnlyProductionOrPausedStatus();
    error UnsupportedSourceId();
    error PaymentAmountZero();
    error InvalidPaymentId();
    error AuthorizationAddressZero();

    /**
     * Payment instruction method.
     * @param _account The PMW multisig account.
     * @param _paymentInstruction The payment instruction.
     * @param _claimBackAddress An address that can claim back the fee if the instructions are not executed (optional).
     * @return _paymentId The payment id of the payment instruction.
     * Can only be called by the authorization address of the PMW multisig account.
     */
    function pay(
        PMWMultisigAccount calldata _account,
        PaymentInstruction calldata _paymentInstruction,
        address _claimBackAddress
    )
        external payable
        returns (uint64 _paymentId);

    /**
     * Payment reissuance method.
     * @param _account The PMW multisig account.
     * @param _batchPaymentId The first payment id of the batch to be reissued.
     * @param _paymentInstructions List of the payment instructions.
     * @param _reissueFeeParams The fee parameters for the reissue.
     * @param _claimBackAddress An address that can claim back the fee if the instructions are not executed (optional).
     * @return _finalized Whether the batch reissue is now finalized. Always true for the account model;
     * for the UTXO model, true once the whole batch has been reissued (the replacement-ready event is emitted).
     * Can only be called by the authorization address of the PMW multisig account.
     */
    function reissue(
        PMWMultisigAccount calldata _account,
        uint64 _batchPaymentId,
        PaymentInstruction[] calldata _paymentInstructions,
        ReissueFeeParams calldata _reissueFeeParams,
        address _claimBackAddress
    )
        external payable
        returns (bool _finalized);

    /**
     * Returns wallet's accounts.
     * @param _walletId The wallet id.
     * @return _walletAccounts The wallet accounts.
     */
    function getWalletAccounts(
        bytes32 _walletId
    )
        external view
        returns (PMWMultisigAccount[] memory _walletAccounts);

    /**
     * Returns wallet's id.
     * @param _account The PMW multisig account.
     * @return _walletId The wallet id.
     */
    function getWalletId(
        PMWMultisigAccount calldata _account
    )
        external view
        returns (bytes32 _walletId);

    /**
     * Returns the authorization address for the given PMW multisig account.
     * @param _account The PMW multisig account.
     * @return _authorizationAddress The authorization address that can submit payment instructions for the account.
     */
    function getAuthorizationAddress(
        PMWMultisigAccount calldata _account
    )
        external view
        returns (address _authorizationAddress);

    /**
     * Returns the fee required to send an operation (e.g. PAY or REISSUE) for the given account.
     * Resolves the wallet and operation type from the account, then returns the same fee a real
     * `pay`/`reissue` would charge (per-tee fee times the deduplicated receiving tee count).
     * Reverts with `PMWMultisigAccountNotRegistered` if the account is not registered, and with
     * `ThresholdNotMet` if the wallet does not have enough available keys.
     * @param _account The PMW multisig account.
     * @param _opCommand The operation command (the exported `PAY` or `REISSUE` constant).
     * @return _fee The fee required, in wei, to send the operation.
     */
    function getPaymentFee(
        PMWMultisigAccount calldata _account,
        bytes32 _opCommand
    )
        external view
        returns (uint256 _fee);

    /**
     * Returns the stored payment hash for an account's payment id — the `keccak256` of the original
     * payment instruction bound to its id. Since the hash is one-way it does not reveal the
     * instruction, but a caller about to reissue can recompute the same hash from the instruction it
     * intends to submit and compare, to pre-validate off-chain before spending gas (a mismatch reverts
     * `PaymentHashMismatch`). Returns 0 if no payment has been recorded at that id.
     * @param _account The PMW multisig account.
     * @param _paymentId The payment id.
     * @return _paymentHash The stored payment hash, or 0 if none.
     */
    function getPaymentHash(
        PMWMultisigAccount calldata _account,
        uint64 _paymentId
    )
        external view
        returns (bytes32 _paymentHash);

    /**
     * Returns the next payment id that will be assigned for an account, i.e. one past the most recent
     * payment. The latest issued payment id is therefore `_nextPaymentId - 1`; a value of 1 means no
     * payment has been made yet. Read it to bootstrap a scan of an account's payments (or, for UTXO
     * accounts, to resolve the current batch via `getBatchPaymentId`/`getBatchRecord`).
     * @param _account The PMW multisig account.
     * @return _nextPaymentId The next payment id to be assigned.
     */
    function getNextPaymentId(
        PMWMultisigAccount calldata _account
    )
        external view
        returns (uint64 _nextPaymentId);
}
