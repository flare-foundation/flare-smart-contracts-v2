// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { PublicKey } from "../IPublicKey.sol";
import { Signature } from "../ISignature.sol";
import { ITeeAvailabilityCheck } from "../fdc2/ITeeAvailabilityCheck.sol";
import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";

bytes32 constant REG_OP_TYPE = bytes32("F_REG");

/**
 * @title ITeeMachineRegistryFacet
 * @notice Public interface for the TeeMachineRegistryFacet.
 */
interface ITeeMachineRegistryFacet is ITeeCommonErrors {

    enum TeeStatus { INITIALIZED, PRODUCTION, SUSPENDED, PAUSED, PAUSED_FOR_UPGRADE, REPLICATING, BANNED }

    struct TeeMachineData {
        uint256 extensionId;
        address initialOwner;
        bytes32 codeHash;
        bytes32 platform;
        PublicKey publicKey;
    }

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

    event TeeMachineStatusChanged(
        address indexed teeId,
        TeeStatus indexed newStatus
    );

    event TeeMachineSettingsUpdated(
        address indexed teeId,
        address indexed teeProxyId,
        string url
    );

    error OnlyTeeReplicationContract();
    error InvalidTeePublicKey();
    error InvalidTeeProxyId();
    error InvalidTeePublicKeyOrSignature();
    error InvalidUrl();
    error AlreadyRegistered();
    error InvalidTeeStatus();
    error InvalidResponseDataOrAvailabilityCheckStatus();
    error OnlyOwnerOrExpiredAvailabilityCheckOrDisabledVersion();
    error OwnerMismatch();
    error TooMany();
    error TeeNotFound();
    error InvalidNewStatus();

    /**
     * Register a new TEE machine. It also triggers availability check.
     * Emits TeeMachineRegistered event.
     * @param _teeMachineData The TEE machine data.
     * @param _teeMachineDataSignature The TEE machine signature over the TEE machine data.
     * @param _teeProxyId The TEE proxy id.
     * @param _url The TEE machine URL (proxy URL).
     * @param _claimBackAddress An address that can claim back the fee if the instructions
     *        are not executed (optional).
     * Can only be called by an allowlisted TEE machine owner.
     */
    function register(
        TeeMachineData calldata _teeMachineData,
        Signature calldata _teeMachineDataSignature,
        address _teeProxyId,
        string calldata _url,
        address _claimBackAddress
    )
        external payable;

    /**
     * Put a TEE machine into production.
     * Emits TeeMachineStatusChanged event.
     * @param _proof The availability check proof.
     */
    function toProduction(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external;

    /**
     * Pause a TEE machine.
     * Emits TeeMachineStatusChanged event.
     * @param _teeId The TEE machine id.
     */
    function pause(
        address _teeId
    )
        external;

    /**
     * Pause a TEE machine with proof.
     * Emits TeeMachineStatusChanged event.
     * @param _proof The availability check proof.
     */
    function pauseWithProof(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external;

    /**
     * Ban a TEE machine - puts it into BANNED status.
     * Emits TeeMachineStatusChanged event.
     * @param _teeId The TEE machine id.
     * Can only be called by the extension owner.
     */
    function ban(
        address _teeId
    )
        external;

    /**
     * Unban a TEE machine - puts it into PAUSED status.
     * Emits TeeMachineStatusChanged event.
     * @param _teeId The TEE machine id.
     * Can only be called by the extension owner.
     */
    function unban(
        address _teeId
    )
        external;

    /**
     * Propose a new owner for a TEE machine.
     * Emits NewOwnerProposed event.
     * @param _teeId The TEE machine id.
     * @param _newOwner The new owner address.
     * Can only be called by the current TEE machine owner.
     */
    function proposeNewOwner(
        address _teeId,
        address _newOwner
    )
        external;

    /**
     * Confirm the ownership of a TEE machine.
     * Emits NewOwnerConfirmed event.
     * @param _teeId The TEE machine id.
     * Can only be called by the proposed new owner.
     */
    function confirmOwnership(
        address _teeId
    )
        external;

    /**
     * Update TEE machine settings.
     * Emits TeeMachineSettingsUpdated event.
     * @param _teeId The TEE machine id.
     * @param _teeProxyId The TEE proxy id.
     * @param _url The TEE machine URL.
     * Can only be called by the TEE machine owner.
     */
    function updateTeeMachineSettings(
        address _teeId,
        address _teeProxyId,
        string calldata _url
    )
        external;

    /**
     * Get the status of a TEE machine.
     * @param _teeId The TEE machine id.
     * @return The status of the TEE machine.
     */
    function getTeeMachineStatus(
        address _teeId
    )
        external view
        returns (TeeStatus);

    /**
     * Get the owner of a TEE machine.
     * @param _teeId The TEE machine id.
     * @return The owner address.
     */
    function getTeeMachineOwner(
        address _teeId
    )
        external view
        returns (address);

    /**
     * Get initial signing policy id of a TEE machine.
     * @param _teeId The TEE machine id.
     * @return The initial signing policy id.
     */
    function getInitialSigningPolicyId(
        address _teeId
    )
        external view
        returns (uint32);

    /**
     * Get TEE machine basic data.
     * @param _teeId The TEE machine id.
     * @return The TEE machine data.
     */
    function getTeeMachine(
        address _teeId
    )
        external view
        returns (TeeMachine memory);

    /**
     * Get TEE machine attestation data.
     * @param _teeId The TEE machine id.
     * @return The TEE machine data.
     */
    function getTeeMachineWithAttestationData(
        address _teeId
    )
        external view
        returns (TeeMachineWithAttestationData memory);

    /**
     * Returns random active TEE machine ids.
     * @param _extensionId The id of the extension.
     * @param _count The number of TEE machine ids to return.
     * @return The list of TEE machine ids.
     */
    function getRandomTeeIds(
        uint256 _extensionId,
        uint256 _count
    )
        external view
        returns (address[] memory);

    /**
     * Get all active TEE machines.
     * @param _start The start index (inclusive) for pagination.
     * @param _end The end index (exclusive) for pagination.
     * @return _teeIds The list of TEE machine ids.
     * @return _urls The list of TEE machine URLs.
     * @return _totalLength The total number of active TEE machines.
     */
    function getAllActiveTeeMachines(
        uint256 _start,
        uint256 _end
    )
        external view
        returns (
            address[] memory _teeIds,
            string[] memory _urls,
            uint256 _totalLength
        );

    /**
     * Get active TEE machines.
     * @param _extensionId The id of the extension.
     * @return _teeIds The list of TEE machine ids.
     * @return _urls The list of TEE machine URLs.
     */
    function getActiveTeeMachines(
        uint256 _extensionId
    )
        external view
        returns (
            address[] memory _teeIds,
            string[] memory _urls
        );

    /**
     * Get the extension id for a TEE machine.
     * @param _teeId The TEE machine id.
     * @return The extension id.
     */
    function getExtensionId(
        address _teeId
    )
        external view
        returns (uint256);

    /**
     * Get the public key for a TEE machine.
     * @param _teeId The TEE machine id.
     * @return The public key.
     */
    function getPublicKey(
        address _teeId
    )
        external view
        returns (PublicKey memory);

    /**
     * Get the last status change timestamp for a TEE machine.
     * @param _teeId The TEE machine id.
     * @return The last status change timestamp.
     */
    function getLastStatusChangeTs(
        address _teeId
    )
        external view
        returns (uint256);
}
