// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeAvailabilityCheck.sol";

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

    event AvailabilityCheckValidityExtended(address indexed teeId, uint256 endTs);

    /**
     * Register a new TEE machine. It also triggers availability check.
     * @param _teeId The TEE machine id.
     * @param _url The TEE machine URL.
     * @param _codeHash The TEE machine code hash.
     * @param _platform The TEE machine platform.
     */
    function register(
        address _teeId,
        string calldata _url,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external payable;

    /**
     * Trigger availability check for a TEE machine.
     * @param _teeId The TEE machine id.
     * @param _testOnTeeId The TEE machine id to test on.
     */
    function triggerAvailabilityCheck(
        address _teeId,
        address _testOnTeeId
    )
        external payable;

    /**
     * Put a TEE machine into production.
     * @param _proof The availability check proof.
     */
    function toProduction(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external;

    /**
     * Extend the availability check validity.
     * @param _proof The availability check proof.
     */
    function confirmAvailability(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external;

    /**
     * Pause a TEE machine. Can be called by the TEE machine owner or by anyone in case version is obsolete.
     * @param _teeId The TEE machine id.
     */
    function pause(address _teeId)
        external;

    /**
     * Pause a TEE machine with proof. Can be called by anyone in case TEE machine is obsolete, down, ...
     * @param _proof The availability check proof.
     */
    function pauseWithProof(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external;

    /**
     * Pause a TEE machine for upgrade. It has to be paused for long enough time first.
     * Can only be called by the TEE machine owner.
     * @param _teeId The TEE machine id.
     */
    function toPauseForUpgrade(address _teeId)
        external payable;

    /**
     * Replicate a TEE machine. Can only be called by the TEE machine owner.
     * @param _oldTeeId The old TEE machine id.
     * @param _proof The availability check proof for the new TEE machine.
     */
    function replicateFrom(
        address _oldTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external payable;

    /**
     * Confirm the replication of a TEE machine. Can only be called by the TEE machine owner.
     * @param _newTeeId The new TEE machine id.
     * @param _proof The availability check proof for the new TEE machine with the old TEE id.
     */
    function confirmReplicate(
        address _newTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external;

    /**
     * Propose a new owner for a TEE machine. Can only be called by the TEE machine owner.
     * It is a two-step process, the new owner has to confirm the ownership.
     * @param _teeId The TEE machine id.
     * @param _newOwner The new owner address.
     */
    function proposeNewOwner(address _teeId, address _newOwner)
        external;

    /**
     * Confirm the ownership of a TEE machine. Can only be called by the proposed new owner.
     * @param _teeId The TEE machine id.
     */
    function confirmOwnership(address _teeId)
        external;

    /**
     * Get the status of a TEE machine, if replication is in progress it will return the status of the new TEE machine.
     * @param _teeId The TEE machine id.
     * @return The status of the TEE machine.
     */
    function getTeeMachineStatus(address _teeId)
        external view
        returns (TeeStatus);

    /**
     * Get TEE machine basic data, if replication is in progress it will return the data of the new TEE machine.
     * @param _teeId The TEE machine id.
     * @return The TEE machine data.
     */
    function getTeeMachine(address _teeId)
        external view
        returns (TeeMachine memory);

    /**
     * Get TEE machine attestation data, if replication is in progress it will return the data of the new TEE machine.
     * @param _teeId The TEE machine id.
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
     * Get the TEE machine version.
     * @param _teeId The TEE machine id.
     * @return The TEE machine version.
     */
    function getTeeMachineVersion(address _teeId)
        external view
        returns(uint256);

    /**
     * Get active TEE machine ids.
     * @return The list of active TEE machine ids.
     */
    function getActiveTeeIds()
        external view
        returns(address[] memory);

    /**
     * Get the version info.
     * @param _version The version.
     * @return _codeHash The code hash.
     * @return _platforms The supported platforms.
     * @return _opTypes The supported operation types.
     */
    function getVersionInfo(uint256 _version)
        external view
        returns(bytes32 _codeHash, bytes32[] memory _platforms, bytes32[] memory _opTypes);

    /**
     * Get the version of the code hash.
     * @param _codeHash The code hash.
     * @return The version.
     */
    function getCodeHashVersion(bytes32 _codeHash)
        external view
        returns(uint256);

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
