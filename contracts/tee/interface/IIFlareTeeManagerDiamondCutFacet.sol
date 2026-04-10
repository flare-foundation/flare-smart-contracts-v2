// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IDiamondCut } from "../../diamond/interfaces/IDiamondCut.sol";
import { IFlareTeeManagerDiamondCutFacet } from
    "../../userInterfaces/tee/IFlareTeeManagerDiamondCutFacet.sol";
import { IIFlareGovernance } from "./IIFlareGovernance.sol";

/**
 * @title IIFlareTeeManagerDiamondCutFacet
 * @notice Internal interface for the FlareTeeManagerDiamondCutFacet.
 * @dev Extends the public interface with governance-only methods:
 *      diamondCut, cancelGovernanceCall, and switchToProductionMode.
 */
interface IIFlareTeeManagerDiamondCutFacet is
    IFlareTeeManagerDiamondCutFacet,
    IDiamondCut,
    IIFlareGovernance
{}
