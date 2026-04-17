// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IIDiamondGovernanceFacet } from
    "../interface/IIDiamondGovernanceFacet.sol";
import { IFlareGovernance } from "../../userInterfaces/tee/IFlareGovernance.sol";
import { IIFlareGovernance } from "../interface/IIFlareGovernance.sol";
import { LibDiamond } from "../../diamond/libraries/LibDiamond.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { FlareGovernance } from "../library/FlareGovernance.sol";
import { GovernedFacet } from "./GovernedFacet.sol";

/**
 * @title DiamondGovernanceFacet
 * @notice DiamondCut facet with Flare governance (timelocked in production mode).
 * @dev This is the ONLY facet that exposes governance public functions
 *      (governance, executeGovernanceCall, cancelGovernanceCall, switchToProductionMode,
 *      governanceSettings, productionMode, isExecutor).
 *      All other facets use GovernedFacet (internal modifiers only, no public functions).
 *      Governance state is stored via FlareGovernance library (ERC-7201 namespaced storage).
 */
contract DiamondGovernanceFacet is IIDiamondGovernanceFacet, GovernedFacet {

    /**
     * @notice Add/replace/remove any number of functions and optionally execute
     *         a function with delegatecall.
     * @param _diamondCut Contains the facet addresses and function selectors.
     * @param _init The address of the contract or facet to execute _calldata.
     * @param _calldata A function call, including function selector and arguments.
     * @dev Only governance can call this method (timelocked in production mode).
     */
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    )
        external
        onlyGovernance
    {
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }

    // =========================================================================
    // IFlareGovernance / IIFlareGovernance — governance API (only on this facet)
    // =========================================================================

    /// @inheritdoc IFlareGovernance
    function executeGovernanceCall(
        bytes calldata _encodedCall
    )
        external
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
        return FlareGovernance.getState().governanceSettings;
    }

    /// @inheritdoc IFlareGovernance
    function productionMode()
        external view
        returns (bool)
    {
        return FlareGovernance.getState().productionMode;
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
