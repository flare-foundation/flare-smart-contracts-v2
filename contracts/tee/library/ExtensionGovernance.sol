// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { ISafeMinimal } from "../../utils/interface/ISafeMinimal.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title ExtensionGovernance
 * @notice Library for managing TEE extension governance: per-extension signer sets and thresholds
 *         identified by a content-derived `governanceHash`.
 * @dev Uses ERC-7201 namespaced storage.
 */
library ExtensionGovernance {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct TeeGovernanceData {
        EnumerableSet.AddressSet signers;
        uint64 signersThreshold;
        /// The Safe multisig backing this governance; `address(0)` for plain governance.
        /// Appended field — mapping values are append-safe.
        address safeAddress;
    }

    struct TeeExtensionGovernanceState {
        /// The latest TEE governance hash.
        bytes32 latestTeeGovernanceHash;
        mapping(bytes32 governanceHash => TeeGovernanceData) governanceHashToTeeGovernance;
    }

    /// @custom:storage-location erc7201:tee.ExtensionGovernance.State
    struct State {
        mapping(uint256 extensionId => TeeExtensionGovernanceState) extensionStates;
    }

    // erc7201 builtin not recognized by slither's parser; the constant is initialized at declaration
    //slither-disable-next-line uninitialized-state
    bytes32 internal constant STATE_POSITION = bytes32(erc7201("tee.ExtensionGovernance.State"));

    function getLatestTeeGovernanceHash(
        uint256 _extensionId
    )
        internal view
        returns (bytes32)
    {
        return getState().extensionStates[_extensionId].latestTeeGovernanceHash;
    }

    function isGovernanceHashValid(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        internal view
        returns (bool)
    {
        return getState().extensionStates[_extensionId]
            .governanceHashToTeeGovernance[_governanceHash].signersThreshold > 0;
    }

    function isTeeGovernanceSigner(
        uint256 _extensionId,
        bytes32 _governanceHash,
        address _signer
    )
        internal view
        returns (bool)
    {
        return getState().extensionStates[_extensionId]
            .governanceHashToTeeGovernance[_governanceHash].signers.contains(_signer);
    }

    function getTeeGovernanceThreshold(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        internal view
        returns (uint64 _threshold)
    {
        _threshold = getState().extensionStates[_extensionId]
            .governanceHashToTeeGovernance[_governanceHash].signersThreshold;
        require(_threshold > 0, ITeeCommonErrors.InvalidGovernanceHash());
    }

    /**
     * Returns the Safe multisig backing the given governance, or `address(0)` for plain governance
     * (and for unrecorded hashes).
     */
    function getTeeGovernanceSafeAddress(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        internal view
        returns (address)
    {
        return getState().extensionStates[_extensionId]
            .governanceHashToTeeGovernance[_governanceHash].safeAddress;
    }

    /**
     * Returns true iff a quorum of `_safe`'s live owners can still satisfy the snapshot recorded
     * under `_governanceHash`: the live threshold must not be below the snapshot threshold, and at
     * least `snapshotThreshold` snapshot signers must still be live owners of `_safe` (checked by
     * staticcalling `isOwner` per stored signer, early-exiting once the threshold is reached — the
     * stored set is unique by construction, so no duplicate handling is needed). SCREENING ONLY,
     * never an authorization check: both inputs are under the Safe's own control, so a Safe whose
     * ownership has since changed can satisfy any historical snapshot by reconfiguring itself
     * beforehand. Authorization comes from
     * `IMachinePathManager.confirmMachinePathListSafeApproval`, which verifies the actual owner
     * signatures against the frozen snapshot; this screen only fails an honestly-stale Safe fast,
     * before it consumes a nonce on an unconfirmable approval.
     */
    function isSnapshotSatisfiable(
        uint256 _extensionId,
        bytes32 _governanceHash,
        ISafeMinimal _safe,
        uint256 _liveThreshold
    )
        internal view
        returns (bool)
    {
        TeeGovernanceData storage teeGov = getState().extensionStates[_extensionId]
            .governanceHashToTeeGovernance[_governanceHash];
        uint256 snapshotThreshold = teeGov.signersThreshold;
        if (snapshotThreshold == 0 || _liveThreshold < snapshotThreshold) {
            return false;
        }
        uint256 stillOwners = 0;
        uint256 signerCount = teeGov.signers.length();
        for (uint256 i = 0; i < signerCount; i++) {
            if (_safe.isOwner(teeGov.signers.at(i))) {
                stillOwners++;
                if (stillOwners >= snapshotThreshold) {
                    return true;
                }
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
}
