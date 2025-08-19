// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./TeeBase.sol";
import "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import "../../userInterfaces/tee/ITeeWalletKeyManager.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../userInterfaces/tee/ITeeMachineRegistry.sol";

/**
 * TeeWalletManager contract used for wallet configuration on chain.
 */
contract TeeWalletManager is ITeeWalletManager, TeeBase {

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
    bytes32 public constant WALLET_OP_TYPE = bytes32("F_WALLET");
    bytes32 public constant SET_PAUSING_ADDRESSES = bytes32("SET_PAUSING_ADDRESSES");
    bytes32 public constant RESUME = bytes32("RESUME");

    uint256 public walletCounter = 0;
    mapping(bytes32 walletId => TeeWalletState) private wallets;
    mapping(bytes32 projectId => bytes32[] walletIds) private projectWallets;

    mapping (bytes32 walletId => uint256) private setPausingAddressesCounter;
    mapping (bytes32 walletId => uint256) private resumeCounter;

    /// TEE extension registry contract.
    ITeeExtensionRegistry public teeExtensionRegistry;
    /// TEE machine registry contract.
    ITeeMachineRegistry public teeMachineRegistry;
    /// TEE wallet project manager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// TEE wallet key manager contract.
    ITeeWalletKeyManager public teeWalletKeyManager;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;

    modifier onlyOwner(bytes32 _walletId) {
        _checkOnlyOwner(_walletId);
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
     * @inheritdoc ITeeWalletManager
     */
    function createWallet(
        bytes32 _projectId
    )
        external
        returns (bytes32 _walletId)
    {
        require(teeWalletProjectManager.getOwner(_projectId) == msg.sender, OnlyOwner());
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
        require(_adminsPublicKeys.length >= _adminsThreshold, NotEnoughAdmins());
        require(_adminsThreshold > 0, InvalidAdminsThreshold());
        for (uint256 i = 0; i < _adminsPublicKeys.length; i++) {
            PublicKey calldata pk = _adminsPublicKeys[i];
            // check public key validity
            _checkPublicKeyValidity(pk);
            // check for duplicates
            for (uint256 j = 0; j < i; j++) {
                require(_adminsPublicKeys[j].x != pk.x || _adminsPublicKeys[j].y != pk.y,
                    DuplicatedPublicKey(pk));
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
        revert InvalidAdmin();
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
            _cosigners.length >= _cosignersThreshold && (_cosigners.length == 0 || _cosignersThreshold > 0),
            InvalidCosignersThreshold()
        );
        TeeWalletState storage wallet = wallets[_walletId];
        _checkWalletStatus(wallet.status, WalletStatus.CREATED);
        for (uint256 i = 0; i < _cosigners.length; i++) {
            require(_cosigners[i] != address(0), InvalidCosigner(_cosigners[i]));
            // check for duplicates
            for (uint256 j = 0; j < i; j++) {
                require(_cosigners[j] != _cosigners[i], DuplicatedCosigner(_cosigners[i]));
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
        revert InvalidCosigner(msg.sender);
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
        require(wallet.adminsPublicKeys.length > 0, AdminsNotSet());
        for (uint256 i = 0; i < wallet.adminsPublicKeys.length; i++) {
            require(wallet.adminConfirmations[_getAddress(wallet.adminsPublicKeys[i])],
                NotAllAdminsConfirmed(_getAddress(wallet.adminsPublicKeys[i])));
        }
        for (uint256 i = 0; i < wallet.cosigners.length; i++) {
            require(wallet.cosignerConfirmations[wallet.cosigners[i]], NotAllCosignersConfirmed(wallet.cosigners[i]));
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
        require(status == WalletStatus.INITIALIZED || status == WalletStatus.PAUSED, InvalidWalletStatus());
        if (status == WalletStatus.INITIALIZED) {
            // check if wallet multisig threshold is set and keys are added + confirmed
            (uint64 multisigThreshold, uint64[] memory keyIds, ) = teeWalletKeyManager.getWalletKeysInfo(_walletId);
            require(multisigThreshold > 0, MultisigThresholdNotSet());
            require(keyIds.length >= multisigThreshold, NotEnoughKeys());
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
    function setPausingAddresses(
        bytes32 _walletId,
        address[] calldata _pausingAddresses
    )
        external payable onlyOwner(_walletId)
    {
        ITeeWalletManager.WalletStatus walletStatus = wallets[_walletId].status;
        require(walletStatus == ITeeWalletManager.WalletStatus.PRODUCTION ||
            walletStatus == ITeeWalletManager.WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus());
        TeeIdKeyIdPair[] memory teeIdKeyIdPairs = teeWalletKeyManager.receivingTeesAndKeys(_walletId);
        address[] memory teeIds = new address[](teeIdKeyIdPairs.length);
        for (uint256 i = 0; i < teeIdKeyIdPairs.length; i++) {
            teeIds[i] = teeIdKeyIdPairs[i].teeId;
        }

        uint256 nonce = setPausingAddressesCounter[_walletId]++;
        SetPausingAddresses memory message = SetPausingAddresses({
            walletId: _walletId,
            nonce: nonce,
            teeIdKeyIdPairs: teeIdKeyIdPairs,
            pausingAddresses: _pausingAddresses
        });
        bytes32 instructionId = keccak256(abi.encode(
            WALLET_OP_TYPE, SET_PAUSING_ADDRESSES, _walletId, nonce
        ));
        (address[] memory admins, uint64 adminsThreshold) = _getWalletAdminsAndThreshold(_walletId);
        teeExtensionRegistry.sendInstructions{value: msg.value}(
            instructionId,
            teeIds,
            WALLET_OP_TYPE,
            SET_PAUSING_ADDRESSES,
            abi.encode(message),
            admins,
            adminsThreshold
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
        require(
            walletStatus == ITeeWalletManager.WalletStatus.PRODUCTION ||
            walletStatus == ITeeWalletManager.WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );

        uint256 numOfKeys = _keysData.length;
        address[] memory teeIds = new address[](numOfKeys);
        (, uint64[] memory keyIds, ) = teeWalletKeyManager.getWalletKeysInfo(_walletId);
        for (uint256 i = 0; i < numOfKeys; i++) {
            bool found = false;
            for (uint256 j = 0; j < keyIds.length; j++) {
                if (keyIds[j] == _keysData[i].keyId) {
                    found = true;
                    break;
                }
            }
            require(found, WrongKeyId());
            require(
                teeMachineRegistry.getTeeMachineStatus(_keysData[i].teeId) == ITeeMachineRegistry.TeeStatus.PRODUCTION,
                TeeMachineNotAvailable()
            );
            teeIds[i] = _keysData[i].teeId;
        }

        Resume memory message = Resume({
            walletId: _walletId,
            keysData: _keysData
        });
        bytes32 instructionId = keccak256(abi.encode(
            WALLET_OP_TYPE, RESUME, _walletId, resumeCounter[_walletId]++
        ));
        teeExtensionRegistry.sendInstructions{value: msg.value}(
            instructionId,
            teeIds,
            WALLET_OP_TYPE,
            RESUME,
            abi.encode(message),
            new address[](0),
            0
        );
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
    function getWalletAdminsPublicKeysAndThreshold(bytes32 _walletId)
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
    function getWalletAdminsAndThreshold(bytes32 _walletId)
        external view
        returns (address[] memory _admins, uint64 _adminsThreshold)
    {
        (_admins, _adminsThreshold) = _getWalletAdminsAndThreshold(_walletId);
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
        teeWalletKeyManager = ITeeWalletKeyManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletKeyManager"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
    }

    function _checkOnlyOwner(bytes32 _walletId)
        internal view
    {
        address owner = teeWalletProjectManager.getOwner(wallets[_walletId].projectId);
        require(owner == msg.sender, OnlyOwner());
    }

    function _getWalletAdminsAndThreshold(bytes32 _walletId)
        internal view
        returns (address[] memory _admins, uint64 _adminsThreshold)
    {
        TeeWalletState storage wallet = wallets[_walletId];
        _admins = new address[](wallet.adminsPublicKeys.length);
        for (uint256 i = 0; i < wallet.adminsPublicKeys.length; i++) {
            _admins[i] = _getAddress(wallet.adminsPublicKeys[i]);
        }
        _adminsThreshold = wallet.adminsThreshold;
    }

    function _getAddress(PublicKey storage _pk) internal view returns (address) {
        uint256[2] memory publicKeyPair = [uint256(_pk.x), uint256(_pk.y)];
        bytes32 hash = keccak256(abi.encodePacked(publicKeyPair));
        return address(uint160(uint256(hash)));
    }

    function _checkWalletStatus(WalletStatus _actualStatus, WalletStatus _expectedStatus)
        internal pure
    {
        require(_actualStatus == _expectedStatus, InvalidWalletStatus());
    }

    function _checkPublicKeyValidity(PublicKey calldata _pk) internal pure {
        uint256 x = uint256(_pk.x);
        uint256 y = uint256(_pk.y);
        require(
            x < P && x > 0 && y < P && y > 0 && mulmod(y, y, P) == addmod(mulmod(mulmod(x, x, P), x, P), 7, P),
            InvalidPublicKey(_pk)
        );
    }
}
