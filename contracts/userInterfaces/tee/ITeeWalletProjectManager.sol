// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TeeWalletProjectManager interface.
 */
interface ITeeWalletProjectManager {

    event ProjectCreated(
        bytes32 indexed projectId,
        address indexed owner,
        uint256 extensionId,
        bytes32 keyType,
        bytes32 signingAlgo
    );

    event BackupManagerSet(
        bytes32 indexed projectId,
        address indexed backupManager
    );

    event NewOwnerProposed(
        bytes32 indexed projectId,
        address indexed newOwner
    );

    event OwnershipConfirmed(
        bytes32 indexed projectId,
        address indexed newOwner
    );

    error OwnerNotAllowed();
    error KeyTypeNotSupported();
    error SigningAlgoNotSupported();
    error WalletNotPartOfProject();
    error WalletNotProductionReady();
    error OnlyProposedOwner();
    error OnlyOwner();

    /**
     * Creates the project that can be used for wallet creation on specified extension.
     * Emits ProjectCreated event.
     * @param _extensionId The id of the extension.
     * @param _keyType The key type (e.g. EVM, XRP).
     * @param _signingAlgo The signing algorithm (e.g. keccak256-secp256k1-ecdsa, sha512half-secp256k1-ecdsa).
     * @return _projectId The project id.
     * Can only be called by an allowlisted wallet project owner.
     */
    function createProject(
        uint256 _extensionId,
        bytes32 _keyType,
        bytes32 _signingAlgo
    )
        external
        returns (bytes32 _projectId);

    /**
     * Sets the project backup manager.
     * Emits BackupManagerSet event.
     * @param _projectId The project id.
     * @param _backupManager The backup manager address (can be address(0)).
     * Can only be called by the project owner.
     */
    function setBackupManager(
        bytes32 _projectId,
        address _backupManager
    )
        external;

    /**
     * Proposes a new owner for the project - has to be on the allowlist.
     * It is a two-step process, the new owner has to confirm the ownership.
     * Emits NewOwnerProposed event.
     * @param _projectId The project id.
     * @param _newOwner The new owner.
     * Can only be called by the current project owner.
     */
    function proposeNewOwner(
        bytes32 _projectId,
        address _newOwner
    )
        external;

    /**
     * Confirms the ownership of the project.
     * Emits OwnershipConfirmed event.
     * @param _projectId The project id.
     * Can only be called by the proposed new owner.
     */
    function confirmOwnership(
        bytes32 _projectId
    )
        external;

    /**
     * Returns the project owner.
     * @param _projectId The project id.
     * @return _owner The owner.
     */
    function getOwner(
        bytes32 _projectId
    )
        external view
        returns (address _owner);

    /**
     * Returns the project extension id.
     * @param _projectId The project id.
     * @return _extensionId The extension id.
     */
    function getExtensionId(
        bytes32 _projectId
    )
        external view
        returns (uint256 _extensionId);

    /**
     * Returns the project key type.
     * @param _projectId The project id.
     * @return _keyType The key type.
     */
    function getKeyType(
        bytes32 _projectId
    )
        external view
        returns (bytes32 _keyType);

    /**
     * Returns the project signing algorithm.
     * @param _projectId The project id.
     * @return _signingAlgo The signing algorithm.
     */
    function getSigningAlgo(
        bytes32 _projectId
    )
        external view
        returns (bytes32 _signingAlgo);

    /**
     * Returns the project backup manager.
     * @param _projectId The project id.
     * @return _backupManager The backup manager address.
     */
    function getBackupManager(
        bytes32 _projectId
    )
        external view
        returns (address _backupManager);
}