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
        address owner;
        string url;
    }

    struct TeeMachineWithAttestationData {
        address teeId;
        address owner;
        string url;
        bytes32 codeHash;
        bytes32 platform;
    }

    struct PauseForUpgrade {
        address teeId;
    }

    struct ReplicateTeeMachine {
        TeeMachineWithAttestationData oldTeeMachine;
        TeeMachineWithAttestationData newTeeMachine;
    }

    /**
     * Get the status of a TEE machine, if replication is in progress it will return the status of the new TEE machine.
     * @param _teeId The TEE machine address.
     * @return The status of the TEE machine.
     */
    function getTeeMachineStatus(address _teeId)
        external view
        returns (TeeStatus);

    /**
     * Get TEE machine basic data, if replication is in progress it will return the data of the new TEE machine.
     * @param _teeId The TEE machine address.
     * @return The TEE machine data.
     */
    function getTeeMachine(address _teeId)
        external view
        returns (TeeMachine memory);

    /**
     * Get TEE machine attestation data, if replication is in progress it will return the data of the new TEE machine.
     * @param _teeId The TEE machine address.
     * @return The TEE machine data.
     */
    function getTeeMachineWithAttestationData(address _teeId)
        external view
        returns (TeeMachineWithAttestationData memory);

    /**
     * Returns random active TEE machine ids.
     * @param _count The number of TEE machine ids to return.
     * @return The list of TEE machine ids.
     */
    function getRandomTeeIds(uint256 _count)
        external view
        returns(address[] memory);

    /**
     * Checks if the TEE machine platforms are compatible.
     * @param _teeId The TEE machine id.
     * @param _backupTeeIds The backup TEE machine ids.
     * @return True if the platforms are compatible.
     */
    function arePlatformsCompatible(address _teeId, address[] calldata _backupTeeIds)
        external view
        returns(bool);

    /**
     * Checks if operation type is supported on the TEE machine.
     * @param _teeId The TEE machine id.
     * @param _opType The operation type.
     * @return True if the operation type is supported.
     */
    function isOpTypeSupported(address _teeId, bytes32 _opType)
        external view
        returns (bool);
}
