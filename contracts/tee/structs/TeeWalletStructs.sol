// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeeWalletKeyManager.sol";
import "../../userInterfaces/tee/ITeeWalletBackupManager.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";


interface TeeWalletStructs {

    function keyGenerateStruct(ITeeWalletKeyManager.KeyGenerate calldata) external;

    function keyDeleteStruct(ITeeWalletKeyManager.KeyDelete calldata) external;

    function keyConfigConstantsStruct(ITeeWalletKeyManager.KeyConfigConstants calldata) external;

    function keyConfigSettingsStruct(ITeeWalletKeyManager.KeyConfigSettings calldata) external;

    function keyExistenceStruct(ITeeWalletKeyManager.KeyExistence calldata) external;

    function keyDataProviderRestoreStruct(ITeeWalletBackupManager.KeyDataProviderRestore calldata) external;

    function backupIdStruct(ITeeWalletBackupManager.BackupId calldata) external;

    function setPausingAddressesStruct(ITeeWalletManager.SetPausingAddresses calldata) external;

    function resumeStruct(ITeeWalletManager.Resume calldata) external;
}
