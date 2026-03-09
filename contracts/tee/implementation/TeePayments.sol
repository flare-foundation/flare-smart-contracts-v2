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
        /// multiple of 4 bytes (int16 factor in BIPS, uint16 delay in seconds from start, sorted ascending)
        bytes feeSchedule;
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
        address claimBackAddress;
    }

    struct ReissueTempState {
        bytes32 accountHash;
        uint64 nonce;
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
        bytes defaultFeeSchedule;
        address claimBackAddress;
        bytes32 sourceId;
        string accountAddress;
    }

    /// @dev default fee schedule: factor 1 (10000 BIPS = 0x2710), delay 0 seconds (0x0000)
    bytes public constant DEFAULT_FEE_SCHEDULE = hex"27100000";

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
    mapping(bytes32 accountHash => bytes) private accountFeeSchedule;
    mapping(bytes32 accountHash => mapping(uint256 nonce => bytes32)) private hashes;
    mapping(bytes32 accountHash => mapping(uint256 nonce => uint256)) private reissueCounter;
    mapping(bytes32 accountHash => uint256) private setPaymentLimitsNonce;
    mapping(bytes32 accountHash => address) private authorizationAddresses;

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
        PaymentInstruction calldata _paymentInstruction,
        address _claimBackAddress
    )
        external payable returns (uint64 _nonce, uint64 _subNonce)
    {
        require(_paymentInstruction.amount > 0, PaymentAmountZero());
        require(
            keccak256(bytes(_paymentInstruction.recipientAddress)) != keccak256(bytes(_account.accountAddress)),
            RecipientIsSender()
        );
        bytes32 accountHash = _toAccountHash(_account.sourceId, _account.accountAddress);
        _checkAuthorizationAddress(accountHash);
        bytes32 walletId = accountHashToWalletId[accountHash];
        _checkWalletStatus(walletId);

        AccountState storage state = states[accountHash];
        AccountSettings storage setting = settings[accountHash];
        uint24 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        // check if new batch should be started
        if (state.batchEndTs < block.timestamp || state.batchCounter >= setting.batchSize ||
            currentRewardEpochId > state.batchRewardEpochId) {
            state.batchRewardEpochId = currentRewardEpochId;
            state.batchEndTs = uint64(block.timestamp) + setting.batchDurationSeconds;
            state.batchCounter = 1;
            state.feeSchedule = accountFeeSchedule[accountHash];
            hashes[accountHash][state.nonce++] = _getBatchHash(_paymentInstruction, state.subNonce);
        } else {
            ++state.batchCounter;
            hashes[accountHash][state.nonce - 1] = _getBatchHash(
                hashes[accountHash][state.nonce - 1],
                _paymentInstruction,
                state.subNonce
            );
        }
        TeeIdKeyIdPair[] memory teeIdKeyIdPairs = teeWalletKeyManager.receivingTeesAndKeys(walletId);

        PayTempState memory tempState;
        tempState.claimBackAddress = _claimBackAddress;
        tempState.message = PaymentInstructionMessage({
            walletId: walletId,
            teeIdKeyIdPairs: teeIdKeyIdPairs,
            sourceId: _account.sourceId,
            senderAddress: _account.accountAddress,
            recipientAddress: _paymentInstruction.recipientAddress,
            tokenId: _paymentInstruction.tokenId,
            amount: _paymentInstruction.amount,
            maxFee: _paymentInstruction.maxFee,
            feeSchedule: state.feeSchedule.length > 0 ? state.feeSchedule : DEFAULT_FEE_SCHEDULE,
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
            tempState.cosignersThreshold,
            tempState.claimBackAddress
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
        uint256[] calldata _maxFees,
        int16[][] calldata _feeFactorScheduleBIPS,
        uint16[] calldata _feeDelayScheduleSeconds,
        address _claimBackAddress
    )
        external payable
    {
        require(_paymentInstructions.length > 0, NoPaymentInstructions());
        require(
            _paymentInstructions.length == _maxFees.length &&
            (_maxFees.length == _feeFactorScheduleBIPS.length ||
                _feeFactorScheduleBIPS.length == 0 && _feeDelayScheduleSeconds.length == 0), // use set/default
            LengthsMismatch()
        );
        for (uint256 i = 0; i < _feeFactorScheduleBIPS.length; i++) {
            require(_feeFactorScheduleBIPS[i].length == _feeDelayScheduleSeconds.length, LengthsMismatch());
        }
        _checkDelays(_feeDelayScheduleSeconds);
        ReissueTempState memory tempState;
        tempState.claimBackAddress = _claimBackAddress;
        tempState.sourceId = _account.sourceId;
        tempState.accountAddress = _account.accountAddress;
        tempState.accountHash = _toAccountHash(tempState.sourceId, tempState.accountAddress);
        tempState.nonce = _nonce;
        tempState.walletId = accountHashToWalletId[tempState.accountHash];
        tempState.projectId = teeWalletManager.getWalletProjectId(tempState.walletId);
        _checkAuthorizationAddress(tempState.accountHash);
        _checkWalletStatus(tempState.walletId);
        {
            AccountState storage state = states[tempState.accountHash];
            // check if batch has ended
            require(
                tempState.nonce + 1 < state.nonce ||
                tempState.nonce + 1 == state.nonce && block.timestamp > state.batchEndTs,
                BatchNotYetEnded()
            );
        }

        // check if hash matches
        tempState.batchHash = _getBatchHash(_paymentInstructions[0], _firstSubNonce);
        for (uint256 i = 1; i < _paymentInstructions.length; i++) {
            tempState.batchHash = _getBatchHash(
                tempState.batchHash,
                _paymentInstructions[i],
                _firstSubNonce + i
            );
        }
        require(hashes[tempState.accountHash][tempState.nonce] == tempState.batchHash, BatchHashMismatch());

        tempState.teeIdKeyIdPairs = teeWalletKeyManager.receivingTeesAndKeys(tempState.walletId);
        tempState.teeIds = _toTeeIds(tempState.teeIdKeyIdPairs);
        tempState.reissueNumber = reissueCounter[tempState.accountHash][tempState.nonce]++;

        (tempState.cosigners, tempState.cosignersThreshold) =
            teeWalletManager.getWalletCosignersAndThreshold(tempState.walletId);

        if (_feeDelayScheduleSeconds.length == 0) { // to save gas as not needed otherwise
            tempState.defaultFeeSchedule = (accountFeeSchedule[tempState.accountHash].length > 0) ?
                accountFeeSchedule[tempState.accountHash] : DEFAULT_FEE_SCHEDULE;
        }

        tempState.instructionId = keccak256(abi.encode(
            opType, REISSUE, tempState.sourceId, tempState.accountAddress, tempState.nonce, tempState.reissueNumber
        ));
        // reissue batch
        tempState.remainingAmount = msg.value;
        for (uint256 i = 0; i < _paymentInstructions.length; i++) {
            bytes memory feeSchedule;
            if (_feeFactorScheduleBIPS.length > 0) {
                feeSchedule = _getFeeSchedule(_feeFactorScheduleBIPS[i], _feeDelayScheduleSeconds);
            }
            if (feeSchedule.length == 0) {
                feeSchedule = tempState.defaultFeeSchedule;
            }
            tempState.message = PaymentInstructionMessage({
                walletId: tempState.walletId,
                teeIdKeyIdPairs: tempState.teeIdKeyIdPairs,
                sourceId: tempState.sourceId,
                senderAddress: tempState.accountAddress,
                recipientAddress: _paymentInstructions[i].recipientAddress,
                tokenId: _paymentInstructions[i].tokenId,
                amount: _paymentInstructions[i].amount,
                maxFee: _maxFees[i],
                feeSchedule: feeSchedule,
                paymentReference: _paymentInstructions[i].paymentReference,
                nonce: tempState.nonce,
                subNonce: uint64(_firstSubNonce + i),
                batchEndTs: uint64(block.timestamp)
            });
            tempState.amount = tempState.remainingAmount / (_paymentInstructions.length - i);
            tempState.remainingAmount -= tempState.amount;
            teeExtensionRegistry.sendSystemInstructions{value: tempState.amount}(
                tempState.instructionId,
                tempState.teeIds,
                opType,
                REISSUE,
                abi.encode(tempState.message),
                tempState.cosigners,
                tempState.cosignersThreshold,
                tempState.claimBackAddress
            );
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
        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        require(teeWalletProjectManager.getOwner(projectId) == msg.sender, OnlyWalletOwner());
        require(teeWalletProjectManager.getExtensionId(projectId) == 0, OnlySystemExtensionId());
        require(teeWalletProjectManager.getKeyType(projectId) == keyType, WrongKeyType());
        require(bytes(_proof.requestBody.accountAddress).length > 0, AccountAddressZero());
        require(supportedSourceIds.contains(_proof.header.sourceId), UnsupportedSourceId());
        require(_authorizationAddress != address(0), AuthorizationAddressZero());
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
    function setFeeSchedule(
        PMWMultisigAccount calldata _account,
        int16[] calldata _factorsBIPS,
        uint16[] calldata _delaysSeconds
    )
        external onlyWalletOwner(_account)
    {
        require(_factorsBIPS.length == _delaysSeconds.length, LengthsMismatch());
        _checkDelays(_delaysSeconds);
        bytes memory feeSchedule = _getFeeSchedule(_factorsBIPS, _delaysSeconds);
        bytes32 accountHash = _toAccountHash(_account.sourceId, _account.accountAddress);
        accountFeeSchedule[accountHash] = feeSchedule;
        emit FeeScheduleSet(
            accountHashToWalletId[accountHash],
            _account.sourceId,
            _account.accountAddress,
            _factorsBIPS,
            _delaysSeconds
        );
    }

    /**
     * @inheritdoc ITeePayments
     */
    function setPaymentLimits(
        PMWMultisigAccount calldata _account,
        uint256 _transactionLimit,
        uint256 _dailyLimit,
        address _claimBackAddress
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

        _sendInstructions(
            _toTeeIds(teeIdKeyIdPairs),
            abi.encode(message),
            admins,
            adminsThreshold,
            _claimBackAddress
        );
    }

    /**
     * Adds supported source ids.
     * Emits SupportedSourceIdsAdded events.
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
    function getFeeSchedule(
        PMWMultisigAccount calldata _account
    )
        external view
        returns(int16[] memory _factorsBIPS, uint16[] memory _delaysSeconds)
    {
        bytes memory feeSchedule = accountFeeSchedule[_toAccountHash(_account.sourceId, _account.accountAddress)];
        uint256 length = feeSchedule.length / 4;
        _factorsBIPS = new int16[](length);
        _delaysSeconds = new uint16[](length);
        for (uint256 i = 0; i < length; i++) {
            uint256 offset = i * 4;
            _factorsBIPS[i] = int16(uint16(uint8(feeSchedule[offset])) << 8 | uint16(uint8(feeSchedule[offset + 1])));
            _delaysSeconds[i] = uint16(uint8(feeSchedule[offset + 2])) << 8 | uint16(uint8(feeSchedule[offset + 3]));
        }
    }

    /**
     * @inheritdoc ITeePayments
     */
    function getAuthorizationAddress(PMWMultisigAccount calldata _account)
        external view
        returns (address _authorizationAddress)
    {
        return authorizationAddresses[_toAccountHash(_account.sourceId, _account.accountAddress)];
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

    function _sendInstructions(
        address[] memory _teeIds,
        bytes memory _message,
        address[] memory _cosigners,
        uint64 _cosignersThreshold,
        address _claimBackAddress
    )
        internal
    {
        teeExtensionRegistry.sendInstructions{value: msg.value}(
            _teeIds,
            opType,
            SET_PAYMENT_LIMITS,
            _message,
            _cosigners,
            _cosignersThreshold,
            _claimBackAddress
        );
    }

    function _addSupportedSourceIds(bytes32[] calldata _sourceIds) internal {
        for (uint256 i = 0; i < _sourceIds.length; i++) {
            require(_sourceIds[i] != bytes32(0), SourceIdZero(i));
            require(supportedSourceIds.add(_sourceIds[i]), SourceIdAlreadyExists(_sourceIds[i]));
        }
        emit SupportedSourceIdsAdded(_sourceIds);
    }

    function _checkOnlyWalletOwner(PMWMultisigAccount calldata _account) internal view {
        bytes32 walletId = _getWalletId(_account);
        bytes32 projectId = teeWalletManager.getWalletProjectId(walletId);
        require(teeWalletProjectManager.getOwner(projectId) == msg.sender, OnlyWalletOwner());
    }

    function _checkAuthorizationAddress(bytes32 _accountHash) internal view {
        require(authorizationAddresses[_accountHash] == msg.sender, OnlyAuthorizationAddress());
    }

    function _checkWalletStatus(bytes32 _walletId) internal view {
        require(
            teeWalletManager.getWalletStatus(_walletId) == ITeeWalletManager.WalletStatus.PRODUCTION,
            WalletNotInProduction()
        );
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

    // _factorsBIPS and _delaysSeconds have the same length
    function _getFeeSchedule(int16[] calldata _factorsBIPS, uint16[] calldata _delaysSeconds)
        internal pure
        returns (bytes memory _feeSchedule)
    {
        _feeSchedule = new bytes(_factorsBIPS.length * 4);
        for (uint256 i = 0; i < _factorsBIPS.length; i++) {
            require(
                -10000 <= _factorsBIPS[i] && _factorsBIPS[i] <= 10000 && _factorsBIPS[i] != 0,
                InvalidFeeFactor(i)
            );
            uint256 offset = i * 4;
            _feeSchedule[offset] = bytes1(uint8(uint16(_factorsBIPS[i]) >> 8));
            _feeSchedule[offset + 1] = bytes1(uint8(uint16(_factorsBIPS[i])));
            _feeSchedule[offset + 2] = bytes1(uint8(_delaysSeconds[i] >> 8));
            _feeSchedule[offset + 3] = bytes1(uint8(_delaysSeconds[i]));
        }
    }

    function _checkDelays(uint16[] calldata _delaysSeconds) internal pure {
        for (uint256 i = 0; i < _delaysSeconds.length; i++) {
            require(i == 0 || _delaysSeconds[i] > _delaysSeconds[i - 1], InvalidFeeDelay(i));
        }
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
