// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeePayments.sol";
import "../../../../contracts/tee/implementation/TeeInstructions.sol";
import "../../../../contracts/tee/proxy/TeeInstructionsProxy.sol";
import "../../../../contracts/tee/proxy/TeePaymentsProxy.sol";
import "../../../../contracts/protocol/interface/IIRewardManager.sol";
import "../../../../contracts/tee/proxy/TeeExtensionRegistryProxy.sol";
import "../../../../contracts/tee/implementation/TeeExtensionRegistry.sol";

//solhint-disable-next-line max-states-count
contract TeePaymentsTest is Test {

    TeePayments private teePayments;
    TeePayments private teePaymentsImpl;
    TeePaymentsProxy private teePaymentsProxy;

    address private mockTeeWalletManager;
    address private mockFSM;
    address private mockTeeFeeCalculator;
    address private mockTeeInstructions;
    TeeInstructions private teeInstructions;
    TeeInstructions private teeInstructionsImpl;
    TeeInstructionsProxy private teeInstructionsProxy;
    address private mockRewardManager;
    address private mockTeeWalletProjectManager;
    address private mockTeeWalletKeyManager;
    address private teeVerificationMock;
    address private teeMachineRegistryMock;

    TeeExtensionRegistry private teeExtensionRegistry;
    TeeExtensionRegistryProxy private teeExtensionRegistryProxy;
    TeeExtensionRegistry private teeExtensionRegistryImpl;

    address private governance;
    address private addressUpdater;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    bytes32 private constant OP_TYPE = bytes32("F_XRP");
    bytes32 private constant SOURCE_ID = bytes32("XRP");
    bytes32 private constant PAY = bytes32("PAY");
    bytes32 private constant REISSUE = bytes32("REISSUE");
    bytes32 private constant SET_PAYMENT_LIMITS = bytes32("SET_PAYMENT_LIMITS");
    bytes32 private walletId = bytes32("walletId");
    address private walletOwner = makeAddr("walletOwner");
    string private senderAddress = "senderAddress";
    uint256 private fee = 123;
    address private submitAddress = makeAddr("submitAddress");
    bytes32 private projectId = bytes32("projectId");
    IPMWMultisigAccountConfigured.Proof private proof;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        mockTeeWalletManager = makeAddr("teeWalletManager");
        mockFSM = makeAddr("mockFlareSystemsManager");
        mockTeeFeeCalculator = makeAddr("teeFeeCalculator");
        mockTeeInstructions = makeAddr("teeInstructions");
        mockRewardManager = makeAddr("rewardManager");
        mockTeeWalletProjectManager = makeAddr("teeWalletProjectManager");
        mockTeeWalletKeyManager = makeAddr("teeWalletKeyManager");
        teeVerificationMock = makeAddr("teeVerificationMock");
        teeMachineRegistryMock = makeAddr("teeMachineRegistry");

        teeInstructionsImpl = new TeeInstructions();
        teeInstructionsProxy = new TeeInstructionsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(teeInstructionsImpl)
        );
        teeInstructions = TeeInstructions(address(teeInstructionsProxy));

        teePaymentsImpl = new TeePayments();
        teePaymentsProxy = new TeePaymentsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            5, // max batch size
            300, // max batch duration seconds
            OP_TYPE,
            SOURCE_ID,
            address(teePaymentsImpl)
        );
        teePayments = TeePayments(address(teePaymentsProxy));

        teeExtensionRegistryImpl = new TeeExtensionRegistry();
        teeExtensionRegistryProxy = new TeeExtensionRegistryProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(teeExtensionRegistryImpl)
        );
        teeExtensionRegistry = TeeExtensionRegistry(address(teeExtensionRegistryProxy));

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](7);
        contractAddresses = new address[](7);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeWalletProjectManager"));
        contractNameHashes[2] = keccak256(abi.encode("TeeWalletManager"));
        contractNameHashes[3] = keccak256(abi.encode("TeeWalletKeyManager"));
        contractNameHashes[4] = keccak256(abi.encode("TeeVerification"));
        contractNameHashes[5] = keccak256(abi.encode("TeeInstructions"));
        contractNameHashes[6] = keccak256(abi.encode("FlareSystemsManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockTeeWalletProjectManager;
        contractAddresses[2] = mockTeeWalletManager;
        contractAddresses[3] = mockTeeWalletKeyManager;
        // contractAddresses[4] = mockTeeInstructions;
        contractAddresses[4] = teeVerificationMock;
        contractAddresses[5] = address(teeInstructions);
        contractAddresses[6] = mockFSM;
        teePayments.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(teeExtensionRegistry);
        teeInstructions.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeMachineRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("TeeGovernance"));
        contractNameHashes[3] = keccak256(abi.encode("TeeFeeCalculator"));
        contractNameHashes[4] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[5] = keccak256(abi.encode("RewardManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = teeMachineRegistryMock;
        contractAddresses[2] = makeAddr("teeGovernance");
        contractAddresses[3] = mockTeeFeeCalculator;
        contractAddresses[4] = mockFSM;
        contractAddresses[5] = mockRewardManager;
        teeExtensionRegistry.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        _mockGetWalletProjectId(walletId, projectId);
        _mockGetOwner(projectId, walletOwner);
        _mockGetDefaultWalletInfo(projectId, walletId, submitAddress, OP_TYPE);
        _mockGetSubmitAddress(projectId, submitAddress);
        _mockGetCurrentRewardEpochId(10);
        _mockReceiveRewards();
        _mockGetOpType(projectId, OP_TYPE);

        // set tee payments contract as instruction initiator on TeeInstructions
        vm.prank(governance);
        address[] memory instructionInitiators = new address[](1);
        instructionInitiators[0] = address(teePayments);
        teeInstructions.registerInstructionInitiators(instructionInitiators);

        // TODO set public keys and threshold for the proof
        proof.requestBody.walletAddress = senderAddress;
        proof.requestBody.opType = OP_TYPE;
        proof.responseBody.status = IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.OK;
        proof.responseBody.sequence = 11; // set initial nonce to 11

        // fund the submit address and the wallet owner address
        vm.deal(submitAddress, 1 ether);
        vm.deal(walletOwner, 1 ether);

        // move time to 500 seconds
        vm.warp(500);

        _mockVerifyPMWMultisigAccountConfiguredProof(true);
        _mockGetExtensionId(0);
        // set system instruction initiator
        vm.prank(governance);
        address[] memory systemInstructionInitiators = new address[](1);
        systemInstructionInitiators[0] = address(teeInstructions);
        teeExtensionRegistry.registerSystemInstructionInitiators(systemInstructionInitiators);
        _mockCalculateFeeByTeeIds(PAY, fee);
        _mockCalculateFeeByTeeIds(REISSUE, fee);
        _mockCalculateFeeByTeeIds(SET_PAYMENT_LIMITS, fee);
    }

    //// settings tests ////
    function testDeployRevertMaxBatchSize() public {
        vm.expectRevert(ITeePayments.MaxBatchSizeZero.selector);
         new TeePaymentsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            0, // max batch size
            300, // max batch duration seconds
            OP_TYPE,
            SOURCE_ID,
            address(teePaymentsImpl)
        );
    }

    function testDeployRevertOpType() public {
        vm.expectRevert(ITeePayments.OpTypeZero.selector);
        new TeePaymentsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            5, // max batch size
            300, // max batch duration seconds
            bytes32(0), // op type
            SOURCE_ID,
            address(teePaymentsImpl)
        );
    }

    function testSetBatchSettings() public {
        (uint64 batchSize, uint64 batchDurationSeconds) = teePayments.getBatchSettings(walletId);
        assertEq(batchSize, 0);
        assertEq(batchDurationSeconds, 0);
        vm.prank(walletOwner);
        teePayments.setBatchSettings(walletId, 5, 300);
        (batchSize, batchDurationSeconds) = teePayments.getBatchSettings(walletId);
        assertEq(batchSize, 5);
        assertEq(batchDurationSeconds, 300);
    }

    function testRevertSetBatchSizeZero() public {
        vm.prank(walletOwner);
        vm.expectRevert(ITeePayments.BatchSizeZero.selector);
        teePayments.setBatchSettings(walletId, 0, 300);
    }

    function testSetBatchSettingsRevertSize() public {
        uint64 maxBatchSize = teePayments.maxBatchSize();
        vm.prank(walletOwner);
        vm.expectRevert(ITeePayments.BatchSizeTooLarge.selector);
        teePayments.setBatchSettings(walletId, maxBatchSize + 1, 600);
    }

    function testSetBatchSettingsRevertDuration() public {
        uint64 maxBatchDurationSeconds = teePayments.maxBatchDurationSeconds();
        vm.prank(walletOwner);
        vm.expectRevert(ITeePayments.BatchDurationTooLarge.selector);
        teePayments.setBatchSettings(walletId, 1, maxBatchDurationSeconds + 1);
    }

    function testSetBatchSettingsRevertOnlyOwner() public {
        vm.expectRevert(ITeePayments.OnlyWalletOwner.selector);
        teePayments.setBatchSettings(walletId, 5, 300);
    }

    function testSetMinFee() public {
        uint256 minFee = teePayments.getMinFee(walletId);
        assertEq(minFee, 0);
        vm.prank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        minFee = teePayments.getMinFee(walletId);
        assertEq(minFee, 10);
    }

    function testSetMinFeeRevertMinFeeZero() public {
        vm.prank(walletOwner);
        vm.expectRevert(ITeePayments.MinFeeZero.selector);
        teePayments.setMinFee(walletId, 0);
    }

    function testSetMinFeeRevertOnlyOwner() public {
        vm.expectRevert(ITeePayments.OnlyWalletOwner.selector);
        teePayments.setMinFee(walletId, 10);
    }

    // set min fee for multiple wallets
    function testSetMinFees2() public {
        bytes32 walletId2 = bytes32("walletId2");
        bytes32 projectId2 = bytes32("projectId2");
        address walletOwner2 = makeAddr("walletOwner2");
        _mockGetWalletProjectId(walletId2, projectId2);
        _mockGetOwner(projectId2, walletOwner2);
        _mockGetOpType(projectId2, OP_TYPE);

        uint256 minFee = teePayments.getMinFee(walletId);
        assertEq(minFee, 0);
        minFee = teePayments.getMinFee(walletId2);
        assertEq(minFee, 0);
        vm.prank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        vm.prank(walletOwner2);
        teePayments.setMinFee(walletId2, 20);

        minFee = teePayments.getMinFee(walletId);
        assertEq(minFee, 10);
        minFee = teePayments.getMinFee(walletId2);
        assertEq(minFee, 20);
    }

    function testSetWalletAddressAndInitialNonce() public {
        assertEq(bytes(teePayments.getWalletAddress(walletId)), bytes(""));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        // set fees
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        teePayments.setWalletAddressAndInitialNonce(walletId, proof);
        vm.stopPrank();
        assertEq(teePayments.getWalletAddress(walletId), senderAddress);
    }

    function testSetWalletAddressRevertAlreadySet() public {
        testSetWalletAddressAndInitialNonce();
        vm.expectRevert(ITeePayments.WalletAddressAlreadySet.selector);
        vm.prank(walletOwner);
        teePayments.setWalletAddressAndInitialNonce(walletId, proof);
    }

    function testSetWalletAddressRevertOnlyOwner() public {
        vm.expectRevert(ITeePayments.OnlyWalletOwner.selector);
        teePayments.setWalletAddressAndInitialNonce(walletId, proof);
    }

    function testSetWalletAddressRevertWrongStatus() public {
        vm.prank(walletOwner);
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.INITIALIZED);
        vm.expectRevert(ITeePayments.OnlyProductionOrPausedStatus.selector);
        teePayments.setWalletAddressAndInitialNonce(walletId, proof);
    }

    function testSetWalletAddressRevertMinFeeNotSet() public {
        vm.prank(walletOwner);
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.expectRevert(ITeePayments.MinFeeNotSet.selector);
        teePayments.setWalletAddressAndInitialNonce(walletId, proof);
    }

    function testGetOpTypeConstants() public {
        bytes memory opTypeConstants = teePayments.getOpTypeConstants(walletId);
        assertEq(opTypeConstants, "");
    }

    function testGetOpType() public {
        assertEq(teePayments.getOpType(), OP_TYPE);
    }

    function testSetPaymentLimits() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        uint256 transactionLimit = 1000;
        uint256 dailyLimit = 10000;
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, SET_PAYMENT_LIMITS, walletId, 0));
        ITeePayments.SetPaymentLimits memory message = ITeePayments.SetPaymentLimits(
            walletId,
            0,
            teeIdKeyIdPairs,
            transactionLimit,
            dailyLimit
        );
        vm.prank(walletOwner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            SET_PAYMENT_LIMITS,
            abi.encode(message),
            988
        );
        teePayments.setPaymentLimits{value: 988}(walletId, transactionLimit, dailyLimit);
    }

    function testSetPaymentLimitsRevertDailyLower() public {
        vm.prank(walletOwner);
        vm.expectRevert(ITeePayments.DailyLimitBelowTransactionLimit.selector);
        teePayments.setPaymentLimits{value: 988}(walletId, 1000, 500);
    }

    function testSetPaymentLimitsRevertOnlyWalletOwner() public {
        vm.expectRevert(ITeePayments.OnlyWalletOwner.selector);
        teePayments.setPaymentLimits(walletId, 1000, 10000);
    }

    function testSetPaymentLimitsRevertWrongStatus() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.INITIALIZED);
        vm.prank(walletOwner);
        vm.expectRevert(ITeePayments.OnlyProductionOrPausedStatus.selector);
        teePayments.setPaymentLimits(walletId, 1000, 10000);
    }

    function testSetPaymentLimitsWrongOpType() public {
        _mockGetOpType(projectId, bytes32("WRONG"));
        vm.prank(walletOwner);
        vm.expectRevert(ITeePayments.WrongOpType.selector);
        teePayments.setPaymentLimits(walletId, 1000, 10000);
    }

    function testSetPaymentLimitsRevertFeeTooLow() public {
        _mockReceivingTeesAndKeys();
        // set sender address
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        teePayments.setWalletAddressAndInitialNonce(walletId, proof);
        vm.stopPrank();
        vm.prank(walletOwner);
        vm.expectRevert(ITeeExtensionRegistry.FeeTooLow.selector);
        teePayments.setPaymentLimits{value: 1}(walletId, 1000, 10000);
    }

    //// pay tests ////
    function testPayRevertFeeTooLow() public {
        _mockReceivingTeesAndKeys();
        // set sender address
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        teePayments.setWalletAddressAndInitialNonce(walletId, proof);
        vm.stopPrank();
        vm.prank(submitAddress);
        vm.expectRevert(ITeeExtensionRegistry.FeeTooLow.selector);
        teePayments.pay{value: fee - 1}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));
    }

    function testPayRevertOnlySubmitAddress() public {
        vm.expectRevert(ITeePayments.OnlySubmitAddress.selector);
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));
    }

    function testPayRevertWalletNotInProduction() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.INITIALIZED);
        vm.prank(submitAddress);
        vm.expectRevert(ITeePayments.WalletNotInProduction.selector);
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));
    }

    function testPayRevertWrongOpType() public {
        _mockGetDefaultWalletInfo(projectId, walletId, submitAddress, bytes32("WRONG"));
        vm.prank(submitAddress);
        vm.expectRevert(ITeePayments.WrongOpType.selector);
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));
    }

    function testPayRevertWalletAddressNotSet() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(submitAddress);
        vm.expectRevert(ITeePayments.WalletAddressNotSet.selector);
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));
    }

    function testPayRevertDefaultWalletNotSet() public {
        _mockGetDefaultWalletInfo(projectId, bytes32(0), submitAddress, OP_TYPE);
        vm.prank(submitAddress);
        vm.expectRevert(ITeePayments.DefaultWalletNotSet.selector);
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));
    }

    // batch duration is not set (default is 0)
    function testPay1() public {
        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        // set sender address
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        teePayments.setWalletAddressAndInitialNonce(walletId, proof);
        vm.stopPrank();
        // create payment instruction
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, PAY, walletId, 11));
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            10,
            bytes32("ref1"),
            11, // nonce
            11, // subNonce
            500 + 0
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));

        // create new payment instruction; new batch should be created
        instructionId = keccak256(abi.encode(OP_TYPE, PAY, walletId, 12));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            10,
            bytes32("ref2"),
            12, // nonce
            12, // subNonce
            500 + 0
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref2")));
    }

    // batch duration is > 0 but batch size is 1
    function testPay2() public {
        // set batch settings
        vm.prank(walletOwner);
        teePayments.setBatchSettings(walletId, 1, 300);

        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        // set sender address
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        teePayments.setWalletAddressAndInitialNonce(walletId, proof);
        vm.stopPrank();
        // create payment instruction
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, PAY, walletId, 11));
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            10,
            bytes32("ref1"),
            11, // nonce
            11, // subNonce
            500 + 300
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));

        // create new payment instruction; new batch should be created
        instructionId = keccak256(abi.encode(OP_TYPE, PAY, walletId, 12));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            10,
            bytes32("ref2"),
            12, // nonce
            12, // subNonce
            500 + 300
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref2")));
    }

    // batch duration is > 0 and batch size is > 1
    function testPay3() public {
        // set batch settings
        vm.prank(walletOwner);
        teePayments.setBatchSettings(walletId, 2, 300);

        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        // set sender address
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        teePayments.setWalletAddressAndInitialNonce(walletId, proof);
        vm.stopPrank();
        // create payment instruction
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, PAY, walletId, 11));
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            10,
            bytes32("ref1"),
            11, // nonce
            11, // subNonce
            500 + 300
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));

        // create new payment instruction
        instructionId = keccak256(abi.encode(OP_TYPE, PAY, walletId, 11));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            10,
            bytes32("ref2"),
            11, // nonce
            12, // subNonce
            500 + 300
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref2")));

        // create new payment instruction; new batch should be created
        instructionId = keccak256(abi.encode(OP_TYPE, PAY, walletId, 12));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            10,
            bytes32("ref3"),
            12, // nonce
            13, // subNonce
            500 + 300
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref3")));

        // move to the end of batch
        vm.warp(500 + 301);
        // create new payment instruction; new batch should be created
        instructionId = keccak256(abi.encode(OP_TYPE, PAY, walletId, 13));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            10,
            bytes32("ref4"),
            13, // nonce
            14, // subNonce
            500 + 301 + 300 // batch end time
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref4")));

        // one transactions in batch 2, end batch time is not yet reached, new reward epoch started
        // new batch should be created
        _mockGetCurrentRewardEpochId(11);
        instructionId = keccak256(abi.encode(OP_TYPE, PAY, walletId, 14));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            10,
            bytes32("ref5"),
            14, // nonce
            15, // subNonce
            500 + 301 + 300
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref5")));
    }

    // two transactions in batch with nonce 10
    function testPay4() public {
        // set batch settings
        vm.prank(walletOwner);
        teePayments.setBatchSettings(walletId, 2, 300);

        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        // set sender address
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        teePayments.setWalletAddressAndInitialNonce(walletId, proof);
        vm.stopPrank();
        // create payment instruction
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, PAY, walletId, 11));
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            10,
            bytes32("ref1"),
            11, // nonce
            11, // subNonce
            500 + 300
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));

        // create new payment instruction
        instructionId = keccak256(abi.encode(OP_TYPE, PAY, walletId, 11));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            10,
            bytes32("ref2"),
            11, // nonce
            12, // subNonce
            500 + 300
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref2")));
    }

    // pay from not default wallet
    function testPay5() public {
        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        bytes32 walletId2 = bytes32("walletId2");
        vm.mockCall(
            mockTeeWalletManager,
            abi.encodeWithSelector(ITeeWalletManager.getWalletStatus.selector, walletId2),
            abi.encode(ITeeWalletManager.WalletStatus.PRODUCTION)
        );
        _mockGetWalletProjectId(walletId2, projectId);
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId2, 10);
        teePayments.setWalletAddressAndInitialNonce(walletId2, proof);
        vm.stopPrank();
        // create payment instruction
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, PAY, walletId2, 11));
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage(
            walletId2,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            10,
            bytes32("ref1"),
            11, // nonce
            11, // subNonce
            500 + 0
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, walletId2, _createPaymentInstruction(bytes32("ref1")));

        // create new payment instruction; new batch should be created
        instructionId = keccak256(abi.encode(OP_TYPE, PAY, walletId2, 12));
        message = ITeePayments.PaymentInstructionMessage(
            walletId2,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            10,
            bytes32("ref2"),
            12, // nonce
            12, // subNonce
            500 + 0
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, walletId2, _createPaymentInstruction(bytes32("ref2")));
    }

    function testPayRevertWrongProjectId() public {
        bytes32 walletId2 = bytes32("walletId2");
        bytes32 projectId2 = bytes32("projectId2");
        vm.mockCall(
            mockTeeWalletManager,
            abi.encodeWithSelector(ITeeWalletManager.getWalletStatus.selector, walletId2),
            abi.encode(ITeeWalletManager.WalletStatus.PRODUCTION)
        );
        _mockGetWalletProjectId(walletId2, projectId2);
        vm.prank(submitAddress);
        vm.expectRevert(ITeePayments.WrongProjectId.selector);
        teePayments.pay{value: fee} (projectId, walletId2, _createPaymentInstruction(bytes32("ref1")));
    }

    function testPayRevertFeeBelowMinFee() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId, 1000);
        teePayments.setWalletAddressAndInitialNonce(walletId, proof);
        vm.stopPrank();
        vm.prank(submitAddress);
        vm.expectRevert(ITeePayments.FeeBelowMinFee.selector);
        teePayments.pay{value: 999}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));
    }

    //// reissue tests ////
    function testReissueRevertNoPaymentInstructions() public {
        vm.expectRevert(ITeePayments.NoPaymentInstructions.selector);
        uint256[] memory fees = new uint256[](1);
        fees[0] = 200;
        bool[] memory nullify = new bool[](1);
        nullify[0] = false;
        teePayments.reissue(walletId, 1, 1, new ITeePayments.PaymentInstruction[](0), fees, nullify);
    }

    function testReissueRevertFeeTooLow() public {
        testPay3();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        bool[] memory nullify = new bool[](2);
        nullify[0] = false;
        nullify[1] = false;
        // set min fee
        vm.prank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        _mockReceivingTeesAndKeys();
        vm.prank(submitAddress);
        vm.expectRevert(ITeeExtensionRegistry.FeeTooLow.selector);
        teePayments.reissue{value: fee * 2 - 1} (walletId, 11, 11, paymentInstructions, fees, nullify);
    }

    function testReissueRevertWalletAddressNotSet() public {
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        uint256[] memory fees = new uint256[](2);
        fees[0] = 200;
        fees[1] = 200;
        bool[] memory nullify = new bool[](2);
        nullify[0] = false;
        nullify[1] = false;
        vm.expectRevert(ITeePayments.WalletAddressNotSet.selector);
        vm.prank(submitAddress);
        teePayments.reissue{value: fee * 2} (walletId, 1, 1, paymentInstructions, fees, nullify);
    }

    function testReissueRevertNotInProduction() public {
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PAUSED);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 200;
        fees[1] = 200;
        bool[] memory nullify = new bool[](2);
        nullify[0] = false;
        nullify[1] = false;
        // set fees and sender address
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        proof.responseBody.sequence = 10; // set initial nonce to 10
        teePayments.setWalletAddressAndInitialNonce(walletId, proof);
        vm.stopPrank();
        vm.expectRevert(ITeePayments.WalletNotInProduction.selector);
        vm.prank(submitAddress);
        teePayments.reissue{value: fee * 2} (walletId, 1, 1, paymentInstructions, fees, nullify);
    }

    function testReissueRevertOnlySubmitAddress() public {
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 200;
        fees[1] = 200;
        bool[] memory nullify = new bool[](2);
        nullify[0] = false;
        nullify[1] = false;
        // set fees and sender address
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        proof.responseBody.sequence = 10; // set initial nonce to 10
        teePayments.setWalletAddressAndInitialNonce(walletId, proof);
        vm.stopPrank();
        vm.expectRevert(ITeePayments.OnlySubmitAddress.selector);
        teePayments.reissue{value: fee * 2} (walletId, 1, 1, paymentInstructions, fees, nullify);
    }

    // current batch nonce is 11 (state.nonce is 12)
    function testReissueRevertBatchNotEnded() public {
        testPay4();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        bool[] memory nullify = new bool[](2);
        nullify[0] = false;
        nullify[1] = false;
        // set min fee
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        vm.stopPrank();
        vm.prank(submitAddress);
        // batch with nonce 11 is not yet finished
        vm.expectRevert(ITeePayments.BatchNotYetEnded.selector);
        teePayments.reissue{value: fee * 2} (walletId, 11, 11, paymentInstructions, fees, nullify);
    }

    function testReissueRevertHashMismatch1() public {
        testPay3();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref3")); // wrong reference
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        bool[] memory nullify = new bool[](2);
        nullify[0] = false;
        nullify[1] = false;
        // set min fee
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        vm.stopPrank();
        vm.prank(submitAddress);
        // batch with nonce 11 is finished
        vm.expectRevert(ITeePayments.BatchHashMismatch.selector);
        teePayments.reissue{value: fee * 2} (walletId, 11, 11, paymentInstructions, fees, nullify);
    }

    function testReissueRevertHashMismatch2() public {
        testPay4();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref3")); // wrong reference
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        bool[] memory nullify = new bool[](2);
        nullify[0] = false;
        nullify[1] = false;
        // set min fee
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        vm.stopPrank();
        vm.prank(submitAddress);
        // batch with nonce 11 not yet finished but batch end timestamp passed
        vm.warp(500 + 301);
        vm.expectRevert(ITeePayments.BatchHashMismatch.selector);
        teePayments.reissue{value: fee * 2 + 6} (walletId, 11, 11, paymentInstructions, fees, nullify);
    }

    function testReissueRevertLengthsMismatch() public {
        testPay4();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        bool[] memory nullify = new bool[](1);
        // set min fee
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        vm.stopPrank();
        vm.prank(submitAddress);
        // batch with nonce 11 not yet finished but batch end timestamp passed
        vm.warp(500 + 301);
        vm.expectRevert(ITeePayments.LengthsMismatch.selector);
        teePayments.reissue{value: fee * 2 + 6} (walletId, 11, 11, paymentInstructions, fees, nullify);
    }

    function testReissue1() public {
        testPay3();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        bool[] memory nullify = new bool[](2);
        nullify[0] = false;
        nullify[1] = false;
        // set min fee
        vm.prank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        vm.prank(submitAddress);
        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, REISSUE, walletId, 11, 0));
        ITeePayments.PaymentInstructionMessage memory message1 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            150,
            bytes32("ref1"),
            11, // nonce
            11, // subNonce
            uint64(block.timestamp)
        );
        ITeePayments.PaymentInstructionMessage memory message2 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            150,
            bytes32("ref2"),
            11, // nonce
            12, // subNonce
            uint64(block.timestamp)
        );
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            REISSUE,
            abi.encode(message1),
            126 // floor(253/2) = 126; value: 253 = 2*123 (fee) + 7
        );
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            REISSUE,
            abi.encode(message2),
            127 // 253 - 126 = 127
        );
        teePayments.reissue{value: fee * 2 + 7} (walletId, 11, 11, paymentInstructions, fees, nullify);

        // reissue also batch with nonce 13
        paymentInstructions = new ITeePayments.PaymentInstruction[](1);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref4"));
        fees = new uint256[](1);
        fees[0] = 150;
        nullify = new bool[](1);
        nullify[0] = false;
        instructionId = keccak256(abi.encode(OP_TYPE, REISSUE, walletId, 13, 0));
        message1 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            150,
            bytes32("ref4"),
            13, // nonce
            14, // subNonce
            uint64(block.timestamp)
        );
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            REISSUE,
            abi.encode(message1),
            123
        );
        vm.prank(submitAddress);
        teePayments.reissue{value: fee} (walletId, 13, 14, paymentInstructions, fees, nullify);

        // try reissue batch with nonce 14; batch is not yet finished
        paymentInstructions = new ITeePayments.PaymentInstruction[](1);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref5"));
        vm.prank(submitAddress);
        vm.expectRevert(ITeePayments.BatchNotYetEnded.selector);
        teePayments.reissue{value: fee} (walletId, 14, 15, paymentInstructions, fees, nullify);
    }

    function testReissueNullify() public {
        testPay3();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        // set min fee
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        vm.stopPrank();
        vm.prank(submitAddress);
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, REISSUE, walletId, 11, 0));
        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        bool[] memory nullify = new bool[](2);
        nullify[0] = true;
        nullify[1] = false;
        ITeePayments.PaymentInstructionMessage memory message1 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            senderAddress, // recipient is sender address
            0, // amount = 0
            150,
            bytes32("ref1"),
            11, // nonce
            11, // subNonce
            uint64(block.timestamp)
        );
        ITeePayments.PaymentInstructionMessage memory message2 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            150,
            bytes32("ref2"),
            11, // nonce
            12, // subNonce
            uint64(block.timestamp)
        );
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            REISSUE,
            abi.encode(message1),
            126 // floor(253/2) = 126; value: 253 = 2*123 (fee) + 7
        );
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            REISSUE,
            abi.encode(message2),
            127 // 253 - 126 = 127
        );
        teePayments.reissue{value: fee * 2 + 7} (walletId, 11, 11, paymentInstructions, fees, nullify);
    }

    // should reissue batch with nonce 11 twice
    function testReissueTwice() public {
        testPay3();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        // set min fee
        vm.startPrank(walletOwner);
        teePayments.setMinFee(walletId, 10);
        vm.stopPrank();
        vm.prank(submitAddress);
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, REISSUE, walletId, 11, 0));
        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        bool[] memory nullify = new bool[](2);
        nullify[0] = false;
        nullify[1] = false;
        ITeePayments.PaymentInstructionMessage memory message1 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            150,
            bytes32("ref1"),
            11, // nonce
            11, // subNonce
            uint64(block.timestamp)
        );
        ITeePayments.PaymentInstructionMessage memory message2 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            150,
            bytes32("ref2"),
            11, // nonce
            12, // subNonce
            uint64(block.timestamp)
        );
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            REISSUE,
            abi.encode(message1),
            126 // floor(253/2) = 126; value: 253 = 2*123 (fee) + 7
        );
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            REISSUE,
            abi.encode(message2),
            127 // 253 - 126 = 127
        );
        teePayments.reissue{value: fee * 2 + 7} (walletId, 11, 11, paymentInstructions, fees, nullify);

        // reissue again; instructionId changes
        instructionId = keccak256(abi.encode(OP_TYPE, REISSUE, walletId, 11, 1));
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            REISSUE,
            abi.encode(message1),
            126
        );
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            REISSUE,
            abi.encode(message2),
            127
        );
        vm.prank(submitAddress);
        teePayments.reissue{value: fee * 2 + 7} (walletId, 11, 11, paymentInstructions, fees, nullify);
    }

    function testReissueRevertFeeBelowMinFee() public {
testPay3();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 8;
        bool[] memory nullify = new bool[](2);
        nullify[0] = false;
        nullify[1] = false;
        // set min fee
        vm.prank(submitAddress);
        vm.expectRevert(ITeePayments.FeeBelowMinFee.selector);
        teePayments.reissue{value: fee * 2 + 7} (walletId, 11, 11, paymentInstructions, fees, nullify);
    }

    //// Proxy upgrade
    function testUpgradeProxy() public {
        assertEq(teePayments.maxBatchSize(), 5);
        assertEq(teePayments.implementation(), address(teePaymentsImpl));
        // upgrade
        TeePayments newTeePaymentsImpl = new TeePayments();
        vm.prank(governance);
        teePayments.upgradeToAndCall(address(newTeePaymentsImpl), bytes(""));
        // check
        assertEq(teePayments.implementation(), address(newTeePaymentsImpl));
        assertEq(teePayments.governance(), governance);
        assertEq(teePayments.maxBatchSize(), 5);
    }

    function testUpgradeProxyRevertOnlyGovernance() public {
        TeePayments newTeePaymentsImpl = new TeePayments();
        vm.expectRevert("only governance");
        teePayments.upgradeToAndCall(address(newTeePaymentsImpl), bytes(""));
    }

    // revert in GovernedBase.initialise
    function testUpgradeProxyAndInitializeRevert() public {
        TeePayments newTeePaymentsImpl = new TeePayments();
        vm.prank(governance);
        vm.expectRevert("initialised != false");
        teePayments.upgradeToAndCall(address(newTeePaymentsImpl), abi.encodeCall(
            TeePayments.initialize, (
                IGovernanceSettings(makeAddr("governanceSettings")),
                governance,
                addressUpdater,
                6,
                400,
                OP_TYPE,
                SOURCE_ID
            )
        ));
    }

    //// mocks and helpers ////
    function _mockGetWalletProjectId(bytes32 _walletId, bytes32 _projectId) internal {
        vm.mockCall(
            mockTeeWalletManager,
            abi.encodeWithSelector(ITeeWalletManager.getWalletProjectId.selector, _walletId),
            abi.encode(_projectId)
        );
    }

    function _mockGetOwner(bytes32 _projectId, address _walletOwner) internal {
        vm.mockCall(
            mockTeeWalletProjectManager,
            abi.encodeWithSelector(ITeeWalletProjectManager.getOwner.selector, _projectId),
            abi.encode(_walletOwner)
        );
    }

    function _mockGetWalletStatus(ITeeWalletManager.WalletStatus _status) internal {
        vm.mockCall(
            mockTeeWalletManager,
            abi.encodeWithSelector(ITeeWalletManager.getWalletStatus.selector, walletId),
            abi.encode(_status)
        );
    }

    function _createPaymentInstruction(
        bytes32 _paymentReference
    )
        internal pure returns (ITeePayments.PaymentInstruction memory)
    {
        return ITeePayments.PaymentInstruction({
            recipientAddress: "recipientAddress",
            amount: 100,
            fee: 10,
            paymentReference: _paymentReference
        });
    }

    function _mockGetDefaultWalletInfo(
        bytes32 _projectId,
        bytes32 _walletId,
        address _submitAddress,
        bytes32 _walletOpType
    )
        internal
    {
        vm.mockCall(
            mockTeeWalletProjectManager,
            abi.encodeWithSelector(ITeeWalletProjectManager.getDefaultWalletInfo.selector, _projectId),
            abi.encode(
                _walletId,
                _walletOpType,
                _submitAddress
            )
        );
    }

    function _mockGetSubmitAddress(bytes32 _projectId, address _submitAddress) internal {
        vm.mockCall(
            mockTeeWalletProjectManager,
            abi.encodeWithSelector(ITeeWalletProjectManager.getSubmitAddress.selector, _projectId),
            abi.encode(_submitAddress)
        );
    }

    function _mockGetCurrentRewardEpochId(uint24 _rewardEpochId) internal {
        vm.mockCall(
            mockFSM,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(_rewardEpochId)
        );
    }

    function _mockReceivingTeesAndKeys() internal returns (
        ITeeMachineRegistry.TeeMachine[] memory,
        TeeIdKeyIdPair[] memory _teeIdKeyIdPairs
    ) {
        ITeeMachineRegistry.TeeMachine[] memory receivingTees = new ITeeMachineRegistry.TeeMachine[](1);
        TeeIdKeyIdPair[] memory teeIdKeyIdPairs =
            new TeeIdKeyIdPair[](1);
        receivingTees[0] = ITeeMachineRegistry.TeeMachine({
            teeId: makeAddr("teeId"),
            teeProxyId: makeAddr("teeProxyId"),
            url: "teeUrl"
        });
        teeIdKeyIdPairs[0] = TeeIdKeyIdPair({
            teeId: receivingTees[0].teeId,
            keyId: 1
        });
        vm.mockCall(
            mockTeeWalletKeyManager,
            abi.encodeWithSelector(ITeeWalletKeyManager.receivingTeesAndKeys.selector),
            abi.encode(teeIdKeyIdPairs)
        );

        // also mock getTeeMachine
        vm.mockCall(
            teeMachineRegistryMock,
            abi.encodeWithSelector(ITeeMachineRegistry.getTeeMachine.selector, receivingTees[0].teeId),
            abi.encode(receivingTees[0])
        );

        return (receivingTees, teeIdKeyIdPairs);
    }

    function _mockReceiveRewards() internal {
        vm.mockCall(
            mockRewardManager,
            abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
            abi.encode()
        );
    }

    function _mockGetOpType(bytes32 _projectId, bytes32 _opType) internal {
        vm.mockCall(
            mockTeeWalletProjectManager,
            abi.encodeWithSelector(ITeeWalletProjectManager.getOpType.selector, _projectId),
            abi.encode(_opType)
        );
    }

    function _mockVerifyPMWMultisigAccountConfiguredProof(bool _valid) internal{
        vm.mockCall(
            teeVerificationMock,
            abi.encodeWithSelector(ITeeVerification.verifyPMWMultisigAccountConfiguredProof.selector),
            abi.encode(_valid)
        );
    }

    function _mockGetExtensionId(bytes32 _extensionId) internal {
        vm.mockCall(
            teeMachineRegistryMock,
            abi.encodeWithSelector(ITeeMachineRegistry.getExtensionId.selector),
            abi.encode(_extensionId)
        );
    }

    function _mockCalculateFeeByTeeIds(bytes32 _opCommand, uint256 _fee)
        internal
    {
        vm.mockCall(
            mockTeeFeeCalculator,
            abi.encodeWithSelector(ITeeFeeCalculator.calculateFeeByTeeIds.selector, OP_TYPE, _opCommand),
            abi.encode(_fee)
        );
    }

}