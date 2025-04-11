// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeePayments.sol";
import "../../../../contracts/tee/implementation/TeeInstructions.sol";

contract TeePaymentsTest is Test {

    TeePayments private teePayments;
    address private mockTeeWalletManager;
    address private mockFSM;
    address private mockTeeFeeCalculator;
    address private mockTeeInstructions;
    TeeInstructions private teeInstructions;
    address private mockRewardManager;
    address private mockTeeWalletProjectManager;

    address private governance;
    address private addressUpdater;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    bytes32 private immutable opType = bytes32("opType");
    bytes32 public constant PAY = bytes32("PAY");
    bytes32 public constant REISSUE = bytes32("REISSUE");
    bytes32 private walletId = bytes32("walletId");
    address private walletOwner = makeAddr("walletOwner");
    string private senderAddress = "senderAddress";
    uint256 private fee = 123;
    address private submitAddress = makeAddr("submitAddress");
    address private controlAddress = makeAddr("controlAddress");
    bytes32 private projectId = bytes32("projectId");

    event TeeInstructionsSent(
        bytes32 indexed instructionId,
        uint24 indexed rewardEpochId,
        ITeeRegistry.TeeMachine[] teeMachines,
        bytes32 opType,
        bytes32 opCommand,
        bytes message,
        uint256 fee
    );

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        mockTeeWalletManager = makeAddr("teeWalletManager");
        mockFSM = makeAddr("flareSystemsManager");
        mockTeeFeeCalculator = makeAddr("teeFeeCalculator");
        mockTeeInstructions = makeAddr("teeInstructions");
        mockRewardManager = makeAddr("rewardManager");
        mockTeeWalletProjectManager = makeAddr("teeWalletProjectManager");
        teeInstructions = new TeeInstructions(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater
        );

        teePayments = new TeePayments(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            5, // max batch size
            300, // max batch duration seconds
            opType
        );

        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeWalletManager"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("TeeFeeCalculator"));
        contractNameHashes[4] = keccak256(abi.encode("TeeInstructions"));
        contractNameHashes[5] = keccak256(abi.encode("TeeWalletProjectManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockTeeWalletManager;
        contractAddresses[2] = mockFSM;
        contractAddresses[3] = mockTeeFeeCalculator;
        // contractAddresses[4] = mockTeeInstructions;
        contractAddresses[4] = address(teeInstructions);
        contractAddresses[5] = mockTeeWalletProjectManager;
        teePayments.updateContractAddresses(contractNameHashes, contractAddresses);

        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockRewardManager;
        teeInstructions.updateContractAddresses(contractNameHashes, contractAddresses);

        _mockGetWalletProjectId(walletId, projectId);
        _mockGetOwner(projectId, walletOwner);
        _mockCalculateFeeByWalletId(walletId, opType, PAY, fee);
        _mockCalculateFeeByWalletId(walletId, opType, REISSUE, fee);
        _mockGetDefaultWalletInfo(projectId, walletId, submitAddress, opType);
        _mockGetCurrentRewardEpochId(10);
        _mockReceiveRewards();

        // set tee payments contract as instruction initiator on TeeInstructions
        vm.prank(governance);
        address[] memory instructionInitiators = new address[](1);
        instructionInitiators[0] = address(teePayments);
        teeInstructions.registerInstructionInitiators(instructionInitiators);

        // fund the submit address and the control address
        vm.deal(submitAddress, 1 ether);
        vm.deal(controlAddress, 1 ether);

        // move time to 500 seconds
        vm.warp(500);
    }

    //// settings tests ////
    function testDeployRevertMaxBatchSize() public {
        vm.expectRevert("max batch size zero");
        new TeePayments(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            0, // max batch size
            300, // max batch duration seconds
            opType
        );
    }

    function testDeployRevertOpType() public {
        vm.expectRevert("op type zero");
        new TeePayments(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            5, // max batch size
            300, // max batch duration seconds
            bytes32(0) // op type
        );
    }

    function testSetBatchSettings() public {
        (uint64 batchSize, uint64 batchDurationSeconds, , , , ) = teePayments.getWalletSettings(walletId);
        assertEq(batchSize, 0);
        assertEq(batchDurationSeconds, 0);
        vm.prank(walletOwner);
        teePayments.setBatchSettings(walletId, 5, 300);
        (batchSize, batchDurationSeconds, , , , ) = teePayments.getWalletSettings(walletId);
        assertEq(batchSize, 5);
        assertEq(batchDurationSeconds, 300);
    }

    function testRevertSetBatchSizeZero() public {
        vm.prank(walletOwner);
        vm.expectRevert("batch size zero");
        teePayments.setBatchSettings(walletId, 0, 300);
    }

    function testSetBatchSettingsRevertSize() public {
        uint64 maxBatchSize = teePayments.maxBatchSize();
        vm.prank(walletOwner);
        vm.expectRevert("batch size too high");
        teePayments.setBatchSettings(walletId, maxBatchSize + 1, 600);
    }

    function testSetBatchSettingsRevertDuration() public {
        uint64 maxBatchDurationSeconds = teePayments.maxBatchDurationSeconds();
        vm.prank(walletOwner);
        vm.expectRevert("batch duration too high");
        teePayments.setBatchSettings(walletId, 1, maxBatchDurationSeconds + 1);
    }

    function testSetBatchSettingsRevertOnlyOwner() public {
        vm.expectRevert("only wallet owner");
        teePayments.setBatchSettings(walletId, 5, 300);
    }

    function testSetFees() public {
        (, , uint256 maxFee, uint256 maxFeeTolerancePPM, , uint256 maxControlFee) =
            teePayments.getWalletSettings(walletId);
        assertEq(maxFee, 0);
        assertEq(maxFeeTolerancePPM, 0);
        assertEq(maxControlFee, 0);
        vm.prank(walletOwner);
        teePayments.setFees(walletId, 100, 1000, 200);
        (, , maxFee, maxFeeTolerancePPM, , maxControlFee) = teePayments.getWalletSettings(walletId);
        assertEq(maxFee, 100);
        assertEq(maxFeeTolerancePPM, 1000);
        assertEq(maxControlFee, 200);
    }

    function testSetFeesRevertMaxFeeHigher() public {
        vm.prank(walletOwner);
        vm.expectRevert("max fee higher than max control fee");
        teePayments.setFees(walletId, 100, 1000, 50);
    }

    function testSetFeesRevertMaxFeeZero() public {
        vm.prank(walletOwner);
        vm.expectRevert("max fee zero");
        teePayments.setFees(walletId, 0, 1000, 200);
    }

    function testSetFessRevertOnlyOwner() public {
        vm.expectRevert("only wallet owner");
        teePayments.setFees(walletId, 100, 1000, 200);
    }

    // set fees for multiple wallets
    function testSetFees2() public {
        bytes32 walletId2 = bytes32("walletId2");
        bytes32 projectId2 = bytes32("projectId2");
        (, , uint256 maxFee, uint256 maxFeeTolerancePPM, , uint256 maxControlFee) =
            teePayments.getWalletSettings(walletId);
        assertEq(maxFee, 0);
        assertEq(maxFeeTolerancePPM, 0);
        assertEq(maxControlFee, 0);
        (, , maxFee, maxFeeTolerancePPM, , maxControlFee) = teePayments.getWalletSettings(walletId2);
        assertEq(maxFee, 0);
        assertEq(maxFeeTolerancePPM, 0);
        assertEq(maxControlFee, 0);
        vm.prank(walletOwner);
        teePayments.setFees(walletId, 100, 1000, 200);
        (, , maxFee, maxFeeTolerancePPM, , maxControlFee) = teePayments.getWalletSettings(walletId);
        assertEq(maxFee, 100);
        assertEq(maxFeeTolerancePPM, 1000);
        assertEq(maxControlFee, 200);
        address walletOwner2 = makeAddr("walletOwner2");
        _mockGetWalletProjectId(walletId2, projectId2);
        _mockGetOwner(projectId2, walletOwner2);
        vm.prank(walletOwner2);
        teePayments.setFees(walletId2, 200, 2000, 400);
        (, , maxFee, maxFeeTolerancePPM, , maxControlFee) = teePayments.getWalletSettings(walletId2);
        assertEq(maxFee, 200);
        assertEq(maxFeeTolerancePPM, 2000);
        assertEq(maxControlFee, 400);
    }

    function testSetControlAddress() public {
        (, , , , address ctrlAddress, ) = teePayments.getWalletSettings(walletId);
        assertEq(ctrlAddress, address(0));
        vm.prank(walletOwner);
        teePayments.setControlAddress(walletId, controlAddress);
        (, , , , ctrlAddress, ) = teePayments.getWalletSettings(walletId);
        assertEq(ctrlAddress, controlAddress);
    }

    function testSetControlAddressRevertOnlyOwner() public {
        vm.expectRevert("only wallet owner");
        teePayments.setControlAddress(walletId, controlAddress);
    }

    function testSetSenderAddressAndInitialNonce() public {
        assertEq(bytes(teePayments.getSenderAddress(walletId)), bytes(""));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        // set fees
        vm.startPrank(walletOwner);
        teePayments.setFees(walletId, 100, 1000, 200);
        teePayments.setSenderAddressAndInitialNonce(walletId, senderAddress, 11);
        vm.stopPrank();
        assertEq(teePayments.getSenderAddress(walletId), senderAddress);
    }

    function testSetSenderAddressRevertAlreadySet() public {
        testSetSenderAddressAndInitialNonce();
        vm.expectRevert("sender address already set");
        vm.prank(walletOwner);
        teePayments.setSenderAddressAndInitialNonce(walletId, senderAddress, 11);
    }

    function testSetSenderAddressRevertOnlyOwner() public {
        vm.expectRevert("only wallet owner");
        teePayments.setSenderAddressAndInitialNonce(walletId, senderAddress, 11);
    }

    function testSetSenderAddressRevertWrongStatus() public {
        vm.prank(walletOwner);
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.INITIALIZED);
        vm.expectRevert("only production or paused status");
        teePayments.setSenderAddressAndInitialNonce(walletId, senderAddress, 11);
    }

    function testSetSenderAddressRevertFeesNotSet() public {
        vm.prank(walletOwner);
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.expectRevert("fees not set");
        teePayments.setSenderAddressAndInitialNonce(walletId, senderAddress, 11);
    }

    function testGetOpTypeConstants() public {
        bytes memory opTypeConstants = teePayments.getOpTypeConstants(walletId);
        assertEq(opTypeConstants, "");
    }

    //// pay tests ////
    function testPayRevertFeeTooLow() public {
        vm.prank(submitAddress);
        vm.expectRevert("fee too low");
        teePayments.pay{value: fee - 1}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));
    }

    function testPayRevertOnlySubmitAddress() public {
        vm.expectRevert("only submit address");
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));
    }

    function testPayRevertWalletNotInProduction() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.INITIALIZED);
        vm.prank(submitAddress);
        vm.expectRevert("wallet not in production");
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));
    }

    function testPayRevertWrongOpType() public {
        _mockGetDefaultWalletInfo(projectId, walletId, submitAddress, bytes32("WRONG"));
        _mockCalculateFeeByWalletId(walletId, bytes32("WRONG"), PAY, fee);
        vm.prank(submitAddress);
        vm.expectRevert("wrong op type");
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));
    }

    function testPayRevertSenderAddressNotSet() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(submitAddress);
        vm.expectRevert("sender address not set");
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));
    }

    // batch duration is not set (default is 0)
    function testPay1() public {
        (ITeeRegistry.TeeMachine[] memory receivingTees,
            ITeeWalletManager.TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        // set sender address
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.startPrank(walletOwner);
        teePayments.setFees(walletId, 100, 1000, 200);
        teePayments.setSenderAddressAndInitialNonce(walletId, senderAddress, 11);
        vm.stopPrank();
        // create payment instruction
        bytes32 instructionId = keccak256(abi.encode(opType, PAY, walletId, 11));
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            bytes32("ref1"),
            11, // nonce
            0, // subNonce
            100,
            1000,
            500 + 0
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            opType,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));

        // create new payment instruction; new batch should be created
        instructionId = keccak256(abi.encode(opType, PAY, walletId, 12));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            bytes32("ref2"),
            12, // nonce
            1, // subNonce
            100,
            1000,
            500 + 0
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            opType,
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

        (ITeeRegistry.TeeMachine[] memory receivingTees,
            ITeeWalletManager.TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        // set sender address
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.startPrank(walletOwner);
        teePayments.setFees(walletId, 100, 1000, 200);
        teePayments.setSenderAddressAndInitialNonce(walletId, senderAddress, 11);
        vm.stopPrank();
        // create payment instruction
        bytes32 instructionId = keccak256(abi.encode(opType, PAY, walletId, 11));
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            bytes32("ref1"),
            11, // nonce
            0, // subNonce
            100,
            1000,
            500 + 300
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            opType,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));

        // create new payment instruction; new batch should be created
        instructionId = keccak256(abi.encode(opType, PAY, walletId, 12));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            bytes32("ref2"),
            12, // nonce
            1, // subNonce
            100,
            1000,
            500 + 300
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            opType,
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

        (ITeeRegistry.TeeMachine[] memory receivingTees,
            ITeeWalletManager.TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        // set sender address
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.startPrank(walletOwner);
        teePayments.setFees(walletId, 100, 1000, 200);
        teePayments.setSenderAddressAndInitialNonce(walletId, senderAddress, 11);
        vm.stopPrank();
        // create payment instruction
        bytes32 instructionId = keccak256(abi.encode(opType, PAY, walletId, 11));
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            bytes32("ref1"),
            11, // nonce
            0, // subNonce
            100,
            1000,
            500 + 300
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            opType,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));

        // create new payment instruction
        instructionId = keccak256(abi.encode(opType, PAY, walletId, 11));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            bytes32("ref2"),
            11, // nonce
            1, // subNonce
            100,
            1000,
            500 + 300
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            opType,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref2")));

        // create new payment instruction; new batch should be created
        instructionId = keccak256(abi.encode(opType, PAY, walletId, 12));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            bytes32("ref3"),
            12, // nonce
            2, // subNonce
            100,
            1000,
            500 + 300
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            opType,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref3")));

        // move to the end of batch
        vm.warp(500 + 301);
        // create new payment instruction; new batch should be created
        instructionId = keccak256(abi.encode(opType, PAY, walletId, 13));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            bytes32("ref4"),
            13, // nonce
            3, // subNonce
            100,
            1000,
            500 + 301 + 300 // batch end time
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            opType,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref4")));

        // one transactions in batch 2, end batch time is not yet reached, new reward epoch started
        // new batch should be created
        _mockGetCurrentRewardEpochId(11);
        instructionId = keccak256(abi.encode(opType, PAY, walletId, 14));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            bytes32("ref5"),
            14, // nonce
            4, // subNonce
            100,
            1000,
            500 + 301 + 300
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            opType,
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

        (ITeeRegistry.TeeMachine[] memory receivingTees,
            ITeeWalletManager.TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        // set sender address
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.startPrank(walletOwner);
        teePayments.setFees(walletId, 100, 1000, 200);
        teePayments.setSenderAddressAndInitialNonce(walletId, senderAddress, 11);
        vm.stopPrank();
        // create payment instruction
        bytes32 instructionId = keccak256(abi.encode(opType, PAY, walletId, 11));
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            bytes32("ref1"),
            11, // nonce
            0, // subNonce
            100,
            1000,
            500 + 300
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            opType,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref1")));

        // create new payment instruction
        instructionId = keccak256(abi.encode(opType, PAY, walletId, 11));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            bytes32("ref2"),
            11, // nonce
            1, // subNonce
            100,
            1000,
            500 + 300
        );
        vm.prank(submitAddress);
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            opType,
            PAY,
            abi.encode(message),
            fee
        );
        teePayments.pay{value: fee}(projectId, bytes32(0), _createPaymentInstruction(bytes32("ref2")));
    }

    //// reissue tests ////
    function testReissueRevertNoPaymentInstructions() public {
        vm.expectRevert("no payment instructions");
        teePayments.reissue(walletId, 1, 1, new ITeePayments.PaymentInstruction[](0), 200, false);
    }

    function testReissueRevertFeeTooLow() public {
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        vm.expectRevert("fee too low");
        teePayments.reissue{value: fee * 2 - 1} (walletId, 1, 1, paymentInstructions, 199, false);
    }

    function testReissueRevertSenderAddressNotSet() public {
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        vm.expectRevert("sender address not set");
        teePayments.reissue{value: fee * 2} (walletId, 1, 1, paymentInstructions, 200, false);
    }

    function testReissueRevertNotInProduction() public {
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PAUSED);
        // set fees and sender address
        vm.startPrank(walletOwner);
        teePayments.setFees(walletId, 100, 1000, 200);
        teePayments.setSenderAddressAndInitialNonce(walletId, senderAddress, 10);
        vm.stopPrank();
        vm.expectRevert("wallet not in production");
        teePayments.reissue{value: fee * 2} (walletId, 1, 1, paymentInstructions, 200, false);
    }

    function testReissueRevertOnlyControlAddress() public {
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        // set fees and sender address
        vm.startPrank(walletOwner);
        teePayments.setFees(walletId, 100, 1000, 200);
        teePayments.setSenderAddressAndInitialNonce(walletId, senderAddress, 10);
        vm.stopPrank();
        vm.expectRevert("only control address");
        teePayments.reissue{value: fee * 2} (walletId, 1, 1, paymentInstructions, 200, false);
    }

    function testReissueRevertFeeTooHigh() public {
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        // set fees, sender address and control address
        vm.startPrank(walletOwner);
        teePayments.setFees(walletId, 100, 1000, 200);
        teePayments.setSenderAddressAndInitialNonce(walletId, senderAddress, 10);
        teePayments.setControlAddress(walletId, controlAddress);
        vm.stopPrank();
        vm.prank(controlAddress);
        vm.expectRevert("fee higher than max control fee");
        teePayments.reissue{value: fee * 2} (walletId, 1, 1, paymentInstructions, 2001, false);
    }

    // current batch nonce is 11 (state.nonce is 12)
    function testReissueRevertBatchNotEnded() public {
        testPay4();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        // set fees and control address
        vm.startPrank(walletOwner);
        teePayments.setFees(walletId, 100, 1000, 200);
        teePayments.setControlAddress(walletId, controlAddress);
        vm.stopPrank();
        vm.prank(controlAddress);
        // batch with nonce 11 is not yet finished
        vm.expectRevert("batch hasn't yet ended");
        teePayments.reissue{value: fee * 2} (walletId, 11, 0, paymentInstructions, 150, false);
    }

    function testReissueRevertHashMismatch1() public {
        testPay3();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref3")); // wrong reference
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        // set fees and control address
        vm.startPrank(walletOwner);
        teePayments.setFees(walletId, 100, 1000, 200);
        teePayments.setControlAddress(walletId, controlAddress);
        vm.stopPrank();
        vm.prank(controlAddress);
        // batch with nonce 11 is finished
        vm.expectRevert("batch hash mismatch");
        teePayments.reissue{value: fee * 2} (walletId, 11, 0, paymentInstructions, 150, false);
    }

    function testReissueRevertHashMismatch2() public {
        testPay4();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref3")); // wrong reference
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        // set fees and control address
        vm.startPrank(walletOwner);
        teePayments.setFees(walletId, 100, 1000, 200);
        teePayments.setControlAddress(walletId, controlAddress);
        vm.stopPrank();
        vm.prank(controlAddress);
        // batch with nonce 11 not yet finished but batch end timestamp passed
        vm.warp(500 + 301);
        vm.expectRevert("batch hash mismatch");
        teePayments.reissue{value: fee * 2 + 6} (walletId, 11, 0, paymentInstructions, 150, false);
    }

    function testReissue1() public {
        testPay3();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        // set fees and control address
        vm.startPrank(walletOwner);
        teePayments.setFees(walletId, 100, 1000, 200);
        teePayments.setControlAddress(walletId, controlAddress);
        vm.stopPrank();
        vm.prank(controlAddress);
        (ITeeRegistry.TeeMachine[] memory receivingTees,
            ITeeWalletManager.TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        bytes32 instructionId = keccak256(abi.encode(opType, REISSUE, walletId, 11, 0));
        ITeePayments.PaymentInstructionMessage memory message1 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            bytes32("ref1"),
            11, // nonce
            0, // subNonce
            150, // fee
            1000,
            block.timestamp
        );
        ITeePayments.PaymentInstructionMessage memory message2 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            bytes32("ref2"),
            11, // nonce
            1, // subNonce
            150, // fee
            1000,
            block.timestamp
        );
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            opType,
            REISSUE,
            abi.encode(message1),
            126 // floor(253/2) = 126; value: 253 = 2*123 (fee) + 7
        );
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            opType,
            REISSUE,
            abi.encode(message2),
            127 // 253 - 126 = 127
        );
        teePayments.reissue{value: fee * 2 + 7} (walletId, 11, 0, paymentInstructions, 150, false);

        // reissue also batch with nonce 13
        paymentInstructions = new ITeePayments.PaymentInstruction[](1);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref4"));
        instructionId = keccak256(abi.encode(opType, REISSUE, walletId, 13, 0));
        message1 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            bytes32("ref4"),
            13, // nonce
            3, // subNonce
            150, // fee
            1000,
            block.timestamp
        );
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            opType,
            REISSUE,
            abi.encode(message1),
            123
        );
        vm.prank(controlAddress);
        teePayments.reissue{value: fee} (walletId, 13, 3, paymentInstructions, 150, false);

        // try reissue batch with nonce 14; batch is not yet finished
        paymentInstructions = new ITeePayments.PaymentInstruction[](1);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref5"));
        vm.prank(controlAddress);
        vm.expectRevert("batch hasn't yet ended");
        teePayments.reissue{value: fee} (walletId, 14, 4, paymentInstructions, 150, false);
    }

    function testReissueNullify() public {
        testPay3();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        // set fees and control address
        vm.startPrank(walletOwner);
        teePayments.setFees(walletId, 100, 1000, 200);
        teePayments.setControlAddress(walletId, controlAddress);
        vm.stopPrank();
        vm.prank(controlAddress);
        bytes32 instructionId = keccak256(abi.encode(opType, REISSUE, walletId, 11, 0));
        (ITeeRegistry.TeeMachine[] memory receivingTees,
            ITeeWalletManager.TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        ITeePayments.PaymentInstructionMessage memory message1 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            senderAddress, // recipient is sender address
            0, // amount = 0
            bytes32("ref1"),
            11, // nonce
            0, // subNonce
            150,
            1000,
            block.timestamp
        );
        ITeePayments.PaymentInstructionMessage memory message2 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            senderAddress, // recipient is sender address
            0, // amount = 0
            bytes32("ref2"),
            11, // nonce
            1, // subNonce
            150, // fee
            1000,
            block.timestamp
        );
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            opType,
            REISSUE,
            abi.encode(message1),
            126 // floor(253/2) = 126; value: 253 = 2*123 (fee) + 7
        );
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            opType,
            REISSUE,
            abi.encode(message2),
            127 // 253 - 126 = 127
        );
        teePayments.reissue{value: fee * 2 + 7} (walletId, 11, 0, paymentInstructions, 150, true);
    }

    // should reissue batch with nonce 11 twice
    function testReissueTwice() public {
              testPay3();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        // set fees and control address
        vm.startPrank(walletOwner);
        teePayments.setFees(walletId, 100, 1000, 200);
        teePayments.setControlAddress(walletId, controlAddress);
        vm.stopPrank();
        vm.prank(controlAddress);
        bytes32 instructionId = keccak256(abi.encode(opType, REISSUE, walletId, 11, 0));
        (ITeeRegistry.TeeMachine[] memory receivingTees,
            ITeeWalletManager.TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        ITeePayments.PaymentInstructionMessage memory message1 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            bytes32("ref1"),
            11, // nonce
            0, // subNonce
            150, // fee
            1000,
            block.timestamp
        );
        ITeePayments.PaymentInstructionMessage memory message2 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            senderAddress,
            "recipientAddress",
            100,
            bytes32("ref2"),
            11, // nonce
            1, // subNonce
            150, // fee
            1000,
            block.timestamp
        );
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            opType,
            REISSUE,
            abi.encode(message1),
            126 // floor(253/2) = 126; value: 253 = 2*123 (fee) + 7
        );
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            opType,
            REISSUE,
            abi.encode(message2),
            127 // 253 - 126 = 127
        );
        teePayments.reissue{value: fee * 2 + 7} (walletId, 11, 0, paymentInstructions, 150, false);

        // reissue again; instructionId changes
        instructionId = keccak256(abi.encode(opType, REISSUE, walletId, 11, 1));
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            opType,
            REISSUE,
            abi.encode(message1),
            126
        );
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            11,
            receivingTees,
            opType,
            REISSUE,
            abi.encode(message2),
            127
        );
        vm.prank(controlAddress);
        teePayments.reissue{value: fee * 2 + 7} (walletId, 11, 0, paymentInstructions, 150, false);
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

    function _mockCalculateFeeByWalletId(
        bytes32 _walletId,
        bytes32 _opType,
        bytes32 _opCommand,
        uint256 _fee
    )
        internal
    {
        vm.mockCall(
            mockTeeFeeCalculator,
            abi.encodeWithSelector(
                ITeeFeeCalculator.calculateFeeByWalletId.selector,
                _opType,
                _opCommand,
                _walletId
            ),
            abi.encode(_fee)
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

    function _mockGetCurrentRewardEpochId(uint24 _rewardEpochId) internal {
        vm.mockCall(
            mockFSM,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(_rewardEpochId)
        );
    }

    function _mockReceivingTeesAndKeys() internal returns (
        ITeeRegistry.TeeMachine[] memory,
        ITeeWalletManager.TeeIdKeyIdPair[] memory _teeIdKeyIdPairs
    ) {
        ITeeRegistry.TeeMachine[] memory receivingTees = new ITeeRegistry.TeeMachine[](1);
        ITeeWalletManager.TeeIdKeyIdPair[] memory teeIdKeyIdPairs =
            new ITeeWalletManager.TeeIdKeyIdPair[](1);
        receivingTees[0] = ITeeRegistry.TeeMachine({
            teeId: makeAddr("teeId"),
            owner: makeAddr("teeOwner"),
            url: "teeUrl"
        });
        teeIdKeyIdPairs[0] = ITeeWalletManager.TeeIdKeyIdPair({
            teeId: receivingTees[0].teeId,
            keyId: 1
        });
        vm.mockCall(
            mockTeeWalletManager,
            abi.encodeWithSelector(ITeeWalletManager.receivingTeesAndKeys.selector),
            abi.encode(receivingTees, teeIdKeyIdPairs)
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

}