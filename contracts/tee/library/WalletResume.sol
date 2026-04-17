// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

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

    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("tee.WalletResume.State")) - 1)
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
