// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeMachineRegistry.sol";

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
        uint256 randomNonce;
    }

    error TeeMachineNotAvailable();
    error InvalidTeeMachine();
    error KeyAlreadyAvailable();
    error KeyNotConfirmed();
    error InvalidPublicKey();
    error UnsupportedRewardEpochId();
    error InvalidRewardEpochId();
    error InvalidOpType();
    error ExtensionIdMismatch();
    error OnlyOwnerOrBackupManager();

    /**
     * Triggers a wallet key restore by data providers and wallet admins from given backup id.
     * @param _teeId The tee id on which the wallet key will be restored.
     * @param _backupId The backup id (tee id, wallet id, key id, operation type, public key and reward epoch id).
     * @param _backupUrl The URL of a backup package.
     * @param _test If true, the restore will be done using nonce = 0 to prevent confirmation on-chain.
     * Once the key is restored and proof of possession is generated, the key will be immediately deleted.
     */
    function backupRestore(
        address _teeId,
        BackupId calldata _backupId,
        string calldata _backupUrl,
        bool _test
    )
        external payable;
}
