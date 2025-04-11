// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/tee/ITeeDataConnector.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../userInterfaces/IRelay.sol";
import "../interface/IITeeWalletOpTypeConstants.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * TeeWalletManager is used for wallet configurations on TEE machines.
 */
contract TeeWalletManager is ITeeWalletManager, Governed, AddressUpdatable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    struct TeeWalletState {
        bytes32 projectId;
        WalletStatus status;
        uint64 keyIdCounter;
        uint64 multisigThreshold; // number of signatures required - k out of n
        uint256[] keyIds; // n
        mapping(uint256 keyId => KeyDefinition) keyDefinitions;
        PublicKey[] adminsPublicKeys;
        uint256 adminsThreshold;
        mapping(address admin => bool) adminConfirmations;
        address[] cosigners;
        uint256 cosignersThreshold;
        mapping(address cosigner => bool) cosignerConfirmations;
        uint256 feeFactor;
    }

    struct KeyDefinition {
        bytes publicKey;
        string addressStr;
        address[] teeIds;
    }

    uint256 constant private P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

    bytes32 public constant TEE_SOURCE_ID = bytes32("TEE");
    bytes32 public constant WALLET_OP_TYPE = bytes32("WALLET");
    bytes32 public constant KEY_GENERATE = bytes32("KEY_GENERATE");
    bytes32 public constant KEY_DELETE = bytes32("KEY_DELETE");

    uint256 public keyExistenceProofValiditySeconds;
    uint256 public walletCounter = 0;
    mapping(bytes32 walletId => TeeWalletState) private wallets;
    mapping(bytes32 projectId => bytes32[] walletIds) private projectWallets;
    mapping(bytes32 walletId => mapping(uint256 keyId => uint256)) private keyDeleteCounter;

    EnumerableSet.Bytes32Set private supportedOpTypes;
    /// Mapping of operation type to operation type constants provider.
    mapping(bytes32 opType => IITeeWalletOpTypeConstants) public opTypeConstantsProviders;

    /// TEE registry contract.
    ITeeRegistry public teeRegistry;
    /// TEE wallet project manager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// TEE fee calculator contract.
    ITeeFeeCalculator public teeFeeCalculator;
    /// TEE instructions contract.
    ITeeInstructions public teeInstructions;
    /// TEE data connector contract.
    ITeeDataConnector public teeDataConnector;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// Relay contract.
    IRelay public relay;

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
     * @param _keyExistenceProofValiditySeconds The key existence proof validity duration (in seconds).
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint256 _keyExistenceProofValiditySeconds
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        _setKeyExistenceProofValidity(_keyExistenceProofValiditySeconds);
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function createWallet(
        bytes32 _projectId,
        uint64 _multisigThreshold
    )
        external
        returns (bytes32 _walletId)
    {
        require(teeWalletProjectManager.getOwner(_projectId) == msg.sender, "only owner");
        require(_multisigThreshold > 0, "invalid multisig threshold");
        _walletId = keccak256(abi.encode("WALLET", msg.sender, ++walletCounter));
        TeeWalletState storage wallet = wallets[_walletId];
        assert(wallet.projectId == bytes32(0)); // should never revert
        projectWallets[_projectId].push(_walletId);
        wallet.projectId = _projectId;
        wallet.status = WalletStatus.CREATED;
        wallet.multisigThreshold = _multisigThreshold;
        emit WalletCreated(_projectId, _walletId, _multisigThreshold);
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function setAdmins(
        bytes32 _walletId,
        PublicKey[] calldata _adminsPublicKeys,
        uint64 _adminsThreshold
    )
        external onlyOwner(_walletId)
    {
        require(_adminsPublicKeys.length >= _adminsThreshold, "not enough admins");
        require(_adminsThreshold > 0, "invalid admins threshold");
        for (uint256 i = 0; i < _adminsPublicKeys.length; i++) {
            _checkPublicKeyValidity(_adminsPublicKeys[i]);
        }
        TeeWalletState storage wallet = wallets[_walletId];
        _checkWalletStatus(wallet.status, WalletStatus.CREATED);
        // remove all previous admins public keys
        while (wallet.adminsPublicKeys.length > 0) {
            wallet.adminsPublicKeys.pop();
        }
        // add new admins public keys
        for (uint256 i = 0; i < _adminsPublicKeys.length; i++) {
            wallet.adminsPublicKeys.push(_adminsPublicKeys[i]);
        }
        wallet.adminsThreshold = _adminsThreshold;
        emit WalletAdminsSet(_walletId, _adminsPublicKeys, _adminsThreshold);
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function confirmAdmin(bytes32 _walletId)
        external
    {
        TeeWalletState storage wallet = wallets[_walletId];
        _checkWalletStatus(wallet.status, WalletStatus.CREATED);
        for (uint256 i = 0; i < wallet.adminsPublicKeys.length; i++) {
            address adminAddress = _getAddress(wallet.adminsPublicKeys[i]);
            if (adminAddress == msg.sender) {
                wallet.adminConfirmations[msg.sender] = true;
                emit WalletAdminConfirmed(_walletId, msg.sender);
                return;
            }
        }
        revert("invalid admin");
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function setCosigners(
        bytes32 _walletId,
        address[] calldata _cosigners,
        uint64 _cosignersThreshold
    )
        external onlyOwner(_walletId)
    {
        require(_cosigners.length >= _cosignersThreshold, "not enough cosigners");
        require(_cosigners.length == 0 || _cosignersThreshold > 0, "invalid cosigners threshold");
        TeeWalletState storage wallet = wallets[_walletId];
        _checkWalletStatus(wallet.status, WalletStatus.CREATED);
        wallet.cosigners = _cosigners;
        wallet.cosignersThreshold = _cosignersThreshold;
        emit WalletCosignersSet(_walletId, _cosigners, _cosignersThreshold);
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function confirmCosigner(bytes32 _walletId)
        external
    {
        TeeWalletState storage wallet = wallets[_walletId];
        _checkWalletStatus(wallet.status, WalletStatus.CREATED);
        for (uint256 i = 0; i < wallet.cosigners.length; i++) {
            if (wallet.cosigners[i] == msg.sender) {
                wallet.cosignerConfirmations[msg.sender] = true;
                emit WalletCosignerConfirmed(_walletId, msg.sender);
                return;
            }
        }
        revert("invalid cosigner");
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function closeWalletInitialization(
        bytes32 _walletId
    )
        external onlyOwner(_walletId)
    {
        TeeWalletState storage wallet = wallets[_walletId];
        _checkWalletStatus(wallet.status, WalletStatus.CREATED);
        require(wallet.adminsPublicKeys.length > 0, "admins not set");
        for (uint256 i = 0; i < wallet.adminsPublicKeys.length; i++) {
            require(wallet.adminConfirmations[_getAddress(wallet.adminsPublicKeys[i])], "not all admins confirmed");
        }
        for (uint256 i = 0; i < wallet.cosigners.length; i++) {
            require(wallet.cosignerConfirmations[wallet.cosigners[i]], "not all cosigners confirmed");
        }

        wallet.status = WalletStatus.INITIALIZED;
        emit WalletInitialized(_walletId);
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
        bytes32 opType = teeWalletProjectManager.getOpType(wallet.projectId);
        IITeeWalletOpTypeConstants opTypeConstantsProvider = opTypeConstantsProviders[opType];
        require(address(opTypeConstantsProvider) != address(0), "op type not supported");
        _checkFee(KEY_GENERATE, _teeId, new address[](0));
        _keyId = wallet.keyIdCounter++;

        emit WalletKeyAdded(_teeId, _walletId, _keyId);

        KeyGenerate memory message = KeyGenerate({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            opType: opType,
            opTypeConstants: opTypeConstantsProvider.getOpTypeConstants(_walletId),
            adminsPublicKeys: wallet.adminsPublicKeys,
            adminsThreshold: wallet.adminsThreshold,
            cosigners: wallet.cosigners,
            cosignersThreshold: wallet.cosignersThreshold
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

    /**
     * @inheritdoc ITeeWalletManager
     */
    function requestKeyExistenceAttestation(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId
    )
        external payable
    {
        _checkTeeStatus(_teeId);
        TeeWalletState storage wallet = wallets[_walletId];
        require(wallet.keyIdCounter > _keyId, "invalid key id");
        bytes32 opType = teeWalletProjectManager.getOpType(wallet.projectId);
        ITeeKeyExistence.RequestBody memory requestBody = ITeeKeyExistence.RequestBody({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            opType: opType
        });
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;

        teeDataConnector.requestAttestation{value: msg.value}(
            0,
            0,
            teeIds,
            bytes.concat(TEE_KEY_EXISTENCE_ATTESTATION_TYPE, TEE_SOURCE_ID, abi.encode(requestBody))
        );
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function confirmKey(
        ITeeKeyExistence.Proof calldata _proof
    )
        external onlyOwnerOrBackupManager(_proof.data.requestBody.walletId)
    {
        bytes32 walletId = _proof.data.requestBody.walletId;
        uint256 keyId = _proof.data.requestBody.keyId;
        TeeWalletState storage wallet = wallets[walletId];
        require(wallet.keyIdCounter > keyId, "invalid key id");
        require(_proof.data.responseBody.publicKey.length > 0, "invalid public key");
        address teeId = _proof.data.requestBody.teeId;
        require(_proof.data.thresholdBIPS == 0, "random threshold not supported");
        require(_proof.data.attestationType == TEE_KEY_EXISTENCE_ATTESTATION_TYPE, "invalid attestation type");
        require(_proof.data.sourceId == TEE_SOURCE_ID, "invalid source id");

        uint256 timestamp = _proof.data.timestamp;
        require(timestamp < block.timestamp, "timestamp in the future");
        require(timestamp + keyExistenceProofValiditySeconds > block.timestamp,
            "key existence proof expired");
        // TODO validate proof
        // bytes32 dataHash = keccak256(abi.encode(_proof.data));
        // // 1 byte (protocolId=1), 4 bytes (votingRoundId=0), 1 byte (isSecureRandom=false), 32 bytes (dataHash)
        // bytes memory relayMessage = bytes.concat(bytes1(uint8(1)), bytes5(0), dataHash);
        // bytes32 messageHash = keccak256(relayMessage);
        // uint256 rewardEpochId = relay.verifyCustomSignature(_proof.relayMessage, messageHash);
        // uint256 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        // require(rewardEpochId == currentRewardEpochId || rewardEpochId + 1 == currentRewardEpochId,
        //     "too old signing policy");

        wallet.feeFactor++;
        KeyDefinition storage keyDefinition = wallet.keyDefinitions[keyId];
        if (keyDefinition.publicKey.length > 0) {
            // add tee id to existing key definition
            require(
                keccak256(keyDefinition.publicKey) == keccak256(_proof.data.responseBody.publicKey),
                "invalid public key"
            );
            require(
                keccak256(bytes(keyDefinition.addressStr)) == keccak256(bytes(_proof.data.responseBody.addressStr)),
                "invalid address"
            );
            address[] storage keyDefinitionTeeIds = keyDefinition.teeIds;
            for (uint256 i = 0; i < keyDefinitionTeeIds.length; i++) {
                require(keyDefinitionTeeIds[i] != teeId, "tee id already added");
            }
            // tee id not found, add it
            keyDefinitionTeeIds.push(teeId);
        } else {
            // new key definition can only be added if wallet is in status initialized
            _checkWalletStatus(wallet.status, WalletStatus.INITIALIZED);
            // new key definition can only be added by the owner
            _checkOnlyOwner(walletId);
            // add new key id
            wallet.keyIds.push(keyId);
            // set public key and add tee id
            keyDefinition.publicKey = _proof.data.responseBody.publicKey;
            keyDefinition.addressStr = _proof.data.responseBody.addressStr;
            keyDefinition.teeIds.push(teeId);
        }
        emit WalletKeyConfirmed(
            teeId,
            walletId,
            keyId,
            _proof.data.responseBody.publicKey,
            _proof.data.responseBody.addressStr
        );
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
        _checkTeeStatus(_teeId);
        TeeWalletState storage wallet = wallets[_walletId];
        require(wallet.keyIdCounter > _keyId, "invalid key id");
        KeyDefinition storage keyDefinition = wallet.keyDefinitions[_keyId];
        require(keyDefinition.publicKey.length > 0, "invalid key id");
        _checkFee(KEY_DELETE, _teeId, new address[](0));
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
                wallet.feeFactor--;
            }
        }

        emit WalletKeyDeleted(_teeId, _walletId, _keyId);

        // trigger key delete instruction (even if no tee id found, but machine is in production status - retry)
        KeyDelete memory message = KeyDelete({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId
        });
        bytes32 instructionId = keccak256(abi.encode(
            WALLET_OP_TYPE, KEY_DELETE, _walletId, _keyId, keyDeleteCounter[_walletId][_keyId]++
        ));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            _getTeeMachines(_teeId),
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            KEY_DELETE,
            abi.encode(message)
        );
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function cleanUpTeeIds(
        bytes32 _walletId,
        uint64 _keyId
    )
        external
        onlyOwnerOrBackupManager(_walletId)
    {
        TeeWalletState storage wallet = wallets[_walletId];
        KeyDefinition storage keyDefinition = wallet.keyDefinitions[_keyId];
        require(wallet.keyIdCounter > _keyId, "invalid key id");
        require(keyDefinition.publicKey.length > 0, "invalid key id");
        address[] storage teeIds = keyDefinition.teeIds;
        for (uint256 i = teeIds.length; i > 0; i--) {
            if (teeRegistry.getTeeMachineStatus(teeIds[i - 1]) != ITeeRegistry.TeeStatus.PRODUCTION) {
                // delete tee id from key definition
                teeIds[i - 1] = teeIds[teeIds.length - 1];
                teeIds.pop();
                wallet.feeFactor--;
            }
        }
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function enableWallet(bytes32 _walletId)
        external onlyOwner(_walletId)
    {
        TeeWalletState storage wallet = wallets[_walletId];
        WalletStatus status = wallet.status;
        require(status == WalletStatus.INITIALIZED || status == WalletStatus.PAUSED, "invalid wallet status");
        if (status == WalletStatus.INITIALIZED) {
            require(wallet.keyIds.length >= wallet.multisigThreshold, "not enough keys");
        }
        wallet.status = WalletStatus.PRODUCTION;
        emit WalletEnabled(_walletId);
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function pauseWallet(bytes32 _walletId)
        external onlyOwner(_walletId)
    {
        TeeWalletState storage wallet = wallets[_walletId];
        _checkWalletStatus(wallet.status, WalletStatus.PRODUCTION);
        wallet.status = WalletStatus.PAUSED;
        emit WalletPaused(_walletId);
    }

     /**
     * @inheritdoc ITeeWalletManager
     */
    function receivingTeesAndKeys(bytes32 _walletId)
        external
        returns (ITeeRegistry.TeeMachine[] memory _receivingTees, TeeIdKeyIdPair[] memory _teeIdKeyIdPairs)
    {
        TeeWalletState storage wallet = wallets[_walletId];
        uint256 keyIdsLength = wallet.keyIds.length;
        uint256 count = 0;
        for (uint256 i = 0; i < keyIdsLength; i++) {
            count += wallet.keyDefinitions[wallet.keyIds[i]].teeIds.length;
        }
        uint256[] memory unavailableKeyIds = new uint256[](keyIdsLength);
        address[] memory teeMachines = new address[](count);
        uint256[] memory keyIds = new uint256[](count);
        count = 0;
        uint256 threshold = 0;
        uint256 unavailableKeyIdsCounter = 0;
        for (uint256 i = 0; i < keyIdsLength; i++) {
            bool keyAvailable = false;
            uint256 keyId = wallet.keyIds[i];
            KeyDefinition storage keyDefinition = wallet.keyDefinitions[keyId];
            for (uint256 j = 0; j < keyDefinition.teeIds.length; j++) {
                if (teeRegistry.getTeeMachineStatus(keyDefinition.teeIds[j]) == ITeeRegistry.TeeStatus.PRODUCTION) {
                    keyAvailable = true;
                    teeMachines[count] = keyDefinition.teeIds[j];
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
        require(threshold >= wallet.multisigThreshold, "not enough keys/tees available");
        _receivingTees = new ITeeRegistry.TeeMachine[](count);
        _teeIdKeyIdPairs = new TeeIdKeyIdPair[](count);
        for (uint256 i = 0; i < count; i++) {
            _receivingTees[i] = teeRegistry.getTeeMachine(teeMachines[i]);
            _teeIdKeyIdPairs[i] = TeeIdKeyIdPair({
                teeId: teeMachines[i],
                keyId: keyIds[i]
            });
        }
        if (unavailableKeyIdsCounter > 0) {
            uint256[] memory unavailableKeyIdsTrimmed = new uint256[](unavailableKeyIdsCounter);
            for (uint256 i = 0; i < unavailableKeyIdsCounter; i++) {
                unavailableKeyIdsTrimmed[i] = unavailableKeyIds[i];
            }
            emit WalletKeysNotAvailable(_walletId, unavailableKeyIdsTrimmed);
        }
    }

    /**
     * Add supported operation types and their constants providers.
     * @param _opTypeConstantsProviders The operation type constants providers for the operation types.
     * Can only be called by the governance.
     */
    function addSupportedOpTypes(IITeeWalletOpTypeConstants[] calldata _opTypeConstantsProviders)
        external onlyGovernance
    {
        for (uint256 i = 0; i < _opTypeConstantsProviders.length; i++) {
            IITeeWalletOpTypeConstants opTypeConstantsProvider = _opTypeConstantsProviders[i];
            bytes32 opType = opTypeConstantsProvider.opType();
            supportedOpTypes.add(opType);
            opTypeConstantsProviders[opType] = opTypeConstantsProvider;
        }
    }

    /**
     * Remove supported operation types.
     * @param _opTypes The operation types to remove.
     * Can only be called by the governance.
     */
    function removeSupportedOpTypes(bytes32[] memory _opTypes)
        external onlyGovernance
    {
        for (uint256 i = 0; i < _opTypes.length; i++) {
            supportedOpTypes.remove(_opTypes[i]);
            delete opTypeConstantsProviders[_opTypes[i]];
        }
    }

    /**
     * Set the key existence proof validity duration.
     * @param _keyExistenceProofValiditySeconds The key existence proof validity duration (in seconds).
     * Can only be called by the governance.
     */
    function setKeyExistenceProofValiditySeconds(uint256 _keyExistenceProofValiditySeconds)
        external onlyGovernance
    {
        _setKeyExistenceProofValidity(_keyExistenceProofValiditySeconds);
    }


    /**
     * @inheritdoc ITeeWalletManager
     */
     function getProjectWalletIds(bytes32 _projectId)
        external view
        returns (bytes32[] memory _walletIds)
    {
        return projectWallets[_projectId];
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function getWalletProjectId(bytes32 _walletId)
        external view
        returns (bytes32 _projectId)
    {
        return wallets[_walletId].projectId;
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
    function getWalletKeyAddress(bytes32 _walletId, uint64 _keyId)
        external view
        returns (string memory _addressStr)
    {
        return wallets[_walletId].keyDefinitions[_keyId].addressStr;
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

    function getWalletAdminsAndThreshold(bytes32 _walletId)
        external view
        returns (PublicKey[] memory _adminsPublicKeys, uint256 _adminsThreshold)
    {
        TeeWalletState storage wallet = wallets[_walletId];
        _adminsPublicKeys = wallet.adminsPublicKeys;
        _adminsThreshold = wallet.adminsThreshold;
    }

    function getWalletCosignersAndThreshold(bytes32 _walletId)
        external view
        returns (address[] memory _cosigners, uint256 _cosignersThreshold)
    {
        TeeWalletState storage wallet = wallets[_walletId];
        _cosigners = wallet.cosigners;
        _cosignersThreshold = wallet.cosignersThreshold;
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
     * @inheritdoc ITeeWalletManager
     */
    function isOpTypeSupported(bytes32 _opType)
        external view
        returns (bool)
    {
        return supportedOpTypes.contains(_opType);
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
        teeWalletProjectManager = ITeeWalletProjectManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletProjectManager"));
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
        teeDataConnector = ITeeDataConnector(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeDataConnector"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }

    function _setKeyExistenceProofValidity(uint256 _keyExistenceProofValiditySeconds) internal {
        require(_keyExistenceProofValiditySeconds >= 1 minutes && _keyExistenceProofValiditySeconds <= 1 days,
            "invalid duration");
        keyExistenceProofValiditySeconds = _keyExistenceProofValiditySeconds;
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
        returns (ITeeRegistry.TeeMachine[] memory)
    {
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = teeRegistry.getTeeMachine(_teeId);
        return teeMachines;
    }

    function _checkOnlyOwner(bytes32 _walletId)
        internal view
    {
        address owner = teeWalletProjectManager.getOwner(wallets[_walletId].projectId);
        require(owner == msg.sender, "only owner");
    }

    function _checkOnlyOwnerOrBackupManager(bytes32 _walletId)
        internal view
    {
        bytes32 projectId = wallets[_walletId].projectId;
        require(
            teeWalletProjectManager.getOwner(projectId) == msg.sender ||
            teeWalletProjectManager.getBackupManager(projectId) == msg.sender,
            "only owner or backup manager"
        );
    }

    function _getAddress(PublicKey storage _pk) internal view returns (address) {
        uint256[2] memory publicKeyPair = [uint256(_pk.x), uint256(_pk.y)];
        bytes32 hash = keccak256(abi.encodePacked(publicKeyPair));
        return address(uint160(uint256(hash)));
    }

    function _checkWalletStatus(WalletStatus _actualStatus, WalletStatus _expectedStatus)
        internal pure
    {
        require(_actualStatus == _expectedStatus, "invalid wallet status");
    }

    function _checkPublicKeyValidity(PublicKey calldata _pk) internal pure {
        uint256 x = uint256(_pk.x);
        uint256 y = uint256(_pk.y);
        require(
            x < P && x > 0 && y < P && y > 0 && mulmod(y, y, P) == addmod(mulmod(mulmod(x, x, P), x, P), 7, P),
            "invalid public key"
        );
    }
}
