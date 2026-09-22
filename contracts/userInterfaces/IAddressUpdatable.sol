// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * @title IAddressUpdatable
 * @notice Public interface for contracts that integrate with the
 *         Flare AddressUpdater.
 */
interface IAddressUpdatable {

    /**
     * Returns the address updater contract address.
     */
    function getAddressUpdater()
        external view
        returns (address);
}
