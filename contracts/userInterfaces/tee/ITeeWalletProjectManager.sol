// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TeeWalletProjectManager interface.
 */
interface ITeeWalletProjectManager {

    event ProjectCreated(
        bytes32 indexed projectId,
        address indexed owner,
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
     * Creates the project that can be used for wallet creation.
     * @param _opType The project/wallet operation type.
     * @param _submitAddress The project/wallet submit address.
     * @return _projectId The project id.
     */
    function createProject(
        bytes32 _opType,
        address _submitAddress
    )
        external
        returns (bytes32 _projectId);

    /**
     * Sets the project backup manager.
     * @param _projectId The project id.
     * @param _backupManager The backup manager address (can be address(0)).
     */
    function setBackupManager(bytes32 _projectId, address _backupManager) external;

    /**
     * Sets the default wallet for the project.
     * @param _projectId The project id.
     * @param _walletId The wallet id.
     */
    function setDefaultWallet(bytes32 _projectId, bytes32 _walletId) external;

    /**
     * Proposes a new owner for the project. The new owner needs to confirm the ownership.
     * @param _projectId The project id.
     * @param _newOwner The new owner.
     */
    function proposeNewOwner(bytes32 _projectId, address _newOwner) external;

    /**
     * Confirms the ownership of the project after the old owner has proposed a new owner.
     * @param _projectId The project id.
     */
    function confirmOwnership(bytes32 _projectId) external;

    /**
     * Returns the project owner.
     * @param _projectId The project id.
     * @return _owner The owner.
     */
    function getOwner(bytes32 _projectId) external view returns (address _owner);

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
}