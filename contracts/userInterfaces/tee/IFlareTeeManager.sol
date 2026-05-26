// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IDiamondLoupe } from "../../diamond/interfaces/IDiamondLoupe.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IExtensionManager } from "./IExtensionManager.sol";
import { IInstructions } from "./IInstructions.sol";
import { IMachineEmergencyPause } from "./IMachineEmergencyPause.sol";
import { IMachineManager } from "./IMachineManager.sol";
import { IVerification } from "./IVerification.sol";
import { IOperationFees } from "./IOperationFees.sol";
import { IOwnerAllowlist } from "./IOwnerAllowlist.sol";
import { ISystemStateVerifier } from "./ISystemStateVerifier.sol";
import { IWalletManager } from "./IWalletManager.sol";
import { IWalletResume } from "./IWalletResume.sol";
import { IWalletKeyManager } from "./IWalletKeyManager.sol";
import { IWalletProjectManager } from "./IWalletProjectManager.sol";
import { IWalletProjectPause } from "./IWalletProjectPause.sol";
import { IWalletBackupManager } from "./IWalletBackupManager.sol";
import { IVrf } from "./IVrf.sol";
import { IReplication } from "./IReplication.sol";
import { IExtensionGovernance } from "./IExtensionGovernance.sol";
import { IExtensionPausing } from "./IExtensionPausing.sol";
import { IExternalAddresses } from "./IExternalAddresses.sol";
import { IUpgradeManager } from "./IUpgradeManager.sol";
import { IMachinePathManager } from "./IMachinePathManager.sol";
import { IDiamondGovernance } from "./IDiamondGovernance.sol";
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
    IExtensionManager,
    IInstructions,
    IMachineEmergencyPause,
    IMachineManager,
    IVerification,
    IOperationFees,
    IOwnerAllowlist,
    ISystemStateVerifier,
    IWalletManager,
    IWalletResume,
    IWalletKeyManager,
    IWalletProjectManager,
    IWalletProjectPause,
    IWalletBackupManager,
    IVrf,
    IReplication,
    IExtensionGovernance,
    IExtensionPausing,
    IExternalAddresses,
    IUpgradeManager,
    IMachinePathManager,
    IDiamondGovernance
{
}
