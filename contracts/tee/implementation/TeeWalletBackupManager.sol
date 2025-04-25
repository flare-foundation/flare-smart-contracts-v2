// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeWalletBackupManager.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../../userInterfaces/tee/ITeeWalletKeyManager.sol";
import "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../governance/implementation/GovernedProxyImplementation.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * TeeWalletBackupManager is used for wallet keys' backups.
 */
contract TeeWalletBackupManager is ITeeWalletBackupManager, GovernedProxyImplementation,
    AddressUpdatable, UUPSUpgradeable {

    bytes32 public constant WALLET_OP_TYPE = bytes32("WALLET");
    bytes32 public constant KEY_DATA_PROVIDER_RESTORE_INIT = bytes32("KEY_DATA_PROVIDER_RESTORE_INIT");
    bytes32 public constant KEY_DATA_PROVIDER_RESTORE = bytes32("KEY_DATA_PROVIDER_RESTORE");

    mapping(bytes32 walletId => mapping(uint64 keyId =>
        mapping (bytes32 opCommand => uint256))) private dataProviderRestoreCounter;

    /// TEE registry contract.
    ITeeRegistry public teeRegistry;
    /// TEE wallet project manager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// TEE wallet manager contract.
    ITeeWalletManager public teeWalletManager;
    /// TEE wallet key manager contract.
    ITeeWalletKeyManager public teeWalletKeyManager;
    /// TEE fee calculator contract.
    ITeeFeeCalculator public teeFeeCalculator;
    /// TEE instructions contract.
    ITeeInstructions public teeInstructions;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;

    modifier onlyOwnerOrBackupManager(bytes32 _walletId) {
        _checkOnlyOwnerOrBackupManager(_walletId);
        _;
    }

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor()
        GovernedProxyImplementation() AddressUpdatable(address(0))
    { }

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
        GovernedBase.initialise(_governanceSettings, _initialGovernance);
        AddressUpdatable.setAddressUpdaterValue(_addressUpdater);
    }

    /**
     * @inheritdoc ITeeWalletBackupManager
     */
    function backupRestoreInit(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId,
        uint24 _rewardEpochId
    )
        external payable
        onlyOwnerOrBackupManager(_walletId)
    {
        _backupRestore(_teeId, _walletId, _keyId, _rewardEpochId, KEY_DATA_PROVIDER_RESTORE_INIT);
    }

    /**
     * @inheritdoc ITeeWalletBackupManager
     */
    function backupRestore(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId,
        uint24 _rewardEpochId
    )
        external payable
        onlyOwnerOrBackupManager(_walletId)
    {
        _backupRestore(_teeId, _walletId, _keyId, _rewardEpochId, KEY_DATA_PROVIDER_RESTORE);
    }

    /////////////////////////////// UUPS UPGRADABLE ///////////////////////////////

    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Only governance can call this method.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data)
        public payable override
        onlyGovernance
        onlyProxy
    {
        super.upgradeToAndCall(newImplementation, data);
    }

    /**
     * Unused. Present just to satisfy UUPSUpgradeable requirement.
     * The real check is in onlyGovernance modifier on upgradeToAndCall.
     */
    function _authorizeUpgrade(address newImplementation) internal override {}

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        teeRegistry = ITeeRegistry(_getContractAddress(_contractNameHashes, _contractAddresses, "TeeRegistry"));
        teeWalletProjectManager = ITeeWalletProjectManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletProjectManager"));
        teeWalletManager = ITeeWalletManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletManager"));
        teeWalletKeyManager = ITeeWalletKeyManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletKeyManager"));
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
    }

    function _backupRestore(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId,
        uint24 _rewardEpochId,
        bytes32 _opCommand
    )
        internal
    {
        require(_rewardEpochId <= flareSystemsManager.getCurrentRewardEpochId(), "invalid reward epoch id");
        _checkTeeStatus(_teeId);
        require(!_isKeyAvailable(_teeId, _walletId, _keyId), "key already available");
        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        bytes32 opType = teeWalletProjectManager.getOpType(projectId);
        bytes memory publicKey = teeWalletKeyManager.getWalletKeyPublicKey(_walletId, _keyId);
        require(publicKey.length > 0, "key not confirmed");
        _checkFee(_opCommand, _teeId);
        KeyDataProviderRestore memory message = KeyDataProviderRestore({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            opType: opType,
            publicKey: publicKey,
            rewardEpochId: _rewardEpochId
        });
        bytes32 instructionId = keccak256(abi.encode(
            WALLET_OP_TYPE, _opCommand, _walletId, _keyId,
            dataProviderRestoreCounter[_walletId][_keyId][_opCommand]++
        ));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            _getTeeMachines(_teeId),
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            _opCommand,
            abi.encode(message)
        );
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

    function _getTeeMachines(address _teeId)
        internal view
        returns(ITeeRegistry.TeeMachine[] memory)
    {
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = teeRegistry.getTeeMachine(_teeId);
        return teeMachines;
    }

    function _checkTeeStatus(address _teeId) internal view {
        require(teeRegistry.getTeeMachineStatus(_teeId) == ITeeRegistry.TeeStatus.PRODUCTION,
            "tee machine not available");
    }

    function _checkTeeStatuses(address[] memory _teeIds) internal view {
        for(uint256 i = 0; i < _teeIds.length; i++) {
            _checkTeeStatus(_teeIds[i]);
        }
    }

    function _checkFee(
        bytes32 _opCommand,
        address _teeId
    )
        internal view
    {
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        require(msg.value >= teeFeeCalculator.calculateFeeByTeeIds(WALLET_OP_TYPE, _opCommand, teeIds), "fee too low");
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
