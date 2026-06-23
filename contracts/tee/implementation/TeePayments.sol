// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { TeePaymentsBase } from "./TeePaymentsBase.sol";
import {
    ITeePaymentsFeeScheduleManager
} from "../../userInterfaces/tee/ITeePaymentsFeeScheduleManager.sol";
import { ITeePaymentsBase, PAY, REISSUE } from "../../userInterfaces/tee/ITeePaymentsBase.sol";
import { ITeePaymentsModel, PaymentModel } from "../../userInterfaces/tee/ITeePaymentsModel.sol";
import { ITeePayments } from "../../userInterfaces/tee/ITeePayments.sol";
import { IPMWMultisigAccountConfigured } from "../../userInterfaces/fdc2/IPMWMultisigAccountConfigured.sol";

/**
 * TeePayments is a contract used for instructing TEE based wallets payments.
 */
contract TeePayments is TeePaymentsBase, ITeePayments {

    struct AccountState {
        uint64 initialNonce;
        uint64 nextPaymentId;
    }

    /// Shared fee schedule registry.
    ITeePaymentsFeeScheduleManager public teePaymentsFeeScheduleManager;

    mapping(bytes32 accountHash => AccountState) private states;
    mapping(bytes32 accountHash => mapping(uint256 paymentId => uint256)) private reissueCounter;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() TeePaymentsBase() {}

    /**
     * @inheritdoc ITeePaymentsBase
     */
    function pay(
        PMWMultisigAccount calldata _account,
        PaymentInstruction calldata _paymentInstruction,
        address _claimBackAddress
    )
        external payable
        returns (uint64 _paymentId)
    {
        require(_paymentInstruction.amount > 0, PaymentAmountZero());
        bytes32 accountHash = _toAccountHash(_account);
        _checkAuthorizationAddress(accountHash);
        _requireValidRecipientAddress(_account.sourceId, _paymentInstruction.recipientAddress);

        bytes32 walletId = accountHashToWalletId[accountHash];
        _checkWalletStatus(walletId);

        AccountState storage state = states[accountHash];
        _paymentId = state.nextPaymentId++;
        paymentHashes[accountHash][_paymentId] = _getPaymentHash(_paymentInstruction, _paymentId);

        PaymentInstructionMessage memory message;
        message.walletId = walletId;
        message.sourceId = _account.sourceId;
        message.senderAddress = _account.accountAddress;
        message.teeIdKeyIdPairs = flareTeeManager.receivingTeesAndKeys(walletId);
        message.recipientAddress = _paymentInstruction.recipientAddress;
        message.tokenId = _paymentInstruction.tokenId;
        message.amount = _paymentInstruction.amount;
        message.maxFee = _paymentInstruction.maxFee;
        bytes32 projectId = flareTeeManager.getWalletProjectId(walletId);
        message.feeSchedule = teePaymentsFeeScheduleManager.getEffectiveSchedule(
            projectId,
            _account.sourceId,
            accountHash
        );
        message.paymentReference = _paymentInstruction.paymentReference;
        message.nonce = _nativeNonce(state.initialNonce, _paymentId);
        message.paymentId = _paymentId;

        (address[] memory cosigners, uint64 cosignersThreshold) =
            flareTeeManager.getWalletCosignersAndThreshold(walletId);

        bytes32 sourceOpType = _sourceOpType(_account.sourceId);
        _sendPaymentInstructions(
            sourceOpType,
            _computeInstructionId(sourceOpType, PAY, _account.sourceId, _account.accountAddress, message.paymentId, 0),
            _toTeeIds(message.teeIdKeyIdPairs),
            PAY,
            abi.encode(message),
            cosigners,
            cosignersThreshold,
            _claimBackAddress,
            msg.value
        );
    }

    /**
     * @inheritdoc ITeePaymentsBase
     */
    function reissue(
        PMWMultisigAccount calldata _account,
        uint64 _paymentId,
        PaymentInstruction[] calldata _paymentInstructions,
        ReissueFeeParams calldata _reissueFeeParams,
        address _claimBackAddress
    )
        external payable
        returns (bool _finalized)
    {
        require(_paymentInstructions.length == 1, InvalidPaymentInstructionCount());
        require(
            _paymentInstructions.length == _reissueFeeParams.maxFeePerPayment.length &&
            (_reissueFeeParams.maxFeePerPayment.length == _reissueFeeParams.factorsBIPSPerPayment.length ||
            _reissueFeeParams.factorsBIPSPerPayment.length == 0 &&
            _reissueFeeParams.delaysSeconds.length == 0),
            LengthsMismatch()
        );
        bytes32 accountHash = _toAccountHash(_account);
        _checkAuthorizationAddress(accountHash);

        // Validate the reissue against the recorded payment hash.
        PaymentInstruction calldata paymentInstruction = _paymentInstructions[0];
        require(
            paymentHashes[accountHash][_paymentId] == _getPaymentHash(paymentInstruction, _paymentId),
            PaymentHashMismatch()
        );

        PaymentInstructionMessage memory message;
        message.sourceId = _account.sourceId;
        message.senderAddress = _account.accountAddress;
        message.walletId = accountHashToWalletId[accountHash];
        _checkWalletStatus(message.walletId);
        AccountState storage state = states[accountHash];
        message.paymentId = _paymentId;
        message.nonce = _nativeNonce(state.initialNonce, _paymentId);

        message.teeIdKeyIdPairs = flareTeeManager.receivingTeesAndKeys(message.walletId);
        // Reissue numbers start at 1 (PAY uses 0), so the unified instruction id distinguishes a
        // payment from each of its reissues by the trailing reissueNumber.
        uint64 reissueNumber = uint64(++reissueCounter[accountHash][_paymentId]);

        (address[] memory cosigners, uint64 cosignersThreshold) =
            flareTeeManager.getWalletCosignersAndThreshold(message.walletId);

        bytes32 projectId = flareTeeManager.getWalletProjectId(message.walletId);
        bytes memory defaultFeeSchedule = teePaymentsFeeScheduleManager.getEffectiveSchedule(
            projectId,
            _account.sourceId,
            accountHash
        );
        bytes[] memory encodedSchedules;
        if (_reissueFeeParams.factorsBIPSPerPayment.length > 0) {
            encodedSchedules = teePaymentsFeeScheduleManager.validateAndEncodeSchedules(
                _account.sourceId,
                _reissueFeeParams.factorsBIPSPerPayment,
                _reissueFeeParams.delaysSeconds
            );
        }

        bytes32 sourceOpType = _sourceOpType(message.sourceId);
        bytes32 instructionId = _computeInstructionId(
            sourceOpType, REISSUE, message.sourceId, message.senderAddress, message.paymentId, reissueNumber
        );

        message.recipientAddress = paymentInstruction.recipientAddress;
        message.tokenId = paymentInstruction.tokenId;
        message.amount = paymentInstruction.amount;
        message.maxFee = _reissueFeeParams.maxFeePerPayment[0];
        message.feeSchedule =
            (encodedSchedules.length > 0 && encodedSchedules[0].length > 0)
                ? encodedSchedules[0]
                : defaultFeeSchedule;
        message.paymentReference = paymentInstruction.paymentReference;

        _sendPaymentInstructions(
            sourceOpType,
            instructionId,
            _toTeeIds(message.teeIdKeyIdPairs),
            REISSUE,
            abi.encode(message),
            cosigners,
            cosignersThreshold,
            _claimBackAddress,
            msg.value
        );
        // The account model reissues a single payment in one instruction, so it always finalizes.
        return true;
    }

    /**
     * @inheritdoc ITeePayments
     */
    function addPMWMultisigAccount(
        bytes32 _walletId,
        IPMWMultisigAccountConfigured.Proof calldata _proof,
        address _authorizationAddress
    )
        external
    {
        // Validates the proof (reverts if invalid); the verified fields are then read straight from
        // the calldata proof — the same bytes the verifier just validated.
        teePaymentsConfigVerifier.verifyAccountConfiguredProof(_walletId, _proof);
        bytes32 accountHash = _registerAccount(
            _walletId,
            _proof.header.sourceId,
            _proof.requestBody.accountAddress,
            _authorizationAddress
        );
        uint64 initialNonce = _proof.responseBody.sequence;
        AccountState storage state = states[accountHash];
        state.initialNonce = initialNonce;
        state.nextPaymentId = 1;
        emit PMWMultisigAccountAdded(
            _walletId,
            _proof.header.sourceId,
            _proof.requestBody.accountAddress,
            _authorizationAddress,
            initialNonce
        );
    }

    /**
     * @inheritdoc ITeePayments
     */
    function getInitialNonce(
        PMWMultisigAccount calldata _account
    )
        external view
        returns (uint64 _initialNonce)
    {
        AccountState storage state = states[_toAccountHash(_account)];
        // nextPaymentId is set to 1 at registration, so 0 unambiguously means "not registered"
        // (distinguishing it from a registered account whose initial nonce is legitimately 0).
        require(state.nextPaymentId != 0, PMWMultisigAccountNotRegistered());
        return state.initialNonce;
    }

    /**
     * @inheritdoc ITeePaymentsModel
     */
    function paymentModel()
        external pure
        returns (PaymentModel)
    {
        return PaymentModel.ACCOUNT;
    }

    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        super._updateContractAddresses(_contractNameHashes, _contractAddresses);
        teePaymentsFeeScheduleManager = ITeePaymentsFeeScheduleManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeePaymentsFeeScheduleManager"));
    }

    /**
     * @inheritdoc TeePaymentsBase
     */
    function _getNextPaymentId(
        bytes32 _accountHash
    )
        internal view override
        returns (uint64)
    {
        return states[_accountHash].nextPaymentId;
    }

    function _nativeNonce(
        uint64 _initialNonce,
        uint64 _paymentId
    )
        internal pure
        returns (uint64)
    {
        require(_paymentId > 0, InvalidPaymentId());
        return _initialNonce + _paymentId - 1;
    }

}
