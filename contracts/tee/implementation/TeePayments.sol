// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeBase } from "./TeeBase.sol";
import { ITeePayments } from "../../userInterfaces/tee/ITeePayments.sol";
import { ITeeWalletProjectOpTypeConstants } from "../../userInterfaces/tee/ITeeWalletProjectOpTypeConstants.sol";
import { ITeeWalletProjectManager } from "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import { ITeeWalletManager } from "../../userInterfaces/tee/ITeeWalletManager.sol";
import { ITeeWalletKeyManager } from "../../userInterfaces/tee/ITeeWalletKeyManager.sol";
import { ITeeVerification } from "../../userInterfaces/tee/ITeeVerification.sol";
import { ITeeInstructions } from "../../userInterfaces/tee/ITeeInstructions.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { IPMWMultisigAccountConfigured } from "../../userInterfaces/ftdc/IPMWMultisigAccountConfigured.sol";
import { TeeIdKeyIdPair } from "../../userInterfaces/tee/ITeeIdKeyIdPair.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";

/**
 * TeePayments is a contract used for instructing TEE based wallets payments.
 */
contract TeePayments is ITeePayments, ITeeWalletProjectOpTypeConstants, TeeBase {
    struct WalletState {
        uint64 nonce;
        uint64 subNonce;
        uint64 batchEndTs;
        uint24 batchRewardEpochId;
        uint40 batchCounter;
    }

    struct WalletSettings {
        uint128 minFee;
        uint64 batchSize;
        uint64 batchDurationSeconds;
    }

    struct ReissueTempState {
        string walletAddress;
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        address[] teeIds;
        uint256 reissueNumber;
        bytes32 instructionId;
        uint256 remainingAmount;
        uint256 amount;
        uint256 minFee;
        PaymentInstructionMessage message;
        address[] cosigners;
        uint64 cosignersThreshold;
    }

    struct PayTempState {
        PaymentInstructionMessage message;
        address[] cosigners;
        uint64 cosignersThreshold;
    }


    bytes32 public constant PAY = bytes32("PAY");
    bytes32 public constant REISSUE = bytes32("REISSUE");
    bytes32 public constant SET_PAYMENT_LIMITS = bytes32("SET_PAYMENT_LIMITS");

    bytes32 internal opType;
    bytes32 internal sourceId;
    uint64 public maxBatchSize;
    uint64 public maxBatchDurationSeconds;

    mapping(bytes32 walletId => WalletState) private states;
    mapping(bytes32 walletId => WalletSettings) private settings;
    mapping(bytes32 walletId => string) private walletAddresses;
    mapping(bytes32 walletId => mapping(uint64 nonce => bytes32)) private hashes;
    mapping(bytes32 walletId => mapping(uint64 nonce => uint256)) private reissueCounter;
    mapping(bytes32 walletId => uint256) private setLimitsCounter;

    /// TeeWalletProjectManager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// TeeWalletManager contract.
    ITeeWalletManager public teeWalletManager;
    /// TeeWalletKeyManager contract.
    ITeeWalletKeyManager public teeWalletKeyManager;
    /// TeeVerification contract.
    ITeeVerification public teeVerification;
    /// TeeInstructions contract.
    ITeeInstructions public teeInstructions;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;

    modifier onlyWalletOwnerAndCorrectOpType(bytes32 _walletId) {
        _checkOnlyWalletOwnerAndCorrectOpType(_walletId);
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
        bytes32 _sourceId
    )
        external virtual
    {
        require(_maxBatchSize > 0, MaxBatchSizeZero());
        require(_opType != bytes32(0), OpTypeZero());
        require(_sourceId != bytes32(0), SourceIdZero());

        TeeBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);

        maxBatchSize = _maxBatchSize;
        maxBatchDurationSeconds = _maxBatchDurationSeconds;
        opType = _opType;
        sourceId = _sourceId;
    }

    /**
     * @inheritdoc ITeePayments
     */
    function pay(
        bytes32 _projectId,
        bytes32 _walletId,
        PaymentInstruction calldata _paymentInstruction
    )
        external payable returns (uint64 _nonce, uint64 _subNonce)
    {
        (bytes32 walletId, bytes32 walletOpType, address submitAddress) =
            teeWalletProjectManager.getDefaultWalletInfo(_projectId);
        require(submitAddress == msg.sender, OnlySubmitAddress());
        require(walletOpType == opType, WrongOpType());
        if (_walletId != bytes32(0)) {
            require(teeWalletManager.getWalletProjectId(_walletId) == _projectId, WrongProjectId());
            walletId = _walletId;
        } else {
            require(walletId != bytes32(0), DefaultWalletNotSet());
        }
        ITeeWalletManager.WalletStatus walletStatus = teeWalletManager.getWalletStatus(walletId);
        require(walletStatus == ITeeWalletManager.WalletStatus.PRODUCTION, WalletNotInProduction());
        string memory walletAddress = walletAddresses[walletId];
        require(bytes(walletAddress).length > 0, WalletAddressNotSet());

        WalletState storage state = states[walletId];
        WalletSettings storage setting = settings[walletId];
        require(_paymentInstruction.fee >= setting.minFee, FeeBelowMinFee());
        uint24 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        // check if new batch should be started
        if (state.batchEndTs < block.timestamp || state.batchCounter >= setting.batchSize ||
            currentRewardEpochId > state.batchRewardEpochId) {
            state.batchRewardEpochId = currentRewardEpochId;
            state.batchEndTs = uint64(block.timestamp) + setting.batchDurationSeconds;
            state.batchCounter = 1;
            hashes[walletId][state.nonce++] = keccak256(abi.encode(
                _paymentInstruction,
                state.subNonce
            ));
        } else {
            ++state.batchCounter;
            hashes[walletId][state.nonce - 1] = keccak256(abi.encode(
                hashes[walletId][state.nonce - 1],
                _paymentInstruction,
                state.subNonce
            ));
        }
        TeeIdKeyIdPair[] memory teeIdKeyIdPairs = teeWalletKeyManager.receivingTeesAndKeys(walletId);

        PayTempState memory tempState;
        tempState.message = PaymentInstructionMessage({
            walletId: walletId,
            teeIdKeyIdPairs: teeIdKeyIdPairs,
            senderAddress: walletAddress,
            recipientAddress: _paymentInstruction.recipientAddress,
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

        bytes32 instructionId = keccak256(abi.encode(
            opType, PAY, walletId, tempState.message.nonce
        ));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
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
        bytes32 _walletId,
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
        require(
            msg.sender == teeWalletProjectManager.getSubmitAddress(teeWalletManager.getWalletProjectId(_walletId)),
            OnlySubmitAddress()
        );
        ReissueTempState memory tempState;
        tempState.walletAddress = walletAddresses[_walletId];
        require(bytes(tempState.walletAddress).length > 0, WalletAddressNotSet());
        require(
            teeWalletManager.getWalletStatus(_walletId) == ITeeWalletManager.WalletStatus.PRODUCTION,
            WalletNotInProduction()
        );
        WalletState storage state = states[_walletId];
        // check if batch has ended
        require(
            _nonce + 1 < state.nonce ||
            _nonce + 1 == state.nonce && block.timestamp > state.batchEndTs,
            BatchNotYetEnded()
        );
        // check if hash matches
        bytes32 batchHash = keccak256(abi.encode(_paymentInstructions[0], _firstSubNonce));
        for (uint256 i = 1; i < _paymentInstructions.length; i++) {
            batchHash = keccak256(abi.encode(
                batchHash,
                _paymentInstructions[i],
                _firstSubNonce + i
            ));
        }
        require(hashes[_walletId][_nonce] == batchHash, BatchHashMismatch());

        tempState.teeIdKeyIdPairs = teeWalletKeyManager.receivingTeesAndKeys(_walletId);
        tempState.teeIds = _toTeeIds(tempState.teeIdKeyIdPairs);
        tempState.minFee = settings[_walletId].minFee;
        tempState.reissueNumber = reissueCounter[_walletId][_nonce]++;
        tempState.instructionId = keccak256(abi.encode(
            opType, REISSUE, _walletId, _nonce, tempState.reissueNumber
        ));
        (tempState.cosigners, tempState.cosignersThreshold) =
            teeWalletManager.getWalletCosignersAndThreshold(_walletId);
        // reissue batch
        tempState.remainingAmount = msg.value;
        for (uint64 i = 0; i < _paymentInstructions.length; i++) {
            require(_fees[i] >= tempState.minFee, FeeBelowMinFee());
            tempState.message = PaymentInstructionMessage({
                walletId: _walletId,
                teeIdKeyIdPairs: tempState.teeIdKeyIdPairs,
                senderAddress: tempState.walletAddress,
                recipientAddress: _paymentInstructions[i].recipientAddress,
                amount: _paymentInstructions[i].amount,
                fee: _fees[i],
                paymentReference: _paymentInstructions[i].paymentReference,
                nonce: _nonce,
                subNonce: _firstSubNonce + i,
                batchEndTs: uint64(block.timestamp)
            });
            if (_nullify[i]) {
                tempState.message.amount = 0;
                tempState.message.recipientAddress = tempState.walletAddress;
            }
            tempState.amount = tempState.remainingAmount / (_paymentInstructions.length - i);
            tempState.remainingAmount -= tempState.amount;
            teeInstructions.sendInstructions{value: tempState.amount}(
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
    function setBatchSettings(
        bytes32 _walletId,
        uint64 _batchSize,
        uint64 _batchDurationSeconds
    )
        external onlyWalletOwnerAndCorrectOpType(_walletId)
    {
        require(_batchSize > 0, BatchSizeZero());
        require(_batchSize <= maxBatchSize, BatchSizeTooLarge());
        require(_batchDurationSeconds <= maxBatchDurationSeconds, BatchDurationTooLarge());
        WalletSettings storage setting = settings[_walletId];
        setting.batchSize = _batchSize;
        setting.batchDurationSeconds = _batchDurationSeconds;
        emit BatchSettingsSet(_walletId, _batchSize, _batchDurationSeconds);
    }

    /**
     * @inheritdoc ITeePayments
     */
    function setMinFee(
        bytes32 _walletId,
        uint128 _minFee
    )
        external onlyWalletOwnerAndCorrectOpType(_walletId)
    {
        WalletSettings storage setting = settings[_walletId];
        require(_minFee > 0, MinFeeZero());
        setting.minFee = _minFee;
        emit MinFeeSet(_walletId, _minFee);
    }

    /**
     * @inheritdoc ITeePayments
     */
    function setWalletAddressAndInitialNonce(
        bytes32 _walletId,
        IPMWMultisigAccountConfigured.Proof calldata _proof
    )
        external onlyWalletOwnerAndCorrectOpType(_walletId)
    {
        require(bytes(_proof.requestBody.walletAddress).length > 0, WalletAddressZero());
        require(bytes(walletAddresses[_walletId]).length == 0, WalletAddressAlreadySet());
        ITeeWalletManager.WalletStatus walletStatus = teeWalletManager.getWalletStatus(_walletId);
        require(
            walletStatus == ITeeWalletManager.WalletStatus.PRODUCTION ||
            walletStatus == ITeeWalletManager.WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );
        require(settings[_walletId].minFee > 0, MinFeeNotSet());
        require(teeVerification.verifyPMWMultisigAccountConfiguredProof(_walletId, sourceId, _proof), InvalidProof());
        walletAddresses[_walletId] = _proof.requestBody.walletAddress;
        states[_walletId].nonce = _proof.responseBody.sequence;
        states[_walletId].subNonce = _proof.responseBody.sequence;
        emit WalletAddressSet(_walletId, _proof.requestBody.walletAddress, _proof.responseBody.sequence);
    }

    /**
     * @inheritdoc ITeePayments
     */
    function setPaymentLimits(
        bytes32 _walletId,
        uint256 _transactionLimit,
        uint256 _dailyLimit
    )
        external payable onlyWalletOwnerAndCorrectOpType(_walletId)
    {
        require(_dailyLimit >= _transactionLimit, DailyLimitBelowTransactionLimit());
        ITeeWalletManager.WalletStatus walletStatus = teeWalletManager.getWalletStatus(_walletId);
        require(
            walletStatus == ITeeWalletManager.WalletStatus.PRODUCTION ||
            walletStatus == ITeeWalletManager.WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );
        TeeIdKeyIdPair[] memory teeIdKeyIdPairs = teeWalletKeyManager.receivingTeesAndKeys(_walletId);

        uint256 nonce = setLimitsCounter[_walletId]++;
        SetPaymentLimits memory message = SetPaymentLimits({
            walletId: _walletId,
            nonce: nonce,
            teeIdKeyIdPairs: teeIdKeyIdPairs,
            transactionLimit: _transactionLimit,
            dailyLimit: _dailyLimit
        });
        bytes32 instructionId = keccak256(abi.encode(
            opType, SET_PAYMENT_LIMITS, _walletId, nonce
        ));
        (address[] memory admins, uint64 adminsThreshold) =
            teeWalletManager.getWalletAdminsAndThreshold(_walletId);
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            _toTeeIds(teeIdKeyIdPairs),
            opType,
            SET_PAYMENT_LIMITS,
            abi.encode(message),
            admins,
            adminsThreshold
        );
    }

    /**
     * @inheritdoc ITeePayments
     */
    function getOpType()
        external view virtual override(ITeePayments, ITeeWalletProjectOpTypeConstants)
        returns(bytes32)
    {
        return opType;
    }

    /**
     * @inheritdoc ITeePayments
     */
    function getWalletAddress(bytes32 _walletId) external view returns(string memory) {
        return walletAddresses[_walletId];
    }

    /**
     * @inheritdoc ITeePayments
     */
    function getBatchSettings(
        bytes32 _walletId
    )
        external view
        returns(
            uint64 _batchSize,
            uint64 _batchDurationSeconds
        )
    {
        WalletSettings storage setting = settings[_walletId];
        _batchSize = setting.batchSize;
        _batchDurationSeconds = setting.batchDurationSeconds;
    }

    /**
     * @inheritdoc ITeePayments
     */
    function getMinFee(
        bytes32 _walletId
    )
        external view
        returns (
            uint128 _minFee
        )
    {
        WalletSettings storage setting = settings[_walletId];
        _minFee = setting.minFee;
    }

    /**
     * @inheritdoc ITeeWalletProjectOpTypeConstants
     */
    function getOpTypeConstants(bytes32 _projectId) external view virtual override returns(bytes memory) {
        // return empty bytes
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
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
    }

    function _checkOnlyWalletOwnerAndCorrectOpType(bytes32 _walletId) internal view {
        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        require(teeWalletProjectManager.getOwner(projectId) == msg.sender, OnlyWalletOwner());
        require(teeWalletProjectManager.getOpType(projectId) == opType, WrongOpType());
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
}
