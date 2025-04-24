// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeeWalletKeyManager.sol";
import "../../userInterfaces/tee/ITeeWalletBackupManager.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";


interface TeeWalletManagerStructs {

    function keyGenerateStruct(ITeeWalletKeyManager.KeyGenerate calldata) external;

    function keyDeleteStruct(ITeeWalletKeyManager.KeyDelete calldata) external;

    function keyMachineBackupStruct(ITeeWalletBackupManager.KeyMachineBackup calldata) external;

    function keyMachineRestoreStruct(ITeeWalletBackupManager.KeyMachineRestore calldata) external;

    function keyMachineBackupRemoveStruct(ITeeWalletBackupManager.KeyMachineBackupRemove calldata) external;

    function keyDataProviderRestoreStruct(ITeeWalletBackupManager.KeyDataProviderRestore calldata) external;

    function setPausingAddressesStruct(ITeeWalletManager.SetPausingAddresses calldata) external;

    function resumeStruct(ITeeWalletManager.Resume calldata) external;
}
