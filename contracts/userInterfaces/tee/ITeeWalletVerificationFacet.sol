// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IPMWMultisigAccountConfigured } from "../fdc2/IPMWMultisigAccountConfigured.sol";
import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";

/**
 * @title ITeeWalletVerificationFacet
 * @notice Public interface for the TeeWalletVerificationFacet (PMW verification).
 */
interface ITeeWalletVerificationFacet is ITeeCommonErrors {

    error AccountAddressZero();

    /**
     * Request PMW multisig account configured attestation - triggers FDC2 attestation.
     * @param _walletId The wallet id.
     * @param _sourceId The source id.
     * @param _accountAddress The account address.
     * @param _testOnTeeId The TEE machine id to test on, if address(0) a random active TEE
     *        machine will be used.
     * @param _proofOwner The proof owner address (optional).
     * @param _claimBackAddress An address that can claim back the fee if the instructions
     *        are not executed (optional).
     */
    function requestPMWMultisigAccountConfiguredAttestation(
        bytes32 _walletId,
        bytes32 _sourceId,
        string calldata _accountAddress,
        address _testOnTeeId,
        address _proofOwner,
        address _claimBackAddress
    )
        external payable;

    /**
     * Verify PMW multisig account configured proof.
     * @param _walletId The wallet id.
     * @param _proof The PMW multisig account configured proof.
     * @return True if the response status is OK.
     */
    function verifyPMWMultisigAccountConfiguredProof(
        bytes32 _walletId,
        IPMWMultisigAccountConfigured.Proof calldata _proof
    )
        external
        returns (bool);
}
