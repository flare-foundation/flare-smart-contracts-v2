// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IFlareGovernance } from "./IFlareGovernance.sol";

/**
 * @title IDiamondGovernanceFacet
 * @notice Public interface for the DiamondGovernanceFacet.
 * @dev Exposes the Flare governance API (governance, productionMode, etc.).
 *      The governance-only diamondCut method is in the internal interface.
 */
interface IDiamondGovernanceFacet is
    IFlareGovernance
{}
