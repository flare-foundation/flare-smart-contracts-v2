// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

import { ITeePaymentsBase } from "./ITeePaymentsBase.sol";
import { TeeIdKeyIdPair } from "./ITeeIdKeyIdPair.sol";
import { IPMWMultisigAccountConfigured } from "../fdc2/IPMWMultisigAccountConfigured.sol";

/**
 * Account-based TeePayments interface.
 */
interface ITeePayments is ITeePaymentsBase {

    struct PaymentInstructionMessage {
        bytes32 walletId;
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        bytes32 sourceId;
        string senderAddress;
        string recipientAddress;
        bytes tokenId;
        uint256 amount;
        uint256 maxFee;
        bytes feeSchedule;
        bytes32 paymentReference;
        uint64 nonce;
        uint64 paymentId;
    }

    event PMWMultisigAccountAdded(
        bytes32 indexed walletId,
        bytes32 sourceId,
        string accountAddress,
        address authorizationAddress,
        uint64 initialNonce
    );

    error InvalidPaymentInstructionCount();
    /// Account-model reissue is always a fresh, single-payment reissue, so `reissue` must be called
    /// with `startNew == true`; `false` reverts this.
    error StartNewRequired();

    /**
     * Method for adding the PMW multisig account to the wallet.
     * Emits PMWMultisigAccountAdded event.
     *
     * The authorization address is IMMUTABLE for the account's lifetime: there is no rotation
     * entry point and the account can never be re-registered. This is deliberate — the wallet
     * owner key stays an admin key with no spend authority (it can pause the wallet but not move
     * funds), and counterparties can audit the authorization contract once, knowing the owner
     * cannot swap it out. Register a contract with its own key management and rotate behind it
     * (see the sample instructions sender pattern); a bare EOA risks permanently stranding the
     * account's funds if its key is lost.
     * @param _walletId The wallet id.
     * @param _proof The PMW multisig account configured proof.
     * @param _authorizationAddress The address authorized to submit payment instructions for the account.
     * Can only be called by the wallet owner.
     */
    function addPMWMultisigAccount(
        bytes32 _walletId,
        IPMWMultisigAccountConfigured.Proof calldata _proof,
        address _authorizationAddress
    )
        external;

    /**
     * Returns the initial nonce recorded for the given PMW multisig account at registration.
     * This is the account's `sequence` from the verified PMWMultisigAccountConfigured proof; the
     * native nonce of payment id `n` is `initialNonce + n - 1`. An initial nonce of 0 is a valid
     * value; reverts with `PMWMultisigAccountNotRegistered` if the account has not been registered.
     * @param _account The PMW multisig account.
     * @return _initialNonce The initial nonce recorded at registration.
     */
    function getInitialNonce(
        PMWMultisigAccount calldata _account
    )
        external view
        returns (uint64 _initialNonce);

}
