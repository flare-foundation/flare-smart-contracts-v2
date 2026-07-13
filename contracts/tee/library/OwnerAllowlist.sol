// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IOwnerAllowlist } from "../../userInterfaces/tee/IOwnerAllowlist.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title OwnerAllowlist
 * @notice Library for managing TEE machine owner and wallet project owner allowlists.
 * @dev Uses ERC-7201 namespaced storage. Contains only methods reused by other
 *      libraries (isAllowed checks). Setter logic lives in OwnerAllowlistFacet.
 */
library OwnerAllowlist {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @custom:storage-location erc7201:tee.OwnerAllowlist.State
    struct State {
        // --- Global allowlist of who can become a public extension owner ---
        EnumerableSet.AddressSet allowedExtensionOwners;
        bool allExtensionOwnersAllowed;

        // --- Per-extension allowlist of TEE machine owners ---
        mapping(uint256 extensionId => EnumerableSet.AddressSet) allowedTeeMachineOwners;
        mapping(uint256 extensionId => bool) allTeeMachineOwnersAllowed;

        // --- Per-extension allowlist of TEE wallet project owners ---
        mapping(uint256 extensionId => EnumerableSet.AddressSet) allowedTeeWalletProjectOwners;
        mapping(uint256 extensionId => bool) allTeeWalletProjectOwnersAllowed;
    }

    // erc7201 builtin not recognized by slither's parser; the constant is initialized at declaration
    //slither-disable-next-line uninitialized-state
    bytes32 internal constant STATE_POSITION = bytes32(erc7201("tee.OwnerAllowlist.State"));

    /// Writes the global extension-owner-allowlist bypass flag into ERC-7201 storage and
    /// emits `IOwnerAllowlist.AllExtensionOwnersAllowed` or
    /// `IOwnerAllowlist.AllExtensionOwnersDisallowed`. Shared by
    /// `OwnerAllowlistFacet.allowAllExtensionOwners` / `disallowAllExtensionOwners`
    /// (governance-gated runtime setters) and `FlareTeeManagerInit.init` (deploy-time
    /// initialization). Auth is the caller's responsibility.
    function setAllExtensionOwnersAllowed(
        bool _allAllowed
    )
        internal
    {
        getState().allExtensionOwnersAllowed = _allAllowed;
        if (_allAllowed) {
            emit IOwnerAllowlist.AllExtensionOwnersAllowed();
        } else {
            emit IOwnerAllowlist.AllExtensionOwnersDisallowed();
        }
    }

    function isAllowedExtensionOwner(
        address _owner
    )
        internal view
        returns (bool)
    {
        State storage s = getState();
        return s.allExtensionOwnersAllowed || s.allowedExtensionOwners.contains(_owner);
    }

    function isAllowedTeeMachineOwner(
        uint256 _extensionId,
        address _owner
    )
        internal view
        returns (bool)
    {
        State storage s = getState();
        return s.allTeeMachineOwnersAllowed[_extensionId] ||
            s.allowedTeeMachineOwners[_extensionId].contains(_owner);
    }

    function isAllowedTeeWalletProjectOwner(
        uint256 _extensionId,
        address _owner
    )
        internal view
        returns (bool)
    {
        State storage s = getState();
        return s.allTeeWalletProjectOwnersAllowed[_extensionId] ||
            s.allowedTeeWalletProjectOwners[_extensionId].contains(_owner);
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
