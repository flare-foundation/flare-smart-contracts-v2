// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";

/**
 * TeeWalletBackupManager interface.
 */
interface ITeeWalletBackupManager {

    struct KeyMachineBackup {
        ITeeRegistry.TeeMachineWithAttestationData teeMachine;
        bytes32 walletId;
        uint256 keyId;
        uint256 backupId;
        uint256 shamirThreshold;
        ITeeRegistry.TeeMachineWithAttestationData[] backupTeeMachines;
    }

    struct KeyMachineRestore {
        ITeeRegistry.TeeMachineWithAttestationData teeMachine;
        bytes32 walletId;
        uint256 keyId;
        uint256 backupId;
        bytes32 opType;
        bytes publicKey;
        ITeeRegistry.TeeMachineWithAttestationData[] backupTeeMachines;
    }

    struct KeyMachineBackupRemove {
        address[] teeIds;
        bytes32 walletId;
        uint256 keyId;
        uint256 backupId;
    }

    struct KeyDataProviderRestore {
        address teeId;
        bytes32 walletId;
        uint256 keyId;
        bytes32 opType;
        bytes publicKey;
        uint24 rewardEpochId;
    }

    /**
     * Creates a wallet key machine backup.
     * @param _teeId The tee id.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     * @param _shamirThreshold The Shamir threshold.
     * @param _backupTeeIds The backup tee ids.
     */
    function machineBackup(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId,
        uint256 _shamirThreshold,
        address[] calldata _backupTeeIds
    )
        external payable;

    /**
     * Restores a wallet key from machine backup.
     * @param _teeId The tee id.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     * @param _backupId The backup id.
     * @param _backupTeeIds The backup tee ids.
     */
    function machineRestore(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId,
        uint256 _backupId,
        address[] calldata _backupTeeIds
    )
        external payable;

    /**
     * Removes a wallet key machine backup.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     * @param _backupId The backup id.
     * @param _teeIds The tee ids.
     */
    function machineBackupRemove(
        bytes32 _walletId,
        uint64 _keyId,
        uint256 _backupId,
        address[] calldata _teeIds
    )
        external payable;

    /**
     * Initiates a wallet key restore from data providers backup created at given reward epoch.
     * Initiator has to upload shamir shares to the tee machine before proceeding with the restore.
     * @param _teeId The tee id.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     * @param _rewardEpochId The reward epoch id.
     */
    function dataProviderRestoreInit(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId,
        uint24 _rewardEpochId
    )
        external payable;

    /**
     * Triggers a wallet key restore (decryption) from data providers backup created at given reward epoch.
     * All shamir shares have to be uploaded to the tee machine before calling this function.
     * The process is initiated by calling `dataProvidersRestoreInit` first.
     * @param _teeId The tee id.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     * @param _rewardEpochId The reward epoch id.
     */
    function dataProviderRestore(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId,
        uint24 _rewardEpochId
    )
        external payable;
}
