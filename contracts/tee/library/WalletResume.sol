// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/**
 * @title WalletResume
 * @notice Library for TEE wallet resume/pausing-address management.
 * @dev Uses ERC-7201 namespaced storage.
 */
library WalletResume {

    /// @custom:storage-location erc7201:tee.WalletResume.State
    struct State {
        mapping(bytes32 walletId => uint256) setPausingAddressesNonce;
    }

    // erc7201 builtin not recognized by slither's parser; the constant is initialized at declaration
    //slither-disable-next-line uninitialized-state
    bytes32 internal constant STATE_POSITION = bytes32(erc7201("tee.WalletResume.State"));

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
