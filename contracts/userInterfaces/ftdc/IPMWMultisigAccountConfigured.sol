// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IFtdcHub } from "../ftdc/IFtdcHub.sol";
import { IFtdcVerification } from "../ftdc/IFtdcVerification.sol";

bytes32 constant PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE = bytes32("PMWMultisigAccountConfigured");

interface IPMWMultisigAccountConfigured {

    enum PMWMultisigAccountStatus { OK, ERROR }

    /**
     * Proof for PMWMultisigAccountConfigured attestation type
     */
    struct Proof {
        IFtdcVerification.FtdcSignatures signatures;
        IFtdcHub.FtdcResponseHeader header;
        RequestBody requestBody;
        ResponseBody responseBody;
    }

    /**
     * Request body for PMWMultisigAccountConfigured attestation type
     * @param walletAddress Address of the multisig wallet.
     * @param publicKeys Public keys of the multisig wallet owners.
     * @param threshold Threshold for the multisig wallet.
     */
    struct RequestBody {
        string walletAddress;
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
