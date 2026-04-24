// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IWalletKeyManager } from "../../userInterfaces/tee/IWalletKeyManager.sol";
import { IWalletBackupManager } from "../../userInterfaces/tee/IWalletBackupManager.sol";
import { IWalletResume } from "../../userInterfaces/tee/IWalletResume.sol";


interface TeeWalletStructs {

    function keyGenerateStruct(IWalletKeyManager.KeyGenerate calldata) external;

    function keyDeleteStruct(IWalletKeyManager.KeyDelete calldata) external;

    function keyConfigConstantsStruct(IWalletKeyManager.KeyConfigConstants calldata) external;

    function keyExistenceStruct(IWalletKeyManager.KeyExistence calldata) external;

    function keyDataProviderRestoreStruct(IWalletBackupManager.KeyDataProviderRestore calldata) external;

    function backupIdStruct(IWalletBackupManager.BackupId calldata) external;

    function setPausingAddressesStruct(IWalletResume.SetPausingAddresses calldata) external;

    function resumeStruct(IWalletResume.Resume calldata) external;
}
