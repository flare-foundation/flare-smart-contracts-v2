// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeWalletBackupManager.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * TeeWalletBackupManager is used for wallet keys' backups.
 */
contract TeeWalletBackupManager is ITeeWalletBackupManager, Governed, AddressUpdatable {

    bytes32 public constant WALLET_OP_TYPE = bytes32("WALLET");
    bytes32 public constant KEY_MACHINE_BACKUP = bytes32("KEY_MACHINE_BACKUP");
    bytes32 public constant KEY_MACHINE_RESTORE = bytes32("KEY_MACHINE_RESTORE");
    bytes32 public constant KEY_MACHINE_BACKUP_REMOVE = bytes32("KEY_MACHINE_BACKUP_REMOVE");
    bytes32 public constant KEY_CUSTODIAN_BACKUP = bytes32("KEY_CUSTODIAN_BACKUP");
    bytes32 public constant KEY_CUSTODIAN_RESTORE = bytes32("KEY_CUSTODIAN_RESTORE");

    mapping(bytes32 walletId => mapping(uint256 keyId => uint256)) private machineBackupCounter;
    mapping(bytes32 walletId => mapping(uint256 keyId => uint256)) private custodianBackupCounter;

    /// TEE registry contract.
    ITeeRegistry public teeRegistry;
    /// TEE wallet manager contract.
    ITeeWalletManager public teeWalletManager;
    /// TEE fee calculator contract.
    ITeeFeeCalculator public teeFeeCalculator;
    /// TEE instructions contract.
    ITeeInstructions public teeInstructions;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;

    modifier onlyOwner(bytes32 _walletId) {
        _checkOnlyOwner(_walletId);
        _;
    }

    modifier onlyOwnerOrBackupManager(bytes32 _walletId) {
        _checkOnlyOwnerOrBackupManager(_walletId);
        _;
    }

    /**
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    { }

    /**
     * @inheritdoc ITeeWalletBackupManager
     */
    function machineBackup(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId,
        uint256 _shamirThreshold,
        address[] calldata _backupTeeIds
    )
        external payable
        onlyOwnerOrBackupManager(_walletId)
    {
        require(_shamirThreshold > 0 && _shamirThreshold <= _backupTeeIds.length, "invalid shamir threshold");
        _checkTeeStatus(_teeId);
        _checkTeeStatuses(_backupTeeIds);
        require(teeRegistry.arePlatformsCompatible(_teeId, _backupTeeIds), "platforms not compatible");
        _checkKeyAvailable(_teeId, teeWalletManager.getWalletKeyTeeIds(_walletId, _keyId));
        _checkFee(KEY_MACHINE_BACKUP, _teeId, _backupTeeIds);
        KeyMachineBackup memory message = KeyMachineBackup({
            teeMachine: teeRegistry.getTeeMachineWithAttestationData(_teeId),
            walletId: _walletId,
            keyId: _keyId,
            backupId: machineBackupCounter[_walletId][_keyId]++,
            shamirThreshold: _shamirThreshold,
            backupTeeMachines: new ITeeRegistry.TeeMachineWithAttestationData[](_backupTeeIds.length)
        });
        for (uint256 i = 0; i < _backupTeeIds.length; i++) {
            message.backupTeeMachines[i] = teeRegistry.getTeeMachineWithAttestationData(_backupTeeIds[i]);
        }
        bytes32 instructionId =
            keccak256(abi.encode(WALLET_OP_TYPE, KEY_MACHINE_BACKUP, _walletId, _keyId, message.backupId));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            _getTeeMachines(_teeId),
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            KEY_MACHINE_BACKUP,
            abi.encode(message)
        );
    }

    /**
     * @inheritdoc ITeeWalletBackupManager
     */
    function machineRestore(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId,
        uint256 _backupId,
        address[] calldata _backupTeeIds
    )
        external payable
        onlyOwnerOrBackupManager(_walletId)
    {
        require(machineBackupCounter[_walletId][_keyId] > _backupId, "invalid key or backup id");
        _checkTeeStatus(_teeId);
        _checkTeeStatuses(_backupTeeIds);
        require(teeRegistry.arePlatformsCompatible(_teeId, _backupTeeIds), "platforms not compatible");
        _checkFee(KEY_MACHINE_RESTORE, _teeId, _backupTeeIds);
        KeyMachineRestore memory message = KeyMachineRestore({
            teeMachine: teeRegistry.getTeeMachineWithAttestationData(_teeId),
            walletId: _walletId,
            keyId: _keyId,
            backupId: _backupId,
            opType: teeWalletManager.getWalletOpType(_walletId),
            publicKey: teeWalletManager.getWalletKeyPublicKey(_walletId, _keyId),
            backupTeeMachines: new ITeeRegistry.TeeMachineWithAttestationData[](_backupTeeIds.length)
        });
        for (uint256 i = 0; i < _backupTeeIds.length; i++) {
            message.backupTeeMachines[i] = teeRegistry.getTeeMachineWithAttestationData(_backupTeeIds[i]);
        }
        bytes32 instructionId =
            keccak256(abi.encode(WALLET_OP_TYPE, KEY_MACHINE_RESTORE, _walletId, _keyId, _backupId));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            _getTeeMachines(_teeId),
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            KEY_MACHINE_RESTORE,
            abi.encode(message)
        );
    }

    /**
     * @inheritdoc ITeeWalletBackupManager
     */
    function machineBackupRemove(
        bytes32 _walletId,
        uint64 _keyId,
        uint256 _backupId,
        address[] calldata _teeIds
    )
        external payable
        onlyOwner(_walletId)
    {
        require(machineBackupCounter[_walletId][_keyId] > _backupId, "invalid key or backup id");
        _checkTeeStatuses(_teeIds);
        _checkFee(KEY_MACHINE_BACKUP_REMOVE, _teeIds, new address[](0));
        KeyMachineBackupRemove memory message = KeyMachineBackupRemove({
            walletId: _walletId,
            keyId: _keyId,
            backupId: _backupId,
            teeIds: _teeIds
        });
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](_teeIds.length);
        for (uint256 i = 0; i < _teeIds.length; i++) {
            teeMachines[i] = teeRegistry.getTeeMachine(_teeIds[i]);
        }
        bytes32 instructionId =
            keccak256(abi.encode(WALLET_OP_TYPE, KEY_MACHINE_BACKUP_REMOVE, _walletId, _keyId, _backupId));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            KEY_MACHINE_BACKUP_REMOVE,
            abi.encode(message)
        );
    }

    function custodianBackup(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId,
        uint256 _shamirThreshold,
        bytes[] calldata _custodianPublicKeys
    )
        external payable
        onlyOwner(_walletId)
    {
        require(_shamirThreshold > 0 && _shamirThreshold <= _custodianPublicKeys.length, "invalid shamir threshold");
        require(teeWalletManager.getWalletStatus(_walletId) == ITeeWalletManager.WalletStatus.INITIALIZED,
            "wallet not in status initialized");
        _checkTeeStatus(_teeId);
        _checkCustodianPublicKeys(_custodianPublicKeys);
        _checkKeyAvailable(_teeId, teeWalletManager.getWalletKeyTeeIds(_walletId, _keyId));
        _checkFee(KEY_CUSTODIAN_BACKUP, _teeId, new address[](0));
        KeyCustodianBackup memory message = KeyCustodianBackup({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            backupId: custodianBackupCounter[_walletId][_keyId]++,
            shamirThreshold: _shamirThreshold,
            custodianPublicKeys: _custodianPublicKeys
        });
        bytes32 instructionId =
            keccak256(abi.encode(WALLET_OP_TYPE, KEY_CUSTODIAN_BACKUP, _walletId, _keyId, message.backupId));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            _getTeeMachines(_teeId),
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            KEY_CUSTODIAN_BACKUP,
            abi.encode(message)
        );
    }

    function custodianRestore(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId,
        uint256 _backupId,
        bytes[] calldata _custodianPublicKeys
    )
        external payable
        onlyOwner(_walletId)
    {
        require(custodianBackupCounter[_walletId][_keyId] > _backupId, "invalid key or backup id");
        _checkTeeStatus(_teeId);
        _checkCustodianPublicKeys(_custodianPublicKeys);
        _checkFee(KEY_CUSTODIAN_RESTORE, _teeId, new address[](0));
        KeyCustodianRestore memory message = KeyCustodianRestore({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            backupId: _backupId,
            opType: teeWalletManager.getWalletOpType(_walletId),
            publicKey: teeWalletManager.getWalletKeyPublicKey(_walletId, _keyId),
            custodianPublicKeys: _custodianPublicKeys
        });
        bytes32 instructionId =
            keccak256(abi.encode(WALLET_OP_TYPE, KEY_CUSTODIAN_RESTORE, _walletId, _keyId, _backupId));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            _getTeeMachines(_teeId),
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            KEY_CUSTODIAN_RESTORE,
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
        teeRegistry = ITeeRegistry(_getContractAddress(_contractNameHashes, _contractAddresses, "TeeRegistry"));
        teeWalletManager = ITeeWalletManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletManager"));
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
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
        address _teeId,
        address[] memory _backupTeeIds
    )
        internal view
    {
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        _checkFee(_opCommand, teeIds, _backupTeeIds);
    }

    function _checkFee(
        bytes32 _opCommand,
        address[] memory _teeIds,
        address[] memory _backupTeeIds
    )
        internal view
    {
        require(msg.value >= teeFeeCalculator.calculateFeeByTeeIds(WALLET_OP_TYPE, _opCommand, _teeIds, _backupTeeIds),
            "fee too low");
    }

    function _getTeeMachines(address _teeId)
        internal view
        returns(ITeeRegistry.TeeMachine[] memory)
    {
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = teeRegistry.getTeeMachine(_teeId);
        return teeMachines;
    }

    function _checkOnlyOwner(bytes32 _walletId)
        internal view
    {
        require(teeWalletManager.getWalletOwner(_walletId) == msg.sender, "only owner");
    }

    function _checkOnlyOwnerOrBackupManager(bytes32 _walletId)
        internal view
    {
        require(
            teeWalletManager.getWalletOwner(_walletId) == msg.sender ||
            teeWalletManager.getWalletBackupManager(_walletId) == msg.sender,
            "only owner or backup manager"
        );
    }

    function _checkKeyAvailable(address _teeId, address[] memory _teeIds) internal pure {
        for(uint256 i = 0; i < _teeIds.length; i++) {
            if (_teeIds[i] == _teeId) {
                return;
            }
        }
        revert("key not available");
    }

    function _checkCustodianPublicKeys(bytes[] memory _custodianPublicKeys)
        internal pure
    {
        for(uint256 i = 0; i < _custodianPublicKeys.length; i++) {
            require(_custodianPublicKeys[i].length > 0, "invalid custodian public key"); // TODO
        }
    }
}
