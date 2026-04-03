// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

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
import { IFlareGovernance } from "../../userInterfaces/tee/IFlareGovernance.sol";
import {
    IIAddressUpdatable
} from "@flarenetwork/flare-periphery-contracts/flare/addressUpdater/interfaces/IIAddressUpdatable.sol";

/**
 * @title IIFlareTeeManager
 * @notice Aggregate internal interface for the FlareTeeManager Diamond.
 * @dev Extends the public aggregate with governance-only methods from II* interfaces.
 */
interface IIFlareTeeManager is
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
    IFlareGovernance,
    IIAddressUpdatable
{
}
