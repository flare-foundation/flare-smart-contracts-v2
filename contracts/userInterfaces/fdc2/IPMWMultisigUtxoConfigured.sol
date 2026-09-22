// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IFdc2Hub } from "../fdc2/IFdc2Hub.sol";
import { IFdc2Verification } from "../fdc2/IFdc2Verification.sol";

bytes32 constant PMW_MULTISIG_UTXO_CONFIGURED_ATTESTATION_TYPE = bytes32("PMWMultisigUtxoConfigured");

interface IPMWMultisigUtxoConfigured {

    enum PMWMultisigUtxoStatus { OK, ERROR }

    /**
     * A single parallel anchor chain for a UTXO multisig account.
     * @param genesisAnchorTxid Funding transaction id of the initial anchor UTXO.
     * @param genesisAnchorVout Output index of the initial anchor UTXO.
     */
    struct Anchor {
        bytes32 genesisAnchorTxid;
        uint32 genesisAnchorVout;
    }

    /**
     * Proof for PMWMultisigUtxoConfigured attestation type.
     */
    struct Proof {
        IFdc2Verification.Fdc2Signatures signatures;
        IFdc2Hub.Fdc2ResponseHeader header;
        RequestBody requestBody;
        ResponseBody responseBody;
    }

    /**
     * Request body for PMWMultisigUtxoConfigured attestation type.
     * @param accountIndex Account-level derivation index.
     * @param publicKeys Wallet-level (parent) extended public keys; the account-level keys are
     * their non-hardened children at `accountIndex`.
     * @param threshold Threshold of the multisig account.
     * @param anchors The full set of verified parallel anchor chains.
     */
    struct RequestBody {
        uint32 accountIndex;
        bytes[] publicKeys;
        uint64 threshold;
        Anchor[] anchors;
    }

    /**
     * Response body for PMWMultisigUtxoConfigured attestation type.
     * @param status Status of the multisig account configuration: OK or ERROR.
     * @param accountAddress The account identifier.
     */
    struct ResponseBody {
        PMWMultisigUtxoStatus status;
        string accountAddress;
    }
}
