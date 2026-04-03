// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title TeeExternalAddresses
 * @notice Library for storing addresses of contracts external to the FlareTeeManager Diamond.
 * @dev Uses ERC-7201 namespaced storage. Addresses are set by TeeAddressUpdatableFacet
 *      when AddressUpdater triggers _updateContractAddresses.
 */
library TeeExternalAddresses {

    /// @custom:storage-location erc7201:tee.TeeExternalAddresses.State
    struct State {
        address flareSystemsManager;
        address rewardManager;
        address relay;
        address fdc2Hub;
        address fdc2Verification;
    }

    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("tee.TeeExternalAddresses.State")) - 1)
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
