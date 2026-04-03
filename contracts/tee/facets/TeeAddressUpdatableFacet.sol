// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { TeeExternalAddresses } from "../library/TeeExternalAddresses.sol";

/**
 * @title TeeAddressUpdatableFacet
 * @notice Facet that integrates FlareTeeManager with the Flare AddressUpdater.
 * @dev Inherits AddressUpdatable (which uses its own diamond-compatible storage slot)
 *      and overrides _updateContractAddresses to populate TeeExternalAddresses.
 */
contract TeeAddressUpdatableFacet is AddressUpdatable {

    /**
     * @dev Constructor sets addressUpdater to address(1) to prevent the implementation
     *      contract from being used directly. The real address updater is set via
     *      FlareTeeManagerInit through delegatecall.
     */
    constructor() AddressUpdatable(address(1)) {}

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        TeeExternalAddresses.State storage ext = TeeExternalAddresses.getState();
        ext.flareSystemsManager = _getContractAddress(
            _contractNameHashes, _contractAddresses, "FlareSystemsManager"
        );
        ext.rewardManager = _getContractAddress(
            _contractNameHashes, _contractAddresses, "RewardManager"
        );
        ext.relay = _getContractAddress(
            _contractNameHashes, _contractAddresses, "Relay"
        );
        ext.fdc2Hub = _getContractAddress(
            _contractNameHashes, _contractAddresses, "Fdc2Hub"
        );
        ext.fdc2Verification = _getContractAddress(
            _contractNameHashes, _contractAddresses, "Fdc2Verification"
        );
    }
}
