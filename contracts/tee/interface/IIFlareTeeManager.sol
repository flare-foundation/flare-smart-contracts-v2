// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IDiamondLoupe } from "../../diamond/interfaces/IDiamondLoupe.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IIDiamondGovernanceFacet } from "./IIDiamondGovernanceFacet.sol";
import { IIExtensionManagerFacet } from "./IIExtensionManagerFacet.sol";
import { IIInstructionsFacet } from "./IIInstructionsFacet.sol";
import { IIVerificationFacet } from "./IIVerificationFacet.sol";
import { IIOperationFeesFacet } from "./IIOperationFeesFacet.sol";
import { IMachineManagerFacet } from "../../userInterfaces/tee/IMachineManagerFacet.sol";
import { IWalletKeyManagerFacet } from "../../userInterfaces/tee/IWalletKeyManagerFacet.sol";
import { IOwnerAllowlistFacet } from "../../userInterfaces/tee/IOwnerAllowlistFacet.sol";
import { ISystemStateVerifierFacet } from "../../userInterfaces/tee/ISystemStateVerifierFacet.sol";
import { IWalletManagerFacet } from "../../userInterfaces/tee/IWalletManagerFacet.sol";
import { IWalletProjectManagerFacet } from "../../userInterfaces/tee/IWalletProjectManagerFacet.sol";
import { IWalletBackupManagerFacet } from "../../userInterfaces/tee/IWalletBackupManagerFacet.sol";
import { IVrfFacet } from "../../userInterfaces/tee/IVrfFacet.sol";
import { IIReplicationFacet } from "./IIReplicationFacet.sol";
import { IExtensionGovernanceFacet } from "../../userInterfaces/tee/IExtensionGovernanceFacet.sol";
import { IUpgradeManagerFacet } from "../../userInterfaces/tee/IUpgradeManagerFacet.sol";
import { IIExternalAddressesFacet } from "./IIExternalAddressesFacet.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";

/**
 * @title IIFlareTeeManager
 * @notice Aggregate internal interface for the FlareTeeManager Diamond.
 * @dev Extends the public aggregate with governance-only methods from II* interfaces.
 *      Includes IDiamondCut, IDiamondLoupe, and IERC165 so that the deployment
 *      selector-extraction script only needs this single interface as a filter.
 */
interface IIFlareTeeManager is
    IDiamondLoupe,
    IERC165,
    ITeeCommonErrors,
    IIDiamondGovernanceFacet,
    IIExtensionManagerFacet,
    IIInstructionsFacet,
    IMachineManagerFacet,
    IIVerificationFacet,
    IIOperationFeesFacet,
    IOwnerAllowlistFacet,
    IWalletKeyManagerFacet,
    ISystemStateVerifierFacet,
    IWalletManagerFacet,
    IWalletProjectManagerFacet,
    IWalletBackupManagerFacet,
    IVrfFacet,
    IIReplicationFacet,
    IExtensionGovernanceFacet,
    IUpgradeManagerFacet,
    IIExternalAddressesFacet
{
}
