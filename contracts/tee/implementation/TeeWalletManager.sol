// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * TeeWalletManager is used for wallet configurations on TEE machines.
 */
contract TeeWalletManager is ITeeWalletManager, Governed, AddressUpdatable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

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
        bytes publicKey;
        address[] teeIds;
    }

    bytes32 public constant WALLET_OP_TYPE = bytes32("WALLET");
    bytes32 public constant KEY_GENERATE = bytes32("KEY_GENERATE");
    bytes32 public constant KEY_DELETE = bytes32("KEY_DELETE");

    uint256 public confirmKeyValidityDurationSeconds;
    uint256 public walletCounter = 0;
    mapping(bytes32 walletId => TeeWalletState) private wallets;
    mapping(bytes32 walletId => address) public proposedWalletOwner;

    EnumerableSet.Bytes32Set private supportedOpTypes;

    /// TEE machines are registered in the TEE registry.
    ITeeRegistry public teeRegistry;
    ITeeFeeCalculator public teeFeeCalculator;
    ITeeInstructions public teeInstructions;
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
        address _addressUpdater,
        bytes32[] memory _supportedOpTypes,
        uint256 _confirmKeyValidityDurationSeconds
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        require(_confirmKeyValidityDurationSeconds > 0, "invalid confirm key validity duration");
        for (uint256 i = 0; i < _supportedOpTypes.length; i++) {
            require(_supportedOpTypes[i] != bytes32(0), "invalid op type");
            supportedOpTypes.add(_supportedOpTypes[i]);
        }
        confirmKeyValidityDurationSeconds = _confirmKeyValidityDurationSeconds;
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function initializeWallet(bytes32 _opType, uint64 _multisigThreshold)
        external payable
        returns (bytes32 _walletId)
    {
        require(supportedOpTypes.contains(_opType), "op type not supported");
        require(_multisigThreshold > 0, "invalid multisig threshold");
        _walletId = keccak256(abi.encode(msg.sender, ++walletCounter));
        TeeWalletState storage wallet = wallets[_walletId];
        assert(wallet.owner == address(0)); // should never revert
        wallet.owner = msg.sender;
        wallet.status = WalletStatus.INITIALIZED;
        wallet.multisigThreshold = _multisigThreshold;
        wallet.opType = _opType;
        emit WalletCreated(_walletId, msg.sender, _opType);
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function addKey(
        address _teeId,
        bytes32 _walletId
    )
        external payable
        onlyOwner(_walletId)
        returns (uint64 _keyId)
    {
        _checkTeeStatus(_teeId);
        TeeWalletState storage wallet = wallets[_walletId];
        _checkWalletStatus(wallet.status, WalletStatus.INITIALIZED);
        require(teeRegistry.isOpTypeSupported(_teeId, wallet.opType), "op type not supported");
        _checkFee(KEY_GENERATE, _teeId, new address[](0));
        _keyId = wallet.keyIdCounter++;
        KeyGenerate memory message = KeyGenerate({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            opType: wallet.opType
        });
        bytes32 instructionId = keccak256(abi.encode(WALLET_OP_TYPE, KEY_GENERATE, _walletId, _keyId));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            _getTeeMachines(_teeId),
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            KEY_GENERATE,
            abi.encode(message)
        );
    }

    function confirmKey(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId,
        bytes calldata _publicKey,
        uint64 _timestamp,
        Signature calldata _signature
    )
        external onlyOwnerOrBackupManager(_walletId)
    {
        TeeWalletState storage wallet = wallets[_walletId];
        require(wallet.keyIdCounter > _keyId, "invalid key id");
        require(_publicKey.length > 0, "invalid public key");
        require(teeRegistry.isOpTypeSupported(_teeId, wallet.opType), "op type not supported");
        require(_timestamp < block.timestamp, "timestamp in the future");
        require(_timestamp + confirmKeyValidityDurationSeconds > block.timestamp,
            "confirm key validity expired");
        bytes32 messageHash = keccak256(abi.encode(_walletId, _keyId, _publicKey, _timestamp));
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

    /**
     * @inheritdoc ITeeWalletManager
     */
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

        // trigger key delete instruction (even if no tee id found, but machine is in production status - retry)
        if (teeRegistry.getTeeMachineStatus(_teeId) == ITeeRegistry.TeeStatus.PRODUCTION) {
            _checkFee(KEY_DELETE, _teeId, new address[](0));
            KeyDelete memory message = KeyDelete({
                teeId: _teeId,
                walletId: _walletId,
                keyId: _keyId
            });
            bytes32 instructionId = keccak256(abi.encode(WALLET_OP_TYPE, KEY_DELETE, _walletId, _keyId));
            teeInstructions.sendInstructions{value: msg.value}(
                instructionId,
                _getTeeMachines(_teeId),
                flareSystemsManager.getCurrentRewardEpochId(),
                WALLET_OP_TYPE,
                KEY_DELETE,
                abi.encode(message)
            );
        } else {
            require(msg.value == 0, "msg.value should be 0");
        }
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function setSubmitAddress(bytes32 _walletId, address _submitAddress)
        external onlyOwner(_walletId)
    {
        wallets[_walletId].submitAddress = _submitAddress;
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function setWalletBackupManager(bytes32 _walletId, address _backupManager)
        external onlyOwner(_walletId)
    {
        wallets[_walletId].backupManager = _backupManager;
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function enableWallet(bytes32 _walletId)
        external onlyOwner(_walletId)
    {
        require(wallets[_walletId].status != WalletStatus.PRODUCTION, "wallet already in status production");
        if (wallets[_walletId].status == WalletStatus.INITIALIZED) {
            require(wallets[_walletId].keyIds.length >= wallets[_walletId].multisigThreshold, "not enough keys");
        }
        wallets[_walletId].status = WalletStatus.PRODUCTION;
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function pauseWallet(bytes32 _walletId)
        external onlyOwner(_walletId)
    {
        _checkWalletStatus(wallets[_walletId].status, WalletStatus.PRODUCTION);
        wallets[_walletId].status = WalletStatus.PAUSED;
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function proposeNewOwner(bytes32 _walletId, address _newOwner)
        external onlyOwner(_walletId)
    {
        proposedWalletOwner[_walletId] = _newOwner;
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function confirmOwnership(bytes32 _walletId)
        external
    {
        require(proposedWalletOwner[_walletId] == msg.sender, "only proposed owner");
        wallets[_walletId].owner = msg.sender;
        delete proposedWalletOwner[_walletId];
    }

    function addSupportedOpTypes(bytes32[] memory _opTypes)
        external onlyGovernance
    {
        for (uint256 i = 0; i < _opTypes.length; i++) {
            require(_opTypes[i] != bytes32(0), "invalid op type");
            supportedOpTypes.add(_opTypes[i]);
        }
    }

    function removeSupportedOpTypes(bytes32[] memory _opTypes)
        external onlyGovernance
    {
        for (uint256 i = 0; i < _opTypes.length; i++) {
            supportedOpTypes.remove(_opTypes[i]);
        }
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
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

    /**
     * @inheritdoc ITeeWalletManager
     */
    function getWalletBackupManager(bytes32 _walletId)
        external view
        returns (address _backupManager)
    {
        return wallets[_walletId].backupManager;
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function getWalletOpType(bytes32 _walletId)
        external view
        returns (bytes32 _opType)
    {
        return wallets[_walletId].opType;
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

    /**
     * @inheritdoc ITeeWalletManager
     */
    function getWalletKeysInfo(bytes32 _walletId)
        external view
        returns (uint64 _multisigThreshold, uint256[] memory _keyIds, uint64 _counter)
    {
        TeeWalletState storage wallet = wallets[_walletId];
        return (wallet.multisigThreshold, wallet.keyIds, wallet.keyIdCounter);
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function getWalletKeyPublicKey(bytes32 _walletId, uint64 _keyId)
        external view
        returns (bytes memory _publicKey)
    {
        return wallets[_walletId].keyDefinitions[_keyId].publicKey;
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function getWalletKeyTeeIds(bytes32 _walletId, uint64 _keyId)
        external view
        returns (address[] memory _teeIds)
    {
        return wallets[_walletId].keyDefinitions[_keyId].teeIds;
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
     * @inheritdoc ITeeWalletManager
     */
    function getSupportedOpTypes()
        external view
        returns (bytes32[] memory _supportedOpTypes)
    {
        return supportedOpTypes.values();
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
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
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
        require(wallets[_walletId].owner == msg.sender, "only owner");
    }

    function _checkOnlyOwnerOrBackupManager(bytes32 _walletId)
        internal view
    {
        require(wallets[_walletId].owner == msg.sender || wallets[_walletId].backupManager == msg.sender,
            "only owner or backup manager");
    }

    function _checkWalletStatus(WalletStatus _actualStatus, WalletStatus _expectedStatus)
        internal pure
    {
        require(_actualStatus == _expectedStatus, "invalid wallet status");
    }
}
