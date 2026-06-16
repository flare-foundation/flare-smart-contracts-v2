// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

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
 * @dev Uses ERC-7201 namespaced storage. Lists are addressed by (extensionId, nonce) and stored in a
 *      nonce-keyed mapping (nonces are 1-based; `listCount` tracks the highest nonce minted per
 *      extension). Paths within a list are likewise stored in an index-keyed mapping bounded by
 *      `pathCount`. Both collections deliberately use mappings rather than dynamic arrays: the element
 *      structs (`MachinePathList`, `MachinePathState`) carry mappings and may gain fields in future
 *      facet upgrades, and a dynamic array of such structs has a fixed per-element stride that shifts
 *      when the struct grows — silently corrupting every stored element on an in-place upgrade. Mapping
 *      values have no such stride, so the layout stays append-safe. The `extensionActiveListNonce`
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
        mapping(uint256 index => MachinePathState) paths;
        uint256 pathCount;
        /// keccak256(abi.encode(...)), set on finalize -> enables signing
        bytes32 messageHash;
        bool listSigned;
    }

    /// @custom:storage-location erc7201:tee.MachinePathManager.State
    struct State {
        // Lists keyed by 1-based nonce; `listCount[extensionId]` is the highest nonce minted.
        mapping(uint256 extensionId => mapping(uint256 nonce => MachinePathList)) lists;
        mapping(uint256 extensionId => uint256) listCount;
        mapping(uint256 extensionId => uint256) extensionActiveListNonce;
    }

    bytes32 internal constant STATE_POSITION = bytes32(erc7201("tee.MachinePathManager.State"));

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
        State storage s = getState();
        require(_nonce != 0 && _nonce <= s.listCount[_extensionId], ITeeCommonErrors.InvalidNonce());
        _listRef = s.lists[_extensionId][_nonce];
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
        MachinePathList storage pathList = s.lists[_extensionId][n];
        for (uint256 i = 0; i < pathList.pathCount; i++) {
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
        MachinePathList storage pathList = getState().lists[_extensionId][_nonce];
        for (uint256 i = 0; i < pathList.pathCount; i++) {
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
