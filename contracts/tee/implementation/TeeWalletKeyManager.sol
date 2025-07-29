// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./TeeBase.sol";
import "../interface/IITeeWalletKeyManager.sol";
import "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../../userInterfaces/tee/ITeeWalletBackupManager.sol";
import "../../userInterfaces/tee/ITeeMachineRegistry.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * TeeWalletKeyManager contract used for wallet keys configuration on TEE machines.
 */
contract TeeWalletKeyManager is IITeeWalletKeyManager, TeeBase {

    struct TeeWalletKeysState {
        uint64 keyIdCounter;
        uint64 multisigThreshold; // number of signatures required - k out of n
        uint64[] keyIds; // n
        mapping(uint64 keyId => KeyDefinition) keyDefinitions;
    }

    struct KeyDefinition {
        bytes publicKey;
        string addressStr;
        mapping(address teeId => uint256 nonce) nonces;
        address[] teeIds;
    }

    bytes32 public constant WALLET_OP_TYPE = bytes32("F_WALLET");
    bytes32 public constant KEY_GENERATE = bytes32("KEY_GENERATE");
    bytes32 public constant KEY_DELETE = bytes32("KEY_DELETE");

    mapping(bytes32 walletId => TeeWalletKeysState) private walletKeys;
    mapping(bytes32 walletId => mapping(uint64 keyId => uint256)) private keyDeleteCounter;

    /// TEE extension registry contract.
    ITeeExtensionRegistry public teeExtensionRegistry;
    /// TEE machine registry contract.
    ITeeMachineRegistry public teeMachineRegistry;
    /// TEE wallet project manager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// TEE wallet manager contract.
    ITeeWalletManager public teeWalletManager;
    /// TEE wallet backup manager contract.
    ITeeWalletBackupManager public teeWalletBackupManager;
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

    modifier onlyTeeWalletBackupManager {
        require(msg.sender == address(teeWalletBackupManager), "only backup manager");
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
     * @inheritdoc ITeeWalletKeyManager
     */
    function setMultisigThreshold(
        bytes32 _walletId,
        uint64 _multisigThreshold
    )
        external onlyOwner(_walletId)
    {
        require(_multisigThreshold > 0, "invalid threshold");
        _checkWalletStatus(_walletId, ITeeWalletManager.WalletStatus.INITIALIZED);
        TeeWalletKeysState storage keys = walletKeys[_walletId];
        keys.multisigThreshold = _multisigThreshold;

        emit WalletMultisigThresholdSet(_walletId, _multisigThreshold);
    }

    /**
     * @inheritdoc ITeeWalletKeyManager
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
        TeeWalletKeysState storage keys = walletKeys[_walletId];
        _checkWalletStatus(_walletId, ITeeWalletManager.WalletStatus.INITIALIZED);
        _keyId = keys.keyIdCounter++;

        emit WalletKeyAdded(_teeId, _walletId, _keyId);

        (PublicKey[] memory adminsPublicKeys, uint64 adminsThreshold) =
            teeWalletManager.getWalletAdminsAndThreshold(_walletId);
        (address[] memory cosigners, uint64 cosignersThreshold) =
            teeWalletManager.getWalletCosignersAndThreshold(_walletId);

        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        KeyGenerate memory message = KeyGenerate({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            opType: teeWalletProjectManager.getOpType(projectId),
            configConstants: KeyConfigConstants({
                adminsPublicKeys: adminsPublicKeys,
                adminsThreshold: adminsThreshold,
                cosigners: cosigners,
                cosignersThreshold: cosignersThreshold,
                opTypeConstants: teeWalletProjectManager.getOpTypeConstants(projectId)
            })
        });
        bytes32 instructionId = keccak256(abi.encode(
            WALLET_OP_TYPE, KEY_GENERATE, _walletId, _keyId
        ));

        _sendInstructions(instructionId, _teeId, KEY_GENERATE, abi.encode(message));
    }

    /**
     * @inheritdoc ITeeWalletKeyManager
     */
    function confirmKey(
        KeyExistence calldata _proof,
        Signature calldata _teeSignature
    )
        external onlyOwnerOrBackupManager(_proof.walletId)
    {
        _checkTeeStatus(_proof.teeId);
        bytes32 walletId = _proof.walletId;
        uint64 keyId = _proof.keyId;
        TeeWalletKeysState storage keys = walletKeys[walletId];
        require(keys.keyIdCounter > keyId, "invalid key id");
        KeyDefinition storage keyDefinition = keys.keyDefinitions[keyId];
        // check nonce
        require(_proof.nonce == keyDefinition.nonces[_proof.teeId], "invalid nonce");
        // check op type
        bytes32 opType = teeWalletProjectManager.getOpType(teeWalletManager.getWalletProjectId(walletId));
        require(_proof.opType == opType, "invalid op type");
        // check config constants
        _validateKeyExistenceConfigConstants(walletId, _proof.configConstants);
        // check TEE signature
        address teeId = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(keccak256(abi.encode(_proof))),
            _teeSignature.v,
            _teeSignature.r,
            _teeSignature.s
        );
        require(teeId == _proof.teeId, "invalid tee signature");

        // add TEE id to the key definition
        if (keyDefinition.publicKey.length > 0) {
            // check that key is restored on the tee machine
            require(_proof.nonce > 0 && _proof.restored, "key not restored on TEE machine");
            // add tee id to existing key definition
            require(
                keccak256(keyDefinition.publicKey) == keccak256(_proof.publicKey),
                "invalid public key"
            );
            require(
                keccak256(bytes(keyDefinition.addressStr)) == keccak256(bytes(_proof.addressStr)),
                "invalid address"
            );
            address[] storage keyDefinitionTeeIds = keyDefinition.teeIds;
            for (uint256 i = 0; i < keyDefinitionTeeIds.length; i++) {
                require(keyDefinitionTeeIds[i] != teeId, "tee id already added");
            }
            // tee id not found, add it
            keyDefinitionTeeIds.push(teeId);
        } else {
            require(_proof.publicKey.length > 0, "invalid public key");
            require(bytes(_proof.addressStr).length > 0, "invalid address");
            // new key definition can only be added if wallet is in status initialized
            _checkWalletStatus(walletId, ITeeWalletManager.WalletStatus.INITIALIZED);
            // new key definition can only be added by the owner
            _checkOnlyOwner(walletId);
            // check that key is generated on the tee machine
            require(_proof.nonce == 0 && !_proof.restored, "key not generated on TEE machine");
            // add new key id
            keys.keyIds.push(keyId);
            // set public key, address and add tee id
            keyDefinition.publicKey = _proof.publicKey;
            keyDefinition.addressStr = _proof.addressStr;
            keyDefinition.teeIds.push(teeId);
        }

        emit WalletKeyConfirmed(
            teeId,
            walletId,
            keyId,
            _proof.publicKey,
            _proof.addressStr
        );
    }

    /**
     * @inheritdoc ITeeWalletKeyManager
     */
    function deleteKey(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId
    )
        external payable
        onlyOwner(_walletId)
    {
        _checkTeeStatus(_teeId);
        TeeWalletKeysState storage keys = walletKeys[_walletId];
        KeyDefinition storage keyDefinition = keys.keyDefinitions[_keyId];
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
                keyDefinition.teeIds[index] = keyDefinition.teeIds[length - 1];
                keyDefinition.teeIds.pop();
            }
        }

        emit WalletKeyDeleted(_teeId, _walletId, _keyId);

        // trigger key delete instruction (even if no tee id found, but machine is in production status - retry)
        KeyDelete memory message = KeyDelete({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            nonce: ++keyDefinition.nonces[_teeId]
        });
        bytes32 instructionId = keccak256(abi.encode(
            WALLET_OP_TYPE, KEY_DELETE, _walletId, _keyId, keyDeleteCounter[_walletId][_keyId]++
        ));

        _sendInstructions(instructionId, _teeId, KEY_DELETE, abi.encode(message));
    }

    /**
     * @inheritdoc ITeeWalletKeyManager
     */
    function cleanUpTeeIds(
        bytes32 _walletId,
        uint64 _keyId
    )
        external
        onlyOwnerOrBackupManager(_walletId)
    {
        TeeWalletKeysState storage keys = walletKeys[_walletId];
        KeyDefinition storage keyDefinition = keys.keyDefinitions[_keyId];
        require(keyDefinition.publicKey.length > 0, "invalid key id");
        address[] storage teeIds = keyDefinition.teeIds;
        for (uint256 i = teeIds.length; i > 0; i--) {
            if (teeMachineRegistry.getTeeMachineStatus(teeIds[i - 1]) != ITeeMachineRegistry.TeeStatus.PRODUCTION) {
                // delete tee id from key definition
                teeIds[i - 1] = teeIds[teeIds.length - 1];
                teeIds.pop();
            }
        }
    }

     /**
     * @inheritdoc ITeeWalletKeyManager
     */
    function receivingTeesAndKeys(bytes32 _walletId)
        external
        returns (TeeIdKeyIdPair[] memory _teeIdKeyIdPairs)
    {
        TeeWalletKeysState storage keys = walletKeys[_walletId];
        uint256 keyIdsLength = keys.keyIds.length;
        uint256 count = 0;
        for (uint256 i = 0; i < keyIdsLength; i++) {
            count += keys.keyDefinitions[keys.keyIds[i]].teeIds.length;
        }
        uint64[] memory unavailableKeyIds = new uint64[](keyIdsLength);
        address[] memory teeIds = new address[](count);
        uint64[] memory keyIds = new uint64[](count);
        count = 0;
        uint256 threshold = 0;
        uint256 unavailableKeyIdsCounter = 0;
        for (uint256 i = 0; i < keyIdsLength; i++) {
            bool keyAvailable = false;
            uint64 keyId = keys.keyIds[i];
            KeyDefinition storage keyDefinition = keys.keyDefinitions[keyId];
            for (uint256 j = 0; j < keyDefinition.teeIds.length; j++) {
                ITeeMachineRegistry.TeeStatus status = teeMachineRegistry.getTeeMachineStatus(keyDefinition.teeIds[j]);
                if (status == ITeeMachineRegistry.TeeStatus.PRODUCTION) {
                    keyAvailable = true;
                    teeIds[count] = keyDefinition.teeIds[j];
                    keyIds[count] = keyId;
                    count++;
                }
            }
            if (keyAvailable) {
                threshold++;
            } else {
                unavailableKeyIds[unavailableKeyIdsCounter++] = keyId;
            }
        }
        require(threshold >= keys.multisigThreshold, "threshold not met");
        _teeIdKeyIdPairs = new TeeIdKeyIdPair[](count);
        for (uint256 i = 0; i < count; i++) {
            _teeIdKeyIdPairs[i] = TeeIdKeyIdPair({
                teeId: teeIds[i],
                keyId: keyIds[i]
            });
        }
        if (unavailableKeyIdsCounter > 0) {
            uint64[] memory unavailableKeyIdsTrimmed = new uint64[](unavailableKeyIdsCounter);
            for (uint256 i = 0; i < unavailableKeyIdsCounter; i++) {
                unavailableKeyIdsTrimmed[i] = unavailableKeyIds[i];
            }
            emit WalletKeysNotAvailable(_walletId, unavailableKeyIdsTrimmed);
        }
    }

    /**
     * @inheritdoc IITeeWalletKeyManager
     */
    function increaseKeyNonce(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId
    )
        external onlyTeeWalletBackupManager
        returns (uint256 _nonce)
    {
        TeeWalletKeysState storage keys = walletKeys[_walletId];
        KeyDefinition storage keyDefinition = keys.keyDefinitions[_keyId];
        require(keyDefinition.publicKey.length > 0, "invalid key id");
        return ++keyDefinition.nonces[_teeId];
    }

    /**
     * @inheritdoc ITeeWalletKeyManager
     */
    function getWalletKeysInfo(bytes32 _walletId)
        external view
        returns (uint64 _multisigThreshold, uint64[] memory _keyIds, uint64 _counter)
    {
        TeeWalletKeysState storage keys = walletKeys[_walletId];
        return (keys.multisigThreshold, keys.keyIds, keys.keyIdCounter);
    }

    /**
     * @inheritdoc ITeeWalletKeyManager
     */
    function getWalletKeyPublicKey(bytes32 _walletId, uint64 _keyId)
        external view
        returns (bytes memory _publicKey)
    {
        return walletKeys[_walletId].keyDefinitions[_keyId].publicKey;
    }

    /**
     * @inheritdoc ITeeWalletKeyManager
     */
    function getWalletKeyAddress(bytes32 _walletId, uint64 _keyId)
        external view
        returns (string memory _addressStr)
    {
        return walletKeys[_walletId].keyDefinitions[_keyId].addressStr;
    }

    /**
     * @inheritdoc ITeeWalletKeyManager
     */
    function getWalletKeyTeeIds(bytes32 _walletId, uint64 _keyId)
        external view
        returns (address[] memory _teeIds)
    {
        return walletKeys[_walletId].keyDefinitions[_keyId].teeIds;
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
        teeWalletBackupManager = ITeeWalletBackupManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletBackupManager"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
    }

    function _sendInstructions(
        bytes32 _instructionId,
        address _teeId,
        bytes32 _opCommand,
        bytes memory _message
    )
        internal
    {
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        teeExtensionRegistry.sendInstructions{value: msg.value}(
            _instructionId,
            teeMachineRegistry.getExtensionId(_teeId),
            teeIds,
            WALLET_OP_TYPE,
            _opCommand,
            _message
        );
    }

    function _validateKeyExistenceConfigConstants(bytes32 _walletId, KeyConfigConstants calldata _configConstants)
        internal view
    {
        (PublicKey[] memory _adminsPublicKeys, uint64 _adminsThreshold) =
            teeWalletManager.getWalletAdminsAndThreshold(_walletId);
        require(_configConstants.adminsPublicKeys.length == _adminsPublicKeys.length, "lengths mismatch");
        require(_configConstants.adminsThreshold == _adminsThreshold, "invalid threshold");
        for (uint256 i = 0; i < _adminsPublicKeys.length; i++) {
            require(
                _configConstants.adminsPublicKeys[i].x == _adminsPublicKeys[i].x &&
                _configConstants.adminsPublicKeys[i].y == _adminsPublicKeys[i].y,
                "invalid public key"
            );
        }
        (address[] memory _cosigners, uint64 _cosignersThreshold) =
            teeWalletManager.getWalletCosignersAndThreshold(_walletId);
        require(_configConstants.cosigners.length == _cosigners.length, "lengths mismatch");
        require(_configConstants.cosignersThreshold == _cosignersThreshold, "invalid threshold");
        for (uint256 i = 0; i < _cosigners.length; i++) {
            require(_configConstants.cosigners[i] == _cosigners[i], "invalid address");
        }

        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        bytes memory opTypeConstants = teeWalletProjectManager.getOpTypeConstants(projectId);
        require(
            keccak256(_configConstants.opTypeConstants) == keccak256(opTypeConstants),
            "invalid op type constants"
        );
    }

    function _checkTeeStatus(address _teeId)
        internal view
    {
        require(
            teeMachineRegistry.getTeeMachineStatus(_teeId) == ITeeMachineRegistry.TeeStatus.PRODUCTION,
            "tee machine not available"
        );
    }

    function _checkOnlyOwner(bytes32 _walletId)
        internal view
    {
        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        address owner = teeWalletProjectManager.getOwner(projectId);
        require(owner == msg.sender, "only owner");
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

    function _checkWalletStatus(
        bytes32 _walletId,
        ITeeWalletManager.WalletStatus _expectedStatus
    )
        internal view
    {
        require(teeWalletManager.getWalletStatus(_walletId) == _expectedStatus, "invalid wallet status");
    }
}
