// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeWalletBackupManagerFacet } from "../../userInterfaces/tee/ITeeWalletBackupManagerFacet.sol";
import { ITeeExtensionRegistryFacet } from "../../userInterfaces/tee/ITeeExtensionRegistryFacet.sol";
import { ITeeMachineRegistryFacet } from "../../userInterfaces/tee/ITeeMachineRegistryFacet.sol";
import { ITeeWalletManagerFacet, WALLET_OP_TYPE } from "../../userInterfaces/tee/ITeeWalletManagerFacet.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { TeeWalletKeyManager } from "../library/TeeWalletKeyManager.sol";
import { TeeWalletManager } from "../library/TeeWalletManager.sol";
import { TeeWalletProjectManager } from "../library/TeeWalletProjectManager.sol";
import { TeeMachineRegistry } from "../library/TeeMachineRegistry.sol";
import { TeeExternalAddresses } from "../library/TeeExternalAddresses.sol";
import { TeeInstructionSender } from "../library/TeeInstructionSender.sol";

/**
 * @title TeeWalletBackupManagerFacet
 * @notice Facet for TEE wallet key backup and restore.
 */
contract TeeWalletBackupManagerFacet is ITeeWalletBackupManagerFacet {

    bytes32 internal constant KEY_DATA_PROVIDER_RESTORE = bytes32("KEY_DATA_PROVIDER_RESTORE");

    /**
     * @inheritdoc ITeeWalletBackupManagerFacet
     */
    function backupRestore(
        address _teeId,
        BackupId calldata _backupId,
        string calldata _backupUrl,
        address _claimBackAddress
    )
        external payable
    {
        // Only owner or backup manager
        TeeWalletProjectManager.checkOnlyOwnerOrBackupManager(
            TeeWalletManager.getWalletProjectId(_backupId.walletId)
        );

        TeeMachineRegistry.checkTeeMachineInProduction(_teeId);
        require(
            TeeMachineRegistry.getTeeMachineStatus(_backupId.teeId) !=
                ITeeMachineRegistryFacet.TeeStatus.INITIALIZED,
            InvalidTeeMachine()
        );
        require(!_isKeyAvailable(_teeId, _backupId.walletId, _backupId.keyId), KeyAlreadyAvailable());
        bytes memory publicKey = TeeWalletKeyManager.getWalletKeyPublicKey(_backupId.walletId, _backupId.keyId);
        require(publicKey.length > 0, KeyNotConfirmed());
        require(keccak256(publicKey) == keccak256(_backupId.publicKey), InvalidPublicKey());
        require(
            TeeMachineRegistry.getInitialSigningPolicyId(_teeId) <= _backupId.rewardEpochId,
            UnsupportedRewardEpochId()
        );

        {
            TeeExternalAddresses.State storage ext = TeeExternalAddresses.getState();
            require(
                _backupId.rewardEpochId <=
                    IFlareSystemsManager(ext.flareSystemsManager).getCurrentRewardEpochId() + 1,
                InvalidRewardEpochId()
            );
        }

        {
            bytes32 projectId = TeeWalletManager.getWalletProjectId(_backupId.walletId);
            require(TeeWalletProjectManager.getKeyType(projectId) == _backupId.keyType, InvalidKeyType());
            require(
                TeeWalletProjectManager.getSigningAlgo(projectId) == _backupId.signingAlgo,
                InvalidSigningAlgo()
            );
            uint256 extensionId = TeeWalletProjectManager.getExtensionId(projectId);
            require(
                extensionId == TeeMachineRegistry.getExtensionId(_backupId.teeId) &&
                    extensionId == TeeMachineRegistry.getExtensionId(_teeId),
                ExtensionIdMismatch()
            );
        }

        KeyDataProviderRestore memory message = KeyDataProviderRestore({
            teePublicKey: TeeMachineRegistry.getPublicKey(_teeId),
            backupId: _backupId,
            backupUrl: _backupUrl,
            nonce: TeeWalletKeyManager.increaseKeyNonce(_teeId, _backupId.walletId, _backupId.keyId)
        });
        (address[] memory admins, uint64 adminsThreshold) =
            TeeWalletManager.getWalletAdminsAndThreshold(_backupId.walletId);

        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        TeeInstructionSender.sendInstructions(
            bytes32(0),
            teeIds,
            ITeeExtensionRegistryFacet.TeeInstructionParams(
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

    function _isKeyAvailable(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId
    )
        private view
        returns (bool)
    {
        address[] memory teeIds = TeeWalletKeyManager.getWalletKeyTeeIds(_walletId, _keyId);
        for (uint256 i = 0; i < teeIds.length; i++) {
            if (teeIds[i] == _teeId) {
                return true;
            }
        }
        return false;
    }
}
