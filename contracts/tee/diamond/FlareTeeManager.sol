// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { Diamond } from "../../diamond/implementation/Diamond.sol";
import { IDiamondCut } from "../../diamond/interfaces/IDiamondCut.sol";
import { LibDiamond } from "../../diamond/libraries/LibDiamond.sol";

/**
 * @title FlareTeeManager
 * @notice Diamond proxy (EIP-2535) that consolidates TEE subsystem contracts
 *         into a single upgradeable diamond.
 * @dev Constructor performs the initial diamond cut and optional init delegatecall.
 *      Governance is set up via the init contract (FlareTeeManagerInit), not via an
 *      ERC-173 OwnershipFacet — the FlareGovernance stack (FlareGovernance library +
 *      FlareGovernedAccess / FlareGovernedBase) is used instead.
 */
contract FlareTeeManager is Diamond {

    struct DiamondArgs {
        address init;
        bytes initCalldata;
    }

    constructor(
        IDiamondCut.FacetCut[] memory _diamondCut,
        DiamondArgs memory _args
    ) {
        LibDiamond.diamondCut(_diamondCut, _args.init, _args.initCalldata);
    }
}
