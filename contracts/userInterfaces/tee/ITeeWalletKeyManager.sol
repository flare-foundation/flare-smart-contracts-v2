// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";
import "../IPublicKey.sol";
import "./ITeeIdKeyIdPair.sol";

/**
 * TeeWalletKeyManager interface.
 */
interface ITeeWalletKeyManager {

    enum TeeKeyStatus { PAUSED, ACTIVE }

    struct KeyGenerate {
        address teeId;
        bytes32 walletId;
        uint64 keyId;
        bytes32 opType;
        KeyConfigConstants configConstants;
    }

    struct KeyConfigConstants {
        PublicKey[] adminsPublicKeys;
        uint64 adminsThreshold;
        address[] cosigners;
        uint64 cosignersThreshold;
        bytes opTypeConstants;
    }

    struct KeyConfigSettings {
        address[] pausingAddresses;
        bytes opTypeSettings;
    }

    struct KeyExistence {
        address teeId;
        bytes32 walletId;
        uint64 keyId;
        bytes32 opType;
        bytes publicKey;
        uint256 nonce;
        uint256 pauseNonce;
        TeeKeyStatus status;
        bool restored;
        string addressStr;
        KeyConfigConstants configConstants;
        KeyConfigSettings configSettings;
    }

    struct KeyDelete {
        address teeId;
        bytes32 walletId;
        uint64 keyId;
        uint256 nonce;
    }

    event WalletMultisigThresholdSet(
        bytes32 indexed walletId,
        uint64 multisigThreshold
    );

    event WalletKeyAdded(
        address indexed teeId,
        bytes32 indexed walletId,
        uint64 indexed keyId
    );

    event WalletKeyConfirmed(
        address indexed teeId,
        bytes32 indexed walletId,
        uint64 indexed keyId,
        bytes publicKey,
        string addressStr
    );

    event WalletKeyDeleted(
        address indexed teeId,
        bytes32 indexed walletId,
        uint64 indexed keyId
    );

    event WalletEnabled(
        bytes32 indexed walletId
    );

    event WalletPaused(
        bytes32 indexed walletId
    );

    event WalletKeysNotAvailable(
        bytes32 indexed walletId,
        uint64[] keyIds
    );

    /**
     * Sets the multisig threshold for the wallet.
     * @param _walletId The wallet id.
     * @param _multisigThreshold The multisig threshold.
     */
    function setMultisigThreshold(
        bytes32 _walletId,
        uint64 _multisigThreshold
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
     * Confirms the key generation.
     * @param _proof The key existence proof.
     * @param _teeSignature The TEE machine signature of the key existence proof.
     */
    function confirmKey(
        KeyExistence calldata _proof,
        Signature calldata _teeSignature
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
     * Returns wallet's receiving tees and keys.
     * Reverts if not enough receiving tees are available.
     * @param _walletId The wallet id.
     * @return _teeMachines The receiving tee machines.
     * @return _teeIdKeyIdPairs The tee id and key id pairs.
     * NOTE: If all keys are not available (e.g. some TEEs being down), `WalletKeysNotAvailable` event is emitted.
     */
    function receivingTeesAndKeys(bytes32 _walletId)
        external
        returns (ITeeRegistry.TeeMachine[] memory _teeMachines, TeeIdKeyIdPair[] memory _teeIdKeyIdPairs);

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
     * @param _counter The counter - number of `addKey` calls.
     */
    function getWalletKeysInfo(bytes32 _walletId)
        external view
        returns (uint64 _multisigThreshold, uint64[] memory _keyIds, uint64 _counter);

    /**
     * Returns wallet's fee factor.
     * @param _walletId The wallet id.
     * @param _feeFactor The fee factor.
     */
    function getFeeFactor(bytes32 _walletId) external view returns (uint256 _feeFactor);
}