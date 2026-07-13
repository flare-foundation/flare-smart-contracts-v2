// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/**
 * @title ExternalAddresses
 * @notice Library for storing addresses of contracts external to the FlareTeeManager Diamond.
 * @dev Uses ERC-7201 namespaced storage. Addresses are set by ExternalAddressesFacet
 *      when AddressUpdater triggers _updateContractAddresses.
 */
library ExternalAddresses {

    /// @custom:storage-location erc7201:tee.ExternalAddresses.State
    struct State {
        address flareSystemsManager;
        address rewardManager;
        address relay;
        address fdc2Hub;
        address fdc2Verification;
    }

    // erc7201 builtin not recognized by slither's parser; the constant is initialized at declaration
    //slither-disable-next-line uninitialized-state
    bytes32 internal constant STATE_POSITION = bytes32(erc7201("tee.ExternalAddresses.State"));

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
