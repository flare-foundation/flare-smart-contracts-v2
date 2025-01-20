// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../../userInterfaces/tee/ITeeWalletConfig.sol";


/**
 * TeeWalletManager is a contract used for instructing TEE based wallets payments.
 */
contract TeeWalletManager is ITeeWalletManager, Governed, AddressUpdatable {

    /// Flare Systems Manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// TeeWalletConfig contract.
    ITeeWalletConfig public teeWalletConfig;
    /// Tx counter.
    mapping(bytes32 walletId => uint256) public txCounter;


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

    /**
     * @inheritdoc ITeeWalletManager
     */
    function pay(PaymentInstruction calldata _paymentInstruction) external returns (uint256 _sequenceNumber) {
        bytes32 walletId = _paymentInstruction.walletId;
        ITeeWalletConfig.TeeWallet memory wallet = teeWalletConfig.getWallet(walletId);
        require(msg.sender == wallet.paymentInitiator, "only payment initiator");
        _sequenceNumber = txCounter[walletId]++;
        emit PaymentInstructed(
            walletId,
            flareSystemsManager.getCurrentRewardEpochId(),
            wallet.walletAddress,
            _paymentInstruction.paymentAddress,
            _sequenceNumber,
            _paymentInstruction.value,
            _paymentInstruction.initialFee,
            _paymentInstruction.paymentReference,
            wallet.teeMachines
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
        teeWalletConfig = ITeeWalletConfig(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletConfig"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
    }
}