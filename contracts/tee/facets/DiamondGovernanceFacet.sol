// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IIDiamondGovernance } from
    "../interface/IIDiamondGovernance.sol";
import { LibDiamond } from "../../diamond/libraries/LibDiamond.sol";
import { FlareGovernedBase } from "../../governance/implementation/FlareGovernedBase.sol";

/**
 * @title DiamondGovernanceFacet
 * @notice DiamondCut facet with Flare governance (timelocked in production mode).
 * @dev This is the ONLY facet that exposes governance public functions
 *      (governance, executeGovernanceCall, cancelGovernanceCall, switchToProductionMode,
 *      governanceSettings, productionMode, isExecutor) — they are inherited from
 *      `FlareGovernedBase`. All other facets use `FlareGovernedAccess` (internal modifiers
 *      only, no public functions). Governance state is stored via the `FlareGovernance`
 *      library (ERC-7201 namespaced storage).
 */
contract DiamondGovernanceFacet is IIDiamondGovernance, FlareGovernedBase {

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
}
