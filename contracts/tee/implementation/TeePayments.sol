// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeBase } from "./TeeBase.sol";
import { IITeeExtensionRegistry } from "../interface/IITeeExtensionRegistry.sol";
import { ITeePayments } from "../../userInterfaces/tee/ITeePayments.sol";
import { ITeeWalletProjectManager } from "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import { ITeeWalletManager } from "../../userInterfaces/tee/ITeeWalletManager.sol";
import { ITeeWalletKeyManager } from "../../userInterfaces/tee/ITeeWalletKeyManager.sol";
import { ITeeVerification } from "../../userInterfaces/tee/ITeeVerification.sol";
import { TeeIdKeyIdPair } from "../../userInterfaces/tee/ITeeIdKeyIdPair.sol";
import { IPMWMultisigAccountConfigured } from "../../userInterfaces/ftdc/IPMWMultisigAccountConfigured.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";

/**
 * TeePayments is a contract used for instructing TEE based wallets payments.
 */
contract TeePayments is ITeePayments, TeeBase {
    using EnumerableSet for EnumerableSet.Bytes32Set;

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
        bytes32 instructionId;
        PaymentInstructionMessage message;
        address[] cosigners;
        uint64 cosignersThreshold;
    }

    struct ReissueTempState {
        bytes32 accountHash;
        bytes32 walletId;
        bytes32 projectId;
        bytes32 batchHash;
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        address[] teeIds;
        uint256 reissueNumber;
        uint256 remainingAmount;
        uint256 amount;
        bytes32 instructionId;
        PaymentInstructionMessage message;
        address[] cosigners;
        uint64 cosignersThreshold;
    }


    bytes32 public constant PAY = bytes32("PAY");
    bytes32 public constant REISSUE = bytes32("REISSUE");
    bytes32 public constant SET_PAYMENT_LIMITS = bytes32("SET_PAYMENT_LIMITS");

    bytes32 internal opType;
    bytes32 internal keyType;
    EnumerableSet.Bytes32Set internal supportedSourceIds;
    uint64 public maxBatchSize;
    uint64 public maxBatchDurationSeconds;

    mapping(bytes32 walletId => PMWMultisigAccount[]) private walletAccounts;
    mapping(bytes32 accountHash => bytes32 walletId) private accountHashToWalletId;
    mapping(bytes32 accountHash => AccountState) private states;
    mapping(bytes32 accountHash => AccountSettings) private settings;
    mapping(bytes32 accountHash => mapping(uint64 nonce => bytes32)) private hashes;
    mapping(bytes32 accountHash => mapping(uint64 nonce => uint256)) private reissueCounter;
    mapping(bytes32 accountHash => uint256) private setPaymentLimitsNonce;

    /// TeeWalletProjectManager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// TeeWalletManager contract.
    ITeeWalletManager public teeWalletManager;
    /// TeeWalletKeyManager contract.
    ITeeWalletKeyManager public teeWalletKeyManager;
    /// TeeVerification contract.
    ITeeVerification public teeVerification;
    /// TeeExtensionRegistry contract.
    IITeeExtensionRegistry public teeExtensionRegistry;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;

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
        bytes32 _keyType,
        bytes32[] calldata _supportedSourceIds
    )
        external virtual
    {
        require(_maxBatchSize > 0, MaxBatchSizeZero());
        require(_opType != bytes32(0), OpTypeZero());
        require(_keyType != bytes32(0), KeyTypeZero());
        require(_supportedSourceIds.length > 0, SupportedSourceIdsLengthZero());

        TeeBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);

        maxBatchSize = _maxBatchSize;
        maxBatchDurationSeconds = _maxBatchDurationSeconds;
        opType = _opType;
        keyType = _keyType;
        _addSupportedSourceIds(_supportedSourceIds);
    }

    /**
     * @inheritdoc ITeePayments
     */
    function pay(
        PMWMultisigAccount calldata _account,
        PaymentInstruction calldata _paymentInstruction
    )
        external payable returns (uint64 _nonce, uint64 _subNonce)
    {
        require(_paymentInstruction.amount > 0, PaymentAmountZero());
        require(
            keccak256(bytes(_paymentInstruction.recipientAddress)) != keccak256(bytes(_account.accountAddress)),
            RecipientIsSender()
        );
        bytes32 accountHash = _toAccountHash(_account.sourceId, _account.accountAddress);
        bytes32 walletId = accountHashToWalletId[accountHash];
        bytes32 projectId = teeWalletManager.getWalletProjectId(walletId);
        require(
            teeWalletProjectManager.getAuthorizationAddress(projectId) == msg.sender,
            OnlyAuthorizationAddress()
        );
        require(
            teeWalletManager.getWalletStatus(walletId) == ITeeWalletManager.WalletStatus.PRODUCTION,
            WalletNotInProduction()
        );

        AccountState storage state = states[accountHash];
        AccountSettings storage setting = settings[accountHash];
        uint24 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        // check if new batch should be started
        if (state.batchEndTs < block.timestamp || state.batchCounter >= setting.batchSize ||
            currentRewardEpochId > state.batchRewardEpochId) {
            state.batchRewardEpochId = currentRewardEpochId;
            state.batchEndTs = uint64(block.timestamp) + setting.batchDurationSeconds;
            state.batchCounter = 1;
            hashes[accountHash][state.nonce++] = keccak256(abi.encode(
                _paymentInstruction,
                state.subNonce
            ));
        } else {
            ++state.batchCounter;
            hashes[accountHash][state.nonce - 1] = keccak256(abi.encode(
                hashes[accountHash][state.nonce - 1],
                _paymentInstruction,
                state.subNonce
            ));
        }
        TeeIdKeyIdPair[] memory teeIdKeyIdPairs = teeWalletKeyManager.receivingTeesAndKeys(walletId);

        PayTempState memory tempState;
        tempState.message = PaymentInstructionMessage({
            walletId: walletId,
            teeIdKeyIdPairs: teeIdKeyIdPairs,
            sourceId: _account.sourceId,
            senderAddress: _account.accountAddress,
            recipientAddress: _paymentInstruction.recipientAddress,
            tokenId: _paymentInstruction.tokenId,
            amount: _paymentInstruction.amount,
            fee: _paymentInstruction.fee,
            paymentReference: _paymentInstruction.paymentReference,
            nonce: state.nonce - 1,
            subNonce: state.subNonce,
            batchEndTs: state.batchEndTs
        });
        ++state.subNonce;

        (tempState.cosigners, tempState.cosignersThreshold) =
            teeWalletManager.getWalletCosignersAndThreshold(walletId);

        tempState.instructionId = keccak256(abi.encode(
            opType, PAY, _account.sourceId, _account.accountAddress, tempState.message.nonce
        ));
        teeExtensionRegistry.sendSystemInstructions{value: msg.value}(
            tempState.instructionId,
            _toTeeIds(teeIdKeyIdPairs),
            opType,
            PAY,
            abi.encode(tempState.message),
            tempState.cosigners,
            tempState.cosignersThreshold
        );
        return (tempState.message.nonce, tempState.message.subNonce);
    }

    /**
     * @inheritdoc ITeePayments
     */
    function reissue(
        PMWMultisigAccount calldata _account,
        uint64 _nonce,
        uint64 _firstSubNonce,
        PaymentInstruction[] calldata _paymentInstructions,
        uint256[] calldata _fees,
        bool[] calldata _nullify
    )
        external payable
    {
        require(_paymentInstructions.length > 0, NoPaymentInstructions());
        require(_paymentInstructions.length == _fees.length && _fees.length == _nullify.length, LengthsMismatch());
        ReissueTempState memory tempState;
        tempState.accountHash = _toAccountHash(_account.sourceId, _account.accountAddress);
        tempState.walletId = accountHashToWalletId[tempState.accountHash];
        tempState.projectId = teeWalletManager.getWalletProjectId(tempState.walletId);
        require(
            teeWalletProjectManager.getAuthorizationAddress(tempState.projectId) == msg.sender,
            OnlyAuthorizationAddress()
        );
        require(
            teeWalletManager.getWalletStatus(tempState.walletId) == ITeeWalletManager.WalletStatus.PRODUCTION,
            WalletNotInProduction()
        );
        AccountState storage state = states[tempState.accountHash];
        // check if batch has ended
        require(
            _nonce + 1 < state.nonce ||
            _nonce + 1 == state.nonce && block.timestamp > state.batchEndTs,
            BatchNotYetEnded()
        );
        // check if hash matches
        tempState.batchHash = keccak256(abi.encode(_paymentInstructions[0], _firstSubNonce));
        for (uint256 i = 1; i < _paymentInstructions.length; i++) {
            tempState.batchHash = keccak256(abi.encode(
                tempState.batchHash,
                _paymentInstructions[i],
                _firstSubNonce + i
            ));
        }
        require(hashes[tempState.accountHash][_nonce] == tempState.batchHash, BatchHashMismatch());

        tempState.teeIdKeyIdPairs = teeWalletKeyManager.receivingTeesAndKeys(tempState.walletId);
        tempState.teeIds = _toTeeIds(tempState.teeIdKeyIdPairs);
        tempState.reissueNumber = reissueCounter[tempState.accountHash][_nonce]++;

        (tempState.cosigners, tempState.cosignersThreshold) =
            teeWalletManager.getWalletCosignersAndThreshold(tempState.walletId);

        tempState.instructionId = keccak256(abi.encode(
            opType, REISSUE, _account.sourceId, _account.accountAddress, _nonce, tempState.reissueNumber
        ));
        // reissue batch
        tempState.remainingAmount = msg.value;
        for (uint64 i = 0; i < _paymentInstructions.length; i++) {
            tempState.message = PaymentInstructionMessage({
                walletId: tempState.walletId,
                teeIdKeyIdPairs: tempState.teeIdKeyIdPairs,
                sourceId: _account.sourceId,
                senderAddress: _account.accountAddress,
                recipientAddress: _paymentInstructions[i].recipientAddress,
                tokenId: _paymentInstructions[i].tokenId,
                amount: _paymentInstructions[i].amount,
                fee: _fees[i],
                paymentReference: _paymentInstructions[i].paymentReference,
                nonce: _nonce,
                subNonce: _firstSubNonce + i,
                batchEndTs: uint64(block.timestamp)
            });
            if (_nullify[i]) {
                tempState.message.tokenId = bytes32(0);
                tempState.message.amount = 0;
                tempState.message.recipientAddress = _account.accountAddress;
            }
            tempState.amount = tempState.remainingAmount / (_paymentInstructions.length - i);
            tempState.remainingAmount -= tempState.amount;
            teeExtensionRegistry.sendSystemInstructions{value: tempState.amount}(
                tempState.instructionId,
                tempState.teeIds,
                opType,
                REISSUE,
                abi.encode(tempState.message),
                tempState.cosigners,
                tempState.cosignersThreshold
            );
        }
    }

    /**
     * @inheritdoc ITeePayments
     */
    function addPMWMultisigAccount(
        bytes32 _walletId,
        IPMWMultisigAccountConfigured.Proof calldata _proof
    )
        external
    {
        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        require(teeWalletProjectManager.getOwner(projectId) == msg.sender, OnlyWalletOwner());
        require(teeWalletProjectManager.getExtensionId(projectId) == 0, OnlySystemExtensionId());
        require(teeWalletProjectManager.getKeyType(projectId) == keyType, WrongKeyType());
        require(bytes(_proof.requestBody.accountAddress).length > 0, AccountAddressZero());
        require(supportedSourceIds.contains(_proof.header.sourceId), UnsupportedSourceId());
        bytes32 accountHash = _toAccountHash(_proof.header.sourceId, _proof.requestBody.accountAddress);
        require(accountHashToWalletId[accountHash] == 0, PMWMultisigAccountAddressAlreadySet());
        ITeeWalletManager.WalletStatus walletStatus = teeWalletManager.getWalletStatus(_walletId);
        require(
            walletStatus == ITeeWalletManager.WalletStatus.PRODUCTION ||
            walletStatus == ITeeWalletManager.WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );
        require(teeVerification.verifyPMWMultisigAccountConfiguredProof(_walletId, _proof), InvalidProof());
        accountHashToWalletId[accountHash] = _walletId;
        walletAccounts[_walletId].push(PMWMultisigAccount(_proof.header.sourceId, _proof.requestBody.accountAddress));
        states[accountHash].nonce = _proof.responseBody.sequence;
        states[accountHash].subNonce = _proof.responseBody.sequence;
        settings[accountHash].batchSize = 1;
        emit PMWMultisigAccountAdded(
            _walletId,
            _proof.header.sourceId,
            _proof.requestBody.accountAddress,
            _proof.responseBody.sequence,
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
        external onlyWalletOwner(_account)
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
    function setPaymentLimits(
        PMWMultisigAccount calldata _account,
        uint256 _transactionLimit,
        uint256 _dailyLimit
    )
        external payable onlyWalletOwner(_account)
    {
        require(_dailyLimit >= _transactionLimit, DailyLimitBelowTransactionLimit());
        bytes32 accountHash = _toAccountHash(_account.sourceId, _account.accountAddress);
        bytes32 walletId = accountHashToWalletId[accountHash];
        TeeIdKeyIdPair[] memory teeIdKeyIdPairs = teeWalletKeyManager.receivingTeesAndKeys(walletId);

        SetPaymentLimits memory message = SetPaymentLimits({
            walletId: walletId,
            sourceId: _account.sourceId,
            accountAddress: _account.accountAddress,
            nonce: setPaymentLimitsNonce[accountHash]++,
            teeIdKeyIdPairs: teeIdKeyIdPairs,
            transactionLimit: _transactionLimit,
            dailyLimit: _dailyLimit
        });
        (address[] memory admins, uint64 adminsThreshold) = teeWalletManager.getWalletAdminsAndThreshold(walletId);
        teeExtensionRegistry.sendInstructions{value: msg.value}(
            _toTeeIds(teeIdKeyIdPairs),
            opType,
            SET_PAYMENT_LIMITS,
            abi.encode(message),
            admins,
            adminsThreshold
        );
    }

    /**
     * Adds supported source ids.
     * Emits SupportedSourceIdAdded events.
     * @param _sourceIds The source ids to add.
     * Can only be called by the governance.
     */
    function addSupportedSourceIds(
        bytes32[] calldata _sourceIds
    )
        external onlyGovernance
    {
        _addSupportedSourceIds(_sourceIds);
    }

    /**
     * @inheritdoc ITeePayments
     */
    function getOpType()
        external view
        returns(bytes32)
    {
        return opType;
    }

    /**
     * @inheritdoc ITeePayments
     */
    function getKeyType()
        external view
        returns(bytes32)
    {
        return keyType;
    }

    /**
     * @inheritdoc ITeePayments
     */
    function getWalletAccounts(bytes32 _walletId) external view returns(PMWMultisigAccount[] memory) {
        return walletAccounts[_walletId];
    }

    /**
     * @inheritdoc ITeePayments
     */
    function getWalletId(PMWMultisigAccount calldata _account) external view returns (bytes32) {
        return _getWalletId(_account);
    }

    /**
     * @inheritdoc ITeePayments
     */
    function getBatchSettings(
        PMWMultisigAccount calldata _account
    )
        external view
        returns(
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
    function getSupportedSourceIds() external view returns (bytes32[] memory) {
        return supportedSourceIds.values();
    }

    /**
     * @inheritdoc ITeePayments
     */
    function isSourceIdSupported(bytes32 _sourceId) external view returns (bool) {
        return supportedSourceIds.contains(_sourceId);
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
        teeWalletProjectManager = ITeeWalletProjectManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletProjectManager"));
        teeWalletManager = ITeeWalletManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletManager"));
        teeWalletKeyManager = ITeeWalletKeyManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletKeyManager"));
        teeVerification = ITeeVerification(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeVerification"));
        teeExtensionRegistry = IITeeExtensionRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeExtensionRegistry"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
    }

    function _addSupportedSourceIds(bytes32[] calldata _sourceIds) internal {
        for (uint256 i = 0; i < _sourceIds.length; i++) {
            require(_sourceIds[i] != bytes32(0), SourceIdZero(i));
            require(supportedSourceIds.add(_sourceIds[i]), SourceIdAlreadyExists(_sourceIds[i]));
            emit SupportedSourceIdAdded(opType, _sourceIds[i]);
        }
    }

    function _checkOnlyWalletOwner(PMWMultisigAccount calldata _account) internal view {
        bytes32 walletId = _getWalletId(_account);
        bytes32 projectId = teeWalletManager.getWalletProjectId(walletId);
        require(teeWalletProjectManager.getOwner(projectId) == msg.sender, OnlyWalletOwner());
    }

    function _getWalletId(PMWMultisigAccount calldata _account) internal view returns (bytes32) {
        return accountHashToWalletId[_toAccountHash(_account.sourceId, _account.accountAddress)];
    }

    function _toTeeIds(
        TeeIdKeyIdPair[] memory _teeIdKeyIdPairs
    )
        internal pure
        returns(address[] memory _teeIds)
    {
        _teeIds = new address[](_teeIdKeyIdPairs.length);
        for (uint256 i = 0; i < _teeIdKeyIdPairs.length; i++) {
            _teeIds[i] = _teeIdKeyIdPairs[i].teeId;
        }
    }

    function _toAccountHash(bytes32 _sourceId, string memory _accountAddress) internal pure returns (bytes32) {
        return keccak256(abi.encode(_sourceId, _accountAddress));
    }
}
