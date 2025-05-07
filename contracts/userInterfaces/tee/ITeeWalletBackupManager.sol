// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";

/**
 * TeeWalletBackupManager interface.
 */
interface ITeeWalletBackupManager {

    struct KeyDataProviderRestore {
        address teeId;
        BackupId backupId;
        string backupUrl;
        uint256 nonce;
    }

    struct BackupId {
        address teeId;
        bytes32 walletId;
        uint64 keyId;
        bytes32 opType;
        bytes publicKey;
        uint24 rewardEpochId;
    }

    /**
     * Triggers a wallet key restore by data providers and wallet admins from given backup id.
     * @param _teeId The tee id on which the wallet key will be restored.
     * @param _backupId The backup id (tee id, wallet id, key id, operation type, public key and reward epoch id).
     * @param _backupUrl The URL of a backup package.
     */
    function backupRestore(
        address _teeId,
        BackupId calldata _backupId,
        string calldata _backupUrl
    )
        external payable;
}
