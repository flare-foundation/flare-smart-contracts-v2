// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../ftdc/IFtdcHub.sol";
import "../ftdc/IFtdcVerification.sol";

bytes32 constant TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE = bytes32("TeeAvailabilityCheck");

interface ITeeAvailabilityCheck {

    enum AvailabilityCheckStatus { OK, OBSOLETE, DOWN }

    /**
     * Proof for TeeAvailabilityCheck attestation type
     */
    struct Proof {
        IFtdcVerification.FtdcSignatures signatures;
        IFtdcHub.FtdcResponseHeader header;
        RequestBody requestBody;
        ResponseBody responseBody;
        bytes state; // ABI encoded state
    }

    /**
     * @notice Request body for TeeAvailabilityCheck attestation type
     * @param teeId Id of the TEE machine, copied from the old TEE machine in case of replication.
     * @param url URL of the TEE.
     * @param challenge Challenge used for TEE attestation request.
     */
    struct RequestBody {
        address teeId;
        string url;
        uint256 challenge;
    }

    /**
     * @notice Response body for TeeAvailabilityCheck attestation type
     * @param status Status of the availability check.
     * @param teeTimestamp Timestamp of the TEE machine.
     * @param codeHash Code hash of the TEE.
     * @param platform Platform of the TEE.
     * @param initialSigningPolicyId Id of the initial signing policy set on the TEE machine, it never changes.
     * @param lastSigningPolicyId Id of the last signing policy relayed to the TEE machine.
     * @param stateHash Hash of the TEE machine state.
     */
    struct ResponseBody {
        AvailabilityCheckStatus status;
        uint64 teeTimestamp;
        bytes32 codeHash;
        bytes32 platform;
        uint24 initialSigningPolicyId;
        uint24 lastSigningPolicyId;
        bytes32 stateHash;
    }
}
