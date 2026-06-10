// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { PublicKey } from "../IPublicKey.sol";
import { TeeIdKeyIdPair } from "./ITeeIdKeyIdPair.sol";
import { Signature } from "../ISignature.sol";
import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";

// Domain prefix for the TEE-attested wallet-key-existence signed payload. See `SignedPayload`.
bytes32 constant TEE_KEY_EXISTENCE = bytes32("TEE_KEY_EXISTENCE");

/**
 * @title IWalletKeyManager
 * @notice Public interface for the WalletKeyManagerFacet.
 */
interface IWalletKeyManager is ITeeCommonErrors {

    struct KeyGenerate {
        address teeId;
        bytes32 walletId;
        uint64 keyId;
        bytes32 keyType;
        bytes32 signingAlgo;
        KeyConfigConstants configConstants;
    }

    struct KeyConfigConstants {
        PublicKey[] adminsPublicKeys;
        uint64 adminsThreshold;
        address[] cosigners;
        uint64 cosignersThreshold;
    }

    struct KeyExistence {
        address teeId;
        bytes32 walletId;
        uint64 keyId;
        bytes32 keyType;
        bytes32 signingAlgo;
        bytes publicKey;
        uint256 nonce;
        bool restored;
        KeyConfigConstants configConstants;
        bytes32 settingsVersion;
        bytes settings;
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
        bytes publicKey
    );

    event WalletKeyDeleted(
        address indexed teeId,
        bytes32 indexed walletId,
        uint64 indexed keyId
    );

    event WalletKeysNotAvailable(
        bytes32 indexed walletId,
        uint64[] keyIds
    );

    error InvalidKeyId();
    error InvalidSettings();
    error InvalidTeeSignature();
    error KeyNotRestoredOnTeeMachine();
    error TeeIdAlreadyAdded();
    error KeyNotGeneratedOnTeeMachine();
    error ThresholdNotMet();

    /**
     * Sets the multisig threshold for the wallet.
     * Emits WalletMultisigThresholdSet event.
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
     * Emits WalletKeyAdded event.
     * @param _teeId The tee id.
     * @param _walletId The wallet id.
     * @param _claimBackAddress An address that can claim back the fee if the instructions are not executed (optional).
     * @return _keyId The key id.
     */
    function addKey(
        address _teeId,
        bytes32 _walletId,
        address _claimBackAddress
    )
        external payable
        returns (uint64 _keyId);

    /**
     * Confirms the key generation.
     * Emits WalletKeyConfirmed event.
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
     * Emits WalletKeyDeleted event.
     * @param _teeId The tee id.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     * @param _claimBackAddress An address that can claim back the fee if the instructions are not executed (optional).
     */
    function deleteKey(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId,
        address _claimBackAddress
    )
        external payable;

    /**
     * For given wallet id and key id cleans up all tee machines that are not in production status.
     * Emits WalletKeyDeleted event for each deleted tee id.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     */
    function cleanUpTeeIds(
        bytes32 _walletId,
        uint64 _keyId
    )
        external;

    /**
     * Returns wallet's receiving tees and keys.
     * Reverts if not enough receiving tees are available.
     * @param _walletId The wallet id.
     * @return _teeIdKeyIdPairs The tee id and key id pairs.
     * NOTE: If all keys are not available (e.g. some TEEs being down), `WalletKeysNotAvailable` event is emitted.
     */
    function receivingTeesAndKeys(
        bytes32 _walletId
    )
        external
        returns (TeeIdKeyIdPair[] memory _teeIdKeyIdPairs);

    /**
     * Returns the list of tee ids that hold the wallet key.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     * @return _teeIds The list of tee ids.
     */
    function getWalletKeyTeeIds(
        bytes32 _walletId,
        uint64 _keyId
    )
        external view
        returns (address[] memory _teeIds);

    /**
     * Returns the public key of the wallet key.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     * @return _publicKey The public key.
     */
    function getWalletKeyPublicKey(
        bytes32 _walletId,
        uint64 _keyId
    )
        external view
        returns (bytes memory _publicKey);

    /**
     * Returns the current per-(teeId, walletId, keyId) nonce and whether the TEE currently holds the key.
     * Reverts with `InvalidKeyId` if the wallet has no such key at all.
     * Reverts with `TeeNotFound` if `_teeId` is not a registered TEE machine.
     * Reverts with `ExtensionIdMismatch` if `_teeId` is registered but belongs to a different extension than
     * the wallet. Together these three reverts guarantee the return tuple is meaningful — a successful call
     * always concerns a real key on a real TEE in the right extension.
     *
     * Interpretation of the return tuple:
     * - (N, true)   : TEE currently holds the key and the next operation will use nonce N+1.
     * - (0, false)  : TEE in the wallet's extension that has never been involved with this key.
     * - (N, false)  : TEE previously held the key (with nonce N) but it has since been deleted from this TEE;
     *                 the nonce is retained so a future re-introduction continues from N+1.
     *
     * Callers MUST consult `_teeHoldsKey` rather than treating nonce 0 as "key present" — nonce 0 alone is ambiguous.
     * @param _teeId The tee id.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     * @return _nonce The current per-tee nonce for this key.
     * @return _teeHoldsKey True iff the TEE is currently registered as holding this key.
     */
    function getKeyNonce(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId
    )
        external view
        returns (
            uint256 _nonce,
            bool _teeHoldsKey
        );

    /**
     * Returns information about the wallet keys.
     * @param _walletId The wallet id.
     * @return _multisigThreshold The multisig threshold.
     * @return _keyIds The key ids.
     * @return _counter The counter - number of `addKey` calls.
     */
    function getWalletKeysInfo(
        bytes32 _walletId
    )
        external view
        returns (
            uint64 _multisigThreshold,
            uint64[] memory _keyIds,
            uint64 _counter
        );

    /**
     * Returns the wallet's multisig threshold and public keys (ordered by key id) in a single call.
     * @param _walletId The wallet id.
     * @return _multisigThreshold The multisig threshold.
     * @return _publicKeys The public keys, ordered by key id.
     */
    function getWalletPublicKeys(
        bytes32 _walletId
    )
        external view
        returns (
            uint64 _multisigThreshold,
            bytes[] memory _publicKeys
        );
}
