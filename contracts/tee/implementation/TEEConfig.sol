// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITEEConfig.sol";

/**
 * TEEConfig is used for project configurations using TEE machines.
 */
contract TEEConfig is ITEEConfig, Governed, AddressUpdatable {

    uint256 internal id = 0;
    ITEERegistry public teeRegistry;
    mapping(bytes32 walletId => Wallet) public wallets;

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

    function createNewWallet() external returns (bytes32 _walletId) {
        id++;
        _walletId = keccak256(abi.encode(msg.sender, id));
        assert(wallets[_walletId].walletAdmin == address(0)); // should never revert
        wallets[_walletId].walletAdmin = msg.sender;
    }

    function addTEEMachineToWallet(bytes32 _walletId, ITEERegistry.TEEMachine calldata _teeMachine) external {
        require(teeRegistry.isRegisteredTEEMachine(_teeMachine), "TEE machine is not registered");
        Wallet storage wallet = wallets[_walletId];
        require(wallet.walletAdmin == msg.sender, "only wallet admin can add TEE machine");
        wallet.teeMachines.push(_teeMachine);
    }

    function setWalletAddress(bytes32 _walletId, string calldata _walletAddress) external {
        Wallet storage wallet = wallets[_walletId];
        require(wallet.walletAdmin == msg.sender, "only wallet admin can set wallet address");
        wallet.walletAddress = _walletAddress;
    }

    function setPaymentInitiator(bytes32 _walletId, address _paymentInitiator) external {
        Wallet storage wallet = wallets[_walletId];
        require(wallet.walletAdmin == msg.sender, "only wallet admin can set payment initiator");
        wallet.paymentInitiator = _paymentInitiator;
    }

    /**
     * @inheritdoc ITEEConfig
     */
    function getWallet(bytes32 _walletId) external view returns (Wallet memory) {
        return wallets[_walletId];
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
        teeRegistry = ITEERegistry(_getContractAddress(_contractNameHashes, _contractAddresses, "TEERegistry"));
    }
}