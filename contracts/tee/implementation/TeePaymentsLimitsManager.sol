// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { FlareUpgradeableBase } from "../../governance/implementation/FlareUpgradeableBase.sol";
import { IIFlareTeeManager } from "../interface/IIFlareTeeManager.sol";
import { IInstructions } from "../../userInterfaces/tee/IInstructions.sol";
import { ITeePayments } from "../../userInterfaces/tee/ITeePayments.sol";
import { ITeePaymentsLimitsManager } from "../../userInterfaces/tee/ITeePaymentsLimitsManager.sol";
import { ITeePaymentsRegistry } from "../../userInterfaces/tee/ITeePaymentsRegistry.sol";
import { TeeIdKeyIdPair } from "../../userInterfaces/tee/ITeeIdKeyIdPair.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * TeePaymentsLimitsManager — shared setPaymentLimits entry point.
 *
 * Resolves the TeePayments instance via the TeePaymentsRegistry (keyed on sourceId),
 * reads the opType dynamically, and forwards SET_PAYMENT_LIMITS instructions to the
 * wallet admins via FlareTeeManager.sendInstructions().
 */
contract TeePaymentsLimitsManager is ITeePaymentsLimitsManager, FlareUpgradeableBase {

    bytes32 internal constant SET_PAYMENT_LIMITS = bytes32("SET_PAYMENT_LIMITS");

    /// FlareTeeManager Diamond contract.
    IIFlareTeeManager public flareTeeManager;
    /// Shared sourceId -> TeePayments registry.
    ITeePaymentsRegistry public teePaymentsRegistry;

    mapping(bytes32 accountHash => uint256) private setPaymentLimitsNonceByAccount;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() FlareUpgradeableBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     * @param _governanceSettings The governance settings interface.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address updater contract.
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        external virtual
    {
        FlareUpgradeableBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
    }

    /**
     * @inheritdoc ITeePaymentsLimitsManager
     */
    function setPaymentLimits(
        ITeePayments.PMWMultisigAccount calldata _account,
        uint256 _transactionLimit,
        uint256 _dailyLimit,
        address _claimBackAddress
    )
        external payable
    {
        address teePayments = teePaymentsRegistry.getTeePaymentsForSource(_account.sourceId);
        require(teePayments != address(0), UnsupportedSourceId());
        bytes32 walletId = ITeePayments(teePayments).getWalletId(_account);
        require(walletId != bytes32(0), AccountNotRegistered());
        require(
            flareTeeManager.getOwner(flareTeeManager.getWalletProjectId(walletId)) == msg.sender,
            OnlyWalletOwner()
        );
        require(_dailyLimit >= _transactionLimit, DailyLimitBelowTransactionLimit());

        TeeIdKeyIdPair[] memory teeIdKeyIdPairs = flareTeeManager.receivingTeesAndKeys(walletId);
        (address[] memory admins, uint64 adminsThreshold) = flareTeeManager.getWalletAdminsAndThreshold(walletId);
        bytes32 accountHash = _toAccountHash(_account);
        bytes memory encodedMessage = abi.encode(
            SetPaymentLimitsMessage({
                walletId: walletId,
                sourceId: _account.sourceId,
                accountAddress: _account.accountAddress,
                nonce: setPaymentLimitsNonceByAccount[accountHash]++,
                teeIdKeyIdPairs: teeIdKeyIdPairs,
                transactionLimit: _transactionLimit,
                dailyLimit: _dailyLimit
            })
        );

        flareTeeManager.sendInstructions{value: msg.value}(
            _toTeeIds(teeIdKeyIdPairs),
            IInstructions.TeeInstructionParams(
                ITeePayments(teePayments).getOpType(),
                SET_PAYMENT_LIMITS,
                encodedMessage,
                admins,
                adminsThreshold,
                _claimBackAddress
            )
        );
        emit PaymentLimitsSet(
            walletId,
            _account.sourceId,
            _account.accountAddress,
            _transactionLimit,
            _dailyLimit
        );
    }

    /**
     * @inheritdoc ITeePaymentsLimitsManager
     */
    function getPaymentLimitsNonce(
        ITeePayments.PMWMultisigAccount calldata _account
    )
        external view
        returns (uint256 _nonce)
    {
        return setPaymentLimitsNonceByAccount[_toAccountHash(_account)];
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal virtual override
    {
        flareTeeManager = IIFlareTeeManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareTeeManager"));
        teePaymentsRegistry = ITeePaymentsRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeePaymentsRegistry"));
    }

    function _toTeeIds(
        TeeIdKeyIdPair[] memory _teeIdKeyIdPairs
    )
        internal pure
        returns (address[] memory _teeIds)
    {
        _teeIds = new address[](_teeIdKeyIdPairs.length);
        for (uint256 i = 0; i < _teeIdKeyIdPairs.length; i++) {
            _teeIds[i] = _teeIdKeyIdPairs[i].teeId;
        }
    }

    function _toAccountHash(
        ITeePayments.PMWMultisigAccount calldata _account
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_account.sourceId, _account.accountAddress));
    }
}
