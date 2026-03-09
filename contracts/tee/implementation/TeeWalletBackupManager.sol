// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeBase } from "./TeeBase.sol";
import { ITeeExtensionRegistry } from "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeWalletBackupManager } from "../../userInterfaces/tee/ITeeWalletBackupManager.sol";
import { ITeeMachineRegistry } from "../../userInterfaces/tee/ITeeMachineRegistry.sol";
import { ITeeWalletManager } from "../../userInterfaces/tee/ITeeWalletManager.sol";
import { IITeeWalletKeyManager } from "../interface/IITeeWalletKeyManager.sol";
import { ITeeWalletProjectManager } from "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";

/**
 * TeeWalletBackupManager is used for wallet keys' backups.
 */
contract TeeWalletBackupManager is ITeeWalletBackupManager, TeeBase {

    bytes32 public constant WALLET_OP_TYPE = bytes32("F_WALLET");
    bytes32 public constant KEY_DATA_PROVIDER_RESTORE = bytes32("KEY_DATA_PROVIDER_RESTORE");

    /// TEE extension registry contract.
    ITeeExtensionRegistry public teeExtensionRegistry;
    /// TEE machine registry contract.
    ITeeMachineRegistry public teeMachineRegistry;
    /// TEE wallet project manager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// TEE wallet manager contract.
    ITeeWalletManager public teeWalletManager;
    /// TEE wallet key manager contract.
    IITeeWalletKeyManager public teeWalletKeyManager;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;

    modifier onlyOwnerOrBackupManager(bytes32 _walletId) {
        _checkOnlyOwnerOrBackupManager(_walletId);
        _;
    }

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() TeeBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        external
    {
        TeeBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
    }

    /**
     * @inheritdoc ITeeWalletBackupManager
     */
    function backupRestore(
        address _teeId,
        BackupId calldata _backupId,
        string calldata _backupUrl,
        address _claimBackAddress
    )
        external payable
        onlyOwnerOrBackupManager(_backupId.walletId)
    {
        require(
            teeMachineRegistry.getTeeMachineStatus(_teeId) == ITeeMachineRegistry.TeeStatus.PRODUCTION,
            TeeMachineNotAvailable()
        );
        require(
            teeMachineRegistry.getTeeMachineStatus(_backupId.teeId) != ITeeMachineRegistry.TeeStatus.INITIALIZED,
            InvalidTeeMachine()
        );
        require(!_isKeyAvailable(_teeId, _backupId.walletId, _backupId.keyId), KeyAlreadyAvailable());
        bytes memory publicKey = teeWalletKeyManager.getWalletKeyPublicKey(_backupId.walletId, _backupId.keyId);
        require(publicKey.length > 0, KeyNotConfirmed());
        require(keccak256(publicKey) == keccak256(_backupId.publicKey), InvalidPublicKey());
        require(
            teeMachineRegistry.getInitialSigningPolicyId(_teeId) <= _backupId.rewardEpochId,
            UnsupportedRewardEpochId()
        );
        // backups are created at the time of relaying new signing policy,
        // which is usually before the next reward epoch starts - so we can allow `current + 1`
        require(
            _backupId.rewardEpochId <= flareSystemsManager.getCurrentRewardEpochId() + 1,
            InvalidRewardEpochId()
        );
        bytes32 projectId = teeWalletManager.getWalletProjectId(_backupId.walletId);
        require(teeWalletProjectManager.getKeyType(projectId) == _backupId.keyType, InvalidKeyType());
        require(teeWalletProjectManager.getSigningAlgo(projectId) == _backupId.signingAlgo, InvalidSigningAlgo());
        uint256 extensionId = teeWalletProjectManager.getExtensionId(projectId);
        require(
            extensionId == teeMachineRegistry.getExtensionId(_backupId.teeId) &&
            extensionId == teeMachineRegistry.getExtensionId(_teeId),
            ExtensionIdMismatch()
        );
        // restored flag in KeyExistence proof will always be set to true after this call
        // nonce should be increased to prevent replay attacks
        KeyDataProviderRestore memory message = KeyDataProviderRestore({
            teePublicKey: teeMachineRegistry.getPublicKey(_teeId),
            backupId: _backupId,
            backupUrl: _backupUrl,
            nonce: teeWalletKeyManager.increaseKeyNonce(_teeId, _backupId.walletId, _backupId.keyId)
        });
        (address[] memory admins, uint64 adminsThreshold) =
            teeWalletManager.getWalletAdminsAndThreshold(_backupId.walletId);

        _sendInstructions(
            _teeId,
            abi.encode(message),
            admins,
            adminsThreshold,
            _claimBackAddress
        );
        emit BackupRestoreTriggered(_teeId, _backupId.walletId, _backupId.keyId, message.nonce);
    }

    function _sendInstructions(
        address _teeId,
        bytes memory _message,
        address[] memory _cosigners,
        uint64 _cosignersThreshold,
        address _claimBackAddress
    )
        internal
    {
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        teeExtensionRegistry.sendInstructions{value: msg.value}(
            teeIds,
            WALLET_OP_TYPE,
            KEY_DATA_PROVIDER_RESTORE,
            _message,
            _cosigners,
            _cosignersThreshold,
            _claimBackAddress
        );
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        teeExtensionRegistry = ITeeExtensionRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeExtensionRegistry"));
        teeMachineRegistry = ITeeMachineRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeMachineRegistry"));
        teeWalletProjectManager = ITeeWalletProjectManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletProjectManager"));
        teeWalletManager = ITeeWalletManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletManager"));
        teeWalletKeyManager = IITeeWalletKeyManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletKeyManager"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
    }

    function _isKeyAvailable(address _teeId, bytes32 _walletId, uint64 _keyId) internal view returns(bool) {
        address[] memory teeIds = teeWalletKeyManager.getWalletKeyTeeIds(_walletId, _keyId);
        for(uint256 i = 0; i < teeIds.length; i++) {
            if (teeIds[i] == _teeId) {
                return true;
            }
        }
        return false;
    }

    function _checkOnlyOwnerOrBackupManager(bytes32 _walletId)
        internal view
    {
        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        require(
            teeWalletProjectManager.getOwner(projectId) == msg.sender ||
            teeWalletProjectManager.getBackupManager(projectId) == msg.sender,
            OnlyOwnerOrBackupManager()
        );
    }
}
