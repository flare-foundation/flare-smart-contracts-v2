// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * TeeWalletManager is used for wallet configurations on TEE machines.
 */
contract TeeWalletManager is ITeeWalletManager, Governed, AddressUpdatable {

    struct TeeWalletState {
        address owner;
        WalletStatus status;
        uint64 keyIdCounter;
        bytes32 opType;
        address backupManager;
        address submitAddress;
        uint64 multisigThreshold; // number of signatures required - k out of n
        uint256[] keyIds; // n
        mapping(uint256 keyId => KeyDefinition) keyDefinitions;
        uint256 feeFactor;
    }

    struct KeyDefinition {
        uint64 machineBackupCounter;
        uint64 custodianBackupCounter;
        bytes publicKey;
        address[] teeIds;
    }

    bytes32 public constant WALLET_OP_TYPE = bytes32("WALLET");
    bytes32 public constant KEY_GENERATE = bytes32("KEY_GENERATE");
    bytes32 public constant KEY_DELETE = bytes32("KEY_DELETE");
    bytes32 public constant KEY_MACHINE_BACKUP = bytes32("KEY_MACHINE_BACKUP");
    bytes32 public constant KEY_MACHINE_RESTORE = bytes32("KEY_MACHINE_RESTORE");
    bytes32 public constant KEY_MACHINE_BACKUP_REMOVE = bytes32("KEY_MACHINE_BACKUP_REMOVE");
    bytes32 public constant KEY_CUSTODIAN_BACKUP = bytes32("KEY_CUSTODIAN_BACKUP");
    bytes32 public constant KEY_CUSTODIAN_RESTORE = bytes32("KEY_CUSTODIAN_RESTORE");


    uint256 public walletCounter = 0;
    mapping(bytes32 walletId => TeeWalletState) private wallets;
    mapping(bytes32 walletId => address) public proposedWalletOwner;


    /// TEE machines are registered in the TEE registry.
    ITeeRegistry public teeRegistry;
    ITeeInstructions public teeInstructions;
    IFlareSystemsManager public flareSystemsManager;

    modifier onlyOwner(bytes32 _walletId) {
        require(wallets[_walletId].owner == msg.sender, "only owner");
        _;
    }

    modifier onlyOwnerOrBackupManager(bytes32 _walletId) {
        require(wallets[_walletId].owner == msg.sender || wallets[_walletId].backupManager == msg.sender,
            "only owner or backup manager");
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
    {
    }

    function initializeWallet(bytes32 _opType, uint64 _multisigThreshold)
        external payable
        returns (bytes32 _walletId)
    {
        require(_multisigThreshold > 0, "invalid multisig threshold");
        _walletId = keccak256(abi.encode(msg.sender, ++walletCounter));
        TeeWalletState storage wallet = wallets[_walletId];
        assert(wallet.owner == address(0)); // should never revert
        wallet.owner = msg.sender;
        wallet.backupManager = msg.sender;
        wallet.status = WalletStatus.INITIALIZED;
        wallet.multisigThreshold = _multisigThreshold;
        wallet.opType = _opType;
        emit WalletCreated(_walletId, msg.sender, _opType);
    }

    function addKey(
        address _teeId,
        bytes32 _walletId
    )
        external payable
        onlyOwner(_walletId)
    {
        _checkTeeStatus(_teeId);
        TeeWalletState storage wallet = wallets[_walletId];
        _checkWalletStatus(wallet.status, WalletStatus.INITIALIZED);
        require(teeRegistry.isOpTypeSupported(_teeId, wallet.opType), "op type not supported");
        uint64 keyId = wallet.keyIdCounter++;
        KeyGenerate memory keyGenerate = KeyGenerate({
            teeId: _teeId,
            walletId: _walletId,
            keyId: keyId,
            opType: wallet.opType
        });
        bytes32 instructionId = keccak256(abi.encode(KEY_GENERATE, _walletId, keyId));
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = teeRegistry.getTeeMachine(_teeId);
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            KEY_GENERATE,
            abi.encode(keyGenerate)
        );
    }

    function confirmKey(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId,
        bytes calldata _publicKey,
        Signature calldata _signature
    )
        external onlyOwnerOrBackupManager(_walletId)
    {
        TeeWalletState storage wallet = wallets[_walletId];
        require(wallet.keyIdCounter > _keyId, "invalid key id");
        require(_publicKey.length > 0, "invalid public key");
        require(teeRegistry.isOpTypeSupported(_teeId, wallet.opType), "op type not supported");
        bytes32 messageHash = keccak256(abi.encode(_walletId, _keyId, _publicKey));
        address teeId = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(messageHash),
            _signature.v,
            _signature.r,
            _signature.s
        );
        require(teeId == _teeId, "invalid signature");

        wallet.feeFactor++;
        KeyDefinition storage keyDefinition = wallet.keyDefinitions[_keyId];
        if (keyDefinition.publicKey.length > 0) {
            // add tee id to existing key definition
            require(keccak256(keyDefinition.publicKey) == keccak256(_publicKey), "invalid public key");
            address[] storage keyDefinitionTeeIds = keyDefinition.teeIds;
            for (uint256 i = 0; i < keyDefinitionTeeIds.length; i++) {
                if (keyDefinitionTeeIds[i] == teeId) {
                    revert("tee id already added");
                }
            }
            // tee id not found, add it
            keyDefinitionTeeIds.push(teeId);
        } else {
            // new key definition can only be added if wallet is in status initialized
            _checkWalletStatus(wallet.status, WalletStatus.INITIALIZED);
            // add new key id
            wallet.keyIds.push(_keyId);
            // set public key and add tee id
            keyDefinition.publicKey = _publicKey;
            keyDefinition.teeIds.push(teeId);
        }
    }

    function deleteKey(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId
    )
        external payable
        onlyOwner(_walletId)
    {
        // should not check for tee machine status here
        // as might want to delete key even if tee machine is not available
        TeeWalletState storage wallet = wallets[_walletId];
        require(wallet.keyIdCounter > _keyId, "invalid key id");
        KeyDefinition storage keyDefinition = wallet.keyDefinitions[_keyId];
        require(keyDefinition.publicKey.length > 0, "invalid key id");
        // delete tee id from key definition if exists
        uint256 length = keyDefinition.teeIds.length;
        if (length > 0) {
            uint256 index;
            for (index = 0; index < length; index++) {
                if (keyDefinition.teeIds[index] == _teeId) {
                    break;
                }
            }
            if (index < length) { // delete tee id
                keyDefinition.teeIds[index] = keyDefinition.teeIds[keyDefinition.teeIds.length - 1];
                keyDefinition.teeIds.pop();
                wallet.feeFactor--;
            }
        }

        // trigger key delete instruction (even if no tee id found - retry)
        KeyDelete memory keyDelete = KeyDelete({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId
        });
        bytes32 instructionId = keccak256(abi.encode(KEY_DELETE, _walletId, _keyId));
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = teeRegistry.getTeeMachine(_teeId);
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            KEY_DELETE,
            abi.encode(keyDelete)
        );
    }

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
        TeeWalletState storage wallet = wallets[_walletId];
        KeyDefinition storage keyDefinition = wallet.keyDefinitions[_keyId];
        require(keyDefinition.publicKey.length > 0, "key id not found on tee machine");
        KeyMachineBackup memory keyMachineBackup = KeyMachineBackup({
            teeMachine: teeRegistry.getTeeMachineWithAttestationData(_teeId),
            walletId: _walletId,
            keyId: _keyId,
            backupId: keyDefinition.machineBackupCounter++,
            shamirThreshold: _shamirThreshold,
            backupTeeMachines: new ITeeRegistry.TeeMachineWithAttestationData[](_backupTeeIds.length)
        });
        for (uint256 i = 0; i < _backupTeeIds.length; i++) {
            keyMachineBackup.backupTeeMachines[i] = teeRegistry.getTeeMachineWithAttestationData(_backupTeeIds[i]);
        }
        bytes32 instructionId =
            keccak256(abi.encode(KEY_MACHINE_BACKUP, _walletId, _keyId, keyMachineBackup.backupId));
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = ITeeRegistry.TeeMachine({
            teeId: keyMachineBackup.teeMachine.teeId,
            owner: keyMachineBackup.teeMachine.owner,
            url: keyMachineBackup.teeMachine.url
        });
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            KEY_MACHINE_BACKUP,
            abi.encode(keyMachineBackup)
        );
    }

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
        _checkTeeStatus(_teeId);
        _checkTeeStatuses(_backupTeeIds);
        TeeWalletState storage wallet = wallets[_walletId];
        require(wallet.keyIdCounter > _keyId, "invalid key id");
        require(wallet.keyDefinitions[_keyId].machineBackupCounter > _backupId, "invalid backup id");
        KeyMachineRestore memory keyMachineRestore = KeyMachineRestore({
            teeMachine: teeRegistry.getTeeMachineWithAttestationData(_teeId),
            walletId: _walletId,
            keyId: _keyId,
            backupId: _backupId,
            opType: wallet.opType,
            publicKey: wallet.keyDefinitions[_keyId].publicKey,
            backupTeeMachines: new ITeeRegistry.TeeMachineWithAttestationData[](_backupTeeIds.length)
        });
        for (uint256 i = 0; i < _backupTeeIds.length; i++) {
            keyMachineRestore.backupTeeMachines[i] = teeRegistry.getTeeMachineWithAttestationData(_backupTeeIds[i]);
        }
        bytes32 instructionId = keccak256(abi.encode(KEY_MACHINE_RESTORE, _walletId, _keyId, _backupId));
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = ITeeRegistry.TeeMachine({
            teeId: keyMachineRestore.teeMachine.teeId,
            owner: keyMachineRestore.teeMachine.owner,
            url: keyMachineRestore.teeMachine.url
        });
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            KEY_MACHINE_RESTORE,
            abi.encode(keyMachineRestore)
        );
    }

    function machineBackupRemove(
        bytes32 _walletId,
        uint64 _keyId,
        uint256 _backupId,
        address[] calldata _teeIds
    )
        external payable
        onlyOwner(_walletId)
    {
        _checkTeeStatuses(_teeIds);
        TeeWalletState storage wallet = wallets[_walletId];
        require(wallet.keyIdCounter > _keyId, "invalid key id");
        require(wallet.keyDefinitions[_keyId].machineBackupCounter > _backupId, "invalid backup id");
        KeyMachineBackupRemove memory keyMachineBackupRemove = KeyMachineBackupRemove({
            walletId: _walletId,
            keyId: _keyId,
            backupId: _backupId,
            teeIds: _teeIds
        });
        bytes32 instructionId = keccak256(abi.encode(KEY_MACHINE_BACKUP_REMOVE, _walletId, _keyId, _backupId));
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](_teeIds.length);
        for (uint256 i = 0; i < _teeIds.length; i++) {
            teeMachines[i] = teeRegistry.getTeeMachine(_teeIds[i]);
        }
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            KEY_MACHINE_BACKUP_REMOVE,
            abi.encode(keyMachineBackupRemove)
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
        _checkTeeStatus(_teeId);
        _checkCustodianPublicKeys(_custodianPublicKeys);
        TeeWalletState storage wallet = wallets[_walletId];
        KeyDefinition storage keyDefinition = wallet.keyDefinitions[_keyId];
        require(keyDefinition.publicKey.length > 0, "key id not found on tee machine");
        KeyCustodianBackup memory keyCustodianBackup = KeyCustodianBackup({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            backupId: keyDefinition.custodianBackupCounter++,
            shamirThreshold: _shamirThreshold,
            custodianPublicKeys: _custodianPublicKeys
        });
        bytes32 instructionId =
            keccak256(abi.encode(KEY_CUSTODIAN_BACKUP, _walletId, _keyId, keyCustodianBackup.backupId));
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = teeRegistry.getTeeMachine(_teeId);
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            KEY_CUSTODIAN_BACKUP,
            abi.encode(keyCustodianBackup)
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
        _checkTeeStatus(_teeId);
        _checkCustodianPublicKeys(_custodianPublicKeys);
        TeeWalletState storage wallet = wallets[_walletId];
        require(wallet.keyIdCounter > _keyId, "invalid key id");
        require(wallet.keyDefinitions[_keyId].custodianBackupCounter > _backupId, "invalid backup id");
        KeyCustodianRestore memory keyCustodianRestore = KeyCustodianRestore({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            backupId: _backupId,
            opType: wallet.opType,
            publicKey: wallet.keyDefinitions[_keyId].publicKey,
            custodianPublicKeys: _custodianPublicKeys
        });
        bytes32 instructionId = keccak256(abi.encode(KEY_CUSTODIAN_RESTORE, _walletId, _keyId, _backupId));
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = teeRegistry.getTeeMachine(_teeId);
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            KEY_CUSTODIAN_RESTORE,
            abi.encode(keyCustodianRestore)
        );
    }

    function setSubmitAddress(bytes32 _walletId, address _submitAddress)
        external onlyOwner(_walletId)
    {
        wallets[_walletId].submitAddress = _submitAddress;
    }

    function setBackupManager(bytes32 _walletId, address _backupManager)
        external onlyOwner(_walletId)
    {
        wallets[_walletId].backupManager = _backupManager;
    }

    function enableWallet(bytes32 _walletId)
        external onlyOwner(_walletId)
    {
        require(wallets[_walletId].status != WalletStatus.PRODUCTION, "wallet already in status production");
        if (wallets[_walletId].status == WalletStatus.INITIALIZED) {
            require(wallets[_walletId].keyIds.length >= wallets[_walletId].multisigThreshold, "not enough keys");
        }
        wallets[_walletId].status = WalletStatus.PRODUCTION;
    }

    function pauseWallet(bytes32 _walletId)
        external onlyOwner(_walletId)
    {
        _checkWalletStatus(wallets[_walletId].status, WalletStatus.PRODUCTION);
        wallets[_walletId].status = WalletStatus.PAUSED;
    }

    function proposeNewOwner(bytes32 _walletId, address _newOwner)
        external onlyOwner(_walletId)
    {
        proposedWalletOwner[_walletId] = _newOwner;
    }

    function confirmOwnership(bytes32 _walletId)
        external
    {
        require(proposedWalletOwner[_walletId] == msg.sender, "only proposed owner");
        wallets[_walletId].owner = msg.sender;
        delete proposedWalletOwner[_walletId];
    }

    function getFeeFactor(bytes32 _walletId)
        external view
        returns (uint256 _feeFactor)
    {
        return wallets[_walletId].feeFactor;
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function getWalletOwner(bytes32 _walletId)
        external view
        returns (address _walletOwner)
    {
        return wallets[_walletId].owner;
    }

    function getWalletBackupManager(bytes32 _walletId)
        external view
        returns (address _backupManager)
    {
        return wallets[_walletId].backupManager;
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function getWalletInfo(bytes32 _walletId)
        external view
        returns (
            address _submitAddress,
            WalletStatus _status,
            bytes32 _opType
        )
    {
        TeeWalletState storage wallet = wallets[_walletId];
        return (wallet.submitAddress, wallet.status, wallet.opType);
    }

    function getWalletKeysInfo(bytes32 _walletId)
        external view
        returns (uint64 _multisigThreshold, uint256[] memory _keyIds, uint64 _counter)
    {
        TeeWalletState storage wallet = wallets[_walletId];
        return (wallet.multisigThreshold, wallet.keyIds, wallet.keyIdCounter);
    }

    function getWalletKeyInfo(bytes32 _walletId, uint64 _keyId)
        external view
        returns (
            uint64 _machineBackupCounter,
            uint64 _custodianBackupCounter,
            bytes memory _publicKey,
            address[] memory _teeIds
        )
    {
        KeyDefinition storage keyDefinition = wallets[_walletId].keyDefinitions[_keyId];
        return (
            keyDefinition.machineBackupCounter,
            keyDefinition.custodianBackupCounter,
            keyDefinition.publicKey,
            keyDefinition.teeIds
        );
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function receivingTees(bytes32 _walletId)
        external view
        returns (ITeeRegistry.TeeMachine[] memory _receivingTees)
    {
        TeeWalletState storage wallet = wallets[_walletId];
        _checkWalletStatus(wallet.status, WalletStatus.PRODUCTION);
        uint256 countTees = 0;
        for (uint256 i = 0; i < wallet.keyIds.length; i++) {
            countTees += wallet.keyDefinitions[wallet.keyIds[i]].teeIds.length;
        }
        address[] memory teeMachines = new address[](countTees);
        countTees = 0;
        uint256 threshold = 0;
        for (uint256 i = 0; i < wallet.keyIds.length; i++) {
            bool keyAvailable = false;
            KeyDefinition storage keyDefinition = wallet.keyDefinitions[wallet.keyIds[i]];
            for (uint256 j = 0; j < keyDefinition.teeIds.length; j++) {
                if (teeRegistry.getTeeMachineStatus(keyDefinition.teeIds[j]) == ITeeRegistry.TeeStatus.PRODUCTION) {
                    teeMachines[countTees++] = keyDefinition.teeIds[j];
                    keyAvailable = true;
                }
            }
            if (keyAvailable) {
                threshold++;
            }
        }
        require(threshold >= wallet.multisigThreshold, "not enough keys/tees available");
        _receivingTees = new ITeeRegistry.TeeMachine[](countTees);
        for (uint256 i = 0; i < countTees; i++) {
            _receivingTees[i] = teeRegistry.getTeeMachine(teeMachines[i]);
        }
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function getWalletStatus(bytes32 _walletId)
        external view
        returns (WalletStatus _status)
    {
        return wallets[_walletId].status;
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
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
    }

    function _checkTeeStatus(address _teeId)
        internal view
    {
        require(teeRegistry.getTeeMachineStatus(_teeId) == ITeeRegistry.TeeStatus.PRODUCTION,
            "tee machine not available");
    }

    function _checkTeeStatuses(address[] memory _teeIds)
        internal view
    {
        for(uint256 i = 0; i < _teeIds.length; i++) {
            _checkTeeStatus(_teeIds[i]);
        }
    }

    function _checkWalletStatus(WalletStatus _actualStatus, WalletStatus _expectedStatus)
        internal pure
    {
        require(_actualStatus == _expectedStatus, "invalid wallet status");
    }

    function _checkCustodianPublicKeys(bytes[] memory _custodianPublicKeys)
        internal pure
    {
        for(uint256 i = 0; i < _custodianPublicKeys.length; i++) {
            require(_custodianPublicKeys[i].length > 0, "invalid custodian public key"); // TODO
        }
    }
}