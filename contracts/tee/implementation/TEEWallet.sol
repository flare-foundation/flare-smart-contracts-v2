// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../userInterfaces/tee/ITEEWallet.sol";
import "./TEEConfig.sol";

/**
 * TEEWallet is a contract used for instructing TEE based wallets payments.
 */
contract TEEWallet is ITEEWallet, Governed, AddressUpdatable {

    /// Flare Systems Manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// TEEConfig contract.
    ITEEConfig public teeConfig;
    /// Next sequence number for wallet id.
    mapping(bytes32 walletId => uint256) public sequenceNumbers;


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
     * @inheritdoc ITEEWallet
     */
    function pay(PaymentInstruction calldata _paymentInstruction) external returns (uint256 _sequenceNumber) {
        bytes32 walletId = _paymentInstruction.walletId;
        ITEEConfig.Wallet memory wallet = teeConfig.getWallet(walletId);
        require(msg.sender == wallet.paymentInitiator, "only payment initiator");
        _sequenceNumber = sequenceNumbers[walletId]++;
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
        teeConfig = ITEEConfig(_getContractAddress(_contractNameHashes, _contractAddresses, "TEEConfig"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
    }
}