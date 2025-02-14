// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../../userInterfaces/tee/ITeePayments.sol";


/**
 * TeePayments is a contract used for instructing TEE based wallets payments.
 */
abstract contract TeePayments is ITeePayments, Governed, AddressUpdatable {

    struct WalletState {
        uint64 nonce;
        uint64 subNonce;
        uint64 batchEndTs;
        uint64 batchRewardEpochId;
    }

    struct WalletSettings {
        uint96 maxFee;
        uint32 maxFeeTolerancePPM;
        uint64 batchSize;
        uint64 batchDurationSeconds;

        address controlAddress;
        uint96 maxControlFee;
    }

    uint64 public immutable maxBatchSize;
    uint64 public immutable maxBatchDurationSeconds;
    bytes32 public immutable opType;

    mapping(bytes32 walletId => WalletState) private states;
    mapping(bytes32 walletId => WalletSettings) private settings;
    mapping(bytes32 walletId => string) private senderAddresses;

    /// Flare Systems Manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// TeeWalletManager contract.
    ITeeWalletManager public teeWalletManager;


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
        uint64 _maxBatchSize,
        uint64 _maxBatchDurationSeconds,
        bytes32 _opType
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        maxBatchSize = _maxBatchSize;
        maxBatchDurationSeconds = _maxBatchDurationSeconds;
        opType = _opType;
    }

    /**
     * @inheritdoc ITeePayments
     */
    function send(bytes32 _walletId, PaymentInstruction calldata _paymentInstruction)
        external returns (uint256 _subNonce) {

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
        teeWalletManager = ITeeWalletManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletManager"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
    }
}