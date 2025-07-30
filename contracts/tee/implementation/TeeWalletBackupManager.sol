// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./TeeBase.sol";
import "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import "../../userInterfaces/tee/ITeeWalletBackupManager.sol";
import "../../userInterfaces/tee/ITeeMachineRegistry.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../interface/IITeeWalletKeyManager.sol";
import "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";

/**
 * TeeWalletBackupManager is used for wallet keys' backups.
 */
contract TeeWalletBackupManager is ITeeWalletBackupManager, TeeBase {

    bytes32 public constant WALLET_OP_TYPE = bytes32("F_WALLET");
    bytes32 public constant KEY_DATA_PROVIDER_RESTORE = bytes32("KEY_DATA_PROVIDER_RESTORE");
    bytes32 public constant KEY_DATA_PROVIDER_RESTORE_TEST = bytes32("KEY_DATA_PROVIDER_RESTORE_TEST");

    mapping(bytes32 walletId => mapping(uint64 keyId => uint256)) private dataProviderRestoreCounter;

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
        bool _test
    )
        external payable
        onlyOwnerOrBackupManager(_backupId.walletId)
    {
        require(
            teeMachineRegistry.getTeeMachineStatus(_teeId) == ITeeMachineRegistry.TeeStatus.PRODUCTION,
            "tee machine not available"
        );
        require(
            teeMachineRegistry.getTeeMachineStatus(_backupId.teeId) != ITeeMachineRegistry.TeeStatus.INITIALIZED,
            "invalid tee machine"
        );
        require(!_isKeyAvailable(_teeId, _backupId.walletId, _backupId.keyId), "key already available");
        bytes memory publicKey = teeWalletKeyManager.getWalletKeyPublicKey(_backupId.walletId, _backupId.keyId);
        require(publicKey.length > 0, "key not confirmed");
        require(keccak256(publicKey) == keccak256(_backupId.publicKey), "invalid public key");
        require(
            teeMachineRegistry.getInitialSigningPolicyId(_teeId) <= _backupId.rewardEpochId,
            "unsupported reward epoch id"
        );
        // backups are created at the time of relaying new signing policy,
        // which is usually before the next reward epoch starts - so we can allow `current + 1`
        require(
            _backupId.rewardEpochId <= flareSystemsManager.getCurrentRewardEpochId() + 1,
            "invalid reward epoch id"
        );
        bytes32 projectId = teeWalletManager.getWalletProjectId(_backupId.walletId);
        require(teeWalletProjectManager.getOpType(projectId) == _backupId.opType, "invalid op type");
        uint256 extensionId = teeWalletProjectManager.getExtensionId(projectId);
        require(
            extensionId == teeMachineRegistry.getExtensionId(_backupId.teeId) &&
            extensionId == teeMachineRegistry.getExtensionId(_teeId),
            "invalid extension id"
        );
        bytes32 opCommand = _test ? KEY_DATA_PROVIDER_RESTORE_TEST : KEY_DATA_PROVIDER_RESTORE;
        // restored flag in KeyExistence proof will always be set to true after this call
        // in case of a test restore, nonce should be 0, so that the key cannot be confirmed on-chain
        // in case of a actual restore, nonce should be increased to prevent replay attacks
        // and to allow the key to be confirmed on-chain
        KeyDataProviderRestore memory message = KeyDataProviderRestore({
            teeId: _teeId,
            backupId: _backupId,
            backupUrl: _backupUrl,
            nonce: _test ? 0 : teeWalletKeyManager.increaseKeyNonce(_teeId, _backupId.walletId, _backupId.keyId)
        });
        uint256 counter = dataProviderRestoreCounter[_backupId.walletId][_backupId.keyId]++;
        bytes32 instructionId = keccak256(abi.encode(
            WALLET_OP_TYPE, opCommand, _backupId.walletId, _backupId.keyId, counter
        ));
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        teeExtensionRegistry.sendInstructions{value: msg.value}(
            instructionId,
            extensionId,
            teeIds,
            WALLET_OP_TYPE,
            opCommand,
            abi.encode(message)
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
            "only owner or backup manager"
        );
    }
}
