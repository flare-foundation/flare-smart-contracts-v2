// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeBase } from "./TeeBase.sol";
import { IIFlareTeeManager } from "../interface/IIFlareTeeManager.sol";
import { IInstructions } from "../../userInterfaces/tee/IInstructions.sol";
import { IWalletManager } from "../../userInterfaces/tee/IWalletManager.sol";
import { ITeePayments } from "../../userInterfaces/tee/ITeePayments.sol";
import {
    ITeePaymentsFeeScheduleManager
} from "../../userInterfaces/tee/ITeePaymentsFeeScheduleManager.sol";
import { ITeePaymentsRegistry } from "../../userInterfaces/tee/ITeePaymentsRegistry.sol";
import { TeeIdKeyIdPair } from "../../userInterfaces/tee/ITeeIdKeyIdPair.sol";
import { IPMWMultisigAccountConfigured } from "../../userInterfaces/fdc2/IPMWMultisigAccountConfigured.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";

/**
 * TeePayments is a contract used for instructing TEE based wallets payments.
 */
contract TeePayments is ITeePayments, TeeBase {

    struct AccountState {
        uint64 nonce;
        uint64 subNonce;
        uint64 batchEndTs;
        uint24 batchRewardEpochId;
        uint40 batchCounter;
    }

    struct AccountSettings {
        uint64 batchSize;
        uint64 batchDurationSeconds;
    }

    struct PayTempState {
        bytes32 walletId;
        bytes32 instructionId;
        address[] cosigners;
        uint64 cosignersThreshold;
        address claimBackAddress;
    }

    struct ReissueTempState {
        bytes32 accountHash;
        bytes32 batchHash;
        address[] teeIds;
        uint256 reissueNumber;
        uint256 remainingAmount;
        uint256 amount;
        bytes32 instructionId;
        address[] cosigners;
        uint64 cosignersThreshold;
        address claimBackAddress;
    }

    bytes32 internal constant PAY = bytes32("PAY");
    bytes32 internal constant REISSUE = bytes32("REISSUE");

    bytes32 internal opType;
    bytes32 internal keyType;
    uint64 public maxBatchSize;
    uint64 public maxBatchDurationSeconds;

    mapping(bytes32 walletId => PMWMultisigAccount[]) private walletAccounts;
    mapping(bytes32 accountHash => bytes32 walletId) private accountHashToWalletId;
    mapping(bytes32 accountHash => AccountState) private states;
    mapping(bytes32 accountHash => AccountSettings) private settings;
    mapping(bytes32 accountHash => mapping(uint256 nonce => bytes32)) private hashes;
    mapping(bytes32 accountHash => mapping(uint256 nonce => uint256)) private reissueCounter;
    mapping(bytes32 accountHash => address) private authorizationAddresses;

    /// FlareTeeManager Diamond contract.
    IIFlareTeeManager public flareTeeManager;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// Shared fee schedule registry.
    ITeePaymentsFeeScheduleManager public teePaymentsFeeScheduleManager;
    /// Shared sourceId -> TeePayments registry.
    ITeePaymentsRegistry public teePaymentsRegistry;

    modifier onlyWalletOwner(PMWMultisigAccount calldata _account) {
        _checkOnlyWalletOwner(_account);
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
        address _addressUpdater,
        uint64 _maxBatchSize,
        uint64 _maxBatchDurationSeconds,
        bytes32 _opType,
        bytes32 _keyType
    )
        external virtual
    {
        require(_maxBatchSize > 0, MaxBatchSizeZero());
        require(_opType != bytes32(0), OpTypeZero());
        require(_keyType != bytes32(0), KeyTypeZero());

        TeeBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);

        maxBatchSize = _maxBatchSize;
        maxBatchDurationSeconds = _maxBatchDurationSeconds;
        opType = _opType;
        keyType = _keyType;
    }

    /**
     * @inheritdoc ITeePayments
     */
    function pay(
        PMWMultisigAccount calldata _account,
        PaymentInstruction calldata _paymentInstruction,
        address _claimBackAddress
    )
        external payable
        returns (
            uint64 _nonce,
            uint64 _subNonce
        )
    {
        require(_paymentInstruction.amount > 0, PaymentAmountZero());
        require(
            keccak256(bytes(_paymentInstruction.recipientAddress)) != keccak256(bytes(_account.accountAddress)),
            RecipientIsSender()
        );
        bytes32 accountHash = _toAccountHash(_account.sourceId, _account.accountAddress);
        _checkAuthorizationAddress(accountHash);

        PayTempState memory tempState;
        tempState.walletId = accountHashToWalletId[accountHash];
        tempState.claimBackAddress = _claimBackAddress;
        _checkWalletStatus(tempState.walletId);

        AccountState storage state = states[accountHash];
        AccountSettings storage setting = settings[accountHash];
        uint24 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        // check if new batch should be started
        if (state.batchEndTs < block.timestamp || state.batchCounter >= setting.batchSize ||
            currentRewardEpochId > state.batchRewardEpochId) {
            state.batchRewardEpochId = currentRewardEpochId;
            state.batchEndTs = uint64(block.timestamp) + setting.batchDurationSeconds;
            state.batchCounter = 1;
            hashes[accountHash][state.nonce++] = _getBatchHash(_paymentInstruction, state.subNonce);
        } else {
            ++state.batchCounter;
            hashes[accountHash][state.nonce - 1] = _getBatchHash(
                hashes[accountHash][state.nonce - 1],
                _paymentInstruction,
                state.subNonce
            );
        }

        PaymentInstructionMessage memory message;
        message.walletId = tempState.walletId;
        message.sourceId = _account.sourceId;
        message.senderAddress = _account.accountAddress;
        message.teeIdKeyIdPairs = flareTeeManager.receivingTeesAndKeys(message.walletId);
        message.recipientAddress = _paymentInstruction.recipientAddress;
        message.tokenId = _paymentInstruction.tokenId;
        message.amount = _paymentInstruction.amount;
        message.maxFee = _paymentInstruction.maxFee;
        bytes32 projectId = flareTeeManager.getWalletProjectId(tempState.walletId);
        message.feeSchedule = teePaymentsFeeScheduleManager.getEffectiveSchedule(
            projectId,
            _account.sourceId,
            accountHash
        );
        message.paymentReference = _paymentInstruction.paymentReference;
        message.nonce = state.nonce - 1;
        message.subNonce = state.subNonce++;
        message.batchEndTs = state.batchEndTs;

        (tempState.cosigners, tempState.cosignersThreshold) =
            flareTeeManager.getWalletCosignersAndThreshold(message.walletId);

        tempState.instructionId = keccak256(abi.encode(
            opType, PAY, message.sourceId, message.senderAddress, message.nonce
        ));
        _sendPaymentInstructions(
            tempState.instructionId,
            _toTeeIds(message.teeIdKeyIdPairs),
            PAY,
            abi.encode(message),
            tempState.cosigners,
            tempState.cosignersThreshold,
            tempState.claimBackAddress,
            msg.value
        );
        return (message.nonce, message.subNonce);
    }

    /**
     * @inheritdoc ITeePayments
     */
    function reissue(
        PMWMultisigAccount calldata _account,
        uint64 _nonce,
        uint64 _firstSubNonce,
        PaymentInstruction[] calldata _paymentInstructions,
        ReissueFeeParams calldata _reissueFeeParams,
        address _claimBackAddress
    )
        external payable
    {
        require(_paymentInstructions.length > 0, NoPaymentInstructions());
        require(
            _paymentInstructions.length == _reissueFeeParams.maxFeePerPayment.length &&
            (_reissueFeeParams.maxFeePerPayment.length == _reissueFeeParams.factorsBIPSPerPayment.length ||
            _reissueFeeParams.factorsBIPSPerPayment.length == 0 &&
            _reissueFeeParams.delaysSeconds.length == 0),
            LengthsMismatch()
        );
        ReissueTempState memory tempState;
        tempState.accountHash = _toAccountHash(_account.sourceId, _account.accountAddress);
        tempState.claimBackAddress = _claimBackAddress;

        PaymentInstructionMessage memory message;
        message.sourceId = _account.sourceId;
        message.senderAddress = _account.accountAddress;
        message.walletId = accountHashToWalletId[tempState.accountHash];
        message.nonce = _nonce;
        message.subNonce = _firstSubNonce;
        message.batchEndTs = uint64(block.timestamp);
        _checkAuthorizationAddress(tempState.accountHash);
        _checkWalletStatus(message.walletId);
        {
            AccountState storage state = states[tempState.accountHash];
            // check if batch has ended
            require(
                message.nonce + 1 < state.nonce ||
                message.nonce + 1 == state.nonce && block.timestamp > state.batchEndTs,
                BatchNotYetEnded()
            );
        }

        // check if hash matches
        tempState.batchHash = _getBatchHash(_paymentInstructions[0], _firstSubNonce);
        for (uint256 i = 1; i < _paymentInstructions.length; i++) {
            tempState.batchHash = _getBatchHash(
                tempState.batchHash,
                _paymentInstructions[i],
                message.subNonce + i
            );
        }
        require(hashes[tempState.accountHash][message.nonce] == tempState.batchHash, BatchHashMismatch());

        message.teeIdKeyIdPairs = flareTeeManager.receivingTeesAndKeys(message.walletId);
        tempState.teeIds = _toTeeIds(message.teeIdKeyIdPairs);
        tempState.reissueNumber = reissueCounter[tempState.accountHash][message.nonce]++;

        (tempState.cosigners, tempState.cosignersThreshold) =
            flareTeeManager.getWalletCosignersAndThreshold(message.walletId);

        bytes32 projectId = flareTeeManager.getWalletProjectId(message.walletId);
        bytes memory defaultFeeSchedule = teePaymentsFeeScheduleManager.getEffectiveSchedule(
            projectId,
            _account.sourceId,
            tempState.accountHash
        );
        bytes[] memory encodedSchedules;
        if (_reissueFeeParams.factorsBIPSPerPayment.length > 0) {
            encodedSchedules = teePaymentsFeeScheduleManager.validateAndEncodeSchedules(
                _account.sourceId,
                _reissueFeeParams.factorsBIPSPerPayment,
                _reissueFeeParams.delaysSeconds
            );
        }

        tempState.instructionId = keccak256(abi.encode(
            opType, REISSUE, message.sourceId, message.senderAddress, message.nonce, tempState.reissueNumber
        ));
        // reissue batch
        tempState.remainingAmount = msg.value;
        for (uint256 i = 0; i < _paymentInstructions.length; i++) {
            bytes memory feeSchedule =
                (encodedSchedules.length > 0 && encodedSchedules[i].length > 0)
                    ? encodedSchedules[i]
                    : defaultFeeSchedule;

            message.recipientAddress = _paymentInstructions[i].recipientAddress;
            message.tokenId = _paymentInstructions[i].tokenId;
            message.amount = _paymentInstructions[i].amount;
            message.maxFee = _reissueFeeParams.maxFeePerPayment[i];
            message.feeSchedule = feeSchedule;
            message.paymentReference = _paymentInstructions[i].paymentReference;

            tempState.amount = tempState.remainingAmount / (_paymentInstructions.length - i);
            tempState.remainingAmount -= tempState.amount;
            _sendPaymentInstructions(
                tempState.instructionId,
                tempState.teeIds,
                REISSUE,
                abi.encode(message),
                tempState.cosigners,
                tempState.cosignersThreshold,
                tempState.claimBackAddress,
                tempState.amount
            );

            // increment subNonce for the next message
            message.subNonce++;
        }
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
        bytes32 projectId = flareTeeManager.getWalletProjectId(_walletId);
        require(flareTeeManager.getOwner(projectId) == msg.sender, OnlyWalletOwner());
        require(flareTeeManager.getExtensionId(projectId) == 0, OnlySystemExtensionId());
        require(flareTeeManager.getKeyType(projectId) == keyType, WrongKeyType());
        require(bytes(_proof.requestBody.accountAddress).length > 0, AccountAddressZero());
        require(
            teePaymentsRegistry.getTeePaymentsForSource(_proof.header.sourceId) == address(this),
            UnsupportedSourceId()
        );
        require(_authorizationAddress != address(0), AuthorizationAddressZero());
        bytes32 accountHash = _toAccountHash(_proof.header.sourceId, _proof.requestBody.accountAddress);
        require(accountHashToWalletId[accountHash] == 0, PMWMultisigAccountAddressAlreadySet());
        IWalletManager.WalletStatus walletStatus = flareTeeManager.getWalletStatus(_walletId);
        require(
            walletStatus == IWalletManager.WalletStatus.PRODUCTION ||
            walletStatus == IWalletManager.WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );
        require(flareTeeManager.verifyPMWMultisigAccountConfiguredProof(_walletId, _proof), InvalidProof());
        accountHashToWalletId[accountHash] = _walletId;
        walletAccounts[_walletId].push(PMWMultisigAccount(_proof.header.sourceId, _proof.requestBody.accountAddress));
        states[accountHash].nonce = _proof.responseBody.sequence;
        states[accountHash].subNonce = _proof.responseBody.sequence;
        settings[accountHash].batchSize = 1;
        authorizationAddresses[accountHash] = _authorizationAddress;
        emit PMWMultisigAccountAdded(
            _walletId,
            _proof.header.sourceId,
            _proof.requestBody.accountAddress,
            _proof.responseBody.sequence,
            _authorizationAddress,
            1,
            0
        );
    }

    /**
     * @inheritdoc ITeePayments
     */
    function setBatchSettings(
        PMWMultisigAccount calldata _account,
        uint64 _batchSize,
        uint64 _batchDurationSeconds
    )
        external
        onlyWalletOwner(_account)
    {
        require(_batchSize > 0, BatchSizeZero());
        require(_batchSize <= maxBatchSize, BatchSizeTooLarge());
        require(_batchDurationSeconds <= maxBatchDurationSeconds, BatchDurationTooLarge());
        bytes32 accountHash = _toAccountHash(_account.sourceId, _account.accountAddress);
        AccountSettings storage setting = settings[accountHash];
        setting.batchSize = _batchSize;
        setting.batchDurationSeconds = _batchDurationSeconds;
        emit BatchSettingsSet(
            accountHashToWalletId[accountHash],
            _account.sourceId,
            _account.accountAddress,
            _batchSize,
            _batchDurationSeconds
        );
    }

    /**
     * @inheritdoc ITeePayments
     */
    function getOpType()
        external view
        returns (bytes32)
    {
        return opType;
    }

    /**
     * @inheritdoc ITeePayments
     */
    function getKeyType()
        external view
        returns (bytes32)
    {
        return keyType;
    }

    /**
     * @inheritdoc ITeePayments
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
     * @inheritdoc ITeePayments
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
     * @inheritdoc ITeePayments
     */
    function getBatchSettings(
        PMWMultisigAccount calldata _account
    )
        external view
        returns (
            uint64 _batchSize,
            uint64 _batchDurationSeconds
        )
    {
        AccountSettings storage setting = settings[_toAccountHash(_account.sourceId, _account.accountAddress)];
        _batchSize = setting.batchSize;
        _batchDurationSeconds = setting.batchDurationSeconds;
    }

    /**
     * @inheritdoc ITeePayments
     */
    function getAuthorizationAddress(
        PMWMultisigAccount calldata _account
    )
        external view
        returns (address _authorizationAddress)
    {
        return authorizationAddresses[_toAccountHash(_account.sourceId, _account.accountAddress)];
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
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        teePaymentsFeeScheduleManager = ITeePaymentsFeeScheduleManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeePaymentsFeeScheduleManager"));
        teePaymentsRegistry = ITeePaymentsRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeePaymentsRegistry"));
    }

    function _sendPaymentInstructions(
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
                opType,
                _opCommand,
                _message,
                _cosigners,
                _cosignersThreshold,
                _claimBackAddress
            )
        );
    }

    function _checkOnlyWalletOwner(
        PMWMultisigAccount calldata _account
    )
        internal view
    {
        bytes32 walletId = _getWalletId(_account);
        bytes32 projectId = flareTeeManager.getWalletProjectId(walletId);
        require(flareTeeManager.getOwner(projectId) == msg.sender, OnlyWalletOwner());
    }

    function _checkAuthorizationAddress(
        bytes32 _accountHash
    )
        internal view
    {
        require(authorizationAddresses[_accountHash] == msg.sender, OnlyAuthorizationAddress());
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
        return accountHashToWalletId[_toAccountHash(_account.sourceId, _account.accountAddress)];
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
        string memory _accountAddress
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_sourceId, _accountAddress));
    }

    function _getBatchHash(
        PaymentInstruction calldata _paymentInstruction,
        uint256 _subNonce
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_paymentInstruction, _subNonce));
    }

    function _getBatchHash(
        bytes32 _previousHash,
        PaymentInstruction calldata _paymentInstruction,
        uint256 _subNonce
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_previousHash, _paymentInstruction, _subNonce));
    }
}
