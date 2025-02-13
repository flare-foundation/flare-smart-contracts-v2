// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";

/**
 * TeeWalletManager is used for wallet configurations on TEE machines.
 */
abstract contract TeeWalletManager is ITeeWalletManager, Governed, AddressUpdatable {

    struct TeeWalletState {
        address owner;
        WalletStatus status;
        uint64 keyIdCounter;
        address backupManager;
        address submitAddress;
        uint64 multisigThreshold; // number of signatures required - k out of n
        bytes32 functionality;
        TeeWalletKey[] keyDefinitions; // n
    }

    struct TeeWalletKey {
        uint64 keyId;
        uint64 machineBackupCounter;
        uint64 custodianBackupCounter;
        bytes publicKey;
        address[] teeIds;
    }

    uint256 internal count = 0;
    mapping(bytes32 walletId => TeeWalletState) private wallets;


    /// TEE machines are registered in the TEE registry.
    ITeeRegistry public teeRegistry;

    modifier onlyWalletOwner(bytes32 _walletId) {
        require(wallets[_walletId].owner == msg.sender, "only wallet admin");
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

    // function createWallet(string calldata _signingAlgorithm)
    //     external payable
    //     returns (bytes32 _walletId)
    // {
    //     _walletId = keccak256(abi.encode(msg.sender, ++count));
    //     TeeWalletState storage wallet = wallets[_walletId];
    //     assert(wallet.owner == address(0)); // should never revert
    //     wallet.owner = msg.sender;
    //     wallet.status = WalletStatus.INITIALIZED;
    //     emit WalletCreated(_walletId, msg.sender, _signingAlgorithm);
    // }

    // function addWalletKeys(bytes32 _walletId, address[] calldata _primaryTeeIds)
    //     external payable
    //     onlyWalletOwner(_walletId)
    // {
    //     TeeWalletState storage wallet = wallets[_walletId];
    //     require(wallet.status == WalletStatus.INITIALIZED, "wallet not initialized");
    //     string memory signingAlgorithm = wallet.signingAlgorithm;
    //     uint256 keyId = wallet.keys.length;
    //     for (uint256 i = 0; i < _primaryTeeIds.length; i++) {
    //         teeRegistry.checkTeeMachineActiveAndSupportsFunctionality(_primaryTeeIds[i], signingAlgorithm);
    //         wallet.keys.push(WalletKey({
    //             primaryTeeMachine: WalletKeyMachine({
    //                 teeId: _primaryTeeIds[i],
    //                 status: WalletKeyStatus.INITIALIZED
    //             }),
    //             secondaryTeeMachines: new WalletKeyMachine[](0)
    //         }));
    //         emit WalletKeyAdded(_walletId, keyId++, _primaryTeeIds[i], signingAlgorithm);
    //     }
    // }

    // function confirmWalletKeys(bytes32 _walletId, uint256[] calldata _keyIds)
    //     external
    //     onlyWalletOwner(_walletId)
    // {
    //     TeeWalletState storage wallet = wallets[_walletId];
    //     require(wallet.status == WalletStatus.IN_PREPARATION, "wallet not in preparation");
    //     for (uint256 i = 0; i < _keyIds.length; i++) {
    //         WalletKey storage key = wallet.keys[_keyIds[i]];
    //         require(key.primaryTeeMachine.status == WalletKeyStatus.INITIALIZED, "key already confirmed");
    //         key.primaryTeeMachine.status = WalletKeyStatus.CONFIRMED;
    //         emit WalletKeyConfirmed(_walletId, _keyIds[i], key.primaryTeeMachine.teeId);
    //     }
    // }

    // function rejectWalletKeys(bytes32 _walletId, uint256[] calldata _keyIds)
    //     external
    //     onlyWalletOwner(_walletId)
    // {
    //     TeeWalletState storage wallet = wallets[_walletId];
    //     require(wallet.status == WalletStatus.IN_PREPARATION, "wallet not in preparation");
    //     for (uint256 i = 0; i < _keyIds.length; i++) {
    //         WalletKey storage key = wallet.keys[_keyIds[i]];
    //         require(key.primaryTeeMachine.status == WalletKeyStatus.INITIALIZED, "key already confirmed");
    //         key.primaryTeeMachine.status = WalletKeyStatus.DEACTIVATED;
    //         emit WalletKeyConfirmed(_walletId, _keyIds[i], key.primaryTeeMachine.teeId);
    //     }
    // }

    // function setWalletAddress(bytes32 _walletId, string calldata _walletAddress)
    //     external
    //     onlyWalletOwner(_walletId)
    // {
    //     TeeWallet storage wallet = wallets[_walletId];
    //     require(wallet.status == WalletStatus.IN_PREPARATION, "wallet not in preparation");
    //     for (uint256 i = 0; i < wallet.keys.length; i++) {
    //         require(wallet.keys[i].primaryTeeMachine.status != WalletKeyStatus.INITIALIZED, "key in initialization");
    //     }
    //     wallet.status = WalletStatus.ACTIVE;
    //     wallet.walletAddress = _walletAddress;
    // }

    // function setPaymentInitiator(bytes32 _walletId, address _paymentInitiator)
    //     external
    //     onlyWalletOwner(_walletId)
    // {
    //     TeeWallet storage wallet = wallets[_walletId];
    //     wallet.paymentInitiator = _paymentInitiator;
    // }

    // /**
    //  * @inheritdoc ITeeWalletConfig
    //  */
    // function getWallet(bytes32 _walletId) external view returns (TeeWallet memory) {
    //     return wallets[_walletId];
    // }

    // function getWalletAdmin(bytes32 _walletId) external view returns (address) {
    //     return walletAdmins[_walletId];
    // }

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
    }
}