// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IDiamondLoupe } from "../../diamond/interfaces/IDiamondLoupe.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IExtensionManagerFacet } from "./IExtensionManagerFacet.sol";
import { IInstructionsFacet } from "./IInstructionsFacet.sol";
import { IMachineManagerFacet } from "./IMachineManagerFacet.sol";
import { IVerificationFacet } from "./IVerificationFacet.sol";
import { IOperationFeesFacet } from "./IOperationFeesFacet.sol";
import { IOwnerAllowlistFacet } from "./IOwnerAllowlistFacet.sol";
import { ISystemStateVerifierFacet } from "./ISystemStateVerifierFacet.sol";
import { IWalletManagerFacet } from "./IWalletManagerFacet.sol";
import { IWalletKeyManagerFacet } from "./IWalletKeyManagerFacet.sol";
import { IWalletProjectManagerFacet } from "./IWalletProjectManagerFacet.sol";
import { IWalletBackupManagerFacet } from "./IWalletBackupManagerFacet.sol";
import { IVrfFacet } from "./IVrfFacet.sol";
import { IReplicationFacet } from "./IReplicationFacet.sol";
import { IExtensionGovernanceFacet } from "./IExtensionGovernanceFacet.sol";
import { IExternalAddressesFacet } from "./IExternalAddressesFacet.sol";
import { IUpgradeManagerFacet } from "./IUpgradeManagerFacet.sol";
import { IDiamondGovernanceFacet } from "./IDiamondGovernanceFacet.sol";
import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";

/**
 * @title IFlareTeeManager
 * @notice Aggregate public interface for the FlareTeeManager Diamond.
 * @dev Inherits all public facet interfaces. Used by external contracts
 *      (Fdc2Hub, Fdc2Verification, TeePayments) to cast the FlareTeeManager address
 *      and call any facet function. No size/gas impact — interfaces are compile-time only.
 *      Includes IDiamondLoupe and IERC165 as public-facing diamond standard interfaces.
 */
interface IFlareTeeManager is
    IDiamondLoupe,
    IERC165,
    ITeeCommonErrors,
    IExtensionManagerFacet,
    IInstructionsFacet,
    IMachineManagerFacet,
    IVerificationFacet,
    IOperationFeesFacet,
    IOwnerAllowlistFacet,
    ISystemStateVerifierFacet,
    IWalletManagerFacet,
    IWalletKeyManagerFacet,
    IWalletProjectManagerFacet,
    IWalletBackupManagerFacet,
    IVrfFacet,
    IReplicationFacet,
    IExtensionGovernanceFacet,
    IExternalAddressesFacet,
    IUpgradeManagerFacet,
    IDiamondGovernanceFacet
{
}
