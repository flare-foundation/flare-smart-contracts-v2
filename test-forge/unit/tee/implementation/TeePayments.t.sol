// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
// solhint-disable no-unused-vars

import { Test } from "forge-std/Test.sol";
import { TeePayments } from "../../../../contracts/tee/implementation/TeePayments.sol";
import { TeePaymentsProxy } from "../../../../contracts/tee/proxy/TeePaymentsProxy.sol";
import { TeePaymentsRegistry } from "../../../../contracts/tee/implementation/TeePaymentsRegistry.sol";
import { TeePaymentsRegistryProxy } from "../../../../contracts/tee/proxy/TeePaymentsRegistryProxy.sol";
import { IWalletManager } from "../../../../contracts/userInterfaces/tee/IWalletManager.sol";
import { ITeePayments } from "../../../../contracts/userInterfaces/tee/ITeePayments.sol";
import { ITeePaymentsRegistry } from "../../../../contracts/userInterfaces/tee/ITeePaymentsRegistry.sol";
import {
    ITeePaymentsFeeScheduleManager
} from "../../../../contracts/userInterfaces/tee/ITeePaymentsFeeScheduleManager.sol";
import { IInstructions } from "../../../../contracts/userInterfaces/tee/IInstructions.sol";
import {
    IWalletProjectManager
} from "../../../../contracts/userInterfaces/tee/IWalletProjectManager.sol";
import {
    IOperationFees
} from "../../../../contracts/userInterfaces/tee/IOperationFees.sol";
import { IVerification } from "../../../../contracts/userInterfaces/tee/IVerification.sol";
import { IMachineManager } from "../../../../contracts/userInterfaces/tee/IMachineManager.sol";
import { IWalletKeyManager } from "../../../../contracts/userInterfaces/tee/IWalletKeyManager.sol";
import { TeeIdKeyIdPair } from "../../../../contracts/userInterfaces/tee/ITeeIdKeyIdPair.sol";
import {
    IPMWMultisigAccountConfigured
} from "../../../../contracts/userInterfaces/fdc2/IPMWMultisigAccountConfigured.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { IFlareGovernance } from "../../../../contracts/userInterfaces/IFlareGovernance.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

