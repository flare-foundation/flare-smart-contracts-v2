// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IFdc2Hub } from "../fdc2/IFdc2Hub.sol";
import { IFdc2Verification } from "../fdc2/IFdc2Verification.sol";

bytes32 constant PMW_FEE_PROOF_ATTESTATION_TYPE = bytes32("PMWFeeProof");

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
     * @param opType Operation type.
     * @param senderAddress Sender address.
     * @param fromNonce Nonce of the first payment.
     * @param toNonce Nonce of the last payment (inclusive).
     * @param untilTimestamp Timestamp defining the cutoff for fetching reissue events.
     */
    struct RequestBody {
        bytes32 opType;
        string senderAddress;
        uint64 fromNonce;
        uint64 toNonce;
        uint64 untilTimestamp;
    }

    /**
     * Response body for PMWFeeProof attestation type
     * @param actualFee Actual fee paid for the payments in the specified nonce range.
     * @param estimatedFee Estimated fee for the payments in the specified nonce range,
     * calculated based on the maxFee values from pay and reissue events.
     */
    struct ResponseBody {
        uint256 actualFee;
        uint256 estimatedFee;
    }
}
