// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IPMWMultisigAccountConfigured } from "../fdc2/IPMWMultisigAccountConfigured.sol";
import { IPMWMultisigUtxoConfigured } from "../fdc2/IPMWMultisigUtxoConfigured.sol";

/**
 * ITeePaymentsConfigVerifier interface.
 *
 * Single shared contract that requests and verifies PMW multisig configuration attestations for
 * both account-based (`PMWMultisigAccountConfigured`) and UTXO/anchor-based
 * (`PMWMultisigUtxoConfigured`) wallets. Extracted out of the TeePayments contracts so the heavy
 * request/verify code lives in one deployable contract; the payment contracts stay slim and only
 * keep account/anchor/nonce state.
 *
 * The verifier is stateless with respect to accounts and anchors: the `verify*` methods only
 * validate a proof (header, wallet public-key cross-check, signatures, shape, OK status) and
 * return the extracted, verified scalars. The TeePayments / TeePaymentsUtxo contracts perform all
 * storage writes from the returned data.
 *
 * Users call the `request*ConfiguredAttestation` methods on this contract directly; there are no
 * forwarders on the payment contracts. The verifier is discoverable via the AddressUpdater /
 * TeePaymentsRegistry by the name `"TeePaymentsConfigVerifier"`.
 */
interface ITeePaymentsConfigVerifier {

    error UnsupportedSourceId();
    error OnlySystemExtensionId();
    error WrongKeyType();
    error OnlyProductionOrPausedStatus();
    error AccountAddressZero();
    error AnchorSetEmpty();
    error AnchorLimitExceeded();
    error InvalidAttestation();
    error InvalidRequestBody();
    error InvalidProof();

    /**
     * Requests a PMW multisig account configured attestation - triggers an FDC2 attestation request.
     * @param _walletId The wallet id.
     * @param _sourceId The source id.
     * @param _accountAddress The account address.
     * @param _testOnTeeId The TEE machine id to test on; if address(0) a random active TEE is used.
     * @param _proofOwner The proof owner address (optional).
     * @param _claimBackAddress An address that can claim back the fee if not executed (optional).
     */
    function requestAccountConfiguredAttestation(
        bytes32 _walletId,
        bytes32 _sourceId,
        string calldata _accountAddress,
        address _testOnTeeId,
        address _proofOwner,
        address _claimBackAddress
    )
        external payable;

    /**
     * Requests a PMW multisig UTXO configured attestation - triggers an FDC2 attestation request.
     * @param _walletId The wallet id.
     * @param _sourceId The source id.
     * @param _accountIndex The account-level derivation index.
     * @param _anchors The full set of parallel anchor chains to attest.
     * @param _testOnTeeId The TEE machine id to test on; if address(0) a random active TEE is used.
     * @param _proofOwner The proof owner address (optional).
     * @param _claimBackAddress An address that can claim back the fee if not executed (optional).
     */
    function requestUtxoConfiguredAttestation(
        bytes32 _walletId,
        bytes32 _sourceId,
        uint32 _accountIndex,
        IPMWMultisigUtxoConfigured.Anchor[] calldata _anchors,
        address _testOnTeeId,
        address _proofOwner,
        address _claimBackAddress
    )
        external payable;

    /**
     * Verifies a `PMWMultisigAccountConfigured` proof against the wallet's keys and the cosigner set.
     * Reverts if the proof is invalid or its status is not OK; returns normally when the proof is valid.
     * The caller reads the verified fields (sourceId, accountAddress, sequence) directly from `_proof`.
     * @param _walletId The wallet id whose public keys the proof request body must match.
     * @param _proof The PMW multisig account configured proof.
     */
    function verifyAccountConfiguredProof(
        bytes32 _walletId,
        IPMWMultisigAccountConfigured.Proof calldata _proof
    )
        external;

    /**
     * Verifies a `PMWMultisigUtxoConfigured` proof against the wallet's keys and the cosigner set.
     * Reverts if the proof is invalid, malformed, or its status is not OK; returns normally when valid.
     * The caller reads the verified fields (sourceId, accountAddress, accountIndex, anchors)
     * directly from `_proof`.
     * @param _walletId The wallet id whose public keys the proof request body must match.
     * @param _proof The PMW multisig UTXO configured proof.
     */
    function verifyUtxoConfiguredProof(
        bytes32 _walletId,
        IPMWMultisigUtxoConfigured.Proof calldata _proof
    )
        external;
}