//solhint-disable-next-line max-states-count
contract TeePaymentsTest is Test {

    bytes32 private constant OP_TYPE = bytes32("F_XRP");
    bytes32 private constant KEY_TYPE = bytes32("XRP_KEY");
    bytes32 private constant SOURCE_ID = bytes32("XRP");
    bytes32 private constant PAY = bytes32("PAY");
    bytes32 private constant REISSUE = bytes32("REISSUE");
    bytes private constant DEFAULT_FEE_SCHEDULE = hex"27100000";

    TeePayments private teePayments;
    TeePayments private teePaymentsImpl;
    TeePaymentsProxy private teePaymentsProxy;
    TeePaymentsRegistry private teePaymentsRegistry;

    address private mockFSM;
    address private mockRewardManager;

    address private flareTeeManager;
    address private teePaymentsFeeScheduleManager;

    address private governance;
    address private addressUpdater;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    bytes32 private walletId = bytes32("walletId");
    address private walletOwner = makeAddr("walletOwner");
    string private senderAddress = "senderAddress";
    uint256 private fee = 123;
    address private authorizationAddress = makeAddr("authorizationAddress");
    bytes32 private projectId = bytes32("projectId");
    ITeePayments.PMWMultisigAccount private pmwMultisigAccount;
    IPMWMultisigAccountConfigured.Proof private proof;
    address[] private admins;
    uint64 private adminsThreshold;
    address[] private cosigners;
    uint64 private cosignersThreshold;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        mockFSM = makeAddr("mockFlareSystemsManager");
        mockRewardManager = makeAddr("rewardManager");

        teePaymentsImpl = new TeePayments();
        teePaymentsProxy = new TeePaymentsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            5, // max batch size
            300, // max batch duration seconds
            OP_TYPE,
            KEY_TYPE,
            address(teePaymentsImpl)
        );
        teePayments = TeePayments(address(teePaymentsProxy));

        // Deploy real TeePaymentsRegistry for use by TeePayments
        TeePaymentsRegistry registryImpl = new TeePaymentsRegistry();
        TeePaymentsRegistryProxy registryProxy = new TeePaymentsRegistryProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(registryImpl)
        );
        teePaymentsRegistry = TeePaymentsRegistry(address(registryProxy));

        // Register test sourceId -> this TeePayments in the registry
        ITeePaymentsRegistry.SourceRegistration[] memory regs =
            new ITeePaymentsRegistry.SourceRegistration[](1);
        regs[0] = ITeePaymentsRegistry.SourceRegistration(SOURCE_ID, address(teePayments));
        vm.prank(governance);
        teePaymentsRegistry.registerSources(regs);

        flareTeeManager = makeAddr("flareTeeManager");
        teePaymentsFeeScheduleManager = makeAddr("teePaymentsFeeScheduleManager");

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](5);
        contractAddresses = new address[](5);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareTeeManager"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("TeePaymentsFeeScheduleManager"));
        contractNameHashes[4] = keccak256(abi.encode("TeePaymentsRegistry"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = flareTeeManager;
        contractAddresses[2] = mockFSM;
        contractAddresses[3] = teePaymentsFeeScheduleManager;
        contractAddresses[4] = address(teePaymentsRegistry);
        teePayments.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        _mockGetWalletProjectId(walletId, projectId);
        _mockGetExtensionId(projectId, 0);
        _mockGetOwner(projectId, walletOwner);
        _mockGetCurrentRewardEpochId(10);
        _mockReceiveRewards();
        _mockGetKeyType(projectId, KEY_TYPE);
        _mockSendSystemInstructions();
        _mockSendInstructions();

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
        _mockCalculateFeeByTeeIds(PAY, fee);
        _mockCalculateFeeByTeeIds(REISSUE, fee);
        _mockGetEffectiveSchedule(DEFAULT_FEE_SCHEDULE);
        _mockValidateAndEncodeSchedules();

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
            address(teePaymentsImpl)
        );
    }

    function testAddPMWMultisigAccount() public {
        assertEq(teePayments.getWalletId(pmwMultisigAccount), bytes32(0));
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
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
        _mockGetWalletStatus(IWalletManager.WalletStatus.INITIALIZED);
        vm.expectRevert(ITeePayments.OnlyProductionOrPausedStatus.selector);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    function testAddPMWMultisigAccountRevertInvalidProof() public {
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
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
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
        proof.header.sourceId = bytes32("WRONG_SOURCE_ID");
        vm.prank(walletOwner);
        vm.expectRevert(ITeePayments.UnsupportedSourceId.selector);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    function testAddPMWMultisigAccountRevertRegistryPointsElsewhere() public {
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
        // Rebind SOURCE_ID in registry to a different TeePayments (strict: unregister + register).
        bytes32[] memory remove = new bytes32[](1);
        remove[0] = SOURCE_ID;
        vm.prank(governance);
        teePaymentsRegistry.unregisterSources(remove);

        address otherTeePayments = makeAddr("otherTeePayments");
        vm.etch(otherTeePayments, hex"01");
        ITeePaymentsRegistry.SourceRegistration[] memory regs =
            new ITeePaymentsRegistry.SourceRegistration[](1);
        regs[0] = ITeePaymentsRegistry.SourceRegistration(SOURCE_ID, otherTeePayments);
        vm.prank(governance);
        teePaymentsRegistry.registerSources(regs);

        vm.prank(walletOwner);
        vm.expectRevert(ITeePayments.UnsupportedSourceId.selector);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    function testAddPMWMultisigAccountRevertAuthorizationAddressZero() public {
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
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

    // NOTE: FeeTooLow tests removed — fee validation is FlareTeeManager's responsibility,
    // tested in FlareTeeManager facet tests. TeePayments forwards msg.value to FlareTeeManager.

    //// pay tests ////

    function testPayRevertOnlyAuthorizationAddress() public {
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
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
        _mockGetWalletStatus(IWalletManager.WalletStatus.PAUSED);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        vm.prank(authorizationAddress);
        vm.expectRevert(ITeePayments.WalletNotInProduction.selector);
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref1")), address(0));
    }

    function testPayRevertPaymentAmountZero() public {
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        ITeePayments.PaymentInstruction memory instruction = _createPaymentInstruction(bytes32("ref1"));
        instruction.amount = 0;
        vm.prank(authorizationAddress);
        vm.expectRevert(ITeePayments.PaymentAmountZero.selector);
        teePayments.pay{value: fee}(pmwMultisigAccount, instruction, address(0));
    }

    function testPayRevertRecipientIsSender() public {
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
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
        (IMachineManager.TeeMachine[] memory _receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
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
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref2")), address(0));
    }

    // batch duration is > 0 but batch size is 1
    function testPay2() public {
        (IMachineManager.TeeMachine[] memory _receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
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
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref2")), address(0));
    }

    // batch duration is > 0 and batch size is > 1
    function testPay3() public {
        (IMachineManager.TeeMachine[] memory _receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
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
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref5")), address(0));
    }

    // two transactions in batch with nonce 10
    function testPay4() public {
        (IMachineManager.TeeMachine[] memory _receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
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
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref2")), address(0));
    }

    // pay from secondary wallet
    function testPay5() public {
        (IMachineManager.TeeMachine[] memory _receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        bytes32 walletId2 = bytes32("walletId2");
        string memory senderAddress2 = "senderAddress2";
        _mockGetWalletCosignersAndThreshold(walletId2, cosigners, cosignersThreshold);
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IWalletManager.getWalletStatus.selector, walletId2),
            abi.encode(IWalletManager.WalletStatus.PRODUCTION)
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
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref2")), address(0));
    }

    //// reissue tests ////
    function testReissueRevertNoPaymentInstructions() public {
        vm.expectRevert(ITeePayments.NoPaymentInstructions.selector);
        uint256[] memory fees = new uint256[](1);
        fees[0] = 200;
        int16[][] memory factorsBIPSPerPayment = new int16[][](1);
        factorsBIPSPerPayment[0] = new int16[](0);
        uint16[] memory delaysSeconds = new uint16[](0);
        teePayments.reissue(
            pmwMultisigAccount,
            1,
            1,
            new ITeePayments.PaymentInstruction[](0),
            ITeePayments.ReissueFeeParams(fees, factorsBIPSPerPayment, delaysSeconds),
            address(0)
        );
    }

    // NOTE: testReissueRevertFeeTooLow removed — fee validation is FlareTeeManager's responsibility

    function testReissueRevertNotInProduction() public {
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(IWalletManager.WalletStatus.PAUSED);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 200;
        fees[1] = 200;
        int16[][] memory factorsBIPSPerPayment = new int16[][](2);
        factorsBIPSPerPayment[0] = new int16[](0);
        factorsBIPSPerPayment[1] = new int16[](0);
        uint16[] memory delaysSeconds = new uint16[](0);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        vm.expectRevert(ITeePayments.WalletNotInProduction.selector);
        vm.prank(authorizationAddress);
        teePayments.reissue{value: fee * 2}(
            pmwMultisigAccount,
            1,
            1,
            paymentInstructions,
            ITeePayments.ReissueFeeParams(fees, factorsBIPSPerPayment, delaysSeconds),
            address(0)
        );
    }

    function testReissueRevertOnlyAuthorizationAddress() public {
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 200;
        fees[1] = 200;
        int16[][] memory factorsBIPSPerPayment = new int16[][](2);
        factorsBIPSPerPayment[0] = new int16[](0);
        factorsBIPSPerPayment[1] = new int16[](0);
        uint16[] memory delaysSeconds = new uint16[](0);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        vm.expectRevert(ITeePayments.OnlyAuthorizationAddress.selector);
        teePayments.reissue{value: fee * 2}(
            pmwMultisigAccount,
            1,
            1,
            paymentInstructions,
            ITeePayments.ReissueFeeParams(fees, factorsBIPSPerPayment, delaysSeconds),
            address(0)
        );
    }

    function testReissueRevertOnlyAuthorizationAddress2() public {
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 200;
        fees[1] = 200;
        int16[][] memory factorsBIPSPerPayment = new int16[][](2);
        factorsBIPSPerPayment[0] = new int16[](0);
        factorsBIPSPerPayment[1] = new int16[](0);
        uint16[] memory delaysSeconds = new uint16[](0);
        // account not added
        _mockGetWalletProjectId(bytes32(0), bytes32(0));
        vm.expectRevert(ITeePayments.OnlyAuthorizationAddress.selector);
        teePayments.reissue{value: fee * 2}(
            pmwMultisigAccount,
            1,
            1,
            paymentInstructions,
            ITeePayments.ReissueFeeParams(fees, factorsBIPSPerPayment, delaysSeconds),
            address(0)
        );
    }

    // current batch nonce is 11 (state.nonce is 12)
    function testReissueRevertBatchNotEnded1() public {
        testPay4();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        int16[][] memory factorsBIPSPerPayment = new int16[][](2);
        factorsBIPSPerPayment[0] = new int16[](0);
        factorsBIPSPerPayment[1] = new int16[](0);
        uint16[] memory delaysSeconds = new uint16[](0);
        vm.prank(authorizationAddress);
        // batch with nonce 11 is not yet finished
        vm.expectRevert(ITeePayments.BatchNotYetEnded.selector);
        teePayments.reissue{value: fee * 2}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            ITeePayments.ReissueFeeParams(fees, factorsBIPSPerPayment, delaysSeconds),
            address(0)
        );
    }

    // current batch nonce is 13 (state.nonce is 12)
    function testReissueRevertBatchNotEnded2() public {
        testPay4();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        int16[][] memory factorsBIPSPerPayment = new int16[][](2);
        factorsBIPSPerPayment[0] = new int16[](0);
        factorsBIPSPerPayment[1] = new int16[](0);
        uint16[] memory delaysSeconds = new uint16[](0);
        vm.prank(authorizationAddress);
        vm.expectRevert(ITeePayments.BatchNotYetEnded.selector);
        teePayments.reissue{value: fee * 2}(
            pmwMultisigAccount,
            13,
            11,
            paymentInstructions,
            ITeePayments.ReissueFeeParams(fees, factorsBIPSPerPayment, delaysSeconds),
            address(0)
        );
    }

    function testReissueRevertHashMismatch1() public {
        testPay3();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref3")); // wrong reference
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        int16[][] memory factorsBIPSPerPayment = new int16[][](2);
        factorsBIPSPerPayment[0] = new int16[](0);
        factorsBIPSPerPayment[1] = new int16[](0);
        uint16[] memory delaysSeconds = new uint16[](0);
        vm.prank(authorizationAddress);
        // batch with nonce 11 is finished
        vm.expectRevert(ITeePayments.BatchHashMismatch.selector);
        teePayments.reissue{value: fee * 2}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            ITeePayments.ReissueFeeParams(fees, factorsBIPSPerPayment, delaysSeconds),
            address(0)
        );
    }

    function testReissueRevertHashMismatch2() public {
        testPay4();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref3")); // wrong reference
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        int16[][] memory factorsBIPSPerPayment = new int16[][](2);
        factorsBIPSPerPayment[0] = new int16[](0);
        factorsBIPSPerPayment[1] = new int16[](0);
        uint16[] memory delaysSeconds = new uint16[](0);
        vm.prank(authorizationAddress);
        // batch with nonce 11 not yet finished but batch end timestamp passed
        vm.warp(500 + 301);
        vm.expectRevert(ITeePayments.BatchHashMismatch.selector);
        teePayments.reissue{value: fee * 2 + 6}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            ITeePayments.ReissueFeeParams(fees, factorsBIPSPerPayment, delaysSeconds),
            address(0)
        );
    }

    // factorsBIPSPerPayment.length != paymentInstructions.length
    function testReissueRevertLengthsMismatch1() public {
        testPay4();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](2);
        fees[0] = 150;
        fees[1] = 150;
        int16[][] memory factorsBIPSPerPayment = new int16[][](1);
        factorsBIPSPerPayment[0] = new int16[](0);
        uint16[] memory delaysSeconds = new uint16[](0);
        vm.prank(authorizationAddress);
        // batch with nonce 11 not yet finished but batch end timestamp passed
        vm.warp(500 + 301);
        vm.expectRevert(ITeePayments.LengthsMismatch.selector);
        teePayments.reissue{value: fee * 2 + 6}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            ITeePayments.ReissueFeeParams(fees, factorsBIPSPerPayment, delaysSeconds),
            address(0)
        );
    }

    // fees.length != paymentInstructions.length
    function testReissueRevertLengthsMismatch2() public {
        testPay4();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
        uint256[] memory fees = new uint256[](1);
        fees[0] = 150;
        int16[][] memory factorsBIPSPerPayment = new int16[][](1);
        factorsBIPSPerPayment[0] = new int16[](0);
        uint16[] memory delaysSeconds = new uint16[](0);
        vm.prank(authorizationAddress);
        // batch with nonce 11 not yet finished but batch end timestamp passed
        vm.warp(500 + 301);
        vm.expectRevert(ITeePayments.LengthsMismatch.selector);
        teePayments.reissue{value: fee * 2 + 6}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            ITeePayments.ReissueFeeParams(fees, factorsBIPSPerPayment, delaysSeconds),
            address(0)
        );
    }

    function testReissue1() public {
        testPay3();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
        ITeePayments.ReissueFeeParams memory feeSettings;
        {
            uint256[] memory fees = new uint256[](2);
            fees[0] = 150;
            fees[1] = 150;
            int16[][] memory factorsBIPSPerPayment = new int16[][](2);
            factorsBIPSPerPayment[0] = new int16[](0);
            factorsBIPSPerPayment[1] = new int16[](0);
            uint16[] memory delaysSeconds = new uint16[](0);
            feeSettings = ITeePayments.ReissueFeeParams(fees, factorsBIPSPerPayment, delaysSeconds);
        }
        vm.prank(authorizationAddress);
        (IMachineManager.TeeMachine[] memory _receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        // solhint-disable-next-line no-unused-vars
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, REISSUE, SOURCE_ID, senderAddress, 11, 0));
        // solhint-disable-next-line no-unused-vars
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
        ITeePayments.PaymentInstructionMessage memory _message2 = ITeePayments.PaymentInstructionMessage(
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
        teePayments.reissue{value: fee * 2 + 7}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            feeSettings,
            address(0)
        );

        // reissue also batch with nonce 13
        paymentInstructions = new ITeePayments.PaymentInstruction[](1);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref4"));
        {
            uint256[] memory fees = new uint256[](1);
            fees[0] = 150;
            int16[][] memory factorsBIPSPerPayment = new int16[][](1);
            factorsBIPSPerPayment[0] = new int16[](0);
            feeSettings = ITeePayments.ReissueFeeParams(
                fees, factorsBIPSPerPayment, new uint16[](0)
            );
        }
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
        vm.prank(authorizationAddress);
        teePayments.reissue{value: fee}(
            pmwMultisigAccount,
            13,
            14,
            paymentInstructions,
            feeSettings,
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
            feeSettings,
            address(0)
        );
    }

    // should reissue batch with nonce 11 twice
    function testReissueTwice() public {
        testPay3();
        ITeePayments.PaymentInstruction[] memory paymentInstructions = new ITeePayments.PaymentInstruction[](2);
        paymentInstructions[0] = _createPaymentInstruction(bytes32("ref1"));
        paymentInstructions[1] = _createPaymentInstruction(bytes32("ref2"));
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
        vm.prank(authorizationAddress);
        bytes32 instructionId = keccak256(abi.encode(OP_TYPE, REISSUE, SOURCE_ID, senderAddress, 11, 0));
        (IMachineManager.TeeMachine[] memory _receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        ITeePayments.ReissueFeeParams memory feeSettings;
        {
            uint256[] memory fees = new uint256[](2);
            fees[0] = 150;
            fees[1] = 150;
            int16[][] memory factorsBIPSPerPayment = new int16[][](2);
            factorsBIPSPerPayment[0] = new int16[](0);
            factorsBIPSPerPayment[1] = new int16[](0);
            uint16[] memory delaysSeconds = new uint16[](0);
            feeSettings = ITeePayments.ReissueFeeParams(fees, factorsBIPSPerPayment, delaysSeconds);
        }
        ITeePayments.PaymentInstructionMessage memory _message1 = ITeePayments.PaymentInstructionMessage(
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
        ITeePayments.PaymentInstructionMessage memory _message2 = ITeePayments.PaymentInstructionMessage(
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
        teePayments.reissue{value: fee * 2 + 7}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            feeSettings,
            address(0)
        );

        // reissue again; instructionId changes
        instructionId = keccak256(abi.encode(OP_TYPE, REISSUE, SOURCE_ID, senderAddress, 11, 1));
        vm.prank(authorizationAddress);
        teePayments.reissue{value: fee * 2 + 7}(
            pmwMultisigAccount,
            11,
            11,
            paymentInstructions,
            feeSettings,
            address(0)
        );
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
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        teePayments.upgradeToAndCall(address(newTeePaymentsImpl), bytes(""));
    }

    // revert in GovernedBase.initialise
    function testUpgradeProxyAndInitializeRevert() public {
        TeePayments newTeePaymentsImpl = new TeePayments();
        vm.prank(governance);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        teePayments.upgradeToAndCall(address(newTeePaymentsImpl), abi.encodeCall(
            TeePayments.initialize, (
                IGovernanceSettings(makeAddr("governanceSettings")),
                governance,
                addressUpdater,
                6,
                400,
                OP_TYPE,
                KEY_TYPE
            )
        ));
    }

    //// mocks and helpers ////
    function _mockGetWalletProjectId(bytes32 _walletId, bytes32 _projectId) internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IWalletManager.getWalletProjectId.selector, _walletId),
            abi.encode(_projectId)
        );
    }

    function _mockGetExtensionId(bytes32 _projectId, uint256 _extensionId) internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IWalletProjectManager.getExtensionId.selector, _projectId),
            abi.encode(_extensionId)
        );
    }

    function _mockGetOwner(bytes32 _projectId, address _walletOwner) internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IWalletProjectManager.getOwner.selector, _projectId),
            abi.encode(_walletOwner)
        );
    }

    function _mockGetWalletStatus(IWalletManager.WalletStatus _status) internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IWalletManager.getWalletStatus.selector, walletId),
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
        IMachineManager.TeeMachine[] memory,
        TeeIdKeyIdPair[] memory _teeIdKeyIdPairs
    ) {
        IMachineManager.TeeMachine[] memory receivingTees = new IMachineManager.TeeMachine[](1);
        TeeIdKeyIdPair[] memory teeIdKeyIdPairs =
            new TeeIdKeyIdPair[](1);
        receivingTees[0] = IMachineManager.TeeMachine({
            teeId: makeAddr("teeId"),
            teeProxyId: makeAddr("teeProxyId"),
            url: "teeUrl"
        });
        teeIdKeyIdPairs[0] = TeeIdKeyIdPair({
            teeId: receivingTees[0].teeId,
            keyId: 1
        });
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IWalletKeyManager.receivingTeesAndKeys.selector),
            abi.encode(teeIdKeyIdPairs)
        );

        // also mock getTeeMachine
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IMachineManager.getTeeMachine.selector, receivingTees[0].teeId),
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
            flareTeeManager,
            abi.encodeWithSelector(IWalletProjectManager.getKeyType.selector, _projectId),
            abi.encode(_keyType)
        );
    }

    function _mockVerifyPMWMultisigAccountConfiguredProof(bool _valid) internal{
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IVerification.verifyPMWMultisigAccountConfiguredProof.selector),
            abi.encode(_valid)
        );
    }

    function _mockGetExtensionId(bytes32 _extensionId) internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IMachineManager.getExtensionId.selector),
            abi.encode(_extensionId)
        );
    }

    function _mockCalculateFeeByTeeIds(bytes32 _opCommand, uint256 _fee)
        internal
    {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IOperationFees.calculateFeeByTeeIds.selector, OP_TYPE, _opCommand),
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
            flareTeeManager,
            abi.encodeWithSelector(IWalletManager.getWalletCosignersAndThreshold.selector, _walletId),
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
            flareTeeManager,
            abi.encodeWithSelector(IWalletManager.getWalletAdminsAndThreshold.selector, _walletId),
            abi.encode(_admins, _threshold)
        );
    }

    function _mockSendSystemInstructions() internal {
        // Mock both overloads of sendSystemInstructions
        // sendSystemInstructions(bytes32,address[],(bytes32,bytes32,bytes,address[],uint64,address))
        bytes4 sel1 = bytes4(keccak256(
            "sendSystemInstructions(bytes32,address[],(bytes32,bytes32,bytes,address[],uint64,address))"
        ));
        vm.mockCall(
            flareTeeManager,
            abi.encodePacked(sel1),
            abi.encode(bytes32(uint256(1)))
        );
    }

    function _mockSendInstructions() internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IInstructions.sendInstructions.selector),
            abi.encode(bytes32(uint256(1)))
        );
    }

    function _mockGetEffectiveSchedule(bytes memory _schedule) internal {
        vm.mockCall(
            teePaymentsFeeScheduleManager,
            abi.encodeWithSelector(ITeePaymentsFeeScheduleManager.getEffectiveSchedule.selector),
            abi.encode(_schedule)
        );
    }

    function _mockValidateAndEncodeSchedules() internal {
        vm.mockCall(
            teePaymentsFeeScheduleManager,
            abi.encodeWithSelector(ITeePaymentsFeeScheduleManager.validateAndEncodeSchedules.selector),
            abi.encode(new bytes[](0))
        );
    }

}
