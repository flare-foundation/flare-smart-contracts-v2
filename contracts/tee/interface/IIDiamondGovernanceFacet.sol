// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IDiamondCut } from "../../diamond/interfaces/IDiamondCut.sol";
import { IDiamondGovernanceFacet } from
    "../../userInterfaces/tee/IDiamondGovernanceFacet.sol";
import { IIFlareGovernance } from "./IIFlareGovernance.sol";

/**
 * @title IIDiamondGovernanceFacet
 * @notice Internal interface for the DiamondGovernanceFacet.
 * @dev Extends the public interface with governance-only methods:
 *      diamondCut, cancelGovernanceCall, and switchToProductionMode.
 */
interface IIDiamondGovernanceFacet is
    IDiamondGovernanceFacet,
    IDiamondCut,
    IIFlareGovernance
{}
