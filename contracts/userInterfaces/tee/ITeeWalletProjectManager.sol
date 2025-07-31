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
        bytes32 opType,
        address submitAddress
    );

    event BackupManagerSet(
        bytes32 indexed projectId,
        address indexed backupManager
    );

    event DefaultWalletSet(
        bytes32 indexed projectId,
        bytes32 indexed walletId
    );

    event NewOwnerProposed(
        bytes32 indexed projectId,
        address indexed newOwner
    );

    event OwnershipConfirmed(
        bytes32 indexed projectId,
        address indexed newOwner
    );

    /**
     * Creates the project that can be used for wallet creation on specified extension.
     * Emits ProjectCreated event.
     * @param _extensionId The id of the extension.
     * @param _opType The project/wallet operation type.
     * @param _submitAddress The project/wallet submit address.
     * @return _projectId The project id.
     * Can only be called by an allowlisted wallet project owner.
     */
    function createProject(
        uint256 _extensionId,
        bytes32 _opType,
        address _submitAddress
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
    function setBackupManager(bytes32 _projectId, address _backupManager) external;

    /**
     * Sets the default wallet for the project.
     * Emits DefaultWalletSet event.
     * @param _projectId The project id.
     * @param _walletId The wallet id.
     * Can only be called by the project owner.
     */
    function setDefaultWallet(bytes32 _projectId, bytes32 _walletId) external;

    /**
     * Proposes a new owner for the project - has to be on the allowlist.
     * It is a two-step process, the new owner has to confirm the ownership.
     * Emits a NewOwnerProposed event.
     * @param _projectId The project id.
     * @param _newOwner The new owner.
     * Can only be called by the current project owner.
     */
    function proposeNewOwner(bytes32 _projectId, address _newOwner) external;

    /**
     * Confirms the ownership of the project.
     * Emits OwnershipConfirmed event.
     * @param _projectId The project id.
     * Can only be called by the proposed new owner.
     */
    function confirmOwnership(bytes32 _projectId) external;

    /**
     * Returns the project owner.
     * @param _projectId The project id.
     * @return _owner The owner.
     */
    function getOwner(bytes32 _projectId) external view returns (address _owner);

    /**
     * Returns the project extension id.
     * @param _projectId The project id.
     * @return _extensionId The extension id.
     */
    function getExtensionId(bytes32 _projectId) external view returns (uint256 _extensionId);

    /**
     * Returns the project operation type.
     * @param _projectId The project id.
     * @return _opType The operation type.
     */
    function getOpType(bytes32 _projectId) external view returns (bytes32 _opType);

    /**
     * Returns the project submit address.
     * @param _projectId The project id.
     * @return _submitAddress The submit address.
     */
    function getSubmitAddress(bytes32 _projectId) external view returns (address _submitAddress);

    /**
     * Returns the project backup manager.
     * @param _projectId The project id.
     * @return _backupManager The backup manager address.
     */
    function getBackupManager(bytes32 _projectId) external view returns (address _backupManager);

    /**
     * Returns the default wallet info.
     * @param _projectId The project id.
     * @return _walletId The wallet id.
     * @return _opType The operation type.
     * @return _submitAddress The submit address.
     */
    function getDefaultWalletInfo(bytes32 _projectId)
        external view
        returns (bytes32 _walletId, bytes32 _opType, address _submitAddress);

    /**
     * Returns the required operation type constants.
     * @param _projectId The project id.
     * @return The ABI encoded operation type constants.
     * NOTE: Should revert if the required operation type constants are not set.
     */
    function getOpTypeConstants(bytes32 _projectId) external view returns(bytes memory);
}