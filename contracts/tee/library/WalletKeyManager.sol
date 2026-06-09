// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IWalletKeyManager } from "../../userInterfaces/tee/IWalletKeyManager.sol";
import { IMachineManager } from "../../userInterfaces/tee/IMachineManager.sol";
import { TeeIdKeyIdPair } from "../../userInterfaces/tee/ITeeIdKeyIdPair.sol";
import { MachineManager } from "./MachineManager.sol";

/**
 * @title WalletKeyManager
 * @notice Library for TEE wallet key management.
 * @dev Uses ERC-7201 namespaced storage. Contains only logic that is
 *      reused by other libraries/facets.
 */
library WalletKeyManager {

    struct KeyDefinition {
        bytes publicKey;
        mapping(address teeId => uint256 nonce) nonces;
        address[] teeIds;
    }

    struct TeeWalletKeysState {
        uint64 keyIdCounter;
        uint64 multisigThreshold;
        uint64[] keyIds;
        mapping(uint64 keyId => KeyDefinition) keyDefinitions;
    }

    /// @custom:storage-location erc7201:tee.WalletKeyManager.State
    struct State {
        mapping(bytes32 walletId => TeeWalletKeysState) walletKeys;
    }

    bytes32 internal constant STATE_POSITION = bytes32(erc7201("tee.WalletKeyManager.State"));

    function increaseKeyNonce(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId
    )
        internal
        returns (uint256)
    {
        TeeWalletKeysState storage keys = getState().walletKeys[_walletId];
        KeyDefinition storage keyDefinition = keys.keyDefinitions[_keyId];
        require(keyDefinition.publicKey.length > 0, IWalletKeyManager.InvalidKeyId());
        return ++keyDefinition.nonces[_teeId];
    }

    /**
     * Returns wallet's receiving tees and keys.
     * Reverts if not enough receiving tees are available.
     */
    function receivingTeesAndKeys(
        bytes32 _walletId
    )
        internal
        returns (TeeIdKeyIdPair[] memory _teeIdKeyIdPairs)
    {
        TeeWalletKeysState storage keys = getState().walletKeys[_walletId];
        uint256 keyIdsLength = keys.keyIds.length;
        uint256 count = 0;
        for (uint256 i = 0; i < keyIdsLength; i++) {
            count += keys.keyDefinitions[keys.keyIds[i]].teeIds.length;
        }
        uint64[] memory unavailableKeyIds = new uint64[](keyIdsLength);
        address[] memory teeIds = new address[](count);
        uint64[] memory keyIds = new uint64[](count);
        count = 0;
        uint256 threshold = 0;
        uint256 unavailableKeyIdsCounter = 0;
        for (uint256 i = 0; i < keyIdsLength; i++) {
            bool keyAvailable = false;
            uint64 keyId = keys.keyIds[i];
            KeyDefinition storage keyDefinition = keys.keyDefinitions[keyId];
            for (uint256 j = 0; j < keyDefinition.teeIds.length; j++) {
                IMachineManager.TeeStatus status =
                    MachineManager.getTeeMachineStatus(keyDefinition.teeIds[j]);
                if (status == IMachineManager.TeeStatus.PRODUCTION) {
                    keyAvailable = true;
                    teeIds[count] = keyDefinition.teeIds[j];
                    keyIds[count] = keyId;
                    count++;
                }
            }
            if (keyAvailable) {
                threshold++;
            } else {
                unavailableKeyIds[unavailableKeyIdsCounter++] = keyId;
            }
        }
        require(threshold >= keys.multisigThreshold, IWalletKeyManager.ThresholdNotMet());
        _teeIdKeyIdPairs = new TeeIdKeyIdPair[](count);
        for (uint256 i = 0; i < count; i++) {
            _teeIdKeyIdPairs[i] = TeeIdKeyIdPair({
                teeId: teeIds[i],
                keyId: keyIds[i]
            });
        }
        if (unavailableKeyIdsCounter > 0) {
            // solhint-disable-next-line no-inline-assembly
            assembly { mstore(unavailableKeyIds, unavailableKeyIdsCounter) }
            emit IWalletKeyManager.WalletKeysNotAvailable(_walletId, unavailableKeyIds);
        }
    }

    function getWalletKeysInfo(
        bytes32 _walletId
    )
        internal view
        returns (
            uint64 _multisigThreshold,
            uint64[] memory _keyIds,
            uint64 _counter
        )
    {
        TeeWalletKeysState storage keys = getState().walletKeys[_walletId];
        return (keys.multisigThreshold, keys.keyIds, keys.keyIdCounter);
    }

    function getWalletKeyPublicKey(
        bytes32 _walletId,
        uint64 _keyId
    )
        internal view
        returns (bytes memory)
    {
        return getState().walletKeys[_walletId].keyDefinitions[_keyId].publicKey;
    }

    function getWalletKeyTeeIds(
        bytes32 _walletId,
        uint64 _keyId
    )
        internal view
        returns (address[] memory)
    {
        return getState().walletKeys[_walletId].keyDefinitions[_keyId].teeIds;
    }

    /**
     * Returns true iff `_teeId` is currently registered as holding `(walletId, keyId)`.
     * Returns false for keys that don't exist (the underlying teeIds array is empty).
     */
    function isKeyAvailable(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId
    )
        internal view
        returns (bool)
    {
        address[] storage teeIds =
            getState().walletKeys[_walletId].keyDefinitions[_keyId].teeIds;
        for (uint256 i = 0; i < teeIds.length; i++) {
            if (teeIds[i] == _teeId) {
                return true;
            }
        }
        return false;
    }

    /**
     * Raw read of the per-(teeId, walletId, keyId) nonce. Performs NO validation — callers are
     * expected to enforce key existence / extension match independently (the backup & restore
     * flows already do this for their own reasons). Returns 0 for any input combination that does
     * not have a stored entry, including non-existent keys.
     */
    function getKeyNonce(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId
    )
        internal view
        returns (uint256)
    {
        return getState().walletKeys[_walletId].keyDefinitions[_keyId].nonces[_teeId];
    }

    function getState()
        internal pure
        returns (State storage _state)
    {
        bytes32 position = STATE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _state.slot := position
        }
    }
}
