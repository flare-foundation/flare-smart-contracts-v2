// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IFdc2Hub } from "../fdc2/IFdc2Hub.sol";
import { IFdc2Verification } from "../fdc2/IFdc2Verification.sol";

bytes32 constant PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE = bytes32("PMWMultisigAccountConfigured");

interface IPMWMultisigAccountConfigured {

    enum PMWMultisigAccountStatus { OK, ERROR }

    /**
     * Proof for PMWMultisigAccountConfigured attestation type
     */
    struct Proof {
        IFdc2Verification.Fdc2Signatures signatures;
        IFdc2Hub.Fdc2ResponseHeader header;
        RequestBody requestBody;
        ResponseBody responseBody;
    }

    /**
     * Request body for PMWMultisigAccountConfigured attestation type
     * @param accountAddress Address of the multisig account.
     * @param publicKeys Public keys of the multisig account owners.
     * @param threshold Threshold for the multisig account.
     */
    struct RequestBody {
        string accountAddress;
        bytes[] publicKeys;
        uint64 threshold;
    }

    /**
     * Response body for PMWMultisigAccountConfigured attestation type
     * @param status Status of the multisig account configuration: OK or ERROR.
     * @param sequence Sequence number of the multisig account.
     */
    struct ResponseBody {
        PMWMultisigAccountStatus status;
        uint64 sequence;
    }
}
