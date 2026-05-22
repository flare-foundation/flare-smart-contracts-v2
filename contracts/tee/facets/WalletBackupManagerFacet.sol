// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IWalletBackupManager } from "../../userInterfaces/tee/IWalletBackupManager.sol";
import { IInstructions } from "../../userInterfaces/tee/IInstructions.sol";
import { IMachineManager } from "../../userInterfaces/tee/IMachineManager.sol";
import { WALLET_OP_TYPE } from "../../userInterfaces/tee/IWalletManager.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { MachinePathManager } from "../library/MachinePathManager.sol";
import { WalletKeyManager } from "../library/WalletKeyManager.sol";
import { WalletManager } from "../library/WalletManager.sol";
import { WalletProjectManager } from "../library/WalletProjectManager.sol";
import { MachineManager } from "../library/MachineManager.sol";
import { ExternalAddresses } from "../library/ExternalAddresses.sol";
import { Instructions } from "../library/Instructions.sol";

/**
 * @title WalletBackupManagerFacet
 * @notice Facet for TEE wallet key backup and restore.
 */
contract WalletBackupManagerFacet is IWalletBackupManager {

    bytes32 internal constant KEY_DATA_PROVIDER_RESTORE = bytes32("KEY_DATA_PROVIDER_RESTORE");
    bytes32 internal constant KEY_DIRECT_BACKUP = bytes32("KEY_DIRECT_BACKUP");
    bytes32 internal constant KEY_DIRECT_RESTORE = bytes32("KEY_DIRECT_RESTORE");

    /**
     * @inheritdoc IWalletBackupManager
     */
    function backupRestore(
        address _teeId,
        BackupId calldata _backupId,
        string calldata _backupUrl,
        address _claimBackAddress
    )
        external payable
    {
        _validateRestoreInputs(_teeId, _backupId);

        KeyDataProviderRestore memory message = KeyDataProviderRestore({
            teePublicKey: MachineManager.getPublicKey(_teeId),
            backupId: _backupId,
            backupUrl: _backupUrl,
            nonce: WalletKeyManager.increaseKeyNonce(_teeId, _backupId.walletId, _backupId.keyId)
        });
        (address[] memory admins, uint64 adminsThreshold) =
            WalletManager.getWalletAdminsAndThreshold(_backupId.walletId);

        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        Instructions.sendInstructions(
            bytes32(0),
            teeIds,
            IInstructions.TeeInstructionParams(
                WALLET_OP_TYPE,
                KEY_DATA_PROVIDER_RESTORE,
                abi.encode(message),
                admins,
                adminsThreshold,
                _claimBackAddress
            )
        );
        emit BackupRestoreTriggered(_teeId, _backupId.walletId, _backupId.keyId, message.nonce);
    }

    /**
     * @inheritdoc IWalletBackupManager
     */
    function directBackup(
        address _sourceTeeId,
        address _destinationTeeId,
        bytes32 _walletId,
        uint64 _keyId,
        address _claimBackAddress
    )
        external payable
        returns (bytes32 _instructionId)
    {
        bytes32 projectId = WalletManager.getWalletProjectId(_walletId);
        WalletProjectManager.checkOnlyOwnerOrBackupManager(projectId);

        // Both ends must be live to produce + receive a fresh backup blob.
        MachineManager.checkTeeMachineInProduction(_sourceTeeId);
        MachineManager.checkTeeMachineInProduction(_destinationTeeId);

        uint256 extensionId = WalletProjectManager.getExtensionId(projectId);
        require(
            extensionId == MachineManager.getExtensionId(_sourceTeeId) &&
                extensionId == MachineManager.getExtensionId(_destinationTeeId),
            ExtensionIdMismatch()
        );

        uint256 listNonce = MachinePathManager.requireActiveListNonceForPath(
            extensionId, _sourceTeeId, _destinationTeeId
        );

        require(
            WalletKeyManager.getWalletKeyPublicKey(_walletId, _keyId).length > 0,
            KeyNotConfirmed()
        );
        require(WalletKeyManager.isKeyAvailable(_sourceTeeId, _walletId, _keyId), SourceTeeDoesNotHoldKey());
        // Fail fast if the destination already holds the key (e.g. a concurrent restore beat us
        // to it). Otherwise we'd produce a backup blob that can never be imported — the
        // eventual directRestore would revert KeyAlreadyAvailable anyway, after the source has
        // already done the off-chain work.
        require(
            !WalletKeyManager.isKeyAvailable(_destinationTeeId, _walletId, _keyId),
            KeyAlreadyAvailable()
        );

        KeyDirectBackup memory message = KeyDirectBackup({
            sourceTeeId: _sourceTeeId,
            walletId: _walletId,
            keyId: _keyId,
            destinationTeePublicKey: MachineManager.getPublicKey(_destinationTeeId),
            destinationNonce: WalletKeyManager.getKeyNonce(_destinationTeeId, _walletId, _keyId) + 1,
            machinePathListNonce: listNonce
        });

        // No additional co-signers: the governance-signed machine-path list is already the
        // authorization for moving the key from source to destination. Pass an empty cosigners
        // array with threshold 0 so the TEE node treats the instruction as self-authorizing.
        address[] memory teeIds = new address[](1);
        teeIds[0] = _sourceTeeId;
        _instructionId = Instructions.sendInstructions(
            bytes32(0),
            teeIds,
            IInstructions.TeeInstructionParams(
                WALLET_OP_TYPE,
                KEY_DIRECT_BACKUP,
                abi.encode(message),
                new address[](0),
                0,
                _claimBackAddress
            )
        );
        emit DirectBackupTriggered(
            _sourceTeeId, _destinationTeeId, _walletId, _keyId, message.destinationNonce, _instructionId
        );
    }

    /**
     * @inheritdoc IWalletBackupManager
     */
    function directRestore(
        address _destinationTeeId,
        BackupId calldata _backupId,
        bytes32 _backupInstructionId,
        address _claimBackAddress
    )
        external payable
        returns (bytes32 _instructionId)
    {
        uint256 extensionId = _validateRestoreInputs(_destinationTeeId, _backupId);
        uint256 listNonce = MachinePathManager.requireActiveListNonceForPath(
            extensionId, _backupId.teeId, _destinationTeeId
        );

        // Now mutate: bump the destination's nonce. The new value must equal the value the source
        // committed to during the prior `directBackup` (off-chain enforcement based on the
        // `DirectBackupTriggered` event the relay client observed).
        uint256 destinationNonce =
            WalletKeyManager.increaseKeyNonce(_destinationTeeId, _backupId.walletId, _backupId.keyId);

        KeyDirectRestore memory message = KeyDirectRestore({
            sourceTeeId: _backupId.teeId,
            sourceProxyUrl: MachineManager.getState().teeMachineStates[_backupId.teeId].url,
            backupId: _backupId,
            backupInstructionId: _backupInstructionId,
            destinationNonce: destinationNonce,
            machinePathListNonce: listNonce
        });

        // No additional co-signers: the governance-signed machine-path list is already the
        // authorization for moving the key from source to destination. Pass an empty cosigners
        // array with threshold 0 so the TEE node treats the instruction as self-authorizing.
        address[] memory teeIds = new address[](1);
        teeIds[0] = _destinationTeeId;
        _instructionId = Instructions.sendInstructions(
            bytes32(0),
            teeIds,
            IInstructions.TeeInstructionParams(
                WALLET_OP_TYPE,
                KEY_DIRECT_RESTORE,
                abi.encode(message),
                new address[](0),
                0,
                _claimBackAddress
            )
        );
        emit DirectRestoreTriggered(
            _destinationTeeId, _backupId.walletId, _backupId.keyId, destinationNonce, _backupInstructionId
        );
    }

    // =========================================================================
    // Private helpers
    // =========================================================================

    /**
     * Performs every common restore-side validation step shared by `backupRestore` and
     * `directRestore`: auth, destination-production, source-not-initialized, key-not-already-held,
     * publicKey match, reward-epoch validity, keyType / signingAlgo match, extension match across
     * source / destination / wallet's project. Returns the wallet's extension id so callers that
     * need it next (e.g. for a machine-path lookup) don't have to re-derive it.
     */
    function _validateRestoreInputs(
        address _destinationTeeId,
        BackupId calldata _backupId
    )
        private view
        returns (uint256 _extensionId)
    {
        bytes32 projectId = WalletManager.getWalletProjectId(_backupId.walletId);
        WalletProjectManager.checkOnlyOwnerOrBackupManager(projectId);

        MachineManager.checkTeeMachineInProduction(_destinationTeeId);
        require(
            MachineManager.getTeeMachineStatus(_backupId.teeId) != IMachineManager.TeeStatus.INITIALIZED,
            InvalidTeeMachine()
        );
        require(
            !WalletKeyManager.isKeyAvailable(_destinationTeeId, _backupId.walletId, _backupId.keyId),
            KeyAlreadyAvailable()
        );
        bytes memory publicKey = WalletKeyManager.getWalletKeyPublicKey(_backupId.walletId, _backupId.keyId);
        require(publicKey.length > 0, KeyNotConfirmed());
        require(keccak256(publicKey) == keccak256(_backupId.publicKey), InvalidPublicKey());
        require(
            MachineManager.getInitialSigningPolicyId(_destinationTeeId) <= _backupId.rewardEpochId,
            UnsupportedRewardEpochId()
        );

        ExternalAddresses.State storage ext = ExternalAddresses.getState();
        require(
            _backupId.rewardEpochId <= IFlareSystemsManager(ext.flareSystemsManager).getCurrentRewardEpochId() + 1,
            InvalidRewardEpochId()
        );

        require(
            WalletProjectManager.getKeyType(projectId) == _backupId.keyType,
            InvalidKeyType()
        );
        require(
            WalletProjectManager.getSigningAlgo(projectId) == _backupId.signingAlgo,
            InvalidSigningAlgo()
        );
        _extensionId = WalletProjectManager.getExtensionId(projectId);
        require(
            _extensionId == MachineManager.getExtensionId(_backupId.teeId) &&
                _extensionId == MachineManager.getExtensionId(_destinationTeeId),
            ExtensionIdMismatch()
        );
    }

}
