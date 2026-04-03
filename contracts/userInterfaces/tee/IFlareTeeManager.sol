// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeExtensionRegistryFacet } from "./ITeeExtensionRegistryFacet.sol";
import { ITeeMachineRegistryFacet } from "./ITeeMachineRegistryFacet.sol";
import { ITeeVerificationFacet } from "./ITeeVerificationFacet.sol";
import { ITeeWalletVerificationFacet } from "./ITeeWalletVerificationFacet.sol";
import { ITeeFeeCalculatorFacet } from "./ITeeFeeCalculatorFacet.sol";
import { ITeeOwnerAllowlistFacet } from "./ITeeOwnerAllowlistFacet.sol";
import { ITeeSystemStateVerifierFacet } from "./ITeeSystemStateVerifierFacet.sol";
import { ITeeWalletManagerFacet } from "./ITeeWalletManagerFacet.sol";
import { ITeeWalletKeyManagerFacet } from "./ITeeWalletKeyManagerFacet.sol";
import { ITeeWalletProjectManagerFacet } from "./ITeeWalletProjectManagerFacet.sol";
import { ITeeWalletBackupManagerFacet } from "./ITeeWalletBackupManagerFacet.sol";
import { ITeeVrfFacet } from "./ITeeVrfFacet.sol";
import { ITeeReplicationFacet } from "./ITeeReplicationFacet.sol";
import { ITeeGovernanceFacet } from "./ITeeGovernanceFacet.sol";
import { ITeeVersionManagerFacet } from "./ITeeVersionManagerFacet.sol";

/**
 * @title IFlareTeeManager
 * @notice Aggregate public interface for the FlareTeeManager Diamond.
 * @dev Inherits all public facet interfaces. Used by external contracts
 *      (Fdc2Hub, Fdc2Verification, TeePayments) to cast the FlareTeeManager address
 *      and call any facet function. No size/gas impact — interfaces are compile-time only.
 */
interface IFlareTeeManager is
    ITeeExtensionRegistryFacet,
    ITeeMachineRegistryFacet,
    ITeeVerificationFacet,
    ITeeWalletVerificationFacet,
    ITeeFeeCalculatorFacet,
    ITeeOwnerAllowlistFacet,
    ITeeSystemStateVerifierFacet,
    ITeeWalletManagerFacet,
    ITeeWalletKeyManagerFacet,
    ITeeWalletProjectManagerFacet,
    ITeeWalletBackupManagerFacet,
    ITeeVrfFacet,
    ITeeReplicationFacet,
    ITeeGovernanceFacet,
    ITeeVersionManagerFacet
{
}
