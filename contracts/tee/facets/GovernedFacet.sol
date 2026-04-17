// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { FlareGovernance } from "../library/FlareGovernance.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * @title GovernedFacet
 * @notice Abstract base for Diamond facets that need governance access control.
 * @dev Provides `onlyGovernance` and `onlyImmediateGovernance` modifiers
 *      backed by the FlareGovernance library.
 *      Unlike GovernedBase, this contract exposes NO public/external functions,
 *      so inheriting facets do not pollute their ABI with duplicate governance selectors.
 *      Only one facet (DiamondGovernanceFacet) should expose the governance
 *      public API; all others inherit this abstract contract.
 *
 *      The constructor marks the implementation as initialised with dummy values
 *      to prevent direct use of the facet contract (anti-selfdestruct pattern,
 *      same as GovernedProxyImplementation).
 */
abstract contract GovernedFacet {
    address private constant EMPTY_ADDRESS = 0x0000000000000000000000000000000000001111;

    constructor() {
        FlareGovernance.initialise(IGovernanceSettings(EMPTY_ADDRESS), EMPTY_ADDRESS);
    }

    modifier onlyGovernance() {
        if (FlareGovernance.beforeOnlyGovernance()) {
            _;
        }
    }

    modifier onlyImmediateGovernance() {
        FlareGovernance.checkOnlyGovernance();
        _;
    }
}
