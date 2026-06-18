// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IDiamondLoupe } from "../../diamond/interfaces/IDiamondLoupe.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IIDiamondGovernance } from "./IIDiamondGovernance.sol";
import { IIExtensionManager } from "./IIExtensionManager.sol";
import { IIInstructions } from "./IIInstructions.sol";
import { IIVerification } from "./IIVerification.sol";
import { IIOperationFees } from "./IIOperationFees.sol";
import { IIMachineEmergencyPause } from "./IIMachineEmergencyPause.sol";
import { IMachineManager } from "../../userInterfaces/tee/IMachineManager.sol";
import { IWalletKeyManager } from "../../userInterfaces/tee/IWalletKeyManager.sol";
import { IOwnerAllowlist } from "../../userInterfaces/tee/IOwnerAllowlist.sol";
import { IWalletManager } from "../../userInterfaces/tee/IWalletManager.sol";
import { IWalletProjectManager } from "../../userInterfaces/tee/IWalletProjectManager.sol";
import { IWalletProjectPause } from "../../userInterfaces/tee/IWalletProjectPause.sol";
import { IWalletBackupManager } from "../../userInterfaces/tee/IWalletBackupManager.sol";
import { IVrf } from "../../userInterfaces/tee/IVrf.sol";
import { IExtensionGovernance } from "../../userInterfaces/tee/IExtensionGovernance.sol";
import { IMachinePathManager } from "../../userInterfaces/tee/IMachinePathManager.sol";
import { IIExternalAddresses } from "./IIExternalAddresses.sol";
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
    IIDiamondGovernance,
    IIExtensionManager,
    IIInstructions,
    IIMachineEmergencyPause,
    IMachineManager,
    IIVerification,
    IIOperationFees,
    IOwnerAllowlist,
    IWalletKeyManager,
    IWalletManager,
    IWalletProjectManager,
    IWalletProjectPause,
    IWalletBackupManager,
    IVrf,
    IExtensionGovernance,
    IMachinePathManager,
    IIExternalAddresses
{
}
