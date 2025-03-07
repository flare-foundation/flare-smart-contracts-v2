// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";

/**
 * TeeWalletBackupManager interface.
 */
interface ITeeWalletBackupManager {

    /// Signature structure
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
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

}
