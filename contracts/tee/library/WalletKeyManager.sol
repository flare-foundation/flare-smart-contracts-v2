// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IWalletKeyManager } from "../../userInterfaces/tee/IWalletKeyManager.sol";
import { IMachineManager } from "../../userInterfaces/tee/IMachineManager.sol";
import { TeeIdKeyIdPair } from "../../userInterfaces/tee/ITeeIdKeyIdPair.sol";
import { MachineManager } from "./MachineManager.sol";
import { Instructions } from "./Instructions.sol";

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

    // erc7201 builtin not recognized by slither's parser; the constant is initialized at declaration
    //slither-disable-next-line uninitialized-state
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
     * NOTE: If some keys are unavailable (e.g. some TEEs being down), `WalletKeysNotAvailable`
     * event is emitted. This is the dispatch-path variant used by `pay`/`reissue`.
     */
    function receivingTeesAndKeys(
        bytes32 _walletId
    )
        internal
        returns (TeeIdKeyIdPair[] memory _teeIdKeyIdPairs)
    {
        uint64[] memory unavailableKeyIds;
        (_teeIdKeyIdPairs, unavailableKeyIds) = _collectReceivingTeesAndKeys(_walletId);
        if (unavailableKeyIds.length > 0) {
            emit IWalletKeyManager.WalletKeysNotAvailable(_walletId, unavailableKeyIds);
        }
    }

    /**
     * Read-only twin of `receivingTeesAndKeys` returning only the deduplicated list of tee ids
     * that would receive instructions for the wallet. This matches exactly the tee ids the
     * dispatch path feeds the fee calculation (`InstructionsFacet` deduplicates before
     * `Instructions.sendInstructions`), so `OperationFees.calculateFeeByTeeIds` applied to this
     * list yields the same fee a real `pay`/`reissue` charges.
     * Reverts with `ThresholdNotMet` if not enough receiving tees are available - mirroring the
     * dispatch path - and emits no event (safe to call via `eth_call`).
     */
    function getReceivingTeeIds(
        bytes32 _walletId
    )
        internal view
        returns (address[] memory _teeIds)
    {
        (TeeIdKeyIdPair[] memory pairs, ) = _collectReceivingTeesAndKeys(_walletId);
        _teeIds = new address[](pairs.length);
        for (uint256 i = 0; i < pairs.length; i++) {
            _teeIds[i] = pairs[i].teeId;
        }
        Instructions.removeDuplicates(_teeIds);
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

    function getWalletPublicKeys(
        bytes32 _walletId
    )
        internal view
        returns (
            uint64 _multisigThreshold,
            bytes[] memory _publicKeys
        )
    {
        TeeWalletKeysState storage keys = getState().walletKeys[_walletId];
        uint64[] memory keyIds = keys.keyIds;
        _multisigThreshold = keys.multisigThreshold;
        _publicKeys = new bytes[](keyIds.length);
        for (uint256 i = 0; i < keyIds.length; i++) {
            _publicKeys[i] = keys.keyDefinitions[keyIds[i]].publicKey;
        }
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

    /**
     * Shared core for `receivingTeesAndKeys` and `getReceivingTeeIds`: collects the PRODUCTION
     * (teeId, keyId) pairs for the wallet and the list of unavailable key ids, and enforces the
     * multisig threshold. Pure data only - no event emission - so it is safe for `view` callers.
     */
    function _collectReceivingTeesAndKeys(
        bytes32 _walletId
    )
        private view
        returns (
            TeeIdKeyIdPair[] memory _teeIdKeyIdPairs,
            uint64[] memory _unavailableKeyIds
        )
    {
        TeeWalletKeysState storage keys = getState().walletKeys[_walletId];
        uint256 keyIdsLength = keys.keyIds.length;
        uint256 count = 0;
        for (uint256 i = 0; i < keyIdsLength; i++) {
            count += keys.keyDefinitions[keys.keyIds[i]].teeIds.length;
        }
        _unavailableKeyIds = new uint64[](keyIdsLength);
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
                _unavailableKeyIds[unavailableKeyIdsCounter++] = keyId;
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
        // solhint-disable-next-line no-inline-assembly
        assembly { mstore(_unavailableKeyIds, unavailableKeyIdsCounter) }
    }
}
