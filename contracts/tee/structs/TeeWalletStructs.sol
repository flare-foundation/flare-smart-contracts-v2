// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../../userInterfaces/tee/ITeeWalletBackupManager.sol";


interface TeeWalletManagerStructs {

    function keyGenerateStruct(ITeeWalletManager.KeyGenerate calldata) external;

    function keyDeleteStruct(ITeeWalletManager.KeyDelete calldata) external;

    function keyMachineBackupStruct(ITeeWalletBackupManager.KeyMachineBackup calldata) external;

    function keyMachineRestoreStruct(ITeeWalletBackupManager.KeyMachineRestore calldata) external;

    function keyMachineBackupRemoveStruct(ITeeWalletBackupManager.KeyMachineBackupRemove calldata) external;

    function keyCustodianBackupStruct(ITeeWalletBackupManager.KeyCustodianBackup calldata) external;

    function keyCustodianRestoreStruct(ITeeWalletBackupManager.KeyCustodianRestore calldata) external;
}
