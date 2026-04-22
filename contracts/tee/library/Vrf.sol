// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title Vrf
 * @notice Library for TEE VRF authorization state.
 * @dev Uses ERC-7201 namespaced storage.
 */
library Vrf {

    /// @custom:storage-location erc7201:tee.Vrf.State
    struct State {
        mapping(bytes32 walletId => address) vrfAuthorizationAddresses;
    }

    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("tee.Vrf.State")) - 1)
    ) & ~bytes32(uint256(0xff));

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
