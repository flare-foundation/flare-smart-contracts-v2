// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeWalletKeyManagerFacet } from "../../userInterfaces/tee/ITeeWalletKeyManagerFacet.sol";
import { ITeeWalletBackupManagerFacet } from "../../userInterfaces/tee/ITeeWalletBackupManagerFacet.sol";
import { ITeeWalletManagerFacet } from "../../userInterfaces/tee/ITeeWalletManagerFacet.sol";


interface TeeWalletStructs {

    function keyGenerateStruct(ITeeWalletKeyManagerFacet.KeyGenerate calldata) external;

    function keyDeleteStruct(ITeeWalletKeyManagerFacet.KeyDelete calldata) external;

    function keyConfigConstantsStruct(ITeeWalletKeyManagerFacet.KeyConfigConstants calldata) external;

    function keyExistenceStruct(ITeeWalletKeyManagerFacet.KeyExistence calldata) external;

    function keyDataProviderRestoreStruct(ITeeWalletBackupManagerFacet.KeyDataProviderRestore calldata) external;

    function backupIdStruct(ITeeWalletBackupManagerFacet.BackupId calldata) external;

    function setPausingAddressesStruct(ITeeWalletManagerFacet.SetPausingAddresses calldata) external;

    function resumeStruct(ITeeWalletManagerFacet.Resume calldata) external;
}
