// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../../userInterfaces/tee/ITeePayments.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";

/**
 * TeePayments is a contract used for instructing TEE based wallets payments.
 */
contract TeePayments is ITeePayments, Governed, AddressUpdatable {

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

    /// Flare Systems Manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// TeeWalletManager contract.
    ITeeWalletManager public teeWalletManager;
    /// TeeInstructions contract.
    ITeeInstructions public teeInstructions;
    /// TeeFeeCalculator contract.
    ITeeFeeCalculator public teeFeeCalculator;

    modifier onlyWalletOwner(bytes32 _walletId) {
        require(teeWalletManager.getWalletOwner(_walletId) == msg.sender, "only wallet owner");
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
        maxBatchSize = _maxBatchSize;
        maxBatchDurationSeconds = _maxBatchDurationSeconds;
        opType = _opType;
    }

    /**
     * @inheritdoc ITeePayments
     */
    function pay(
        bytes32 _walletId,
        PaymentInstruction calldata _paymentInstruction
    )
        external payable returns(uint256)
    {
        require(msg.value >= teeFeeCalculator.calculateFeeByWalletId(opType, PAY, _walletId), "fee too low");
        (address submitAddress, ITeeWalletManager.WalletStatus walletStatus, bytes32 walletOpType) =
            teeWalletManager.getWalletInfo(_walletId);
        require(submitAddress == msg.sender, "only submit address");
        require(walletStatus == ITeeWalletManager.WalletStatus.PRODUCTION, "wallet not in production");

        require(walletOpType == opType, "wrong op type");
        require(bytes(senderAddresses[_walletId]).length > 0, "sender address not set");

        WalletState storage state = states[_walletId];
        WalletSettings storage setting = settings[_walletId];
        uint24 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        // check if new batch is needed
        if (state.batchEndTs < block.timestamp || state.batchCounter >= setting.batchSize ||
            currentRewardEpochId > state.batchRewardEpochId) {
            state.batchRewardEpochId = currentRewardEpochId;
            state.batchEndTs = uint64(block.timestamp) + setting.batchDurationSeconds;
            state.batchCounter = 1;
            hashes[_walletId][state.nonce++] = keccak256(abi.encode(
                _paymentInstruction,
                state.subNonce
            ));
        } else {
            ++state.batchCounter;
            hashes[_walletId][state.nonce - 1] = keccak256(abi.encode(
                hashes[_walletId][state.nonce - 1],
                _paymentInstruction,
                state.subNonce
            ));
        }

        PaymentInstructionMessage memory message = PaymentInstructionMessage(
            _walletId,
            senderAddresses[_walletId],
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

        ITeeRegistry.TeeMachine[] memory receivingTees = teeWalletManager.receivingTees(_walletId);

        bytes32 instructionId = keccak256(abi.encode(opType, PAY, _walletId, message.nonce));
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
        require(msg.value >= teeFeeCalculator.calculateFeeByWalletId(opType, PAY, _walletId)
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

        tempState.receivingTees = teeWalletManager.receivingTees(_walletId);
        tempState.maxFeeTolerancePPM = setting.maxFeeTolerancePPM;
        tempState.currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        tempState.instructionId = keccak256(abi.encode(opType, REISSUE, _walletId, _nonce));
        // reissue batch
        tempState.remainingAmount = msg.value;
        for (uint256 i = 0; i < _paymentInstructions.length; ++i) {
            PaymentInstructionMessage memory message = PaymentInstructionMessage(
                _walletId,
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
    function setControlAddress(bytes32 _walletId, address _controlAddress) external {
        require(teeWalletManager.getWalletOwner(_walletId) == msg.sender, "only wallet owner");
        settings[_walletId].controlAddress = _controlAddress;
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
        WalletSettings storage setting = settings[_walletId];
        setting.batchSize = _batchSize;
        setting.batchDurationSeconds = _batchDurationSeconds;
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
        require(_maxControlFee > 0, "max control fee zero");
        setting.maxFee = _maxFee;
        setting.maxFeeTolerancePPM = _maxFeeTolerancePPM;
        setting.maxControlFee = _maxControlFee;
    }

    /**
     * @inheritdoc ITeePayments
     */
    function setSenderAddress(
        bytes32 _walletId,
        string calldata _senderAddress
    )
        external onlyWalletOwner(_walletId)
    {
        require(bytes(senderAddresses[_walletId]).length == 0, "sender address already set");
        ITeeWalletManager.WalletStatus walletStatus = teeWalletManager.getWalletStatus(_walletId);
        require(walletStatus != ITeeWalletManager.WalletStatus.INITIALIZED, "only production or paused status");
        require(settings[_walletId].maxFee > 0, "fees not set");
        senderAddresses[_walletId] = _senderAddress;
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
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
    }
}