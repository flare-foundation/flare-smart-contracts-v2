// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IIExternalAddressesFacet } from
    "../interface/IIExternalAddressesFacet.sol";
import { IExternalAddressesFacet } from
    "../../userInterfaces/tee/IExternalAddressesFacet.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { ExternalAddresses } from "../library/ExternalAddresses.sol";

/**
 * @title ExternalAddressesFacet
 * @notice Facet that integrates FlareTeeManager with the Flare AddressUpdater.
 * @dev Inherits AddressUpdatable (which uses its own diamond-compatible storage slot)
 *      and overrides _updateContractAddresses to populate ExternalAddresses.
 */
contract ExternalAddressesFacet is IIExternalAddressesFacet, AddressUpdatable {

    /**
     * @dev Constructor sets addressUpdater to address(1) to prevent the implementation
     *      contract from being used directly. The real address updater is set via
     *      FlareTeeManagerInit through delegatecall.
     */
    constructor() AddressUpdatable(address(1)) {}

    /// @inheritdoc IExternalAddressesFacet
    function flareSystemsManager() external view returns (address) {
        return ExternalAddresses.getState().flareSystemsManager;
    }

    /// @inheritdoc IExternalAddressesFacet
    function rewardManager() external view returns (address) {
        return ExternalAddresses.getState().rewardManager;
    }

    /// @inheritdoc IExternalAddressesFacet
    function relay() external view returns (address) {
        return ExternalAddresses.getState().relay;
    }

    /// @inheritdoc IExternalAddressesFacet
    function fdc2Hub() external view returns (address) {
        return ExternalAddresses.getState().fdc2Hub;
    }

    /// @inheritdoc IExternalAddressesFacet
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
