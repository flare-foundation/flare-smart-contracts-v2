// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../interface/IITeeWalletManager.sol";
import "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import "../../userInterfaces/tee/ITeeWalletKeyManager.sol";
import "../interface/IITeeWalletOpTypeConstants.sol";
import "../../governance/implementation/GovernedProxyImplementation.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";

/**
 * TeeWalletManager contract used for wallet configuration on chain.
 */
contract TeeWalletManager is IITeeWalletManager, GovernedProxyImplementation, AddressUpdatable, UUPSUpgradeable {

    struct TeeWalletState {
        bytes32 projectId;
        WalletStatus status;
        PublicKey[] adminsPublicKeys;
        uint64 adminsThreshold;
        mapping(address admin => bool) adminConfirmations;
        address[] cosigners;
        uint64 cosignersThreshold;
        mapping(address cosigner => bool) cosignerConfirmations;
    }

    uint256 constant private P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
    bytes32 public constant WALLET_OP_TYPE = bytes32("WALLET");
    bytes32 public constant SET_PAUSING_ADDRESSES = bytes32("SET_PAUSING_ADDRESSES");
    bytes32 public constant RESUME = bytes32("RESUME");

    uint256 public walletCounter = 0;
    mapping(bytes32 walletId => TeeWalletState) private wallets;
    mapping(bytes32 projectId => bytes32[] walletIds) private projectWallets;

    bytes32[] private supportedOpTypes;
    /// Mapping of operation type to operation type constants provider.
    mapping(bytes32 opType => IITeeWalletOpTypeConstants) public opTypeConstantsProviders;

    mapping (bytes32 walletId => uint256) private setPausingAddressesCounter;
    mapping (bytes32 walletId => uint256) private resumeCounter;

    /// TEE registry contract.
    ITeeRegistry public teeRegistry;
    /// TEE wallet project manager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// TEE wallet key manager contract.
    ITeeWalletKeyManager public teeWalletKeyManager;
    /// TeeFeeCalculator contract.
    ITeeFeeCalculator public teeFeeCalculator;
    /// TeeInstructions contract.
    ITeeInstructions public teeInstructions;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;

    modifier onlyOwner(bytes32 _walletId) {
        _checkOnlyOwner(_walletId);
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
     * @inheritdoc ITeeWalletManager
     */
    function createWallet(
        bytes32 _projectId
    )
        external
        returns (bytes32 _walletId)
    {
        require(teeWalletProjectManager.getOwner(_projectId) == msg.sender, "only owner");
        _walletId = keccak256(abi.encode("WALLET", msg.sender, ++walletCounter));
        TeeWalletState storage wallet = wallets[_walletId];
        assert(wallet.projectId == bytes32(0)); // should never revert
        projectWallets[_projectId].push(_walletId);
        wallet.projectId = _projectId;
        wallet.status = WalletStatus.CREATED;
        emit WalletCreated(_projectId, _walletId);
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
            PublicKey calldata pk = _adminsPublicKeys[i];
            // check public key validity
            _checkPublicKeyValidity(pk);
            // check for duplicates
            for (uint256 j = 0; j < i; j++) {
                require(_adminsPublicKeys[j].x != pk.x || _adminsPublicKeys[j].y != pk.y, "duplicated public key");
            }
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
        require(
            _cosigners.length >= _cosignersThreshold &&
            (_cosigners.length == 0 || _cosignersThreshold > 0),
            "invalid threshold"
        );
        TeeWalletState storage wallet = wallets[_walletId];
        _checkWalletStatus(wallet.status, WalletStatus.CREATED);
        for (uint256 i = 0; i < _cosigners.length; i++) {
            require(_cosigners[i] != address(0), "invalid cosigner");
            // check for duplicates
            for (uint256 j = 0; j < i; j++) {
                require(_cosigners[j] != _cosigners[i], "duplicated cosigner");
            }
        }
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
    function enableWallet(bytes32 _walletId)
        external onlyOwner(_walletId)
    {
        TeeWalletState storage wallet = wallets[_walletId];
        WalletStatus status = wallet.status;
        require(status == WalletStatus.INITIALIZED || status == WalletStatus.PAUSED, "invalid wallet status");
        if (status == WalletStatus.INITIALIZED) {
            // check if wallet multisig threshold is set and keys are added + confirmed
            (uint64 multisigThreshold, uint64[] memory keyIds, ) = teeWalletKeyManager.getWalletKeysInfo(_walletId);
            require(multisigThreshold > 0, "multisig threshold not set");
            require(keyIds.length >= multisigThreshold, "not enough keys");
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
     * Add supported operation types and their constants providers.
     * @param _opTypeConstantsProviders The operation type constants providers for the operation types.
     * Can only be called by the governance.
     */
    function addSupportedOpTypes(IITeeWalletOpTypeConstants[] calldata _opTypeConstantsProviders)
        external onlyGovernance
    {
        for (uint256 i = 0; i < _opTypeConstantsProviders.length; i++) {
            IITeeWalletOpTypeConstants opTypeConstantsProvider = _opTypeConstantsProviders[i];
            bytes32 opType = opTypeConstantsProvider.getOpType();
            if (address(opTypeConstantsProviders[opType]) == address(0)) {
                supportedOpTypes.push(opType);
            }
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
            for (uint256 j = 0; j < supportedOpTypes.length; j++) {
                if (supportedOpTypes[j] == _opTypes[i]) {
                    supportedOpTypes[j] = supportedOpTypes[supportedOpTypes.length - 1];
                    supportedOpTypes.pop();
                    delete opTypeConstantsProviders[_opTypes[i]];
                    break;
                }
            }
        }
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function setPausingAddresses(
        bytes32 _walletId,
        address[] calldata _pausingAddresses
    )
        external payable onlyOwner(_walletId)
    {
        ITeeWalletManager.WalletStatus walletStatus = wallets[_walletId].status;
        require(walletStatus == ITeeWalletManager.WalletStatus.PRODUCTION ||
            walletStatus == ITeeWalletManager.WalletStatus.PAUSED, "only production or paused status");
        require(msg.value >= teeFeeCalculator.calculateFeeByWalletId(WALLET_OP_TYPE, SET_PAUSING_ADDRESSES, _walletId),
            "fee too low");
        (ITeeRegistry.TeeMachine[] memory teeMachines, TeeIdKeyIdPair[] memory teeIdKeyIdPairs) =
            teeWalletKeyManager.receivingTeesAndKeys(_walletId);

        SetPausingAddresses memory message = SetPausingAddresses({
            walletId: _walletId,
            teeIdKeyIdPairs: teeIdKeyIdPairs,
            pausingAddresses: _pausingAddresses
        });
        bytes32 instructionId = keccak256(abi.encode(
            WALLET_OP_TYPE, SET_PAUSING_ADDRESSES, _walletId, setPausingAddressesCounter[_walletId]++
        ));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            SET_PAUSING_ADDRESSES,
            abi.encode(message)
        );
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function resume(
        bytes32 _walletId,
        ResumeKeyData[] calldata _keysData
    )
        external payable onlyOwner(_walletId)
    {
        ITeeWalletManager.WalletStatus walletStatus = wallets[_walletId].status;
        require(walletStatus == ITeeWalletManager.WalletStatus.PRODUCTION ||
            walletStatus == ITeeWalletManager.WalletStatus.PAUSED, "only production or paused status");

        uint256 numOfKeys = _keysData.length;
        address[] memory teeIds = new address[](numOfKeys);
        for (uint256 i = 0; i < numOfKeys; i++) {
            teeIds[i] = _keysData[i].teeId;
        }
        require(msg.value >= teeFeeCalculator.calculateFeeByTeeIds
            (WALLET_OP_TYPE, RESUME, teeIds, new address[](0)), "fee too low");

        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](numOfKeys);
        (, , uint64 keyIdCounter) = teeWalletKeyManager.getWalletKeysInfo(_walletId);
        for (uint256 i = 0; i < numOfKeys; i++) {
            require(keyIdCounter > _keysData[i].keyId, "invalid key id");
            require(teeRegistry.getTeeMachineStatus(_keysData[i].teeId) == ITeeRegistry.TeeStatus.PRODUCTION,
                "tee machine not available");
            teeMachines[i] = teeRegistry.getTeeMachine(_keysData[i].teeId);
        }

        Resume memory message = Resume({
            walletId: _walletId,
            keysData: _keysData
        });
        bytes32 instructionId = keccak256(abi.encode(
            WALLET_OP_TYPE, RESUME, _walletId, resumeCounter[_walletId]++
        ));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
            WALLET_OP_TYPE,
            RESUME,
            abi.encode(message)
        );
    }

    /**
     * @inheritdoc IITeeWalletManager
     */
    function getOpTypeConstants(bytes32 _walletId) external view virtual returns(bytes memory) {
        bytes32 projectId = wallets[_walletId].projectId;
        require(projectId != bytes32(0), "wallet not found");
        bytes32 opType = teeWalletProjectManager.getOpType(projectId);
        IITeeWalletOpTypeConstants opTypeConstantsProvider = opTypeConstantsProviders[opType];
        require(address(opTypeConstantsProvider) != address(0), "operation type not supported");
        return opTypeConstantsProvider.getOpTypeConstants(_walletId);
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
    function getWalletAdminsAndThreshold(bytes32 _walletId)
        external view
        returns (PublicKey[] memory _adminsPublicKeys, uint64 _adminsThreshold)
    {
        TeeWalletState storage wallet = wallets[_walletId];
        _adminsPublicKeys = wallet.adminsPublicKeys;
        _adminsThreshold = wallet.adminsThreshold;
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function getWalletCosignersAndThreshold(bytes32 _walletId)
        external view
        returns (address[] memory _cosigners, uint64 _cosignersThreshold)
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
        return supportedOpTypes;
    }

    /**
     * @inheritdoc ITeeWalletManager
     */
    function isOpTypeSupported(bytes32 _opType)
        external view
        returns (bool)
    {
        return address(opTypeConstantsProviders[_opType]) != address(0);
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
        teeRegistry = ITeeRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeRegistry"));
        teeWalletProjectManager = ITeeWalletProjectManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletProjectManager"));
        teeWalletKeyManager = ITeeWalletKeyManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletKeyManager"));
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
    }

    function _checkOnlyOwner(bytes32 _walletId)
        internal view
    {
        address owner = teeWalletProjectManager.getOwner(wallets[_walletId].projectId);
        require(owner == msg.sender, "only owner");
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
