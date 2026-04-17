// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { PublicKey } from "../IPublicKey.sol";
import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";

/**
 * @title IWalletBackupManagerFacet
 * @notice Public interface for the WalletBackupManagerFacet.
 */
interface IWalletBackupManagerFacet is ITeeCommonErrors {

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

    event BackupRestoreTriggered(
        address indexed teeId,
        bytes32 indexed walletId,
        uint64 indexed keyId,
        uint256 nonce
    );

    error InvalidTeeMachine();
    error KeyAlreadyAvailable();
    error KeyNotConfirmed();
    error UnsupportedRewardEpochId();
    error InvalidRewardEpochId();

    /**
     * Triggers a wallet key restore by data providers and wallet admins from given backup id.
     * Emits BackupRestoreTriggered event.
     * @param _teeId The tee id on which the wallet key will be restored.
     * @param _backupId The backup id (tee id, wallet id, key id, operation type, public key and reward epoch id).
     * @param _backupUrl The URL of a backup package.
     * @param _claimBackAddress An address that can claim back the fee if the instructions are not executed (optional).
     */
    function backupRestore(
        address _teeId,
        BackupId calldata _backupId,
        string calldata _backupUrl,
        address _claimBackAddress
    )
        external payable;
}
