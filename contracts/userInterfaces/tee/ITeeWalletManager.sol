// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../IPublicKey.sol";
import "./ITeeIdKeyIdPair.sol";

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
    struct SetPausingAddresses {
        bytes32 walletId;
        uint256 nonce;
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        address[] pausingAddresses;
    }

    struct ResumeKeyData {
        uint64 keyId;
        address teeId;
        uint256 nonce;
    }

    struct Resume {
        bytes32 walletId;
        ResumeKeyData[] keysData;
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

    error OnlyOwner();
    error NotEnoughAdmins();
    error InvalidAdminsThreshold();
    error DuplicatedPublicKey(PublicKey publicKey);
    error InvalidCosignersThreshold();
    error InvalidCosigner(address cosigner);
    error DuplicatedCosigner(address cosigner);
    error AdminsNotSet();
    error NotAllAdminsConfirmed(address admin);
    error NotAllCosignersConfirmed(address cosigner);
    error InvalidWalletStatus();
    error MultisigThresholdNotSet();
    error NotEnoughKeys();
    error OnlyProductionOrPausedStatus();
    error WrongKeyId();
    error TeeMachineNotAvailable();
    error InvalidPublicKey(PublicKey publicKey);
    error InvalidAdmin();

    /**
     * Creates the wallet for the project.
     * Emits WalletCreated event.
     * @param _projectId The project id.
     * @return _walletId The wallet id.
     * Can only be called by the project owner.
     */
    function createWallet(
        bytes32 _projectId    )
        external
        returns (bytes32 _walletId);

    /**
     * Sets the wallet admins.
     * Emits WalletAdminsSet event.
     * @param _walletId The wallet id.
     * @param _adminsPublicKeys The wallet admins public keys.
     * @param _adminsThreshold The wallet admins threshold.
     * Can only be called by the wallet owner.
     */
    function setAdmins(
        bytes32 _walletId,
        PublicKey[] calldata _adminsPublicKeys,
        uint64 _adminsThreshold
    )
        external;

    /**
     * Confirms the admin.
     * Emits WalletAdminConfirmed event.
     * @param _walletId The wallet id.
     */
    function confirmAdmin(bytes32 _walletId)
        external;

    /**
     * Sets the wallet cosigners.
     * Emits WalletCosignersSet event.
     * @param _walletId The wallet id.
     * @param _cosigners The wallet cosigners.
     * @param _cosignersThreshold The wallet cosigners threshold.
     * Can only be called by the wallet owner.
     */
    function setCosigners(
        bytes32 _walletId,
        address[] calldata _cosigners,
        uint64 _cosignersThreshold
    )
        external;

    /**
     * Confirms the cosigner.
     * Emits WalletCosignerConfirmed event.
     * @param _walletId The wallet id.
     */
    function confirmCosigner(bytes32 _walletId)
        external;

    /**
     * Closes the wallet initialization and enables adding keys.
     * All admins and cosigners need to be set and confirmed.
     * They cannot be changed after this call.
     * Emits WalletInitialized event.
     * @param _walletId The wallet id.
     * Can only be called by the wallet owner.
     */
    function closeWalletInitialization(
        bytes32 _walletId
    )
        external;

    /**
     * Enables the wallet.
     * Emits WalletEnabled event.
     * @param _walletId The wallet id.
     * Can only be called by the wallet owner.
     */
    function enableWallet(bytes32 _walletId) external;

    /**
     * Pauses the wallet.
     * Emits WalletPaused event.
     * @param _walletId The wallet id.
     * Can only be called by the wallet owner.
     */
    function pauseWallet(bytes32 _walletId) external;

    /**
     * Set pausing addresses (for pausing keys) instruction method.
     * @param _walletId The wallet id.
     * @param _pausingAddresses The list of pausing addresses, can be empty.
     * Can only be called by the wallet owner.
     */
    function setPausingAddresses(
        bytes32 _walletId,
        address[] calldata _pausingAddresses
    )
        external payable;

    /**
     * Resume paused keys instruction method.
     * @param _walletId The wallet id.
     * @param _keysData The list of keys's data.
     * Can only be called by the wallet owner.
     */
    function resume(
        bytes32 _walletId,
        ResumeKeyData[] calldata _keysData
    )
        external payable;

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
     * Returns wallet's admins public keys and threshold.
     * @param _walletId The wallet id.
     * @return _adminsPublicKeys The wallet admins public keys.
     * @return _adminsThreshold The wallet admins threshold.
     */
    function getWalletAdminsPublicKeysAndThreshold(bytes32 _walletId)
        external view
        returns (PublicKey[] memory _adminsPublicKeys, uint64 _adminsThreshold);

    /**
     * Returns wallet's admins and threshold.
     * @param _walletId The wallet id.
     * @return _admins The wallet admins.
     * @return _adminsThreshold The wallet admins threshold.
     */
    function getWalletAdminsAndThreshold(bytes32 _walletId)
        external view
        returns (address[] memory _admins, uint64 _adminsThreshold);

    /**
     * Returns wallet's cosigners and threshold.
     * @param _walletId The wallet id.
     * @return _cosigners The wallet cosigners.
     * @return _cosignersThreshold The wallet cosigners threshold.
     */
    function getWalletCosignersAndThreshold(bytes32 _walletId)
        external view
        returns (address[] memory _cosigners, uint64 _cosignersThreshold);

    /**
     * Returns wallet's status.
     * @param _walletId The wallet id.
     * @param _status The status.
     */
    function getWalletStatus(bytes32 _walletId) external view returns (WalletStatus _status);
}