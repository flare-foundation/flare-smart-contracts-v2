// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";
import "./ITeeKeyExistence.sol";

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

    struct PublicKey {
        bytes32 x;
        bytes32 y;
    }

    struct KeyGenerate {
        address teeId;
        bytes32 walletId;
        uint256 keyId;
        bytes32 opType;
        bytes opTypeConstants;
        PublicKey[] adminsPublicKeys;
        uint256 adminsThreshold;
        address[] cosigners;
        uint256 cosignersThreshold;
    }

    struct KeyDelete {
        address teeId;
        bytes32 walletId;
        uint256 keyId;
    }

    struct TeeIdKeyIdPair {
        address teeId;
        uint256 keyId;
    }

    event WalletCreated(
        bytes32 indexed projectId,
        bytes32 indexed walletId,
        uint64 multisigThreshold
    );

    event WalletInitialized(
        bytes32 indexed walletId
    );

    event WalletKeysNotAvailable(
        bytes32 indexed walletId,
        uint256[] keyIds
    );

    /**
     * Creates the wallet for the project.
     * @param _projectId The project id.
     * @param _multisigThreshold The multisig threshold.
     * @return _walletId The wallet id.
     */
    function createWallet(
        bytes32 _projectId,
        uint64 _multisigThreshold
    )
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
     * Adds a key to the wallet - triggers a key generation process.
     * @param _teeId The tee id.
     * @param _walletId The wallet id.
     * @return _keyId The key id.
     */
    function addKey(address _teeId, bytes32 _walletId) external payable returns (uint64 _keyId);

    /**
     * Requests a key existence attestation.
     * @param _teeId The tee id.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     */
    function requestKeyExistenceAttestation(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId
    )
        external payable;

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
     * Returns wallet's receiving tees and keys.
     * Reverts if not enough receiving tees are available or wallet is not in production status.
     * @param _walletId The wallet id.
     * @return _receivingTees The receiving tees.
     * @return _teeIdKeyIdPairs The tee id and key id pairs.
     * NOTE: If all keys are not available (e.g. some TEEs being down), `WalletKeysNotAvailable` event is emitted.
     */
    function receivingTeesAndKeys(bytes32 _walletId)
        external
        returns (ITeeRegistry.TeeMachine[] memory _receivingTees, TeeIdKeyIdPair[] memory _teeIdKeyIdPairs);

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

    /**
     * Checks if operation type is supported on TEE wallet manager.
     * @param _opType The operation type.
     * @return True if the operation type is supported.
     */
    function isOpTypeSupported(bytes32 _opType)
        external view
        returns (bool);
}