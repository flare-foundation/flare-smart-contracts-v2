// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { TeePayments } from "../../../../contracts/tee/implementation/TeePayments.sol";
import { TeePaymentsProxy } from "../../../../contracts/tee/proxy/TeePaymentsProxy.sol";
import { TeeExtensionRegistryProxy } from "../../../../contracts/tee/proxy/TeeExtensionRegistryProxy.sol";
import { TeeExtensionRegistry } from "../../../../contracts/tee/implementation/TeeExtensionRegistry.sol";
import { ITeeWalletManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletManager.sol";
import { ITeePayments } from "../../../../contracts/userInterfaces/tee/ITeePayments.sol";
import { ITeeExtensionRegistry } from "../../../../contracts/userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeWalletProjectManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletProjectManager.sol";
import { ITeeFeeCalculator } from "../../../../contracts/userInterfaces/tee/ITeeFeeCalculator.sol";
import { ITeeVerification } from "../../../../contracts/userInterfaces/tee/ITeeVerification.sol";
import { ITeeMachineRegistry } from "../../../../contracts/userInterfaces/tee/ITeeMachineRegistry.sol";
import { ITeeWalletKeyManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletKeyManager.sol";
import { TeeIdKeyIdPair } from "../../../../contracts/userInterfaces/tee/ITeeIdKeyIdPair.sol";
import {
    IPMWMultisigAccountConfigured
} from "../../../../contracts/userInterfaces/ftdc/IPMWMultisigAccountConfigured.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

//solhint-disable-next-line max-states-count
contract TeePaymentsTest is Test {

    TeePayments private teePayments;
    TeePayments private teePaymentsImpl;
    TeePaymentsProxy private teePaymentsProxy;

    address private mockTeeWalletManager;
    address private mockFSM;
    address private mockTeeFeeCalculator;
    address private mockTeeInstructions;
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
    bytes32 private constant KEY_TYPE = bytes32("XRP_KEY");
    bytes32 private constant SOURCE_ID = bytes32("XRP");
    bytes32 private constant PAY = bytes32("PAY");
    bytes32 private constant REISSUE = bytes32("REISSUE");
    bytes32 private constant SET_PAYMENT_LIMITS = bytes32("SET_PAYMENT_LIMITS");
    bytes32 private walletId = bytes32("walletId");
    address private walletOwner = makeAddr("walletOwner");
    string private senderAddress = "senderAddress";
    uint256 private fee = 123;
    address private authorizationAddress = makeAddr("authorizationAddress");
    bytes32 private projectId = bytes32("projectId");
    bytes32[] private sourceIds;
    ITeePayments.PMWMultisigAccount private pmwMultisigAccount;
    IPMWMultisigAccountConfigured.Proof private proof;
    address[] private admins;
    uint64 private adminsThreshold;
    address[] private cosigners;
    uint64 private cosignersThreshold;

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


        teePaymentsImpl = new TeePayments();
        sourceIds = new bytes32[](1);
        sourceIds[0] = SOURCE_ID;
        teePaymentsProxy = new TeePaymentsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            5, // max batch size
            300, // max batch duration seconds
            OP_TYPE,
            KEY_TYPE,
            sourceIds,
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
        contractNameHashes[5] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractNameHashes[6] = keccak256(abi.encode("FlareSystemsManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockTeeWalletProjectManager;
        contractAddresses[2] = mockTeeWalletManager;
        contractAddresses[3] = mockTeeWalletKeyManager;
        contractAddresses[4] = teeVerificationMock;
        contractAddresses[5] = address(teeExtensionRegistry);
        contractAddresses[6] = mockFSM;
        teePayments.updateContractAddresses(contractNameHashes, contractAddresses);

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
        _mockGetExtensionId(projectId, 0);
        _mockGetOwner(projectId, walletOwner);
        _mockGetCurrentRewardEpochId(10);
        _mockReceiveRewards();
        _mockGetKeyType(projectId, KEY_TYPE);

        pmwMultisigAccount.sourceId = SOURCE_ID;
        pmwMultisigAccount.accountAddress = senderAddress;

        // TODO set public keys and threshold for the proof
        proof.header.sourceId = SOURCE_ID;
        proof.requestBody.accountAddress = senderAddress;
        proof.responseBody.status = IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.OK;
        proof.responseBody.sequence = 11; // set initial nonce to 11

        // fund the authorization address and the wallet owner address
        vm.deal(authorizationAddress, 1 ether);
        vm.deal(walletOwner, 1 ether);

        // move time to 500 seconds
        vm.warp(500);

        _mockVerifyPMWMultisigAccountConfiguredProof(true);
        _mockGetExtensionId(0);
        // set TeePayments contract as system instructions sender on TeeExtensionRegistry
        vm.prank(governance);
        address[] memory systemInstructionsSenders = new address[](1);
        systemInstructionsSenders[0] = address(teePayments);
        teeExtensionRegistry.registerSystemInstructionsSenders(systemInstructionsSenders);
        _mockCalculateFeeByTeeIds(PAY, fee);
        _mockCalculateFeeByTeeIds(REISSUE, fee);
        _mockCalculateFeeByTeeIds(SET_PAYMENT_LIMITS, fee);

        cosigners = new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");
        cosignersThreshold = 1;
        _mockGetWalletCosignersAndThreshold(walletId, cosigners, cosignersThreshold);

        admins = new address[](2);
        admins[0] = makeAddr("admin1");
        admins[1] = makeAddr("admin2");
        adminsThreshold = 2;
        _mockGetWalletAdminsAndThreshold(walletId, admins, adminsThreshold);
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
            KEY_TYPE,
            sourceIds,
            address(teePaymentsImpl)
        );
    }

    function testDeployRevertOpTypeZero() public {
        vm.expectRevert(ITeePayments.OpTypeZero.selector);
        new TeePaymentsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            5, // max batch size
            300, // max batch duration seconds
            bytes32(0), // op type
            KEY_TYPE,
            sourceIds,
            address(teePaymentsImpl)
        );
    }

    function testDeployRevertKeyTypeZero() public {
        vm.expectRevert(ITeePayments.KeyTypeZero.selector);
        new TeePaymentsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            5, // max batch size
            300, // max batch duration seconds
            OP_TYPE,
            bytes32(0), // key type
            sourceIds,
            address(teePaymentsImpl)
        );
    }

    function testDeploySupportedSourceIdsLengthZero() public {
        vm.expectRevert(ITeePayments.SupportedSourceIdsLengthZero.selector);
        sourceIds = new bytes32[](0);
        new TeePaymentsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            5, // max batch size
            300, // max batch duration seconds
            OP_TYPE, // op type
            KEY_TYPE,
            sourceIds,
            address(teePaymentsImpl)
        );
    }

    function testDeploySourceIdZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeePayments.SourceIdZero.selector,
                0
            )
        );
        sourceIds[0] = bytes32(0);
        new TeePaymentsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            5, // max batch size
            300, // max batch duration seconds
            OP_TYPE, // op type
            KEY_TYPE,
            sourceIds,
            address(teePaymentsImpl)
        );
    }

    function testAddPMWMultisigAccount() public {
        assertEq(teePayments.getWalletId(pmwMultisigAccount), bytes32(0));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        assertEq(teePayments.getWalletId(pmwMultisigAccount), walletId);
        assertEq(teePayments.getAuthorizationAddress(pmwMultisigAccount), authorizationAddress);

        ITeePayments.PMWMultisigAccount[] memory accounts = teePayments.getWalletAccounts(walletId);
        assertEq(accounts.length, 1);
        assertEq(accounts[0].accountAddress, senderAddress);
        assertEq(accounts[0].sourceId, SOURCE_ID);
    }

    function testAddPMWMultisigAccountRevertAccountAddressZero() public {
        vm.prank(walletOwner);
        proof.requestBody.accountAddress = "";
        vm.expectRevert(ITeePayments.AccountAddressZero.selector);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    function testAddPMWMultisigAccountRevertAlreadySet() public {
        testAddPMWMultisigAccount();
        vm.expectRevert(ITeePayments.PMWMultisigAccountAddressAlreadySet.selector);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    function testAddPMWMultisigAccountRevertOnlyOwner() public {
        vm.expectRevert(ITeePayments.OnlyWalletOwner.selector);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    function testAddPMWMultisigAccountRevertOnlySystemExtensionId() public {
        _mockGetExtensionId(projectId, 1);
        vm.expectRevert(ITeePayments.OnlySystemExtensionId.selector);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    function testAddPMWMultisigAccountRevertWrongStatus() public {
        vm.prank(walletOwner);
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.INITIALIZED);
        vm.expectRevert(ITeePayments.OnlyProductionOrPausedStatus.selector);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    function testAddPMWMultisigAccountRevertInvalidProof() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        _mockVerifyPMWMultisigAccountConfiguredProof(false);
        vm.expectRevert(ITeePayments.InvalidProof.selector);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    function testAddPMWMultisigAccountRevertWrongKeyType() public {
        _mockGetKeyType(projectId, bytes32("WRONG_KEY_TYPE"));
        vm.expectRevert(ITeePayments.WrongKeyType.selector);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    function testAddPMWMultisigAccountRevertUnsupportedSourceId() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        proof.header.sourceId = bytes32("WRONG_SOURCE_ID");
        vm.prank(walletOwner);
        vm.expectRevert(ITeePayments.UnsupportedSourceId.selector);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    function testAddPMWMultisigAccountRevertAuthorizationAddressZero() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(walletOwner);
        vm.expectRevert(ITeePayments.AuthorizationAddressZero.selector);
        teePayments.addPMWMultisigAccount(walletId, proof, address(0));
    }

    function testGetAuthorizationAddress() public {
        testAddPMWMultisigAccount();
        assertEq(teePayments.getAuthorizationAddress(pmwMultisigAccount), authorizationAddress);
    }

    function testSetBatchSettings() public {
        testAddPMWMultisigAccount();
        (uint64 batchSize, uint64 batchDurationSeconds) = teePayments.getBatchSettings(pmwMultisigAccount);
        assertEq(batchSize, 1);
        assertEq(batchDurationSeconds, 0);
        vm.prank(walletOwner);
        teePayments.setBatchSettings(pmwMultisigAccount, 5, 300);
        (batchSize, batchDurationSeconds) = teePayments.getBatchSettings(pmwMultisigAccount);
        assertEq(batchSize, 5);
        assertEq(batchDurationSeconds, 300);
    }

    function testRevertSetBatchSizeZero() public {
        testAddPMWMultisigAccount();
        vm.prank(walletOwner);
        vm.expectRevert(ITeePayments.BatchSizeZero.selector);
        teePayments.setBatchSettings(pmwMultisigAccount, 0, 300);
    }

    function testSetBatchSettingsRevertSize() public {
        testAddPMWMultisigAccount();
        uint64 maxBatchSize = teePayments.maxBatchSize();
        vm.prank(walletOwner);
        vm.expectRevert(ITeePayments.BatchSizeTooLarge.selector);
        teePayments.setBatchSettings(pmwMultisigAccount, maxBatchSize + 1, 600);
    }

    function testSetBatchSettingsRevertDuration() public {
        testAddPMWMultisigAccount();
        uint64 maxBatchDurationSeconds = teePayments.maxBatchDurationSeconds();
        vm.prank(walletOwner);
        vm.expectRevert(ITeePayments.BatchDurationTooLarge.selector);
        teePayments.setBatchSettings(pmwMultisigAccount, 1, maxBatchDurationSeconds + 1);
    }

    function testSetBatchSettingsRevertOnlyOwner() public {
        testAddPMWMultisigAccount();
        vm.expectRevert(ITeePayments.OnlyWalletOwner.selector);
        teePayments.setBatchSettings(pmwMultisigAccount, 5, 300);
    }

    function testSetBatchSettingsRevertOnlyOwner2() public {
        // account not added
        _mockGetWalletProjectId(bytes32(0), bytes32(0));
        _mockGetOwner(bytes32(0), address(0));
        vm.expectRevert(ITeePayments.OnlyWalletOwner.selector);
        teePayments.setBatchSettings(pmwMultisigAccount, 5, 300);
    }

    function testGetOpType() public {
        assertEq(teePayments.getOpType(), OP_TYPE);
    }

    function testSetPaymentLimits() public {
        testAddPMWMultisigAccount();
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        uint256 transactionLimit = 1000;
        uint256 dailyLimit = 10000;
        bytes32 instructionId = keccak256(abi.encode(0, 0, blockhash(block.number - 1)));
        ITeePayments.SetPaymentLimits memory message = ITeePayments.SetPaymentLimits(
            walletId,
            SOURCE_ID,
            senderAddress,
            0,
            teeIdKeyIdPairs,
            transactionLimit,
            dailyLimit
        );
        vm.prank(walletOwner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            SET_PAYMENT_LIMITS,
            abi.encode(message),
            admins,
            adminsThreshold,
            address(0),
            988
        );
        teePayments.setPaymentLimits{value: 988}(pmwMultisigAccount, transactionLimit, dailyLimit, address(0));
    }

    function testSetPaymentLimitsWithClaimBackAddress() public {
        testAddPMWMultisigAccount();
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        vm.prank(walletOwner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            keccak256(abi.encode(0, 0, blockhash(block.number - 1))),
            10,
            receivingTees,
            OP_TYPE,
            SET_PAYMENT_LIMITS,
            abi.encode(ITeePayments.SetPaymentLimits(walletId, SOURCE_ID, senderAddress, 0, teeIdKeyIdPairs, 1000, 10000)),
            admins,
            adminsThreshold,
            makeAddr("claimBack"),
            988
        );
        teePayments.setPaymentLimits{value: 988}(pmwMultisigAccount, 1000, 10000, makeAddr("claimBack"));
    }

    function testSetPaymentLimitsRevertDailyLower() public {
        testAddPMWMultisigAccount();
        vm.prank(walletOwner);
        vm.expectRevert(ITeePayments.DailyLimitBelowTransactionLimit.selector);
        teePayments.setPaymentLimits{value: 988}(pmwMultisigAccount, 1000, 500, address(0));
    }

    function testSetPaymentLimitsRevertOnlyWalletOwner() public {
        testAddPMWMultisigAccount();
        vm.expectRevert(ITeePayments.OnlyWalletOwner.selector);
        teePayments.setPaymentLimits(pmwMultisigAccount, 1000, 10000, address(0));
    }

    function testSetPaymentLimitsRevertOnlyWalletOwner2() public {
        // account not added
        _mockGetWalletProjectId(bytes32(0), bytes32(0));
        _mockGetOwner(bytes32(0), address(0));
        vm.expectRevert(ITeePayments.OnlyWalletOwner.selector);
        teePayments.setPaymentLimits(pmwMultisigAccount, 1000, 10000, address(0));
    }

    function testSetPaymentLimitsRevertFeeTooLow() public {
        testAddPMWMultisigAccount();
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        _mockReceivingTeesAndKeys();
        vm.prank(walletOwner);
        vm.expectRevert(ITeeExtensionRegistry.FeeTooLow.selector);
        teePayments.setPaymentLimits{value: 1}(pmwMultisigAccount, 1000, 10000, address(0));
    }

    //// pay tests ////
    function testPayRevertFeeTooLow() public {
        _mockReceivingTeesAndKeys();
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        vm.prank(authorizationAddress);
        vm.expectRevert(ITeeExtensionRegistry.FeeTooLow.selector);
        teePayments.pay{value: fee - 1}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref1")), address(0));
    }

    function testPayRevertOnlyAuthorizationAddress() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        vm.expectRevert(ITeePayments.OnlyAuthorizationAddress.selector);
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref1")), address(0));
    }

    function testPayRevertOnlyAuthorizationAddress2() public {
        // account not added
        _mockGetWalletProjectId(bytes32(0), bytes32(0));
        vm.expectRevert(ITeePayments.OnlyAuthorizationAddress.selector);
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref1")), address(0));
    }

    function testPayRevertWalletNotInProduction() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PAUSED);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        vm.prank(authorizationAddress);
        vm.expectRevert(ITeePayments.WalletNotInProduction.selector);
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref1")), address(0));
    }

    function testPayRevertPaymentAmountZero() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        ITeePayments.PaymentInstruction memory instruction = _createPaymentInstruction(bytes32("ref1"));
        instruction.amount = 0;
        vm.prank(authorizationAddress);
        vm.expectRevert(ITeePayments.PaymentAmountZero.selector);
        teePayments.pay{value: fee}(pmwMultisigAccount, instruction, address(0));
    }

    function testPayRevertRecipientIsSender() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        ITeePayments.PaymentInstruction memory instruction = _createPaymentInstruction(bytes32("ref1"));
        instruction.recipientAddress = senderAddress;
        vm.prank(authorizationAddress);
        vm.expectRevert(ITeePayments.RecipientIsSender.selector);
        teePayments.pay{value: fee}(pmwMultisigAccount, instruction, address(0));
    }

    // batch duration is not set (default is 0)
    function testPay1() public {
        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        // create payment instruction
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, PAY, SOURCE_ID, senderAddress, 11));
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            10,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref1"),
            11, // nonce
            11, // subNonce
            500 + 0
        );
        vm.prank(authorizationAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            cosigners,
            cosignersThreshold,
            address(0),
            fee
        );
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref1")), address(0));

        // create new payment instruction; new batch should be created
        instructionId = keccak256(abi.encode(OP_TYPE, PAY, SOURCE_ID, senderAddress, 12));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            10,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref2"),
            12, // nonce
            12, // subNonce
            500 + 0
        );
        vm.prank(authorizationAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            cosigners,
            cosignersThreshold,
            address(0),
            fee
        );
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref2")), address(0));
    }

    // batch duration is > 0 but batch size is 1
    function testPay2() public {
        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.startPrank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        // set batch settings
        teePayments.setBatchSettings(pmwMultisigAccount, 1, 300);
        vm.stopPrank();
        // create payment instruction
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, PAY, SOURCE_ID, senderAddress, 11));
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            10,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref1"),
            11, // nonce
            11, // subNonce
            500 + 300
        );
        vm.prank(authorizationAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            cosigners,
            cosignersThreshold,
            address(0),
            fee
        );
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref1")), address(0));

        // create new payment instruction; new batch should be created
        instructionId = keccak256(abi.encode(OP_TYPE, PAY, SOURCE_ID, senderAddress, 12));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            10,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref2"),
            12, // nonce
            12, // subNonce
            500 + 300
        );
        vm.prank(authorizationAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            cosigners,
            cosignersThreshold,
            address(0),
            fee
        );
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref2")), address(0));
    }

    // batch duration is > 0 and batch size is > 1
    function testPay3() public {
        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.startPrank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        // set batch settings
        teePayments.setBatchSettings(pmwMultisigAccount, 2, 300);
        vm.stopPrank();
        // create payment instruction
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, PAY, SOURCE_ID, senderAddress, 11));
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            10,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref1"),
            11, // nonce
            11, // subNonce
            500 + 300
        );
        vm.prank(authorizationAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            cosigners,
            cosignersThreshold,
            address(0),
            fee
        );
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref1")), address(0));

        // create new payment instruction
        instructionId = keccak256(abi.encode(OP_TYPE, PAY, SOURCE_ID, senderAddress, 11));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            10,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref2"),
            11, // nonce
            12, // subNonce
            500 + 300
        );
        vm.prank(authorizationAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            cosigners,
            cosignersThreshold,
            address(0),
            fee
        );
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref2")), address(0));

        // create new payment instruction with tokenId; new batch should be created
        instructionId = keccak256(abi.encode(OP_TYPE, PAY, SOURCE_ID, senderAddress, 12));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress,
            "recipientAddress",
            bytes("tokenId"), // tokenId
            100,
            10,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref3"),
            12, // nonce
            13, // subNonce
            500 + 300
        );
        vm.prank(authorizationAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            cosigners,
            cosignersThreshold,
            address(0),
            fee
        );
        ITeePayments.PaymentInstruction memory instruction = _createPaymentInstruction(bytes32("ref3"));
        instruction.tokenId = bytes("tokenId");
        teePayments.pay{value: fee}(pmwMultisigAccount, instruction, address(0));

        // move to the end of batch
        vm.warp(500 + 301);
        // create new payment instruction; new batch should be created
        instructionId = keccak256(abi.encode(OP_TYPE, PAY, SOURCE_ID, senderAddress, 13));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            10,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref4"),
            13, // nonce
            14, // subNonce
            500 + 301 + 300 // batch end time
        );
        vm.prank(authorizationAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            cosigners,
            cosignersThreshold,
            address(0),
            fee
        );
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref4")), address(0));

        // one transactions in batch 2, end batch time is not yet reached, new reward epoch started
        // new batch should be created
        _mockGetCurrentRewardEpochId(11);
        instructionId = keccak256(abi.encode(OP_TYPE, PAY, SOURCE_ID, senderAddress, 14));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            10,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref5"),
            14, // nonce
            15, // subNonce
            500 + 301 + 300
        );
        vm.prank(authorizationAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            cosigners,
            cosignersThreshold,
            address(0),
            fee
        );
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref5")), address(0));
    }

    // two transactions in batch with nonce 10
    function testPay4() public {
        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.startPrank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        // set batch settings
        teePayments.setBatchSettings(pmwMultisigAccount, 2, 300);
        vm.stopPrank();
        // create payment instruction
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, PAY, SOURCE_ID, senderAddress, 11));
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            10,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref1"),
            11, // nonce
            11, // subNonce
            500 + 300
        );
        vm.prank(authorizationAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            cosigners,
            cosignersThreshold,
            address(0),
            fee
        );
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref1")), address(0));

        // create new payment instruction
        instructionId = keccak256(abi.encode(OP_TYPE, PAY, SOURCE_ID, senderAddress, 11));
        message = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            10,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref2"),
            11, // nonce
            12, // subNonce
            500 + 300
        );
        vm.prank(authorizationAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            cosigners,
            cosignersThreshold,
            address(0),
            fee
        );
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref2")), address(0));
    }

    // pay from secondary wallet
    function testPay5() public {
        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        bytes32 walletId2 = bytes32("walletId2");
        string memory senderAddress2 = "senderAddress2";
        _mockGetWalletCosignersAndThreshold(walletId2, cosigners, cosignersThreshold);
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.mockCall(
            mockTeeWalletManager,
            abi.encodeWithSelector(ITeeWalletManager.getWalletStatus.selector, walletId2),
            abi.encode(ITeeWalletManager.WalletStatus.PRODUCTION)
        );
        _mockGetWalletProjectId(walletId2, projectId);
        vm.startPrank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        proof.requestBody.accountAddress = senderAddress2;
        teePayments.addPMWMultisigAccount(walletId2, proof, authorizationAddress);
        vm.stopPrank();
        // create payment instruction
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, PAY, SOURCE_ID, senderAddress2, 11));
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage(
            walletId2,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress2,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            10,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref1"),
            11, // nonce
            11, // subNonce
            500 + 0
        );
        vm.prank(authorizationAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            cosigners,
            cosignersThreshold,
            address(0),
            fee
        );
        pmwMultisigAccount.accountAddress = senderAddress2;
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref1")), address(0));

        // create new payment instruction; new batch should be created
        instructionId = keccak256(abi.encode(OP_TYPE, PAY, SOURCE_ID, senderAddress2, 12));
        message = ITeePayments.PaymentInstructionMessage(
            walletId2,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress2,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            10,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref2"),
            12, // nonce
            12, // subNonce
            500 + 0
        );
        vm.prank(authorizationAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            10,
            receivingTees,
            OP_TYPE,
            PAY,
            abi.encode(message),
            cosigners,
            cosignersThreshold,
            address(0),
            fee
        );
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref2")), address(0));
    }

    //// reissue tests ////
    function testReissueRevertNoPaymentInstructions() public {
        vm.expectRevert(ITeePayments.NoPaymentInstructions.selector);
        uint256[] memory fees = new uint256[](1);
        fees[0] = 200;
        int16[][] memory feeFactorScheduleBIPS = new int16[][](1);
        feeFactorScheduleBIPS[0] = new int16[](0);
        uint16[] memory feeDelayScheduleSeconds = new uint16[](0);
        teePayments.reissue(
            pmwMultisigAccount,
            1,
            1,
            new ITeePayments.PaymentInstruction[](0),
            fees,
            feeFactorScheduleBIPS,
            feeDelayScheduleSeconds,
            address(0)
        );
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
        int16[][] memory feeFactorScheduleBIPS = new int16[][](2);
        feeFactorScheduleBIPS[0] = new int16[](0);
        feeFactorScheduleBIPS[1] = new int16[](0);
        uint16[] memory feeDelayScheduleSeconds = new uint16[](0);
        _mockReceivingTeesAndKeys();
        vm.prank(authorizationAddress);
        vm.expectRevert(ITeeExtensionRegistry.FeeTooLow.selector);
        teePayments.reissue{value: fee * 2 - 1}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            fees,
            feeFactorScheduleBIPS,
            feeDelayScheduleSeconds,
            address(0)
        );
    }

    function testReissueRevertNotInProduction() public {
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PAUSED);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 200;
        fees[1] = 200;
        int16[][] memory feeFactorScheduleBIPS = new int16[][](2);
        feeFactorScheduleBIPS[0] = new int16[](0);
        feeFactorScheduleBIPS[1] = new int16[](0);
        uint16[] memory feeDelayScheduleSeconds = new uint16[](0);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        vm.expectRevert(ITeePayments.WalletNotInProduction.selector);
        vm.prank(authorizationAddress);
        teePayments.reissue{value: fee * 2}(
            pmwMultisigAccount,
            1,
            1,
            paymentInstructions,
            fees,
            feeFactorScheduleBIPS,
            feeDelayScheduleSeconds,
            address(0)
        );
    }

    function testReissueRevertOnlyAuthorizationAddress() public {
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 200;
        fees[1] = 200;
        int16[][] memory feeFactorScheduleBIPS = new int16[][](2);
        feeFactorScheduleBIPS[0] = new int16[](0);
        feeFactorScheduleBIPS[1] = new int16[](0);
        uint16[] memory feeDelayScheduleSeconds = new uint16[](0);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        vm.expectRevert(ITeePayments.OnlyAuthorizationAddress.selector);
        teePayments.reissue{value: fee * 2}(
            pmwMultisigAccount,
            1,
            1,
            paymentInstructions,
            fees,
            feeFactorScheduleBIPS,
            feeDelayScheduleSeconds,
            address(0)
        );
    }

    function testReissueRevertOnlyAuthorizationAddress2() public {
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 200;
        fees[1] = 200;
        int16[][] memory feeFactorScheduleBIPS = new int16[][](2);
        feeFactorScheduleBIPS[0] = new int16[](0);
        feeFactorScheduleBIPS[1] = new int16[](0);
        uint16[] memory feeDelayScheduleSeconds = new uint16[](0);
        // account not added
        _mockGetWalletProjectId(bytes32(0), bytes32(0));
        vm.expectRevert(ITeePayments.OnlyAuthorizationAddress.selector);
        teePayments.reissue{value: fee * 2}(
            pmwMultisigAccount,
            1,
            1,
            paymentInstructions,
            fees,
            feeFactorScheduleBIPS,
            feeDelayScheduleSeconds,
            address(0)
        );
    }

    // current batch nonce is 11 (state.nonce is 12)
    function testReissueRevertBatchNotEnded1() public {
        testPay4();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        int16[][] memory feeFactorScheduleBIPS = new int16[][](2);
        feeFactorScheduleBIPS[0] = new int16[](0);
        feeFactorScheduleBIPS[1] = new int16[](0);
        uint16[] memory feeDelayScheduleSeconds = new uint16[](0);
        vm.prank(authorizationAddress);
        // batch with nonce 11 is not yet finished
        vm.expectRevert(ITeePayments.BatchNotYetEnded.selector);
        teePayments.reissue{value: fee * 2}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            fees,
            feeFactorScheduleBIPS,
            feeDelayScheduleSeconds,
            address(0)
        );
    }

    // current batch nonce is 13 (state.nonce is 12)
    function testReissueRevertBatchNotEnded2() public {
        testPay4();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        int16[][] memory feeFactorScheduleBIPS = new int16[][](2);
        feeFactorScheduleBIPS[0] = new int16[](0);
        feeFactorScheduleBIPS[1] = new int16[](0);
        uint16[] memory feeDelayScheduleSeconds = new uint16[](0);
        vm.prank(authorizationAddress);
        vm.expectRevert(ITeePayments.BatchNotYetEnded.selector);
        teePayments.reissue{value: fee * 2}(
            pmwMultisigAccount,
            13,
            11,
            paymentInstructions,
            fees,
            feeFactorScheduleBIPS,
            feeDelayScheduleSeconds,
            address(0)
        );
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
        int16[][] memory feeFactorScheduleBIPS = new int16[][](2);
        feeFactorScheduleBIPS[0] = new int16[](0);
        feeFactorScheduleBIPS[1] = new int16[](0);
        uint16[] memory feeDelayScheduleSeconds = new uint16[](0);
        vm.prank(authorizationAddress);
        // batch with nonce 11 is finished
        vm.expectRevert(ITeePayments.BatchHashMismatch.selector);
        teePayments.reissue{value: fee * 2}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            fees,
            feeFactorScheduleBIPS,
            feeDelayScheduleSeconds,
            address(0)
        );
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
        int16[][] memory feeFactorScheduleBIPS = new int16[][](2);
        feeFactorScheduleBIPS[0] = new int16[](0);
        feeFactorScheduleBIPS[1] = new int16[](0);
        uint16[] memory feeDelayScheduleSeconds = new uint16[](0);
        vm.prank(authorizationAddress);
        // batch with nonce 11 not yet finished but batch end timestamp passed
        vm.warp(500 + 301);
        vm.expectRevert(ITeePayments.BatchHashMismatch.selector);
        teePayments.reissue{value: fee * 2 + 6}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            fees,
            feeFactorScheduleBIPS,
            feeDelayScheduleSeconds,
            address(0)
        );
    }

    // feeFactorScheduleBIPS.length != paymentInstructions.length
    function testReissueRevertLengthsMismatch1() public {
        testPay4();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        int16[][] memory feeFactorScheduleBIPS = new int16[][](1);
        feeFactorScheduleBIPS[0] = new int16[](0);
        uint16[] memory feeDelayScheduleSeconds = new uint16[](0);
        vm.prank(authorizationAddress);
        // batch with nonce 11 not yet finished but batch end timestamp passed
        vm.warp(500 + 301);
        vm.expectRevert(ITeePayments.LengthsMismatch.selector);
        teePayments.reissue{value: fee * 2 + 6}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            fees,
            feeFactorScheduleBIPS,
            feeDelayScheduleSeconds,
            address(0)
        );
    }

    // fees.length != paymentInstructions.length
    function testReissueRevertLengthsMismatch2() public {
        testPay4();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](1);
        fees[0] = 150;
        int16[][] memory feeFactorScheduleBIPS = new int16[][](1);
        feeFactorScheduleBIPS[0] = new int16[](0);
        uint16[] memory feeDelayScheduleSeconds = new uint16[](0);
        vm.prank(authorizationAddress);
        // batch with nonce 11 not yet finished but batch end timestamp passed
        vm.warp(500 + 301);
        vm.expectRevert(ITeePayments.LengthsMismatch.selector);
        teePayments.reissue{value: fee * 2 + 6}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            fees,
            feeFactorScheduleBIPS,
            feeDelayScheduleSeconds,
            address(0)
        );
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
        int16[][] memory feeFactorScheduleBIPS = new int16[][](2);
        feeFactorScheduleBIPS[0] = new int16[](0);
        feeFactorScheduleBIPS[1] = new int16[](0);
        uint16[] memory feeDelayScheduleSeconds = new uint16[](0);
        vm.prank(authorizationAddress);
        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, REISSUE, SOURCE_ID, senderAddress, 11, 0));
        ITeePayments.PaymentInstructionMessage memory message1 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            150,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref1"),
            11, // nonce
            11, // subNonce
            uint64(block.timestamp)
        );
        ITeePayments.PaymentInstructionMessage memory message2 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            150,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref2"),
            11, // nonce
            12, // subNonce
            uint64(block.timestamp)
        );
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            REISSUE,
            abi.encode(message1),
            cosigners,
            cosignersThreshold,
            address(0),
            126 // floor(253/2) = 126; value: 253 = 2*123 (fee) + 7
        );
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            REISSUE,
            abi.encode(message2),
            cosigners,
            cosignersThreshold,
            address(0),
            127 // 253 - 126 = 127
        );
        teePayments.reissue{value: fee * 2 + 7}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            fees,
            feeFactorScheduleBIPS,
            feeDelayScheduleSeconds,
            address(0)
        );

        // reissue also batch with nonce 13
        paymentInstructions = new ITeePayments.PaymentInstruction[](1);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref4"));
        fees = new uint256[](1);
        fees[0] = 150;
        feeFactorScheduleBIPS = new int16[][](1);
        feeFactorScheduleBIPS[0] = new int16[](0);
        instructionId = keccak256(abi.encode(OP_TYPE, REISSUE, SOURCE_ID, senderAddress, 13, 0));
        message1 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            150,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref4"),
            13, // nonce
            14, // subNonce
            uint64(block.timestamp)
        );
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            REISSUE,
            abi.encode(message1),
            cosigners,
            cosignersThreshold,
            address(0),
            123
        );
        vm.prank(authorizationAddress);
        teePayments.reissue{value: fee}(
            pmwMultisigAccount,
            13,
            14,
            paymentInstructions,
            fees,
            feeFactorScheduleBIPS,
            feeDelayScheduleSeconds,
            address(0)
        );

        // try reissue batch with nonce 14; batch is not yet finished
        paymentInstructions = new ITeePayments.PaymentInstruction[](1);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref5"));
        vm.prank(authorizationAddress);
        vm.expectRevert(ITeePayments.BatchNotYetEnded.selector);
        teePayments.reissue{value: fee}(
            pmwMultisigAccount,
            14,
            15,
            paymentInstructions,
            fees,
            feeFactorScheduleBIPS,
            feeDelayScheduleSeconds,
            address(0)
        );
    }

    // should reissue batch with nonce 11 twice
    function testReissueTwice() public {
        testPay3();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(authorizationAddress);
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, REISSUE, SOURCE_ID, senderAddress, 11, 0));
        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        int16[][] memory feeFactorScheduleBIPS = new int16[][](2);
        feeFactorScheduleBIPS[0] = new int16[](0);
        feeFactorScheduleBIPS[1] = new int16[](0);
        uint16[] memory feeDelayScheduleSeconds = new uint16[](0);
        ITeePayments.PaymentInstructionMessage memory message1 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            150,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref1"),
            11, // nonce
            11, // subNonce
            uint64(block.timestamp)
        );
        ITeePayments.PaymentInstructionMessage memory message2 = ITeePayments.PaymentInstructionMessage(
            walletId,
            teeIdKeyIdPairs,
            SOURCE_ID,
            senderAddress,
            "recipientAddress",
            bytes(""), // tokenId
            100,
            150,
            abi.encodePacked(int16(10000), uint16(0)),
            bytes32("ref2"),
            11, // nonce
            12, // subNonce
            uint64(block.timestamp)
        );
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            REISSUE,
            abi.encode(message1),
            cosigners,
            cosignersThreshold,
            address(0),
            126 // floor(253/2) = 126; value: 253 = 2*123 (fee) + 7
        );
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            REISSUE,
            abi.encode(message2),
            cosigners,
            cosignersThreshold,
            address(0),
            127 // 253 - 126 = 127
        );
        teePayments.reissue{value: fee * 2 + 7}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            fees,
            feeFactorScheduleBIPS,
            feeDelayScheduleSeconds,
            address(0)
        );

        // reissue again; instructionId changes
        instructionId = keccak256(abi.encode(OP_TYPE, REISSUE, SOURCE_ID, senderAddress, 11, 1));
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            REISSUE,
            abi.encode(message1),
            cosigners,
            cosignersThreshold,
            address(0),
            126
        );
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            11,
            receivingTees,
            OP_TYPE,
            REISSUE,
            abi.encode(message2),
            cosigners,
            cosignersThreshold,
            address(0),
            127
        );
        vm.prank(authorizationAddress);
        teePayments.reissue{value: fee * 2 + 7}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            fees,
            feeFactorScheduleBIPS,
            feeDelayScheduleSeconds,
            address(0)
        );
    }

    function testAddSupportedSourceIds() public {
        bytes32[] memory supportedSourceIds = teePayments.getSupportedSourceIds();
        assertEq(supportedSourceIds.length, 1);
        assertEq(supportedSourceIds[0], SOURCE_ID);

        bytes32 newSourceId1 = bytes32("NEW_SOURCE_ID1");
        bytes32 newSourceId2 = bytes32("NEW_SOURCE_ID2");
        assertTrue(teePayments.isSourceIdSupported(SOURCE_ID));
        assertFalse(teePayments.isSourceIdSupported(newSourceId1));
        assertFalse(teePayments.isSourceIdSupported(newSourceId2));

        vm.prank(governance);
        bytes32[] memory newSourceIds = new bytes32[](2);
        newSourceIds[0] = newSourceId1;
        newSourceIds[1] = newSourceId2;
        vm.expectEmit();
        emit ITeePayments.SupportedSourceIdsAdded(newSourceIds);
        teePayments.addSupportedSourceIds(newSourceIds);
        assertEq(teePayments.getSupportedSourceIds().length, 3);
        assertEq(teePayments.getSupportedSourceIds()[0], SOURCE_ID);
        assertEq(teePayments.getSupportedSourceIds()[1], newSourceId1);
        assertEq(teePayments.getSupportedSourceIds()[2], newSourceId2);
        assertTrue(teePayments.isSourceIdSupported(SOURCE_ID));
        assertTrue(teePayments.isSourceIdSupported(newSourceId2));
        assertTrue(teePayments.isSourceIdSupported(newSourceId1));
    }

    function testAddSupportedSourceIdsRevertOnlyGovernance() public {
        bytes32 newSourceId1 = bytes32("NEW_SOURCE_ID1");
        bytes32 newSourceId2 = bytes32("NEW_SOURCE_ID2");
        bytes32[] memory newSourceIds = new bytes32[](2);
        newSourceIds[0] = newSourceId1;
        newSourceIds[1] = newSourceId2;
        vm.expectRevert("only governance");
        teePayments.addSupportedSourceIds(newSourceIds);
    }

    function testAddSupportedSourceIdsRevertAlreadyExists() public {
        bytes32 newSourceId1 = bytes32("NEW_SOURCE_ID1");
        bytes32 newSourceId2 = SOURCE_ID; // already supported
        bytes32[] memory newSourceIds = new bytes32[](2);
        newSourceIds[0] = newSourceId1;
        newSourceIds[1] = newSourceId2;
        vm.prank(governance);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeePayments.SourceIdAlreadyExists.selector,
                SOURCE_ID
            )
        );
        teePayments.addSupportedSourceIds(newSourceIds);
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
                KEY_TYPE,
                sourceIds
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

    function _mockGetExtensionId(bytes32 _projectId, uint256 _extensionId) internal {
        vm.mockCall(
            mockTeeWalletProjectManager,
            abi.encodeWithSelector(ITeeWalletProjectManager.getExtensionId.selector, _projectId),
            abi.encode(_extensionId)
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
            tokenId: bytes(""),
            amount: 100,
            maxFee: 10,
            paymentReference: _paymentReference
        });
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

    function _mockGetKeyType(bytes32 _projectId, bytes32 _keyType) internal {
        vm.mockCall(
            mockTeeWalletProjectManager,
            abi.encodeWithSelector(ITeeWalletProjectManager.getKeyType.selector, _projectId),
            abi.encode(_keyType)
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

    function _mockGetWalletCosignersAndThreshold(
        bytes32 _walletId,
        address[] memory _cosigners,
        uint64 _threshold
    )
        internal
    {
        vm.mockCall(
            mockTeeWalletManager,
            abi.encodeWithSelector(ITeeWalletManager.getWalletCosignersAndThreshold.selector, _walletId),
            abi.encode(_cosigners, _threshold)
        );
    }

    function _mockGetWalletAdminsAndThreshold(bytes32 _walletId,
        address[] memory _admins,
        uint64 _threshold
    )
        internal
    {
        vm.mockCall(
            mockTeeWalletManager,
            abi.encodeWithSelector(ITeeWalletManager.getWalletAdminsAndThreshold.selector, _walletId),
            abi.encode(_admins, _threshold)
        );
    }

}