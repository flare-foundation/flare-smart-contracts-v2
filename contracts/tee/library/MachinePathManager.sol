// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IMachinePathManager } from "../../userInterfaces/tee/IMachinePathManager.sol";
import { IMachineManager } from "../../userInterfaces/tee/IMachineManager.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ExtensionManager } from "./ExtensionManager.sol";
import { MachineManager } from "./MachineManager.sol";

/**
 * @title MachinePathManager
 * @notice Library for managing per-extension governance-signed TEE machine path lists.
 * @dev Uses ERC-7201 namespaced storage. Lists are addressed by (extensionId, nonce). The list with
 *      nonce `N` lives at array index `N - 1` inside its extension's array. The `extensionActiveListNonce`
 *      mapping defaults to 0 to unambiguously mean "no list signed yet" — list nonces start at 1.
 */
library MachinePathManager {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    struct MachinePathState {
        IMachinePathManager.MachinePath path;
        mapping(address sourceTeeId => bool) sourceTeeIdExists;
        mapping(address destinationTeeId => bool) destinationTeeIdExists;
    }

    struct MachinePathList {
        EnumerableSet.Bytes32Set involvedGovernanceHashes;
        Signature[] signatures;
        mapping(address signer => bool) signerHasSigned;
        mapping(bytes32 governanceHash => uint64) signatureCount;
        MachinePathState[] paths;
        /// keccak256(abi.encode(...)), set on finalize -> enables signing
        bytes32 messageHash;
        bool listSigned;
    }

    /// @custom:storage-location erc7201:tee.MachinePathManager.State
    struct State {
        mapping(uint256 extensionId => MachinePathList[]) lists;
        mapping(uint256 extensionId => uint256) extensionActiveListNonce;
    }

    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("tee.MachinePathManager.State")) - 1)
    ) & ~bytes32(uint256(0xff));

    /**
     * Returns the storage handle for the list at (extensionId, nonce).
     * Reverts `InvalidNonce` if nonce is zero or out of range.
     */
    function list(
        uint256 _extensionId,
        uint256 _nonce
    )
        internal view
        returns (MachinePathList storage _listRef)
    {
        MachinePathList[] storage arr = getState().lists[_extensionId];
        require(_nonce != 0 && _nonce <= arr.length, ITeeCommonErrors.InvalidNonce());
        _listRef = arr[_nonce - 1];
    }

    /**
     * Returns the nonce of the active (latest-signed) list for the given extension.
     * Reverts `NoActiveMachinePathList` if the extension has never had a signed list.
     */
    function getActiveListNonce(
        uint256 _extensionId
    )
        internal view
        returns (uint256 _nonce)
    {
        _nonce = getState().extensionActiveListNonce[_extensionId];
        require(_nonce != 0, IMachinePathManager.NoActiveMachinePathList());
    }

    /**
     * Non-reverting probe: returns true iff the extension has an active signed list AND that list
     * contains a path with `_sourceTeeId` in its source set and `_destinationTeeId` in its destination set.
     */
    function isMachinePathValid(
        uint256 _extensionId,
        address _sourceTeeId,
        address _destinationTeeId
    )
        internal view
        returns (bool)
    {
        State storage s = getState();
        uint256 n = s.extensionActiveListNonce[_extensionId];
        if (n == 0) {
            return false;
        }
        MachinePathList storage pathList = s.lists[_extensionId][n - 1];
        for (uint256 i = 0; i < pathList.paths.length; i++) {
            MachinePathState storage p = pathList.paths[i];
            if (p.sourceTeeIdExists[_sourceTeeId] && p.destinationTeeIdExists[_destinationTeeId]) {
                return true;
            }
        }
        return false;
    }

    /**
     * Reverting variant for on-chain consumers that need the active list nonce to forward into an
     * instruction payload. Reverts `NoActiveMachinePathList` if the extension has none, or
     * `InvalidMachinePath` if the pair is not present in the currently-active list.
     */
    function requireActiveListNonceForPath(
        uint256 _extensionId,
        address _sourceTeeId,
        address _destinationTeeId
    )
        internal view
        returns (uint256 _nonce)
    {
        _nonce = getActiveListNonce(_extensionId);
        MachinePathList storage pathList = getState().lists[_extensionId][_nonce - 1];
        for (uint256 i = 0; i < pathList.paths.length; i++) {
            MachinePathState storage p = pathList.paths[i];
            if (p.sourceTeeIdExists[_sourceTeeId] && p.destinationTeeIdExists[_destinationTeeId]) {
                return _nonce;
            }
        }
        revert IMachinePathManager.InvalidMachinePath();
    }

    /**
     * Asserts that `_teeId` belongs to `_extensionId` and has a non-zero governance hash recorded,
     * then returns that governance hash. Helper used by the facet when appending paths.
     * @dev Status is intentionally not checked here: a freshly registered TEE (status INITIALIZED)
     *      that has chosen the current latest governance at registration time is a legitimate
     *      destination for replication path lists. Callers that need stricter status semantics
     *      (e.g. directBackup requiring PRODUCTION) check status themselves.
     */
    function assertEligibleAndDeriveGovernanceHash(
        uint256 _extensionId,
        address _teeId
    )
        internal view
        returns (bytes32 _governanceHash)
    {
        MachineManager.TeeMachineState storage tee = MachineManager.getState().teeMachineStates[_teeId];
        require(tee.extensionId == _extensionId, ITeeCommonErrors.ExtensionIdMismatch());
        _governanceHash = MachineManager.getTeeMachineGovernanceHash(_teeId);
        require(
            _governanceHash != bytes32(0),
            IMachinePathManager.GovernanceHashZero(_teeId)
        );
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
