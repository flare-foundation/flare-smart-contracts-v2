// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IWalletBackupManagerFacet } from "../../userInterfaces/tee/IWalletBackupManagerFacet.sol";
import { IInstructionsFacet } from "../../userInterfaces/tee/IInstructionsFacet.sol";
import { IMachineManagerFacet } from "../../userInterfaces/tee/IMachineManagerFacet.sol";
import { WALLET_OP_TYPE } from "../../userInterfaces/tee/IWalletManagerFacet.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
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
contract WalletBackupManagerFacet is IWalletBackupManagerFacet {

    bytes32 internal constant KEY_DATA_PROVIDER_RESTORE = bytes32("KEY_DATA_PROVIDER_RESTORE");

    /**
     * @inheritdoc IWalletBackupManagerFacet
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
        WalletProjectManager.checkOnlyOwnerOrBackupManager(
            WalletManager.getWalletProjectId(_backupId.walletId)
        );

        MachineManager.checkTeeMachineInProduction(_teeId);
        require(
            MachineManager.getTeeMachineStatus(_backupId.teeId) !=
                IMachineManagerFacet.TeeStatus.INITIALIZED,
            InvalidTeeMachine()
        );
        require(!_isKeyAvailable(_teeId, _backupId.walletId, _backupId.keyId), KeyAlreadyAvailable());
        bytes memory publicKey = WalletKeyManager.getWalletKeyPublicKey(_backupId.walletId, _backupId.keyId);
        require(publicKey.length > 0, KeyNotConfirmed());
        require(keccak256(publicKey) == keccak256(_backupId.publicKey), InvalidPublicKey());
        require(
            MachineManager.getInitialSigningPolicyId(_teeId) <= _backupId.rewardEpochId,
            UnsupportedRewardEpochId()
        );

        {
            ExternalAddresses.State storage ext = ExternalAddresses.getState();
            require(
                _backupId.rewardEpochId <=
                    IFlareSystemsManager(ext.flareSystemsManager).getCurrentRewardEpochId() + 1,
                InvalidRewardEpochId()
            );
        }

        {
            bytes32 projectId = WalletManager.getWalletProjectId(_backupId.walletId);
            require(WalletProjectManager.getKeyType(projectId) == _backupId.keyType, InvalidKeyType());
            require(
                WalletProjectManager.getSigningAlgo(projectId) == _backupId.signingAlgo,
                InvalidSigningAlgo()
            );
            uint256 extensionId = WalletProjectManager.getExtensionId(projectId);
            require(
                extensionId == MachineManager.getExtensionId(_backupId.teeId) &&
                    extensionId == MachineManager.getExtensionId(_teeId),
                ExtensionIdMismatch()
            );
        }

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
            IInstructionsFacet.TeeInstructionParams(
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
        address[] memory teeIds = WalletKeyManager.getWalletKeyTeeIds(_walletId, _keyId);
        for (uint256 i = 0; i < teeIds.length; i++) {
            if (teeIds[i] == _teeId) {
                return true;
            }
        }
        return false;
    }
}
