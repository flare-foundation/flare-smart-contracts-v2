// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";

/**
 * TeeWalletManager interface.
 */
interface ITeeWalletManager {

    enum WalletStatus {
        INITIALIZED,
        PRODUCTION,
        PAUSED
    }

    /// Signature structure
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct KeyGenerate {
        address teeId;
        bytes32 walletId;
        uint256 keyId;
        bytes32 opType;
    }

    struct KeyDelete {
        address teeId;
        bytes32 walletId;
        uint256 keyId;
    }

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

    struct KeyCustodianBackup {
        address teeId;
        bytes32 walletId;
        uint256 keyId;
        uint256 backupId;
        uint256 shamirThreshold;
        bytes[] custodianPublicKeys;
    }

    struct KeyCustodianRestore {
        address teeId;
        bytes32 walletId;
        uint256 keyId;
        uint256 backupId;
        bytes32 opType;
        bytes publicKey;
        bytes[] custodianPublicKeys;
    }

    event WalletCreated(
        bytes32 indexed walletId,
        address indexed owner,
        bytes32 opType
    );

    /**
     * Returns the wallet owner.
     * @param _walletId The wallet id.
     * @return _walletOwner The wallet owner.
     */
    function getWalletOwner(bytes32 _walletId) external view returns (address _walletOwner);

    /**
     * Returns information about the tee wallet.
     * @param _walletId The wallet id.
     * @param _submitAddress The submit address.
     * @param _status The wallet status.
     * @param _opType The wallet operation type.
     */
    function getWalletInfo(bytes32 _walletId) external view returns (
        address _submitAddress,
        WalletStatus _status,
        bytes32 _opType
    );

    /**
     * Returns wallet's receiving tees.
     * Reverts if not enough receiving tees are available or wallet is not in production status.
     * @param _walletId The wallet id.
     * @return _receivingTees The receiving tees.
     */
    function receivingTees(bytes32 _walletId) external view returns (ITeeRegistry.TeeMachine[] memory _receivingTees);
}