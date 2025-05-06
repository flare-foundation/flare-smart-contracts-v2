// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";

/**
 * TeeWalletBackupManager interface.
 */
interface ITeeWalletBackupManager {

    struct KeyDataProviderRestore {
        address teeId;
        bytes32 walletId;
        uint64 keyId;
        uint256 nonce;
        bytes32 opType;
        bytes publicKey;
        uint24 rewardEpochId;
        string backupUrl;
    }

    /**
     * Triggers a wallet key restore (decryption) from data providers backup created at given reward epoch.
     * All shamir shares have to be uploaded to the tee machine before calling this function.
     * The process is initiated by calling `backupRestoreInit` first.
     * @param _teeId The tee id.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     * @param _rewardEpochId The reward epoch id.
     * @param _backupUrl The backup url.
     */
    function backupRestore(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId,
        uint24 _rewardEpochId,
        string calldata _backupUrl
    )
        external payable;
}
