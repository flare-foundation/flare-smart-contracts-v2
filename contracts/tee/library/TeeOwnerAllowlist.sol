// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title TeeOwnerAllowlist
 * @notice Library for managing TEE machine owner and wallet project owner allowlists.
 * @dev Uses ERC-7201 namespaced storage. Contains only methods reused by other
 *      libraries (isAllowed checks). Setter logic lives in TeeOwnerAllowlistFacet.
 */
library TeeOwnerAllowlist {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @custom:storage-location erc7201:tee.TeeOwnerAllowlist.State
    struct State {
        mapping(uint256 extensionId => EnumerableSet.AddressSet) allowedTeeMachineOwners;
        mapping(uint256 extensionId => EnumerableSet.AddressSet) allowedTeeWalletProjectOwners;
        mapping(uint256 extensionId => bool) allTeeMachineOwnersAllowed;
        mapping(uint256 extensionId => bool) allTeeWalletProjectOwnersAllowed;
    }

    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("tee.TeeOwnerAllowlist.State")) - 1)
    ) & ~bytes32(uint256(0xff));

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
