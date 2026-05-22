// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { PublicKey } from "../IPublicKey.sol";
import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";

/**
 * @title IWalletBackupManager
 * @notice Public interface for the WalletBackupManagerFacet.
 */
interface IWalletBackupManager is ITeeCommonErrors {

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

    /**
     * Payload sent to the SOURCE TEE machine on a `directBackup` call. The source TEE produces an
     * encrypted backup blob (encrypted to `destinationTeePublicKey` so only the destination TEE can
     * decrypt it). The relay client also forwards the machine-path list (looked up by
     * `(extensionId, machinePathListNonce)`) so the TEE can verify the source→destination pair is
     * governance-attested. `destinationNonce` is the exact value the destination will be at AFTER
     * a successful `directRestore` (current_destination_nonce + 1) — the source binds the backup
     * blob to that future nonce.
     *
     * The wallet key's keyType / signingAlgo / public key are NOT carried in the payload because
     * the tuple `(walletId, keyId)` uniquely identifies the on-chain key; the source TEE (and
     * relay client) can resolve them from chain state when needed.
     */
    struct KeyDirectBackup {
        address sourceTeeId;
        bytes32 walletId;
        uint64 keyId;
        PublicKey destinationTeePublicKey;
        uint256 destinationNonce;
        uint256 machinePathListNonce;
    }

    /**
     * Payload sent to the DESTINATION TEE machine on a `directRestore` call. The destination
     * fetches the previously-produced backup blob from the source proxy at
     * `(sourceProxyUrl, backupInstructionId)` and imports it as the key. `destinationNonce` is
     * the just-incremented (now mutated) nonce; it must equal the value the source committed to
     * during `directBackup` for the restore proof to match.
     */
    struct KeyDirectRestore {
        address sourceTeeId;
        string sourceProxyUrl;
        BackupId backupId;
        bytes32 backupInstructionId;
        uint256 destinationNonce;
        uint256 machinePathListNonce;
    }

    event BackupRestoreTriggered(
        address indexed teeId,
        bytes32 indexed walletId,
        uint64 indexed keyId,
        uint256 nonce
    );

    event DirectBackupTriggered(
        address indexed sourceTeeId,
        address indexed destinationTeeId,
        bytes32 indexed walletId,
        uint64 keyId,
        uint256 destinationNonce,
        bytes32 backupInstructionId
    );

    event DirectRestoreTriggered(
        address indexed destinationTeeId,
        bytes32 indexed walletId,
        uint64 indexed keyId,
        uint256 destinationNonce,
        bytes32 backupInstructionId
    );

    error InvalidTeeMachine();
    error KeyAlreadyAvailable();
    error KeyNotConfirmed();
    error UnsupportedRewardEpochId();
    error InvalidRewardEpochId();
    error SourceTeeDoesNotHoldKey();

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

    /**
     * Triggers backup creation on the SOURCE TEE machine. The source TEE produces an encrypted
     * backup blob and exposes it on its proxy under the returned instruction id. The
     * `(sourceTeeId, destinationTeeId)` pair must be present in the extension's currently-active
     * signed machine-path list.
     *
     * Does NOT mutate any on-chain nonce. The destination's current key nonce is read and `+1` is
     * shipped to the source so its backup blob binds to the value the destination will be at after
     * a successful `directRestore`.
     *
     * Reverts:
     * - `OnlyOwnerOrBackupManager` if the caller is not the project owner / backup manager.
     * - `OnlyProductionStatus`-ish: source TEE not in PRODUCTION (`TeeMachineNotInProduction`).
     * - `InvalidTeeMachine` if destination TEE is in INITIALIZED status.
     * - `ExtensionIdMismatch` if source or destination TEE does not belong to the wallet's extension.
     * - `NoActiveMachinePathList` if the extension has no signed list yet.
     * - `InvalidMachinePath` if `(sourceTeeId, destinationTeeId)` is not present in the active list.
     * - `KeyNotConfirmed` if the wallet has no confirmed public key for the given (walletId, keyId).
     * - `SourceTeeDoesNotHoldKey` if the source TEE is not currently registered as holding the key.
     *
     * Emits DirectBackupTriggered.
     * @param _sourceTeeId The TEE machine that currently holds the key.
     * @param _destinationTeeId The TEE machine the key will be restored to via a later directRestore.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     * @param _claimBackAddress An address that can claim back the fee if the instruction is not executed (optional).
     * @return _instructionId The id of the dispatched backup instruction. Off-chain code passes this
     *         to a later `directRestore` so the destination knows which response to fetch from the source.
     */
    function directBackup(
        address _sourceTeeId,
        address _destinationTeeId,
        bytes32 _walletId,
        uint64 _keyId,
        address _claimBackAddress
    )
        external payable
        returns (bytes32 _instructionId);

    /**
     * Triggers restore on the DESTINATION TEE machine using a backup blob produced by an earlier
     * `directBackup` call. The destination fetches the blob from the source TEE's proxy URL
     * (looked up on-chain) at the `_backupInstructionId` reference.
     *
     * Increments the destination's per-key nonce by exactly 1; the new nonce must equal the value
     * the source committed to during `directBackup`.
     *
     * Reverts:
     * - `OnlyOwnerOrBackupManager`, `TeeMachineNotInProduction` (destination), `InvalidTeeMachine`
     *   (source), `KeyAlreadyAvailable`, `KeyNotConfirmed`, `InvalidPublicKey`,
     *   `UnsupportedRewardEpochId`, `InvalidRewardEpochId`, `InvalidKeyType`, `InvalidSigningAlgo`,
     *   `ExtensionIdMismatch` — same gates as the legacy `backupRestore` flow.
     * - `NoActiveMachinePathList`, `InvalidMachinePath` — path-list gating.
     *
     * Emits DirectRestoreTriggered.
     * @param _destinationTeeId The TEE machine on which the key will be restored.
     * @param _backupId The backup id of the blob produced by the prior `directBackup`.
     * @param _backupInstructionId The instruction id returned by the prior `directBackup`. The destination
     *        TEE uses it together with the source's proxy URL to fetch the encrypted blob.
     * @param _claimBackAddress An address that can claim back the fee if the instruction is not executed (optional).
     * @return _instructionId The id of the dispatched restore instruction.
     */
    function directRestore(
        address _destinationTeeId,
        BackupId calldata _backupId,
        bytes32 _backupInstructionId,
        address _claimBackAddress
    )
        external payable
        returns (bytes32 _instructionId);
}
