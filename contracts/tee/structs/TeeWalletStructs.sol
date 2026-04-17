// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IWalletKeyManagerFacet } from "../../userInterfaces/tee/IWalletKeyManagerFacet.sol";
import { IWalletBackupManagerFacet } from "../../userInterfaces/tee/IWalletBackupManagerFacet.sol";
import { IWalletResumeFacet } from "../../userInterfaces/tee/IWalletResumeFacet.sol";


interface TeeWalletStructs {

    function keyGenerateStruct(IWalletKeyManagerFacet.KeyGenerate calldata) external;

    function keyDeleteStruct(IWalletKeyManagerFacet.KeyDelete calldata) external;

    function keyConfigConstantsStruct(IWalletKeyManagerFacet.KeyConfigConstants calldata) external;

    function keyExistenceStruct(IWalletKeyManagerFacet.KeyExistence calldata) external;

    function keyDataProviderRestoreStruct(IWalletBackupManagerFacet.KeyDataProviderRestore calldata) external;

    function backupIdStruct(IWalletBackupManagerFacet.BackupId calldata) external;

    function setPausingAddressesStruct(IWalletResumeFacet.SetPausingAddresses calldata) external;

    function resumeStruct(IWalletResumeFacet.Resume calldata) external;
}
