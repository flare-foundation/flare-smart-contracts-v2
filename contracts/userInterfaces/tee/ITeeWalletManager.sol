// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";
import "./ITeeKeyExistence.sol";

/**
 * TeeWalletManager interface.
 */
interface ITeeWalletManager {

    enum WalletStatus {
        INITIALIZED,
        PRODUCTION,
        PAUSED
    }

    struct KeyGenerate {
        address teeId;
        bytes32 walletId;
        uint256 keyId;
        bytes32 opType;
    }

    struct KeyDelete {
        address teeId;
        bytes32 walletId;
        uint256 keyId;
    }

    event WalletCreated(
        bytes32 indexed walletId,
        address indexed owner,
        bytes32 opType
    );

    /**
     * Initializes the wallet.
     * @param _opType The wallet operation type.
     * @param _multisigThreshold The multisig threshold.
     * @return _walletId The wallet id.
     */
    function initializeWallet(bytes32 _opType, uint64 _multisigThreshold)
        external payable
        returns (bytes32 _walletId);

    /**
     * Adds a key to the wallet - triggers a key generation process.
     * @param _teeId The tee id.
     * @param _walletId The wallet id.
     * @return _keyId The key id.
     */
    function addKey(address _teeId, bytes32 _walletId) external payable returns (uint64 _keyId);

    /**
     * Confirms the key generation.
     * @param _proof The key existence proof.
     */
    function confirmKey(
        ITeeKeyExistence.Proof calldata _proof
    )
        external;

    /**
     * Deletes key from the tee machine - triggers a key deletion process.
     * @param _teeId The tee id.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     */
    function deleteKey(address _teeId, bytes32 _walletId, uint64 _keyId) external payable;

    /**
     * For given wallet id and key id cleans up all tee machines that are not in production status.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     */
    function cleanUpTeeIds(bytes32 _walletId, uint64 _keyId) external;

    /**
     * Sets the wallet's submit address (can only be set once).
     * @param _walletId The wallet id.
     * @param _submitAddress The wallet submit address.
     */
    function setSubmitAddress(bytes32 _walletId, address _submitAddress) external;

    /**
     * Sets the wallet backup manager.
     * @param _walletId The wallet id.
     * @param _backupManager The wallet backup manager.
     */
    function setWalletBackupManager(bytes32 _walletId, address _backupManager) external;

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
     * Proposes a new owner for the wallet. The new owner needs to confirm the ownership.
     * @param _walletId The wallet id.
     * @param _newOwner The new owner.
     */
    function proposeNewOwner(bytes32 _walletId, address _newOwner) external;

    /**
     * Confirms the ownership of the wallet after the old owner has proposed a new owner.
     * @param _walletId The wallet id.
     */
    function confirmOwnership(bytes32 _walletId) external;

    /**
     * Returns the wallet owner.
     * @param _walletId The wallet id.
     * @return _walletOwner The wallet owner.
     */
    function getWalletOwner(bytes32 _walletId) external view returns (address _walletOwner);

    /**
     * Returns the wallet backup manager.
     * @param _walletId The wallet id.
     * @return _backupManager The wallet backup manager.
     */
    function getWalletBackupManager(bytes32 _walletId) external view returns (address _backupManager);

    /**
     * Returns the wallet operation type.
     * @param _walletId The wallet id.
     * @return _opType The wallet operation type.
     */
    function getWalletOpType(bytes32 _walletId) external view returns (bytes32 _opType);

    /**
     * Returns the list of tee ids that hold the wallet key.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     * @return _teeIds The list of tee ids.
     */
    function getWalletKeyTeeIds(bytes32 _walletId, uint64 _keyId) external view returns (address[] memory _teeIds);

    /**
     * Returns the public key of the wallet key.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     * @return _publicKey The public key.
     */
    function getWalletKeyPublicKey(bytes32 _walletId, uint64 _keyId) external view returns (bytes memory _publicKey);

    /**
     * Returns the address of the wallet key.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     * @return _addressStr The address.
     */
    function getWalletKeyAddress(bytes32 _walletId, uint64 _keyId) external view returns (string memory _addressStr);

    /**
     * Returns information about the tee wallet.
     * @param _walletId The wallet id.
     * @param _submitAddress The submit address.
     * @param _status The wallet status.
     * @param _opType The wallet operation type.
     */
    function getWalletInfo(bytes32 _walletId) external view returns (
        address _submitAddress,
        WalletStatus _status,
        bytes32 _opType
    );

    /**
     * Returns information about the wallet keys.
     * @param _walletId The wallet id.
     * @param _multisigThreshold The multisig threshold.
     * @param _keyIds The key ids.
     * @param _counter The counter.
     */
    function getWalletKeysInfo(bytes32 _walletId)
        external view
        returns (uint64 _multisigThreshold, uint256[] memory _keyIds, uint64 _counter);

    /**
     * Returns wallet's receiving tees.
     * Reverts if not enough receiving tees are available or wallet is not in production status.
     * @param _walletId The wallet id.
     * @return _receivingTees The receiving tees.
     */
    function receivingTees(bytes32 _walletId) external view returns (ITeeRegistry.TeeMachine[] memory _receivingTees);

    /**
     * Returns wallet's status.
     * @param _walletId The wallet id.
     * @param _status The status.
     */
    function getWalletStatus(bytes32 _walletId) external view returns (WalletStatus _status);

    /**
     * Returns wallet's fee factor.
     * @param _walletId The wallet id.
     * @param _feeFactor The fee factor.
     */
    function getFeeFactor(bytes32 _walletId) external view returns (uint256 _feeFactor);

    /**
     * Returns supported operation types.
     * @return _supportedOpTypes The supported operation types.
     */
    function getSupportedOpTypes() external view returns (bytes32[] memory _supportedOpTypes);
}