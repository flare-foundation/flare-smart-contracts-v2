// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import "../../userInterfaces/tee/ITeePayments.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../interface/IITeeWalletOpTypeConstants.sol";

/**
 * TeePayments is a contract used for instructing TEE based wallets payments.
 */
contract TeePayments is ITeePayments, IITeeWalletOpTypeConstants, Governed, AddressUpdatable {

    struct WalletState {
        uint64 nonce;
        uint64 subNonce;
        uint64 batchEndTs;
        uint24 batchRewardEpochId;
        uint40 batchCounter;
    }

    struct WalletSettings {
        uint96 maxFee;
        uint32 maxFeeTolerancePPM;
        uint64 batchSize;
        uint64 batchDurationSeconds;

        address controlAddress;
        uint96 maxControlFee;
    }

    struct ReissueTempState {
        string senderAddress;
        ITeeWalletManager.TeeIdKeyIdPair[] teeIdKeyIdPairs;
        ITeeRegistry.TeeMachine[] receivingTees;
        uint32 maxFeeTolerancePPM;
        uint24 currentRewardEpochId;
        bytes32 instructionId;
        uint256 remainingAmount;
        uint256 amount;
    }

    bytes32 public constant PAY = bytes32("PAY");
    bytes32 public constant REISSUE = bytes32("REISSUE");

    uint64 public immutable maxBatchSize;
    uint64 public immutable maxBatchDurationSeconds;
    bytes32 public immutable opType;

    mapping(bytes32 walletId => WalletState) private states;
    mapping(bytes32 walletId => WalletSettings) private settings;
    mapping(bytes32 walletId => string) private senderAddresses;
    mapping(bytes32 walletId => mapping(uint64 nonce => bytes32)) private hashes;
    mapping(bytes32 walletId => mapping(uint64 nonce => uint256)) private reissueCounter;

    /// Flare Systems Manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// TeeWalletProjectManager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// TeeWalletManager contract.
    ITeeWalletManager public teeWalletManager;
    /// TeeInstructions contract.
    ITeeInstructions public teeInstructions;
    /// TeeFeeCalculator contract.
    ITeeFeeCalculator public teeFeeCalculator;


    modifier onlyWalletOwner(bytes32 _walletId) {
        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        require(teeWalletProjectManager.getOwner(projectId) == msg.sender, "only wallet owner");
        _;
    }

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
        require(_maxBatchSize > 0, "max batch size zero");
        require(_opType != bytes32(0), "op type zero");
        maxBatchSize = _maxBatchSize;
        maxBatchDurationSeconds = _maxBatchDurationSeconds;
        opType = _opType;
    }

    /**
     * @inheritdoc ITeePayments
     */
    function pay(
        bytes32 _projectId,
        PaymentInstruction calldata _paymentInstruction
    )
        external payable returns(uint256)
    {
        (bytes32 walletId, bytes32 walletOpType, address submitAddress) =
            teeWalletProjectManager.getDefaultWalletInfo(_projectId);
        require(walletId != bytes32(0), "default wallet not set");
        require(msg.value >= teeFeeCalculator.calculateFeeByWalletId(walletOpType, PAY, walletId), "fee too low");
        require(submitAddress == msg.sender, "only submit address");
        require(walletOpType == opType, "wrong op type");
        ITeeWalletManager.WalletStatus walletStatus = teeWalletManager.getWalletStatus(walletId);
        require(walletStatus == ITeeWalletManager.WalletStatus.PRODUCTION, "wallet not in production");
        require(bytes(senderAddresses[walletId]).length > 0, "sender address not set");

        WalletState storage state = states[walletId];
        WalletSettings storage setting = settings[walletId];
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

        (ITeeRegistry.TeeMachine[] memory receivingTees, ITeeWalletManager.TeeIdKeyIdPair[] memory teeIdKeyIdPairs) =
            teeWalletManager.receivingTeesAndKeys(walletId);

        PaymentInstructionMessage memory message = PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddresses[walletId],
            _paymentInstruction.recipientAddress,
            _paymentInstruction.amount,
            _paymentInstruction.paymentReference,
            state.nonce - 1,
            state.subNonce,
            setting.maxFee,
            setting.maxFeeTolerancePPM,
            state.batchEndTs
        );
        ++state.subNonce;

        bytes32 instructionId = keccak256(abi.encode(opType, PAY, walletId, message.nonce));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            receivingTees,
            state.batchRewardEpochId,
            opType,
            PAY,
            abi.encode(message)
        );
        return message.subNonce;
    }

    /**
     * @inheritdoc ITeePayments
     */
    function reissue(
        bytes32 _walletId,
        uint64 _nonce,
        uint64 _firstSubNonce,
        PaymentInstruction[] calldata _paymentInstructions,
        uint96 _fee,
        bool _nullify
    )
        external payable
    {
        require(_paymentInstructions.length > 0, "no payment instructions");
        require(msg.value >= teeFeeCalculator.calculateFeeByWalletId(opType, REISSUE, _walletId)
            * _paymentInstructions.length, "fee too low");
        ReissueTempState memory tempState;
        tempState.senderAddress = senderAddresses[_walletId];
        require(bytes(tempState.senderAddress).length > 0, "sender address not set");
        require(teeWalletManager.getWalletStatus(_walletId) == ITeeWalletManager.WalletStatus.PRODUCTION,
            "wallet not in production");
        WalletSettings storage setting = settings[_walletId];
        require(msg.sender == setting.controlAddress, "only control address");
        require(_fee <= setting.maxControlFee, "fee higher than max control fee");
        WalletState storage state = states[_walletId];
        // check if batch has ended
        require(_nonce + 1 < state.nonce || _nonce + 1 == state.nonce && block.timestamp > state.batchEndTs,
            "batch hasn't yet ended");
        // check if hash matches
        bytes32 batchHash = keccak256(abi.encode(_paymentInstructions[0], _firstSubNonce));
        for (uint256 i = 1; i < _paymentInstructions.length; ++i) {
            batchHash = keccak256(abi.encode(
                batchHash,
                _paymentInstructions[i],
                _firstSubNonce + i
            ));
        }
        require(hashes[_walletId][_nonce] == batchHash, "batch hash mismatch");

        (tempState.receivingTees, tempState.teeIdKeyIdPairs) = teeWalletManager.receivingTeesAndKeys(_walletId);
        tempState.maxFeeTolerancePPM = setting.maxFeeTolerancePPM;
        tempState.currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        uint256 reissueNumber = reissueCounter[_walletId][_nonce]++;
        tempState.instructionId = keccak256(abi.encode(opType, REISSUE, _walletId, _nonce, reissueNumber));
        // reissue batch
        tempState.remainingAmount = msg.value;
        for (uint256 i = 0; i < _paymentInstructions.length; ++i) {
            PaymentInstructionMessage memory message = PaymentInstructionMessage(
                _walletId,
                tempState.teeIdKeyIdPairs,
                tempState.senderAddress,
                _paymentInstructions[i].recipientAddress,
                _paymentInstructions[i].amount,
                _paymentInstructions[i].paymentReference,
                _nonce,
                _firstSubNonce + i,
                _fee,
                tempState.maxFeeTolerancePPM,
                block.timestamp
            );
            if (_nullify) {
                message.amount = 0;
                message.recipientAddress = tempState.senderAddress;
            }
            tempState.amount = tempState.remainingAmount / (_paymentInstructions.length - i);
            tempState.remainingAmount -= tempState.amount;
            teeInstructions.sendInstructions{value: tempState.amount}(
                tempState.instructionId,
                tempState.receivingTees,
                tempState.currentRewardEpochId,
                opType,
                REISSUE,
                abi.encode(message)
            );
        }
    }

    /**
     * @inheritdoc ITeePayments
     */
    function setControlAddress(
        bytes32 _walletId,
        address _controlAddress
    )
        external onlyWalletOwner(_walletId)
    {
        settings[_walletId].controlAddress = _controlAddress;
        emit ControlAddressSet(_walletId, _controlAddress);
    }

    /**
     * @inheritdoc ITeePayments
     */
    function setBatchSettings(
        bytes32 _walletId,
        uint64 _batchSize,
        uint64 _batchDurationSeconds
    )
        external onlyWalletOwner(_walletId)
    {
        require(_batchSize > 0, "batch size zero");
        require(_batchSize <= maxBatchSize, "batch size too high");
        require(_batchDurationSeconds <= maxBatchDurationSeconds, "batch duration too high");
        WalletSettings storage setting = settings[_walletId];
        setting.batchSize = _batchSize;
        setting.batchDurationSeconds = _batchDurationSeconds;
        emit BatchSettingsSet(_walletId, _batchSize, _batchDurationSeconds);
    }

    /**
     * @inheritdoc ITeePayments
     */
    function setFees(
        bytes32 _walletId,
        uint96 _maxFee,
        uint32 _maxFeeTolerancePPM,
        uint96 _maxControlFee
    )
        external onlyWalletOwner(_walletId)
    {
        WalletSettings storage setting = settings[_walletId];
        require(_maxFee <= _maxControlFee, "max fee higher than max control fee");
        require(_maxFee > 0, "max fee zero");
        setting.maxFee = _maxFee;
        setting.maxFeeTolerancePPM = _maxFeeTolerancePPM;
        setting.maxControlFee = _maxControlFee;
        emit FeesSet(_walletId, _maxFee, _maxFeeTolerancePPM, _maxControlFee);
    }

    /**
     * @inheritdoc ITeePayments
     */
    function setSenderAddressAndInitialNonce(
        bytes32 _walletId,
        string calldata _senderAddress,
        uint64 _initialNonce
    )
        external onlyWalletOwner(_walletId)
    {
        require(bytes(senderAddresses[_walletId]).length == 0, "sender address already set");
        ITeeWalletManager.WalletStatus walletStatus = teeWalletManager.getWalletStatus(_walletId);
        require(walletStatus == ITeeWalletManager.WalletStatus.PRODUCTION ||
            walletStatus == ITeeWalletManager.WalletStatus.PAUSED, "only production or paused status");
        require(settings[_walletId].maxFee > 0, "fees not set");
        senderAddresses[_walletId] = _senderAddress;
        states[_walletId].nonce = _initialNonce;
    }

    function getSenderAddress(bytes32 _walletId) external view returns(string memory) {
        return senderAddresses[_walletId];
    }

    function getWalletSettings(
        bytes32 _walletId
    )
        external view
        returns(
            uint64 _batchSize,
            uint64 _batchDurationSeconds,
            uint96 _maxFee,
            uint32 _maxFeeTolerancePPM,
            address _controlAddress,
            uint96 _maxControlFee
        )
    {
        WalletSettings storage setting = settings[_walletId];
        _batchSize = setting.batchSize;
        _batchDurationSeconds = setting.batchDurationSeconds;
        _maxFee = setting.maxFee;
        _maxFeeTolerancePPM = setting.maxFeeTolerancePPM;
        _controlAddress = setting.controlAddress;
        _maxControlFee = setting.maxControlFee;
    }

    /**
     * @inheritdoc IITeeWalletOpTypeConstants
     */
    function getOpTypeConstants(bytes32 _walletId) external view virtual returns(bytes memory) {
        // return empty bytes
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
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        teeWalletProjectManager = ITeeWalletProjectManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletProjectManager"));
        teeWalletManager = ITeeWalletManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletManager"));
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
    }
}