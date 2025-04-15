// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../IPublicKey.sol";

/**
 * TeeWalletManager interface.
 */
interface ITeeWalletManager {

    enum WalletStatus {
        CREATED,
        INITIALIZED,
        PRODUCTION,
        PAUSED
    }

    event WalletCreated(
        bytes32 indexed projectId,
        bytes32 indexed walletId
    );

    event WalletAdminsSet(
        bytes32 indexed walletId,
        PublicKey[] adminsPublicKeys,
        uint64 adminsThreshold
    );

    event WalletAdminConfirmed(
        bytes32 indexed walletId,
        address indexed admin
    );

    event WalletCosignersSet(
        bytes32 indexed walletId,
        address[] cosigners,
        uint64 cosignersThreshold
    );

    event WalletCosignerConfirmed(
        bytes32 indexed walletId,
        address indexed cosigner
    );

    event WalletInitialized(
        bytes32 indexed walletId
    );

    event WalletEnabled(
        bytes32 indexed walletId
    );

    event WalletPaused(
        bytes32 indexed walletId
    );

    /**
     * Creates the wallet for the project.
     * @param _projectId The project id.
     * @return _walletId The wallet id.
     */
    function createWallet(
        bytes32 _projectId    )
        external
        returns (bytes32 _walletId);

    /**
     * Sets the wallet admins.
     * @param _walletId The wallet id.
     * @param _adminsPublicKeys The wallet admins public keys.
     * @param _adminsThreshold The wallet admins threshold.
     */
    function setAdmins(
        bytes32 _walletId,
        PublicKey[] calldata _adminsPublicKeys,
        uint64 _adminsThreshold
    )
        external;

    /**
     * Confirms the admin.
     * @param _walletId The wallet id.
     */
    function confirmAdmin(bytes32 _walletId)
        external;

    /**
     * Sets the wallet cosigners.
     * @param _walletId The wallet id.
     * @param _cosigners The wallet cosigners.
     * @param _cosignersThreshold The wallet cosigners threshold.
     */
    function setCosigners(
        bytes32 _walletId,
        address[] calldata _cosigners,
        uint64 _cosignersThreshold
    )
        external;

    /**
     * Confirms the cosigner.
     * @param _walletId The wallet id.
     */
    function confirmCosigner(bytes32 _walletId)
        external;

    /**
     * Closes the wallet initialization and enables adding keys.
     * All admins and cosigners need to be set and confirmed.
     * They cannot be changed after this call.
     * @param _walletId The wallet id.
     */
    function closeWalletInitialization(
        bytes32 _walletId
    )
        external;

    /**
     * Enables the wallet.
     * @param _walletId The wallet id.
     */
    function enableWallet(bytes32 _walletId) external;

    /**
     * Pauses the wallet.
     * @param _walletId The wallet id.
     */
    function pauseWallet(bytes32 _walletId) external;


    /**
     * Returns the list of wallet ids for the project.
     * @param _projectId The project id.
     * @return _walletIds The list of wallet ids.
     */
    function getProjectWalletIds(bytes32 _projectId)
        external view
        returns (bytes32[] memory _walletIds);

    /**
     * Returns wallet project id.
     * @param _walletId The wallet id.
     * @return _projectId The project id.
     */
    function getWalletProjectId(bytes32 _walletId) external view returns (bytes32 _projectId);

    /**
     * Returns wallet's admins and threshold.
     * @param _walletId The wallet id.
     * @return _adminsPublicKeys The wallet admins public keys.
     * @return _adminsThreshold The wallet admins threshold.
     */
    function getWalletAdminsAndThreshold(bytes32 _walletId)
        external view
        returns (PublicKey[] memory _adminsPublicKeys, uint256 _adminsThreshold);

    /**
     * Returns wallet's cosigners and threshold.
     * @param _walletId The wallet id.
     * @return _cosigners The wallet cosigners.
     * @return _cosignersThreshold The wallet cosigners threshold.
     */
    function getWalletCosignersAndThreshold(bytes32 _walletId)
        external view
        returns (address[] memory _cosigners, uint256 _cosignersThreshold);

    /**
     * Returns wallet's status.
     * @param _walletId The wallet id.
     * @param _status The status.
     */
    function getWalletStatus(bytes32 _walletId) external view returns (WalletStatus _status);

    /**
     * Returns supported operation types.
     * @return _supportedOpTypes The supported operation types.
     */
    function getSupportedOpTypes() external view returns (bytes32[] memory _supportedOpTypes);

    /**
     * Checks if operation type is supported on TEE wallet manager.
     * @param _opType The operation type.
     * @return True if the operation type is supported.
     */
    function isOpTypeSupported(bytes32 _opType)
        external view
        returns (bool);
}