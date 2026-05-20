// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { FlareGovernance } from "../lib/FlareGovernance.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

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
 *      The constructor marks the implementation as initialised with dummy values
 *      to prevent direct use of the implementation/facet contract (anti-selfdestruct
 *      pattern, same as `GovernedProxyImplementation`).
 */
abstract contract FlareGovernedAccess {
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
