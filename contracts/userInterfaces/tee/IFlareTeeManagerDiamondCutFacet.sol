// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IFlareGovernance } from "./IFlareGovernance.sol";

/**
 * @title IFlareTeeManagerDiamondCutFacet
 * @notice Public interface for the FlareTeeManagerDiamondCutFacet.
 * @dev Exposes the Flare governance API (governance, productionMode, etc.).
 *      The governance-only diamondCut method is in the internal interface.
 */
interface IFlareTeeManagerDiamondCutFacet is
    IFlareGovernance
{}
