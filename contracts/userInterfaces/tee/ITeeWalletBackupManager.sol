// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { PublicKey } from "../IPublicKey.sol";

/**
 * TeeWalletBackupManager interface.
 */
interface ITeeWalletBackupManager {

    struct KeyDataProviderRestore {
        PublicKey teePublicKey;
        BackupId backupId;
        string backupUrl;
        uint256 nonce;
    }

    struct BackupId {
        address teeId;
        bytes32 walletId;
        uint64 keyId;
        bytes32 keyType;
        bytes32 signingAlgo;
        bytes publicKey;
        uint32 rewardEpochId;
        bytes32 randomNonce;
    }

    error TeeMachineNotAvailable();
    error InvalidTeeMachine();
    error KeyAlreadyAvailable();
    error KeyNotConfirmed();
    error InvalidPublicKey();
    error UnsupportedRewardEpochId();
    error InvalidRewardEpochId();
    error InvalidKeyType();
    error InvalidSigningAlgo();
    error ExtensionIdMismatch();
    error OnlyOwnerOrBackupManager();

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
