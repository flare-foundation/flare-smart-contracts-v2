// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IFdc2Hub } from "../fdc2/IFdc2Hub.sol";
import { IFdc2Verification } from "../fdc2/IFdc2Verification.sol";

bytes32 constant TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE = bytes32("TeeAvailabilityCheck");

interface ITeeAvailabilityCheck {

    enum AvailabilityCheckStatus { OK, OBSOLETE, DOWN }

    /**
     * State of the TEE machine
     */
    struct TeeState {
        bytes systemState;
        bytes32 systemStateVersion;
        bytes state;
        bytes32 stateVersion;
    }

    /**
     * Proof for TeeAvailabilityCheck attestation type
     */
    struct Proof {
        IFdc2Verification.Fdc2Signatures signatures;
        IFdc2Hub.Fdc2ResponseHeader header;
        RequestBody requestBody;
        ResponseBody responseBody;
    }

    /**
     * @notice Request body for TeeAvailabilityCheck attestation type
     * @param teeId Id of the TEE machine.
     * @param teeProxyId The TEE proxy id.
     * @param url URL of the TEE.
     * @param challenge Challenge used for TEE attestation request.
     * @param instructionId Instruction ID used for the availability check (challenge must match).
     */
    struct RequestBody {
        address teeId;
        address teeProxyId;
        string url;
        bytes32 challenge;
        bytes32 instructionId;
    }

    /**
     * @notice Response body for TeeAvailabilityCheck attestation type
     * @param status Status of the availability check.
     * @param teeTimestamp Timestamp of the TEE machine.
     * @param codeHash Code hash of the TEE.
     * @param platform Platform of the TEE.
     * @param initialSigningPolicyId Id of the initial signing policy set on the TEE machine, it never changes.
     * @param lastSigningPolicyId Id of the last signing policy relayed to the TEE machine.
     * @param state TEE machine state.
     */
    struct ResponseBody {
        AvailabilityCheckStatus status;
        uint64 teeTimestamp;
        bytes32 codeHash;
        bytes32 platform;
        uint32 initialSigningPolicyId;
        uint32 lastSigningPolicyId;
        TeeState state;
    }
}
