// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IIExternalAddresses } from
    "../interface/IIExternalAddresses.sol";
import { IExternalAddresses } from
    "../../userInterfaces/tee/IExternalAddresses.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { ExternalAddresses } from "../library/ExternalAddresses.sol";

/**
 * @title ExternalAddressesFacet
 * @notice Facet that integrates FlareTeeManager with the Flare AddressUpdater.
 * @dev Inherits AddressUpdatable (which uses its own diamond-compatible storage slot)
 *      and overrides _updateContractAddresses to populate ExternalAddresses.
 */
contract ExternalAddressesFacet is IIExternalAddresses, AddressUpdatable {

    /**
     * @dev Constructor sets addressUpdater to address(1) to prevent the implementation
     *      contract from being used directly. The real address updater is set via
     *      FlareTeeManagerInit through delegatecall.
     */
    constructor() AddressUpdatable(address(1)) {}

    /// @inheritdoc IExternalAddresses
    function flareSystemsManager() external view returns (address) {
        return ExternalAddresses.getState().flareSystemsManager;
    }

    /// @inheritdoc IExternalAddresses
    function rewardManager() external view returns (address) {
        return ExternalAddresses.getState().rewardManager;
    }

    /// @inheritdoc IExternalAddresses
    function relay() external view returns (address) {
        return ExternalAddresses.getState().relay;
    }

    /// @inheritdoc IExternalAddresses
    function fdc2Hub() external view returns (address) {
        return ExternalAddresses.getState().fdc2Hub;
    }

    /// @inheritdoc IExternalAddresses
    function fdc2Verification() external view returns (address) {
        return ExternalAddresses.getState().fdc2Verification;
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        ExternalAddresses.State storage ext = ExternalAddresses.getState();
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
