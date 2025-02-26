// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeeWalletManager.sol";


interface TeeWalletManagerStructs {

    function keyGenerateStruct(ITeeWalletManager.KeyGenerate calldata) external;

    function keyDeleteStruct(ITeeWalletManager.KeyDelete calldata) external;

    function keyMachineBackupStruct(ITeeWalletManager.KeyMachineBackup calldata) external;

    function keyMachineRestoreStruct(ITeeWalletManager.KeyMachineRestore calldata) external;

    function keyMachineBackupRemoveStruct(ITeeWalletManager.KeyMachineBackupRemove calldata) external;

    function keyCustodianBackupStruct(ITeeWalletManager.KeyCustodianBackup calldata) external;

    function keyCustodianRestoreStruct(ITeeWalletManager.KeyCustodianRestore calldata) external;
}
