// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { FlareGovernance } from "../lib/FlareGovernance.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title FlareGovernedAccess
 * @notice Abstract base providing governance access-control modifiers backed by the
 *         `FlareGovernance` library (ERC-7201 namespaced storage).
 * @dev Exposes NO public/external functions, so inheriting contracts do not pollute
 *      their ABI with duplicate governance selectors. Used by:
 *        - Diamond facets that share the Diamond's governance state but must not
 *          re-export the public governance API (only `DiamondGovernanceFacet` does).
 *        - Indirectly by `FlareGovernedBase`, which adds the public governance API on top.
 *
 *      Inherits OpenZeppelin's `Initializable` and calls `_disableInitializers()` in
 *      the constructor — this is the implementation-side anti-selfdestruct, locking
 *      OZ's `_initialized` flag on the impl so the impl bytecode cannot be initialised
 *      directly. The proxy/diamond storage has its own `_initialized` slot (ERC-7201
 *      namespaced), which is what concrete `initializer`-modifier-guarded entry points
 *      check at runtime.
 *
 *      The `FlareGovernance` library keeps its own `bool initialised` guard as a
 *      defense-in-depth layer that also fires if an existing proxy is upgraded to new
 *      bytecode whose OZ slot is virgin but whose FlareGovernance state is already set.
 */
abstract contract FlareGovernedAccess is Initializable {

    constructor() {
        _disableInitializers();
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
