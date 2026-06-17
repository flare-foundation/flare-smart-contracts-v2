// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeePaymentsModel } from "./ITeePaymentsModel.sol";

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
}
