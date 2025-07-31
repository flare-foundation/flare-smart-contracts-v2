// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../ftdc/ITeeAvailabilityCheck.sol";

/**
 * TeeMachineRegistry interface.
 */
interface ITeeMachineRegistry {

    enum TeeStatus { INITIALIZED, PRODUCTION, PAUSED_WITH_PROOF, PAUSED, PAUSED_FOR_UPGRADE, REPLICATING }

    struct TeeMachine {
        address teeId;
        address teeProxyId;
        string url;
    }

    struct TeeMachineWithAttestationData {
        address teeId;
        address initialTeeId;
        string url;
        bytes32 codeHash;
        bytes32 platform;
    }

    event NewOwnerProposed(
        address indexed teeId,
        address indexed oldOwner,
        address indexed newOwner
    );

    event NewOwnerConfirmed(
        address indexed teeId,
        address indexed newOwner
    );

    event TeeMachineRegistered(
        address indexed teeId,
        address indexed teeProxyId,
        address indexed owner,
        uint256 extensionId,
        string url,
        bytes32 codeHash,
        bytes32 platform
    );

    event TeeMachinePutIntoProduction(
        address indexed teeId
    );

    event TeeMachinePaused(
        address indexed teeId,
        bool withProof
    );

    event TeeProxyIdSet(
        address indexed teeId,
        address indexed teeProxyId
    );

    /**
     * Register a new TEE machine. It also triggers availability check.
     * Emits TeeMachineRegistered event.
     * @param _extensionId The id of the extension.
     * @param _teeId The TEE machine id.
     * @param _teeProxyId The TEE proxy id.
     * @param _url The TEE machine URL.
     * @param _codeHash The TEE machine code hash.
     * @param _platform The TEE machine platform.
     * Can only be called by an allowlisted TEE machine owner.
     */
    function register(
        uint256 _extensionId,
        address _teeId,
        address _teeProxyId,
        string calldata _url,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external payable;

    /**
     * Put a TEE machine into production.
     * Emits a TeeMachinePutIntoProduction event.
     * @param _proof The availability check proof.
     * Can only be called by the TEE machine owner or by anyone in case TEE machine was paused with proof.
     */
    function toProduction(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external;

    /**
     * Pause a TEE machine.
     * Emits a TeeMachinePaused event.
     * @param _teeId The TEE machine id.
     * Can be called by the TEE machine owner or by anyone in case version is obsolete.
     */
    function pause(address _teeId)
        external;

    /**
     * Pause a TEE machine with proof.
     * Emits a TeeMachinePaused event.
     * @param _proof The availability check proof.
     * Can be called by anyone in case TEE machine is obsolete, down, ...
     */
    function pauseWithProof(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external;

    /**
     * Propose a new owner for a TEE machine - has to be on the allowlist.
     * It is a two-step process, the new owner has to confirm the ownership.
     * Emits a NewOwnerProposed event.
     * @param _teeId The TEE machine id.
     * @param _newOwner The new owner address.
     * Can only be called by the current TEE machine owner.
     */
    function proposeNewOwner(address _teeId, address _newOwner)
        external;

    /**
     * Confirm the ownership of a TEE machine.
     * Emits a NewOwnerConfirmed event.
     * @param _teeId The TEE machine id.
     * Can only be called by the proposed new owner.
     */
    function confirmOwnership(address _teeId)
        external;

    /**
     * Set TEE proxy id.
     * Emits TeeProxyIdSet event.
     * @param _teeId The TEE machine id.
     * @param _teeProxyId The TEE proxy id.
     * Can only be called by the TEE machine owner.
     */
    function setTeeProxyId(address _teeId, address _teeProxyId)
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
     * Get the owner of a TEE machine.
     * @param _teeId The TEE machine id.
     * @return The owner address.
     */
    function getTeeMachineOwner(address _teeId)
        external view
        returns (address);

    /**
     * Get initial signing policy id of a TEE machine.
     * @param _teeId The TEE machine id.
     * @return The initial signing policy id.
     */
    function getInitialSigningPolicyId(address _teeId)
        external view
        returns (uint32);

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
     * @param _extensionId The id of the extension.
     * @param _count The number of TEE machine ids to return.
     * @return The list of TEE machine ids.
     */
    function getRandomTeeIds(uint256 _extensionId, uint256 _count)
        external view
        returns(address[] memory);

    /**
     * Get all active TEE machines.
     * @return _teeIds The list of TEE machine ids.
     * @return _urls The list of TEE machine URLs.
     */
    function getAllActiveTeeMachines()
        external view
        returns(address[] memory _teeIds, string[] memory _urls);

    /**
     * Get active TEE machines.
     * @param _extensionId The id of the extension.
     * @return _teeIds The list of TEE machine ids.
     * @return _urls The list of TEE machine URLs.
     */
    function getActiveTeeMachines(uint256 _extensionId)
        external view
        returns(address[] memory _teeIds, string[] memory _urls);

    /**
     * Get the extension id for a TEE machine.
     * @param _teeId The TEE machine id.
     * @return The extension id.
     */
    function getExtensionId(address _teeId)
        external view
        returns (uint256);

    /**
     * Get the last status change timestamp for a TEE machine.
     * @param _teeId The TEE machine id.
     * @return The last status change timestamp.
     */
    function getLastStatusChangeTs(address _teeId)
        external view
        returns (uint256);
}
