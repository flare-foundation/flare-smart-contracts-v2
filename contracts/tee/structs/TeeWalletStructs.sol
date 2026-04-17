// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IWalletKeyManagerFacet } from "../../userInterfaces/tee/IWalletKeyManagerFacet.sol";
import { IWalletBackupManagerFacet } from "../../userInterfaces/tee/IWalletBackupManagerFacet.sol";
import { IWalletManagerFacet } from "../../userInterfaces/tee/IWalletManagerFacet.sol";


interface TeeWalletStructs {

    function keyGenerateStruct(IWalletKeyManagerFacet.KeyGenerate calldata) external;

    function keyDeleteStruct(IWalletKeyManagerFacet.KeyDelete calldata) external;

    function keyConfigConstantsStruct(IWalletKeyManagerFacet.KeyConfigConstants calldata) external;

    function keyExistenceStruct(IWalletKeyManagerFacet.KeyExistence calldata) external;

    function keyDataProviderRestoreStruct(IWalletBackupManagerFacet.KeyDataProviderRestore calldata) external;

    function backupIdStruct(IWalletBackupManagerFacet.BackupId calldata) external;

    function setPausingAddressesStruct(IWalletManagerFacet.SetPausingAddresses calldata) external;

    function resumeStruct(IWalletManagerFacet.Resume calldata) external;
}
