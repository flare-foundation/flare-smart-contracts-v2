// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IAddressUpdatable } from "../IAddressUpdatable.sol";

/**
 * @title IExternalAddressesFacet
 * @notice Public interface for the ExternalAddressesFacet.
 *         Provides getters for the address updater and external
 *         contract addresses resolved by the AddressUpdater.
 */
interface IExternalAddressesFacet is IAddressUpdatable {

    /**
     * Returns the FlareSystemsManager contract address.
     */
    function flareSystemsManager()
        external view
        returns (address);

    /**
     * Returns the RewardManager contract address.
     */
    function rewardManager()
        external view
        returns (address);

    /**
     * Returns the Relay contract address.
     */
    function relay()
        external view
        returns (address);

    /**
     * Returns the Fdc2Hub contract address.
     */
    function fdc2Hub()
        external view
        returns (address);

    /**
     * Returns the Fdc2Verification contract address.
     */
    function fdc2Verification()
        external view
        returns (address);
}
