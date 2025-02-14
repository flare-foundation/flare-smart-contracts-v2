// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TeeRegistry interface.
 */
interface ITeeRegistry {

    enum TeeStatus {INITIALIZED, PRODUCTION, PAUSED, PAUSED_FOR_UPGRADE}

    struct TeeMachine {
        address teeId;
        string url;
    }

    struct TeeMachineWithAttestationData {
        address teeId;
        string url;
        bytes32 platform;
        bytes32 codeHash;
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