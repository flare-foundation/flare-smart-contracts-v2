// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { FlareUpgradeableBase } from "../../governance/implementation/FlareUpgradeableBase.sol";
import { IIFlareTeeManager } from "../interface/IIFlareTeeManager.sol";
import { IInstructions } from "../../userInterfaces/tee/IInstructions.sol";
import { IWalletManager } from "../../userInterfaces/tee/IWalletManager.sol";
import { ITeePaymentsBase } from "../../userInterfaces/tee/ITeePaymentsBase.sol";
import { ITeePaymentsRegistry } from "../../userInterfaces/tee/ITeePaymentsRegistry.sol";
import {
    ITeePaymentsConfigVerifier
} from "../../userInterfaces/tee/ITeePaymentsConfigVerifier.sol";
import { IAddressValidator } from "../../userInterfaces/tee/IAddressValidator.sol";
import { TeeIdKeyIdPair } from "../../userInterfaces/tee/ITeeIdKeyIdPair.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * Shared implementation base for TEE payment contracts.
 */
abstract contract TeePaymentsBase is ITeePaymentsBase, FlareUpgradeableBase {

    mapping(bytes32 walletId => PMWMultisigAccount[]) internal walletAccounts;
    mapping(bytes32 accountHash => bytes32 walletId) internal accountHashToWalletId;
    // Written by the concrete payment models (TeePayments, TeePaymentsUtxo) at pay time; this abstract
    // base only reads it, so slither's uninitialized-state check fires here as a false positive.
    //slither-disable-next-line uninitialized-state
    mapping(bytes32 accountHash => mapping(uint256 paymentId => bytes32)) internal paymentHashes;
    mapping(bytes32 accountHash => address) internal authorizationAddresses;

    /// FlareTeeManager Diamond contract.
    IIFlareTeeManager public flareTeeManager;
    /// Shared sourceId -> TeePayments registry.
    ITeePaymentsRegistry public teePaymentsRegistry;
    /// Shared PMW configuration request + verify contract.
    ITeePaymentsConfigVerifier public teePaymentsConfigVerifier;
    /// Shared sourceId-aware recipient address validator.
    IAddressValidator public addressValidator;

    modifier onlyWalletOwner(PMWMultisigAccount calldata _account) {
        _checkOnlyWalletOwner(_account);
        _;
    }

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() FlareUpgradeableBase() {}

    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        external virtual
        initializer
    {
        FlareUpgradeableBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
    }

    /**
     * @inheritdoc ITeePaymentsBase
     */
    function getWalletAccounts(
        bytes32 _walletId
    )
        external view
        returns (PMWMultisigAccount[] memory)
    {
        return walletAccounts[_walletId];
    }

    /**
     * @inheritdoc ITeePaymentsBase
     */
    function getWalletId(
        PMWMultisigAccount calldata _account
    )
        external view
        returns (bytes32)
    {
        return _getWalletId(_account);
    }

    /**
     * @inheritdoc ITeePaymentsBase
     */
    function getAuthorizationAddress(
        PMWMultisigAccount calldata _account
    )
        external view
        returns (address _authorizationAddress)
    {
        return authorizationAddresses[_toAccountHash(_account)];
    }

    /**
     * @inheritdoc ITeePaymentsBase
     */
    function getPaymentFee(
        PMWMultisigAccount calldata _account,
        bytes32 _opCommand
    )
        external view
        returns (uint256 _fee)
    {
        bytes32 walletId = _getWalletId(_account);
        require(walletId != 0, PMWMultisigAccountNotRegistered());
        bytes32 opType = _sourceOpType(_account.sourceId);
        return flareTeeManager.calculateFeeByWalletId(walletId, opType, _opCommand);
    }

    /**
     * @inheritdoc ITeePaymentsBase
     */
    function getPaymentHash(
        PMWMultisigAccount calldata _account,
        uint64 _paymentId
    )
        external view
        returns (bytes32 _paymentHash)
    {
        return paymentHashes[_toAccountHash(_account)][_paymentId];
    }

    /**
     * @inheritdoc ITeePaymentsBase
     */
    function getNextPaymentId(
        PMWMultisigAccount calldata _account
    )
        external view
        returns (uint64 _nextPaymentId)
    {
        return _getNextPaymentId(_toAccountHash(_account));
    }

    /**
     * Updates external contract addresses.
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
        teePaymentsConfigVerifier = ITeePaymentsConfigVerifier(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeePaymentsConfigVerifier"));
        addressValidator = IAddressValidator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "AddressValidator"));
    }

    // flareTeeManager is a trusted system contract set via AddressUpdatable, not an arbitrary address.
    // The disable sits on the function (where slither anchors arbitrary-send-eth), not the call line.
    //slither-disable-next-line arbitrary-send-eth
    function _sendPaymentInstructions(
        bytes32 _opType,
        bytes32 _instructionId,
        address[] memory _teeIds,
        bytes32 _opCommand,
        bytes memory _message,
        address[] memory _cosigners,
        uint64 _cosignersThreshold,
        address _claimBackAddress,
        uint256 _instructionsFee
    )
        internal
    {
        flareTeeManager.sendSystemInstructions{value: _instructionsFee}(
            _instructionId,
            _teeIds,
            IInstructions.TeeInstructionParams(
                _opType,
                _opCommand,
                _message,
                _cosigners,
                _cosignersThreshold,
                _claimBackAddress
            )
        );
    }

    function _registerAccount(
        bytes32 _walletId,
        bytes32 _sourceId,
        string calldata _accountAddress,
        address _authorizationAddress
    )
        internal
        returns (bytes32 _accountHash)
    {
        bytes32 projectId = flareTeeManager.getWalletProjectId(_walletId);
        bytes32 sourceKeyType = _sourceKeyType(_sourceId);
        require(flareTeeManager.getOwner(projectId) == msg.sender, OnlyWalletOwner());
        require(flareTeeManager.getExtensionId(projectId) == 0, OnlySystemExtensionId());
        require(flareTeeManager.getKeyType(projectId) == sourceKeyType, WrongKeyType());
        // The account address is validated non-empty by the config verifier (verify*ConfiguredProof),
        // which always runs before this on the registration path.
        require(_authorizationAddress != address(0), AuthorizationAddressZero());
        _accountHash = _toAccountHash(_sourceId, _accountAddress);
        require(accountHashToWalletId[_accountHash] == 0, PMWMultisigAccountAddressAlreadySet());
        _checkProductionOrPausedWallet(_walletId);

        accountHashToWalletId[_accountHash] = _walletId;
        walletAccounts[_walletId].push(PMWMultisigAccount(_sourceId, _accountAddress));
        authorizationAddresses[_accountHash] = _authorizationAddress;
        // Each payment model emits its own registration event (account: PMWMultisigAccountAdded;
        // UTXO: PMWMultisigUtxoAccountAdded) after this returns — no generic event from the base.
    }

    /**
     * Returns the next payment id for an account hash. Implemented by each payment model, which owns
     * its own account state.
     */
    function _getNextPaymentId(
        bytes32 _accountHash
    )
        internal view virtual
        returns (uint64 _nextPaymentId);

    function _checkProductionOrPausedWallet(
        bytes32 _walletId
    )
        internal view
    {
        IWalletManager.WalletStatus walletStatus = flareTeeManager.getWalletStatus(_walletId);
        require(
            walletStatus == IWalletManager.WalletStatus.PRODUCTION ||
            walletStatus == IWalletManager.WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );
    }

    function _sourceOpType(
        bytes32 _sourceId
    )
        internal view
        returns (bytes32 _opType)
    {
        address teePayments;
        (_opType, teePayments) = teePaymentsRegistry.getSourceOpTypeAndTeePayments(_sourceId);
        require(teePayments == address(this), UnsupportedSourceId());
    }

    function _sourceKeyType(
        bytes32 _sourceId
    )
        internal view
        returns (bytes32 _keyType)
    {
        address teePayments;
        (_keyType, teePayments) = teePaymentsRegistry.getSourceKeyTypeAndTeePayments(_sourceId);
        require(teePayments == address(this), UnsupportedSourceId());
    }

    function _checkSource(
        bytes32 _sourceId
    )
        internal view
    {
        require(teePaymentsRegistry.getTeePaymentsForSource(_sourceId) == address(this), UnsupportedSourceId());
    }

    function _checkOnlyWalletOwner(
        PMWMultisigAccount calldata _account
    )
        internal view
    {
        _checkWalletOwner(_getWalletId(_account));
    }

    function _checkWalletOwner(
        bytes32 _walletId
    )
        internal view
    {
        bytes32 projectId = flareTeeManager.getWalletProjectId(_walletId);
        require(flareTeeManager.getOwner(projectId) == msg.sender, OnlyWalletOwner());
    }

    function _checkAuthorizationAddress(
        bytes32 _accountHash
    )
        internal view
    {
        require(authorizationAddresses[_accountHash] == msg.sender, OnlyAuthorizationAddress());
    }

    function _requireValidRecipientAddress(
        bytes32 _sourceId,
        string calldata _recipientAddress
    )
        internal view
    {
        require(addressValidator.isValidAddress(_sourceId, _recipientAddress), InvalidRecipientAddress());
    }

    function _checkWalletStatus(
        bytes32 _walletId
    )
        internal view
    {
        require(
            flareTeeManager.getWalletStatus(_walletId) == IWalletManager.WalletStatus.PRODUCTION,
            WalletNotInProduction()
        );
    }

    function _getWalletId(
        PMWMultisigAccount calldata _account
    )
        internal view
        returns (bytes32)
    {
        return accountHashToWalletId[_toAccountHash(_account)];
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
        bytes32 _sourceId,
        string calldata _accountAddress
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_sourceId, _accountAddress));
    }

    /**
     * Account-hash overload for a calldata account — reads the fields straight from calldata.
     * Produces the same hash as `_toAccountHash(_account.sourceId, _account.accountAddress)`.
     */
    function _toAccountHash(
        PMWMultisigAccount calldata _account
    )
        internal pure
        returns (bytes32)
    {
        return _toAccountHash(_account.sourceId, _account.accountAddress);
    }

    function _getPaymentHash(
        PaymentInstruction calldata _paymentInstruction,
        uint256 _paymentId
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_paymentInstruction, _paymentId));
    }

    /**
     * Computes the payment instruction id, unified across both payment models. Every payment
     * instruction shares the same preimage shape - `(opType, opCommand, sourceId, accountAddress,
     * paymentId, reissueNumber)` - so a PAY and its REISSUEs differ only by `opCommand` and the
     * `reissueNumber`: PAY always uses `reissueNumber == 0`, REISSUE uses `1, 2, ...`. For the
     * account model `paymentId` is the payment's own id; for the UTXO model it is the batch's first
     * payment id (`batchPaymentId`), shared by every payment in the batch.
     */
    function _computeInstructionId(
        bytes32 _opType,
        bytes32 _opCommand,
        bytes32 _sourceId,
        string memory _accountAddress,
        uint64 _paymentId,
        uint64 _reissueNumber
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_opType, _opCommand, _sourceId, _accountAddress, _paymentId, _reissueNumber));
    }

    function _addToUint64(
        uint64 _value,
        uint256 _increment
    )
        internal pure
        returns (uint64)
    {
        require(_increment <= type(uint64).max - _value, InvalidPaymentId());
        return _value + uint64(_increment);
    }

}
