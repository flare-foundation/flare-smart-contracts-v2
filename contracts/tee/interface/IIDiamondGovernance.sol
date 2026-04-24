// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IDiamondCut } from "../../diamond/interfaces/IDiamondCut.sol";
import { IDiamondGovernance } from
    "../../userInterfaces/tee/IDiamondGovernance.sol";
import { IIFlareGovernance } from "./IIFlareGovernance.sol";

/**
 * @title IIDiamondGovernance
 * @notice Internal interface for the DiamondGovernanceFacet.
 * @dev Extends the public interface with governance-only methods:
 *      diamondCut, cancelGovernanceCall, and switchToProductionMode.
 */
interface IIDiamondGovernance is
    IDiamondGovernance,
    IDiamondCut,
    IIFlareGovernance
{}
