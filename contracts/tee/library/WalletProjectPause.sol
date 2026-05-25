// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title WalletProjectPause
 * @notice Library holding the per-wallet-project pauser and unpauser allowlists.
 * @dev Uses ERC-7201 namespaced storage. Contains only methods reused by other
 *      libraries (isPauser / isUnpauser checks). Mutation logic lives in
 *      WalletProjectPauseFacet.
 */
library WalletProjectPause {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @custom:storage-location erc7201:tee.WalletProjectPause.State
    struct State {
        mapping(bytes32 projectId => EnumerableSet.AddressSet) pausers;
        mapping(bytes32 projectId => EnumerableSet.AddressSet) unpausers;
    }

    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("tee.WalletProjectPause.State")) - 1)
    ) & ~bytes32(uint256(0xff));

    function isPauser(
        bytes32 _projectId,
        address _addr
    )
        internal view
        returns (bool)
    {
        return getState().pausers[_projectId].contains(_addr);
    }

    function isUnpauser(
        bytes32 _projectId,
        address _addr
    )
        internal view
        returns (bool)
    {
        return getState().unpausers[_projectId].contains(_addr);
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
