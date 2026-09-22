// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IFlareGovernance } from "../../userInterfaces/IFlareGovernance.sol";
import { IIFlareGovernance } from "../interface/IIFlareGovernance.sol";
import { FlareGovernance } from "../lib/FlareGovernance.sol";
import { FlareGovernedAccess } from "./FlareGovernedAccess.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * @title FlareGovernedBase
 * @notice Abstract base that exposes the public Flare governance API on top of
 *         `FlareGovernedAccess`.
 * @dev Inherits the `onlyGovernance` / `onlyImmediateGovernance` modifiers from
 *      `FlareGovernedAccess` and adds the seven public governance functions
 *      (executeGovernanceCall, cancelGovernanceCall, switchToProductionMode,
 *      governance, governanceSettings, productionMode, isExecutor). Function
 *      bodies are one-line delegates to the `FlareGovernance` library.
 *
 *      Used by `FlareUpgradeableBase` (UUPS proxy implementations) and by
 *      `DiamondGovernanceFacet` (the only Diamond facet exposing this API).
 */
abstract contract FlareGovernedBase is IIFlareGovernance, FlareGovernedAccess {

    /// @inheritdoc IFlareGovernance
    function executeGovernanceCall(
        bytes calldata _encodedCall
    )
        external payable
    {
        FlareGovernance.executeGovernanceCall(_encodedCall);
    }

    /// @inheritdoc IIFlareGovernance
    function cancelGovernanceCall(
        bytes calldata _encodedCall
    )
        external
    {
        FlareGovernance.cancelGovernanceCall(_encodedCall);
    }

    /// @inheritdoc IIFlareGovernance
    function switchToProductionMode()
        external
    {
        FlareGovernance.switchToProductionMode();
    }

    /// @inheritdoc IFlareGovernance
    function governance()
        external view
        returns (address)
    {
        return FlareGovernance.governance();
    }

    /// @inheritdoc IFlareGovernance
    function governanceSettings()
        external view
        returns (IGovernanceSettings)
    {
        return FlareGovernance.governanceSettings();
    }

    /// @inheritdoc IFlareGovernance
    function productionMode()
        external view
        returns (bool)
    {
        return FlareGovernance.productionMode();
    }

    /// @inheritdoc IFlareGovernance
    function isExecutor(
        address _address
    )
        external view
        returns (bool)
    {
        return FlareGovernance.isExecutor(_address);
    }
}
