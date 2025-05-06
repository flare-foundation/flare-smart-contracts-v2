// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeePayments.sol";
import "../interface/IITeeWalletOpTypeConstants.sol";
import "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../../userInterfaces/tee/ITeeWalletKeyManager.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../governance/implementation/GovernedProxyImplementation.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * TeePayments is a contract used for instructing TEE based wallets payments.
 */
contract TeePayments is ITeePayments, IITeeWalletOpTypeConstants,
    GovernedProxyImplementation, AddressUpdatable, UUPSUpgradeable
{

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
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        ITeeRegistry.TeeMachine[] teeMachines;
        uint32 maxFeeTolerancePPM;
        uint24 currentRewardEpochId;
        uint256 reissueNumber;
        bytes32 instructionId;
        uint256 remainingAmount;
        uint256 amount;
        PaymentInstructionMessage message;
    }

    bytes32 public constant PAY = bytes32("PAY");
    bytes32 public constant REISSUE = bytes32("REISSUE");
    bytes32 public constant SET_PAYMENT_LIMITS = bytes32("SET_PAYMENT_LIMITS");


    bytes32 internal opType;
    uint64 public maxBatchSize;
    uint64 public maxBatchDurationSeconds;

    mapping(bytes32 walletId => WalletState) private states;
    mapping(bytes32 walletId => WalletSettings) private settings;
    mapping(bytes32 walletId => string) private senderAddresses;
    mapping(bytes32 walletId => mapping(uint64 nonce => bytes32)) private hashes;
    mapping(bytes32 walletId => mapping(uint64 nonce => uint256)) private reissueCounter;
    mapping(bytes32 walletId => uint256) private setLimitsCounter;

    /// TeeWalletProjectManager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// TeeWalletManager contract.
    ITeeWalletManager public teeWalletManager;
    /// TeeWalletKeyManager contract.
    ITeeWalletKeyManager public teeWalletKeyManager;
    /// TeeFeeCalculator contract.
    ITeeFeeCalculator public teeFeeCalculator;
    /// TeeInstructions contract.
    ITeeInstructions public teeInstructions;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;

    modifier onlyWalletOwner(bytes32 _walletId) {
        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        require(teeWalletProjectManager.getOwner(projectId) == msg.sender, "only wallet owner");
        _;
    }

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor()
        GovernedProxyImplementation() AddressUpdatable(address(0))
    { }

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
        bytes32 _opType
    )
        external virtual
    {
        require(_maxBatchSize > 0, "max batch size zero");
        require(_opType != bytes32(0), "op type zero");

        GovernedBase.initialise(_governanceSettings, _initialGovernance);
        AddressUpdatable.setAddressUpdaterValue(_addressUpdater);

        maxBatchSize = _maxBatchSize;
        maxBatchDurationSeconds = _maxBatchDurationSeconds;
        opType = _opType;
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
        require(submitAddress == msg.sender, "only submit address");
        require(walletOpType == opType, "wrong op type");
        if (_walletId != bytes32(0)) {
            require(teeWalletManager.getWalletProjectId(_walletId) == _projectId, "wrong project id");
            walletId = _walletId;
        } else {
            require(walletId != bytes32(0), "default wallet not set");
        }
        require(msg.value >= teeFeeCalculator.calculateFeeByWalletId(walletOpType, PAY, walletId), "fee too low");
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

        (ITeeRegistry.TeeMachine[] memory teeMachines, TeeIdKeyIdPair[] memory teeIdKeyIdPairs) =
            teeWalletKeyManager.receivingTeesAndKeys(walletId);

        PaymentInstructionMessage memory message = PaymentInstructionMessage({
            walletId: walletId,
            teeIdKeyIdPairs: teeIdKeyIdPairs,
            senderAddress: senderAddresses[walletId],
            recipientAddress: _paymentInstruction.recipientAddress,
            amount: _paymentInstruction.amount,
            paymentReference: _paymentInstruction.paymentReference,
            nonce: state.nonce - 1,
            subNonce: state.subNonce,
            maxFee: setting.maxFee,
            maxFeeTolerancePPM: setting.maxFeeTolerancePPM,
            batchEndTs: state.batchEndTs
        });
        ++state.subNonce;

        bytes32 instructionId = keccak256(abi.encode(
            opType, PAY, walletId, message.nonce
        ));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
            state.batchRewardEpochId,
            opType,
            PAY,
            abi.encode(message)
        );
        return (message.nonce, message.subNonce);
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
        bool[] calldata _nullify
    )
        external payable
    {
        require(_paymentInstructions.length > 0, "no payment instructions");
        require(_paymentInstructions.length == _nullify.length, "lengths mismatch");
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

        (tempState.teeMachines, tempState.teeIdKeyIdPairs) = teeWalletKeyManager.receivingTeesAndKeys(_walletId);
        tempState.maxFeeTolerancePPM = setting.maxFeeTolerancePPM;
        tempState.currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        tempState.reissueNumber = reissueCounter[_walletId][_nonce]++;
        tempState.instructionId = keccak256(abi.encode(
            opType, REISSUE, _walletId, _nonce, tempState.reissueNumber
        ));
        // reissue batch
        tempState.remainingAmount = msg.value;
        for (uint64 i = 0; i < _paymentInstructions.length; ++i) {
            tempState.message = PaymentInstructionMessage({
                walletId: _walletId,
                teeIdKeyIdPairs: tempState.teeIdKeyIdPairs,
                senderAddress: tempState.senderAddress,
                recipientAddress: _paymentInstructions[i].recipientAddress,
                amount: _paymentInstructions[i].amount,
                paymentReference: _paymentInstructions[i].paymentReference,
                nonce: _nonce,
                subNonce: _firstSubNonce + i,
                maxFee: _fee,
                maxFeeTolerancePPM: tempState.maxFeeTolerancePPM,
                batchEndTs: uint64(block.timestamp)
            });
            if (_nullify[i]) {
                tempState.message.amount = 0;
                tempState.message.recipientAddress = tempState.senderAddress;
            }
            tempState.amount = tempState.remainingAmount / (_paymentInstructions.length - i);
            tempState.remainingAmount -= tempState.amount;
            teeInstructions.sendInstructions{value: tempState.amount}(
                tempState.instructionId,
                tempState.teeMachines,
                tempState.currentRewardEpochId,
                opType,
                REISSUE,
                abi.encode(tempState.message)
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
        emit SenderAddressSet(_walletId, _senderAddress, _initialNonce);
    }

    /**
     * @inheritdoc ITeePayments
     */
    function setPaymentLimits(
        bytes32 _walletId,
        uint256 _transactionLimit,
        uint256 _dailyLimit
    )
        external payable onlyWalletOwner(_walletId)
    {
        require(_dailyLimit >= _transactionLimit, "daily limit lower than transaction limit");
        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        require(teeWalletProjectManager.getOpType(projectId) == opType, "wrong op type");
        ITeeWalletManager.WalletStatus walletStatus = teeWalletManager.getWalletStatus(_walletId);
        require(walletStatus == ITeeWalletManager.WalletStatus.PRODUCTION ||
            walletStatus == ITeeWalletManager.WalletStatus.PAUSED, "only production or paused status");
        require(msg.value >= teeFeeCalculator.calculateFeeByWalletId(opType, SET_PAYMENT_LIMITS, _walletId),
            "fee too low");
        (ITeeRegistry.TeeMachine[] memory teeMachines, TeeIdKeyIdPair[] memory teeIdKeyIdPairs) =
            teeWalletKeyManager.receivingTeesAndKeys(_walletId);

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
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
            opType,
            SET_PAYMENT_LIMITS,
            abi.encode(message)
        );
    }

    /**
     * @inheritdoc ITeePayments
     */
    function getOpType() external view virtual override(ITeePayments, IITeeWalletOpTypeConstants) returns(bytes32) {
        return opType;
    }

    /**
     * @inheritdoc ITeePayments
     */
    function getSenderAddress(bytes32 _walletId) external view returns(string memory) {
        return senderAddresses[_walletId];
    }

    /**
     * @inheritdoc ITeePayments
     */
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
    function getOpTypeConstants(bytes32 _walletId) external view virtual override returns(bytes memory) {
        // return empty bytes
    }

    /////////////////////////////// UUPS UPGRADABLE ///////////////////////////////

    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Only governance can call this method.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data)
        public payable override
        onlyGovernance
        onlyProxy
    {
        super.upgradeToAndCall(newImplementation, data);
    }

    /**
     * Unused. Present just to satisfy UUPSUpgradeable requirement.
     * The real check is in onlyGovernance modifier on upgradeToAndCall.
     */
    function _authorizeUpgrade(address newImplementation) internal override {}

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
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
    }
}