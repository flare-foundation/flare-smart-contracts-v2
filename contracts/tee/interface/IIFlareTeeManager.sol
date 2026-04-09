// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IDiamondCut } from "../../diamond/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "../../diamond/interfaces/IDiamondLoupe.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IITeeExtensionRegistryFacet } from "./IITeeExtensionRegistryFacet.sol";
import { IITeeVerificationFacet } from "./IITeeVerificationFacet.sol";
import { IITeeFeeCalculatorFacet } from "./IITeeFeeCalculatorFacet.sol";
import { ITeeMachineRegistryFacet } from "../../userInterfaces/tee/ITeeMachineRegistryFacet.sol";
import { ITeeWalletKeyManagerFacet } from "../../userInterfaces/tee/ITeeWalletKeyManagerFacet.sol";
import { ITeeOwnerAllowlistFacet } from "../../userInterfaces/tee/ITeeOwnerAllowlistFacet.sol";
import { ITeeWalletVerificationFacet } from "../../userInterfaces/tee/ITeeWalletVerificationFacet.sol";
import { ITeeSystemStateVerifierFacet } from "../../userInterfaces/tee/ITeeSystemStateVerifierFacet.sol";
import { ITeeWalletManagerFacet } from "../../userInterfaces/tee/ITeeWalletManagerFacet.sol";
import { ITeeWalletProjectManagerFacet } from "../../userInterfaces/tee/ITeeWalletProjectManagerFacet.sol";
import { ITeeWalletBackupManagerFacet } from "../../userInterfaces/tee/ITeeWalletBackupManagerFacet.sol";
import { ITeeVrfFacet } from "../../userInterfaces/tee/ITeeVrfFacet.sol";
import { IITeeReplicationFacet } from "./IITeeReplicationFacet.sol";
import { ITeeGovernanceFacet } from "../../userInterfaces/tee/ITeeGovernanceFacet.sol";
import { ITeeVersionManagerFacet } from "../../userInterfaces/tee/ITeeVersionManagerFacet.sol";
import { IIFlareGovernance } from "./IIFlareGovernance.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import {
    IIAddressUpdatable
} from "@flarenetwork/flare-periphery-contracts/flare/addressUpdater/interfaces/IIAddressUpdatable.sol";

/**
 * @title IIFlareTeeManager
 * @notice Aggregate internal interface for the FlareTeeManager Diamond.
 * @dev Extends the public aggregate with governance-only methods from II* interfaces.
 *      Includes IDiamondCut, IDiamondLoupe, and IERC165 so that the deployment
 *      selector-extraction script only needs this single interface as a filter.
 */
interface IIFlareTeeManager is
    IDiamondCut,
    IDiamondLoupe,
    IERC165,
    ITeeCommonErrors,
    IITeeExtensionRegistryFacet,
    ITeeMachineRegistryFacet,
    IITeeVerificationFacet,
    IITeeFeeCalculatorFacet,
    ITeeOwnerAllowlistFacet,
    ITeeWalletKeyManagerFacet,
    ITeeWalletVerificationFacet,
    ITeeSystemStateVerifierFacet,
    ITeeWalletManagerFacet,
    ITeeWalletProjectManagerFacet,
    ITeeWalletBackupManagerFacet,
    ITeeVrfFacet,
    IITeeReplicationFacet,
    ITeeGovernanceFacet,
    ITeeVersionManagerFacet,
    IIFlareGovernance,
    IIAddressUpdatable
{
}
