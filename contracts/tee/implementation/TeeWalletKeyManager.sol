// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../interface/IITeeWalletManager.sol";
import "../../userInterfaces/tee/ITeeWalletKeyManager.sol";
import "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/ftdc/IFtdcHub.sol";
import "../../userInterfaces/ftdc/IFtdcVerification.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../interface/IITeeWalletOpTypeConstants.sol";
import "../../governance/implementation/GovernedProxyImplementation.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * TeeWalletKeyManager contract used for wallet keys configuration on TEE machines.
 */
contract TeeWalletKeyManager is ITeeWalletKeyManager, GovernedProxyImplementation, AddressUpdatable, UUPSUpgradeable {

    struct TeeWalletKeysState {
        uint256 keyIdCounter;
        uint256 multisigThreshold; // number of signatures required - k out of n
        uint256[] keyIds; // n
        mapping(uint256 keyId => KeyDefinition) keyDefinitions;
        uint256 feeFactor;
    }

    struct KeyDefinition {
        bytes publicKey;
        string addressStr;
        address[] teeIds;
    }

    bytes32 public constant TEE_SOURCE_ID = bytes32("TEE");
    bytes32 public constant WALLET_OP_TYPE = bytes32("WALLET");
    bytes32 public constant KEY_GENERATE = bytes32("KEY_GENERATE");
    bytes32 public constant KEY_DELETE = bytes32("KEY_DELETE");

    uint256 public keyExistenceProofValiditySeconds;
    mapping(bytes32 walletId => TeeWalletKeysState) private walletKeys;
    mapping(bytes32 walletId => mapping(uint256 keyId => uint256)) private keyDeleteCounter;

    /// TEE registry contract.
    ITeeRegistry public teeRegistry;
    /// TEE wallet project manager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// TEE wallet manager contract.
    IITeeWalletManager public teeWalletManager;
    /// TEE fee calculator contract.
    ITeeFeeCalculator public teeFeeCalculator;
    /// TEE instructions contract.
    ITeeInstructions public teeInstructions;
    /// Flare TEE data connector contract.
    IFtdcHub public ftdcHub;
    /// FTDC verification contract.
    IFtdcVerification public ftdcVerification;
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
        address _addressUpdater,
        uint256 _keyExistenceProofValiditySeconds
    )
        external
    {
        GovernedBase.initialise(_governanceSettings, _initialGovernance);
        AddressUpdatable.setAddressUpdaterValue(_addressUpdater);

        _setKeyExistenceProofValidity(_keyExistenceProofValiditySeconds);
    }

    /**
     * @inheritdoc ITeeWalletKeyManager
     */
    function setMultisigThreshold(
        bytes32 _walletId,
        uint256 _multisigThreshold
    )
        external onlyOwner(_walletId)
    {
        require(_multisigThreshold > 0, "invalid multisig threshold");
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
        returns (uint256 _keyId)
    {
        _checkTeeStatus(_teeId);
        TeeWalletKeysState storage keys = walletKeys[_walletId];
        _checkWalletStatus(_walletId, ITeeWalletManager.WalletStatus.INITIALIZED);
        _checkFee(KEY_GENERATE, _teeId);
        _keyId = keys.keyIdCounter++;

        emit WalletKeyAdded(_teeId, _walletId, _keyId);

        (PublicKey[] memory adminsPublicKeys, uint256 adminsThreshold) =
            teeWalletManager.getWalletAdminsAndThreshold(_walletId);
        (address[] memory cosigners, uint256 cosignersThreshold) =
            teeWalletManager.getWalletCosignersAndThreshold(_walletId);

        KeyGenerate memory message = KeyGenerate({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            opType: teeWalletProjectManager.getOpType(teeWalletManager.getWalletProjectId(_walletId)),
            opTypeConstants: teeWalletManager.getOpTypeConstants(_walletId),
            adminsPublicKeys: adminsPublicKeys,
            adminsThreshold: adminsThreshold,
            cosigners: cosigners,
            cosignersThreshold: cosignersThreshold
        });
        bytes32 instructionId = keccak256(abi.encode(
            WALLET_OP_TYPE, KEY_GENERATE, _walletId, _keyId
        ));
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
     * @inheritdoc ITeeWalletKeyManager
     */
    function requestKeyExistenceAttestation(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId
    )
        external payable
    {
        _checkTeeStatus(_teeId);
        TeeWalletKeysState storage keys = walletKeys[_walletId];
        require(keys.keyIdCounter > _keyId, "invalid key id");
        ITeeKeyExistence.RequestBody memory requestBody = ITeeKeyExistence.RequestBody({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            opType: teeWalletProjectManager.getOpType(teeWalletManager.getWalletProjectId(_walletId))
        });
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;

        ftdcHub.requestAttestation{value: msg.value}(
            0,
            0,
            teeIds,
            bytes.concat(TEE_KEY_EXISTENCE_ATTESTATION_TYPE, TEE_SOURCE_ID, abi.encode(requestBody))
        );
    }

    /**
     * @inheritdoc ITeeWalletKeyManager
     */
    function confirmKey(
        ITeeKeyExistence.Proof calldata _proof
    )
        external onlyOwnerOrBackupManager(_proof.data.requestBody.walletId)
    {
        bytes32 walletId = _proof.data.requestBody.walletId;
        uint256 keyId = _proof.data.requestBody.keyId;
        TeeWalletKeysState storage keys = walletKeys[walletId];
        require(keys.keyIdCounter > keyId, "invalid key id");
        require(_proof.data.responseBody.publicKey.length > 0, "invalid public key");
        address teeId = _proof.data.requestBody.teeId;
        require(_proof.data.thresholdBIPS == 0, "random threshold not supported");
        require(_proof.data.attestationType == TEE_KEY_EXISTENCE_ATTESTATION_TYPE, "invalid attestation type");
        require(_proof.data.sourceId == TEE_SOURCE_ID, "invalid source id");

        uint256 timestamp = _proof.data.timestamp;
        require(timestamp < block.timestamp, "timestamp in the future");
        require(timestamp + keyExistenceProofValiditySeconds > block.timestamp,
            "key existence proof expired");
        uint256 rewardEpochId = ftdcVerification.verifySigningPolicySignatures(
            _proof.relayMessage,
            keccak256(abi.encode(_proof.data))
        );
        uint256 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        require(rewardEpochId == currentRewardEpochId || rewardEpochId + 1 == currentRewardEpochId,
            "too old signing policy");

        keys.feeFactor++;
        KeyDefinition storage keyDefinition = keys.keyDefinitions[keyId];
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
            _checkWalletStatus(walletId, ITeeWalletManager.WalletStatus.INITIALIZED);
            // new key definition can only be added by the owner
            _checkOnlyOwner(walletId);
            // new key must be signed by the tee machine, so that it confirms the key generation on it
            address[] memory teeIds = ftdcVerification.verifyTeeSignatures(
                _proof.teeSignatures,
                keccak256(abi.encode(_proof.data))
            );
            require(teeIds.length == 1 && teeIds[0] == teeId, "invalid tee signature");
            // add new key id
            keys.keyIds.push(keyId);
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
        require(keys.keyIdCounter > _keyId, "invalid key id");
        KeyDefinition storage keyDefinition = keys.keyDefinitions[_keyId];
        require(keyDefinition.publicKey.length > 0, "invalid key id");
        _checkFee(KEY_DELETE, _teeId);
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
                keys.feeFactor--;
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
        require(keys.keyIdCounter > _keyId, "invalid key id");
        KeyDefinition storage keyDefinition = keys.keyDefinitions[_keyId];
        require(keyDefinition.publicKey.length > 0, "invalid key id");
        address[] storage teeIds = keyDefinition.teeIds;
        for (uint256 i = teeIds.length; i > 0; i--) {
            if (teeRegistry.getTeeMachineStatus(teeIds[i - 1]) != ITeeRegistry.TeeStatus.PRODUCTION) {
                // delete tee id from key definition
                teeIds[i - 1] = teeIds[teeIds.length - 1];
                teeIds.pop();
                keys.feeFactor--;
            }
        }
    }

     /**
     * @inheritdoc ITeeWalletKeyManager
     */
    function receivingTeesAndKeys(bytes32 _walletId)
        external
        returns (ITeeRegistry.TeeMachine[] memory _receivingTees, TeeIdKeyIdPair[] memory _teeIdKeyIdPairs)
    {
        TeeWalletKeysState storage keys = walletKeys[_walletId];
        uint256 keyIdsLength = keys.keyIds.length;
        uint256 count = 0;
        for (uint256 i = 0; i < keyIdsLength; i++) {
            count += keys.keyDefinitions[keys.keyIds[i]].teeIds.length;
        }
        uint256[] memory unavailableKeyIds = new uint256[](keyIdsLength);
        address[] memory teeMachines = new address[](count);
        uint256[] memory keyIds = new uint256[](count);
        count = 0;
        uint256 threshold = 0;
        uint256 unavailableKeyIdsCounter = 0;
        for (uint256 i = 0; i < keyIdsLength; i++) {
            bool keyAvailable = false;
            uint256 keyId = keys.keyIds[i];
            KeyDefinition storage keyDefinition = keys.keyDefinitions[keyId];
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
        require(threshold >= keys.multisigThreshold, "not enough keys/tees available");
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
     * @inheritdoc ITeeWalletKeyManager
     */
    function getFeeFactor(bytes32 _walletId)
        external view
        returns (uint256 _feeFactor)
    {
        return walletKeys[_walletId].feeFactor;
    }

    /**
     * @inheritdoc ITeeWalletKeyManager
     */
    function getWalletKeysInfo(bytes32 _walletId)
        external view
        returns (uint256 _multisigThreshold, uint256[] memory _keyIds, uint256 _counter)
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
     * Unused. just to present to satisfy UUPSUpgradeable requirement.
     * The real check is in onlyGovernance modifier on upgradeTo and upgradeToAndCall.
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
        teeWalletManager = IITeeWalletManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletManager"));
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
        ftdcHub = IFtdcHub(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtdcHub"));
        ftdcVerification = IFtdcVerification(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtdcVerification"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
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
        address _teeId
    )
        internal view
    {
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        require(
            msg.value >= teeFeeCalculator.calculateFeeByTeeIds(WALLET_OP_TYPE, _opCommand, teeIds, new address[](0)),
            "fee too low"
        );
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
