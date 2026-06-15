// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { FlareGovernedBase } from "./FlareGovernedBase.sol";
import { FlareGovernance } from "../lib/FlareGovernance.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";


/**
 * Base class for Flare governed proxy implementations that support UUPS upgradeability and address updatability.
 **/
abstract contract FlareUpgradeableBase is FlareGovernedBase, UUPSUpgradeable, AddressUpdatable {

    constructor() AddressUpdatable(address(0)) {}

    /**
     * Returns the current implementation address.
     * @return The current implementation address.
     */
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Only governance can call this method.
     */
    function upgradeToAndCall(
        address _newImplementation,
        bytes memory _data
    )
        public payable virtual override
        onlyGovernance
    {
        super.upgradeToAndCall(_newImplementation, _data);
    }

    /**
     * Unused. Present just to satisfy UUPSUpgradeable requirement.
     * The real check is in onlyGovernance modifier on upgradeToAndCall.
     */
    function _authorizeUpgrade(address _newImplementation) internal virtual override {}

    /**
     * Initializes the contract with governance settings, initial governance address and address updater.
     * @param _governanceSettings The governance settings interface.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address updater contract.
     */
    function initializeBase(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        internal virtual
        onlyInitializing
    {
        FlareGovernance.initialise(_governanceSettings, _initialGovernance);
        AddressUpdatable.setAddressUpdaterValue(_addressUpdater);
    }
}
