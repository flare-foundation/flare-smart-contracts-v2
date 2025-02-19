// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TeeRegistry interface.
 */
interface ITeeRegistry {

    enum TeeStatus {INITIALIZED, PRODUCTION, PAUSED, PAUSED_FOR_UPGRADE, REPLICATING}

    enum AvailabilityStatus {OK, OBSOLETE, DATA_MISMATCH, DOWN}

    struct TeeMachine {
        address teeId;
        string url;
    }

    struct TeeMachineWithAttestationData {
        address teeId;
        string url;
        bytes32 codeHash;
        bytes32 platform;
    }

    struct AvailabilityCheckRequest {
        address teeId;
        string url;
        bytes32 codeHash;
        bytes32 platform;
        uint256 timestamp;
    }

    struct AvailabilityCheckResponse {
        address teeId;
        string url;
        bytes32 codeHash;
        bytes32 platform;
        uint256 timestamp;
        AvailabilityStatus status;
    }

    struct ReplicateTeeMachine {
        TeeMachineWithAttestationData oldTeeMachine;
        TeeMachineWithAttestationData newTeeMachine;
    }

    function getTeeMachineStatus(address _teeId)
        external view
        returns (TeeStatus);

    function getTeeMachine(address _teeId)
        external view
        returns (TeeMachine memory);

    function getTeeMachineWithAttestationData(address _teeId)
        external view
        returns (TeeMachineWithAttestationData memory);

    function isOpTypeSupported(address _teeId, bytes32 _opType)
        external view
        returns (bool);
}