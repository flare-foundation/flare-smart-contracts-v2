// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
// solhint-disable no-unused-vars

import { Test } from "forge-std/Test.sol";
import { TeePaymentsUtxo } from "../../../../contracts/tee/implementation/TeePaymentsUtxo.sol";
import { TeePaymentsProxy } from "../../../../contracts/tee/proxy/TeePaymentsProxy.sol";
import { TeePaymentsRegistry } from "../../../../contracts/tee/implementation/TeePaymentsRegistry.sol";
import { TeePaymentsRegistryProxy } from "../../../../contracts/tee/proxy/TeePaymentsRegistryProxy.sol";
import { IWalletManager } from "../../../../contracts/userInterfaces/tee/IWalletManager.sol";
import { ITeePaymentsBase } from "../../../../contracts/userInterfaces/tee/ITeePaymentsBase.sol";
import { ITeePaymentsUtxo } from "../../../../contracts/userInterfaces/tee/ITeePaymentsUtxo.sol";
import { IITeePaymentsUtxo } from "../../../../contracts/tee/interface/IITeePaymentsUtxo.sol";
import {
    ITeePaymentsConfigVerifier
} from "../../../../contracts/userInterfaces/tee/ITeePaymentsConfigVerifier.sol";
import { ITeePaymentsRegistry } from "../../../../contracts/userInterfaces/tee/ITeePaymentsRegistry.sol";
import { PaymentModel } from "../../../../contracts/userInterfaces/tee/ITeePaymentsModel.sol";
import { IInstructions } from "../../../../contracts/userInterfaces/tee/IInstructions.sol";
import {
    IWalletProjectManager
} from "../../../../contracts/userInterfaces/tee/IWalletProjectManager.sol";
import { IWalletKeyManager } from "../../../../contracts/userInterfaces/tee/IWalletKeyManager.sol";
import { IOperationFees } from "../../../../contracts/userInterfaces/tee/IOperationFees.sol";
import { TeeIdKeyIdPair } from "../../../../contracts/userInterfaces/tee/ITeeIdKeyIdPair.sol";
import {
    IPMWMultisigUtxoConfigured
} from "../../../../contracts/userInterfaces/fdc2/IPMWMultisigUtxoConfigured.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IFlareGovernance } from "../../../../contracts/userInterfaces/IFlareGovernance.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * Minimal FlareTeeManager stand-in that records the encoded message passed to sendSystemInstructions,
 * so a test can inspect the emitted PaymentInstructionMessage. All read methods are still vm.mockCall'd
 * on this address; only sendSystemInstructions reaches this code.
 */
contract SendInstructionsSpy {
    bytes public lastMessage;

    function sendSystemInstructions(
        bytes32,
        address[] calldata,
        IInstructions.TeeInstructionParams calldata _params
    )
        external payable
        returns (bytes32)
    {
        lastMessage = _params.message;
        return bytes32(uint256(1));
    }
}

//solhint-disable-next-line max-states-count
contract TeePaymentsUtxoTest is Test {

    bytes32 private constant OP_TYPE = bytes32("F_BTC");
    bytes32 private constant KEY_TYPE = bytes32("BTC_KEY");
    bytes32 private constant SOURCE_ID = bytes32("BTC");
    uint32 private constant ACCOUNT_INDEX = 7;

    TeePaymentsUtxo private teePayments;
    TeePaymentsRegistry private teePaymentsRegistry;

    address private mockFSM;
    address private flareTeeManager;
    address private teePaymentsFeeScheduleManager;
    address private teePaymentsConfigVerifier;

    address private governance;
    address private addressUpdater;

    bytes32 private walletId = bytes32("walletId");
    address private walletOwner = makeAddr("walletOwner");
    string private accountAddress = "bc1qaccount";
    address private authorizationAddress = makeAddr("authorizationAddress");
    bytes32 private projectId = bytes32("projectId");
    ITeePaymentsBase.PMWMultisigAccount private account;
    address[] private cosigners;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        mockFSM = makeAddr("mockFlareSystemsManager");
        // A recording stand-in so tests can read the message emitted to sendSystemInstructions;
        // every read method on this address is still mocked via vm.mockCall below.
        flareTeeManager = address(new SendInstructionsSpy());
        teePaymentsFeeScheduleManager = makeAddr("teePaymentsFeeScheduleManager");
        teePaymentsConfigVerifier = makeAddr("teePaymentsConfigVerifier");

        TeePaymentsUtxo impl = new TeePaymentsUtxo();
        TeePaymentsProxy proxy = new TeePaymentsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(impl)
        );
        teePayments = TeePaymentsUtxo(address(proxy));

        TeePaymentsRegistry registryImpl = new TeePaymentsRegistry();
        TeePaymentsRegistryProxy registryProxy = new TeePaymentsRegistryProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(registryImpl)
        );
        teePaymentsRegistry = TeePaymentsRegistry(address(registryProxy));

        ITeePaymentsRegistry.SourceRegistration[] memory regs =
            new ITeePaymentsRegistry.SourceRegistration[](1);
        regs[0] = ITeePaymentsRegistry.SourceRegistration({
            keyType: KEY_TYPE,
            opType: OP_TYPE,
            paymentModel: PaymentModel.UTXO,
            sourceId: SOURCE_ID,
            teePayments: address(teePayments)
        });
        vm.prank(governance);
        teePaymentsRegistry.registerSources(regs);

        vm.startPrank(addressUpdater);
        bytes32[] memory names = new bytes32[](6);
        address[] memory addrs = new address[](6);
        names[0] = keccak256(abi.encode("AddressUpdater"));
        names[1] = keccak256(abi.encode("FlareTeeManager"));
        names[2] = keccak256(abi.encode("FlareSystemsManager"));
        names[3] = keccak256(abi.encode("TeePaymentsFeeScheduleManager"));
        names[4] = keccak256(abi.encode("TeePaymentsRegistry"));
        names[5] = keccak256(abi.encode("TeePaymentsConfigVerifier"));
        addrs[0] = addressUpdater;
        addrs[1] = flareTeeManager;
        addrs[2] = mockFSM;
        addrs[3] = teePaymentsFeeScheduleManager;
        addrs[4] = address(teePaymentsRegistry);
        addrs[5] = teePaymentsConfigVerifier;
        teePayments.updateContractAddresses(names, addrs);
        vm.stopPrank();

        _mockGetWalletProjectId(walletId, projectId);
        _mockGetExtensionId(projectId, 0);
        _mockGetOwner(projectId, walletOwner);
        _mockGetKeyType(projectId, KEY_TYPE);
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
        _mockGetCurrentRewardEpochId(10);
        _mockReceivingTeesAndKeys();

        account.sourceId = SOURCE_ID;
        account.accountAddress = accountAddress;

        cosigners = new address[](1);
        cosigners[0] = makeAddr("cosigner1");
        _mockGetWalletCosignersAndThreshold(walletId, cosigners, 1);

        // Default max batch settings so batches can open during pay/reissue.
        vm.prank(governance);
        teePayments.setMaxBatchSettings(SOURCE_ID, 5, 300);

        vm.deal(authorizationAddress, 1 ether);
        vm.deal(walletOwner, 1 ether);
        vm.warp(1000);
    }

    //// addPMWMultisigAccount ////

    function testAddAccount() public {
        _mockVerifyUtxo(2);
        vm.expectEmit();
        emit ITeePaymentsUtxo.PMWMultisigUtxoAccountAdded(
            walletId, SOURCE_ID, accountAddress, ACCOUNT_INDEX, 2, authorizationAddress);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, _utxoProof(2), authorizationAddress);

        assertEq(teePayments.getWalletId(account), walletId);
        assertEq(teePayments.getAuthorizationAddress(account), authorizationAddress);
        assertEq(teePayments.getAnchorCount(account), 2);
        ITeePaymentsUtxo.UtxoAnchorState memory anchor0 = teePayments.getAnchor(account, 0);
        assertEq(anchor0.anchorAddress, accountAddress);
        assertEq(anchor0.nextNonce, 1);
        assertEq(anchor0.availableAt, 0);
        assertEq(uint256(teePayments.paymentModel()), uint256(PaymentModel.UTXO));
    }

    function testAddAccountRevertOnlyWalletOwner() public {
        _mockVerifyUtxo(1);
        vm.expectRevert(ITeePaymentsBase.OnlyWalletOwner.selector);
        vm.prank(makeAddr("notOwner"));
        teePayments.addPMWMultisigAccount(walletId, _utxoProof(1), authorizationAddress);
    }

    function testAddAccountRevertAlreadySet() public {
        _addAccount(2);
        _mockVerifyUtxo(2);
        vm.expectRevert(ITeePaymentsBase.PMWMultisigAccountAddressAlreadySet.selector);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, _utxoProof(2), authorizationAddress);
    }

    function testAddAccountRevertInvalidProof() public {
        vm.mockCallRevert(
            teePaymentsConfigVerifier,
            abi.encodeWithSelector(ITeePaymentsConfigVerifier.verifyUtxoConfiguredProof.selector),
            abi.encodeWithSelector(ITeePaymentsConfigVerifier.InvalidProof.selector)
        );
        vm.expectRevert(ITeePaymentsConfigVerifier.InvalidProof.selector);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, _utxoProof(1), authorizationAddress);
    }

    //// addAnchors ////

    function testAddAnchors() public {
        _addAccount(2);
        _mockVerifyUtxo(4);
        vm.expectEmit();
        emit ITeePaymentsUtxo.UtxoAnchorsAdded(walletId, SOURCE_ID, accountAddress, ACCOUNT_INDEX, 4);
        vm.prank(walletOwner);
        teePayments.addAnchors(_utxoProof(4));
        assertEq(teePayments.getAnchorCount(account), 4);
    }

    function testAddAnchorsRevertNoNewAnchors() public {
        _addAccount(2);
        _mockVerifyUtxo(2);
        vm.expectRevert(ITeePaymentsUtxo.NoNewAnchors.selector);
        vm.prank(walletOwner);
        teePayments.addAnchors(_utxoProof(2));
    }

    function testAddAnchorsRevertOnlyWalletOwner() public {
        _addAccount(2);
        _mockVerifyUtxo(3);
        vm.expectRevert(ITeePaymentsBase.OnlyWalletOwner.selector);
        vm.prank(makeAddr("notOwner"));
        teePayments.addAnchors(_utxoProof(3));
    }

    //// batch settings ////

    function testSetBatchSettings() public {
        _addAccount(2);
        vm.prank(walletOwner);
        teePayments.setBatchSettings(account, 3, 120);
        (uint64 batchSize, uint64 batchDurationSeconds) = teePayments.getBatchSettings(account);
        assertEq(batchSize, 3);
        assertEq(batchDurationSeconds, 120);
    }

    function testSetBatchSettingsRevertZero() public {
        _addAccount(2);
        vm.expectRevert(ITeePaymentsUtxo.BatchSizeZero.selector);
        vm.prank(walletOwner);
        teePayments.setBatchSettings(account, 0, 120);
    }

    function testSetBatchSettingsRevertOnlyWalletOwner() public {
        _addAccount(2);
        vm.expectRevert(ITeePaymentsBase.OnlyWalletOwner.selector);
        vm.prank(makeAddr("notOwner"));
        teePayments.setBatchSettings(account, 3, 120);
    }

    function testSetMaxBatchSettings() public {
        vm.prank(governance);
        teePayments.setMaxBatchSettings(SOURCE_ID, 9, 600);
        (uint64 maxBatchSize, uint64 maxBatchDurationSeconds) = teePayments.getMaxBatchSettings(SOURCE_ID);
        assertEq(maxBatchSize, 9);
        assertEq(maxBatchDurationSeconds, 600);
    }

    function testSetMaxBatchSettingsRevertZero() public {
        vm.expectRevert(ITeePaymentsUtxo.MaxBatchSizeZero.selector);
        vm.prank(governance);
        teePayments.setMaxBatchSettings(SOURCE_ID, 0, 600);
    }

    function testSetMaxBatchSettingsRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        teePayments.setMaxBatchSettings(SOURCE_ID, 9, 600);
    }

    function testSetDefaultAnchorReuseDelay() public {
        vm.prank(governance);
        teePayments.setDefaultAnchorReuseDelay(SOURCE_ID, 720);
        assertEq(teePayments.getDefaultAnchorReuseDelay(SOURCE_ID), 720);
    }

    function testSetDefaultAnchorReuseDelayRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        teePayments.setDefaultAnchorReuseDelay(SOURCE_ID, 720);
    }

    //// pay ////

    function testPay() public {
        _addAccount(2);
        vm.prank(authorizationAddress);
        uint64 paymentId = teePayments.pay{value: 100}(
            account, _instruction(bytes32("ref1")), address(0));
        assertEq(paymentId, 1);
    }

    function testPayRevertAmountZero() public {
        _addAccount(2);
        ITeePaymentsBase.PaymentInstruction memory instruction = _instruction(bytes32("ref1"));
        instruction.amount = 0;
        vm.expectRevert(ITeePaymentsBase.PaymentAmountZero.selector);
        vm.prank(authorizationAddress);
        teePayments.pay{value: 100}(account, instruction, address(0));
    }

    function testPayRevertOnlyAuthorizationAddress() public {
        _addAccount(2);
        vm.expectRevert(ITeePaymentsBase.OnlyAuthorizationAddress.selector);
        vm.prank(makeAddr("notAuth"));
        teePayments.pay(account, _instruction(bytes32("ref1")), address(0));
    }

    function testPayRevertWalletNotInProduction() public {
        _addAccount(2);
        _mockGetWalletStatus(IWalletManager.WalletStatus.PAUSED);
        vm.expectRevert(ITeePaymentsBase.WalletNotInProduction.selector);
        vm.prank(authorizationAddress);
        teePayments.pay{value: 100}(account, _instruction(bytes32("ref1")), address(0));
    }

    function testPayRoundRobinAnchors() public {
        _addAccount(2);
        // batchSize defaults to 1, so each pay closes its batch and the next opens on the next anchor.
        vm.prank(authorizationAddress);
        teePayments.pay{value: 100}(account, _instruction(bytes32("r1")), address(0));
        // first batch used anchor 0 -> its nonce advanced to 2
        assertEq(teePayments.getAnchor(account, 0).nextNonce, 2);
        vm.prank(authorizationAddress);
        teePayments.pay{value: 100}(account, _instruction(bytes32("r2")), address(0));
        // second batch used anchor 1
        assertEq(teePayments.getAnchor(account, 1).nextNonce, 2);
    }

    function testPaySkipsBusyAnchorAfterGrowth() public {
        _addAccount(1); // single anchor
        vm.prank(governance);
        teePayments.setDefaultAnchorReuseDelay(SOURCE_ID, 10000);

        // First payment uses anchor 0 and (batchSize 1) closes immediately, putting anchor 0 into its
        // reuse window.
        vm.prank(authorizationAddress);
        teePayments.pay{value: 100}(account, _instruction(bytes32("r1")), address(0));
        assertEq(teePayments.getAnchor(account, 0).nextNonce, 2);

        // With only one (busy) anchor, the next payment reverts AnchorNotReady (all anchors busy).
        uint64 anchor0AvailableAt = teePayments.getAnchor(account, 0).availableAt;
        vm.expectRevert(abi.encodeWithSelector(ITeePaymentsUtxo.AnchorNotReady.selector, anchor0AvailableAt));
        vm.prank(authorizationAddress);
        teePayments.pay{value: 100}(account, _instruction(bytes32("r2")), address(0));

        // Grow to two anchors; the freshly added anchor 1 is free.
        _mockVerifyUtxo(2);
        vm.prank(walletOwner);
        teePayments.addAnchors(_utxoProof(2));

        // The busy cursor anchor (0) is now skipped and the batch opens on the free anchor 1.
        vm.prank(authorizationAddress);
        teePayments.pay{value: 100}(account, _instruction(bytes32("r3")), address(0));
        assertEq(teePayments.getAnchor(account, 1).nextNonce, 2); // anchor 1 used
        assertEq(teePayments.getAnchor(account, 0).nextNonce, 2); // anchor 0 still only used once
    }

    function testBatchEndTsReflectsActualCloseOnFull() public {
        _addAccount(2);
        // Batch holds 2 payments; duration 300s so the planned end differs from "now".
        vm.prank(walletOwner);
        teePayments.setBatchSettings(account, 2, 300);

        // Payment 1 does not fill the batch -> emits the planned end (now + 300).
        vm.prank(authorizationAddress);
        teePayments.pay{value: 100}(account, _instruction(bytes32("r1")), address(0));
        assertEq(
            _lastMessageBatchEndTs(), uint64(vm.getBlockTimestamp()) + 300, "non-filling payment uses planned end");

        // Payment 2 fills the batch (closes it now) -> emits the actual close timestamp (now).
        vm.prank(authorizationAddress);
        teePayments.pay{value: 100}(account, _instruction(bytes32("r2")), address(0));
        assertEq(
            _lastMessageBatchEndTs(), uint64(vm.getBlockTimestamp()), "batch-filling payment uses close timestamp");
    }

    //// reissue / replacement block list ////

    function testReissueRecordsBlockList() public {
        _addAccount(2);
        // A batch holds 2 payments; duration 300s so it does not close on time.
        vm.prank(walletOwner);
        teePayments.setBatchSettings(account, 2, 300);

        ITeePaymentsBase.PaymentInstruction memory instr1 = _instruction(bytes32("r1"));
        ITeePaymentsBase.PaymentInstruction memory instr2 = _instruction(bytes32("r2"));
        instr2.recipientAddress = "bc1qsecond";

        // Two payments fill batch #1 (batchPaymentId 1); the second pay closes it (full).
        vm.prank(authorizationAddress);
        teePayments.pay{value: 100}(account, instr1, address(0)); // paymentId 1
        vm.prank(authorizationAddress);
        teePayments.pay{value: 100}(account, instr2, address(0)); // paymentId 2 -> closes batch

        // Reissue chunk 1 (payment 1) in block 1000 — starts the replacement, not yet finalized.
        ITeePaymentsBase.PaymentInstruction[] memory chunk1 = new ITeePaymentsBase.PaymentInstruction[](1);
        chunk1[0] = instr1;
        vm.roll(1000);
        vm.prank(authorizationAddress);
        bool finalized1 = teePayments.reissue{value: 50}(account, 1, chunk1, _reissueFee(50), address(0));
        assertFalse(finalized1, "first chunk must not finalize the batch reissue");

        // Move to block 1001 and reissue chunk 2 (payment 2) — finalizes the replacement.
        vm.roll(1001);
        ITeePaymentsBase.PaymentInstruction[] memory chunk2 = new ITeePaymentsBase.PaymentInstruction[](1);
        chunk2[0] = instr2;

        // The replacement records the exact blocks in which it emitted reissue instructions.
        uint256[] memory expectedBlocks = new uint256[](2);
        expectedBlocks[0] = 1000;
        expectedBlocks[1] = 1001;
        bytes32 accountHash = keccak256(abi.encode(SOURCE_ID, accountAddress));
        vm.expectEmit();
        emit ITeePaymentsUtxo.UtxoReplacementReady(walletId, accountHash, 1, 1, 1, 2, expectedBlocks);
        vm.prank(authorizationAddress);
        bool finalized2 = teePayments.reissue{value: 50}(account, 1, chunk2, _reissueFee(50), address(0));
        assertTrue(finalized2, "second chunk completes and finalizes the batch reissue");
    }

    //// helpers ////

    function _reissueFee(
        uint256 _maxFee
    )
        internal pure returns (ITeePaymentsBase.ReissueFeeParams memory)
    {
        uint256[] memory maxFeePerPayment = new uint256[](1);
        maxFeePerPayment[0] = _maxFee;
        return ITeePaymentsBase.ReissueFeeParams({
            maxFeePerPayment: maxFeePerPayment,
            factorsBIPSPerPayment: new int16[][](0),
            delaysSeconds: new uint16[](0)
        });
    }

    function testGetPaymentFeePay() public {
        _addAccount(2);
        uint256 expectedFee = 900;
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(
                IOperationFees.calculateFeeByWalletId.selector, walletId, OP_TYPE, bytes32("PAY")),
            abi.encode(expectedFee)
        );
        assertEq(teePayments.getPaymentFee(account, bytes32("PAY")), expectedFee);
    }

    function testGetPaymentFeeRevertNotRegistered() public {
        vm.expectRevert(ITeePaymentsBase.PMWMultisigAccountNotRegistered.selector);
        teePayments.getPaymentFee(account, bytes32("PAY"));
    }

    function _addAccount(uint32 _anchorCount) internal {
        _mockVerifyUtxo(_anchorCount);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, _utxoProof(_anchorCount), authorizationAddress);
    }

    function _instruction(
        bytes32 _ref
    )
        internal pure returns (ITeePaymentsBase.PaymentInstruction memory)
    {
        return ITeePaymentsBase.PaymentInstruction({
            recipientAddress: "bc1qrecipient",
            tokenId: bytes(""),
            amount: 1000,
            maxFee: 10,
            paymentReference: _ref
        });
    }

    function _utxoProof(
        uint32 _anchorCount
    )
        internal view returns (IPMWMultisigUtxoConfigured.Proof memory _proof)
    {
        IPMWMultisigUtxoConfigured.Anchor[] memory anchors =
            new IPMWMultisigUtxoConfigured.Anchor[](_anchorCount);
        string[] memory anchorAddresses = new string[](_anchorCount);
        for (uint32 i = 0; i < _anchorCount; i++) {
            anchors[i] = IPMWMultisigUtxoConfigured.Anchor({
                genesisAnchorTxid: keccak256(abi.encode("txid", i)),
                genesisAnchorVout: i
            });
            anchorAddresses[i] = i == 0 ? accountAddress : string.concat("anchor", vm.toString(i));
        }
        _proof.header.sourceId = SOURCE_ID;
        _proof.requestBody.accountIndex = ACCOUNT_INDEX;
        _proof.requestBody.anchors = anchors;
        _proof.responseBody.status = IPMWMultisigUtxoConfigured.PMWMultisigUtxoStatus.OK;
        _proof.responseBody.accountAddress = accountAddress;
        _proof.responseBody.anchorAddresses = anchorAddresses;
    }

    // verifyUtxoConfiguredProof is validate-only (returns nothing); the contract reads the verified
    // fields from the proof. Mock it to simply not revert. (Unused arg kept for call-site readability.)
    function _mockVerifyUtxo(uint32) internal {
        vm.mockCall(
            teePaymentsConfigVerifier,
            abi.encodeWithSelector(ITeePaymentsConfigVerifier.verifyUtxoConfiguredProof.selector),
            ""
        );
    }

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

    function _mockGetKeyType(bytes32 _projectId, bytes32 _keyType) internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IWalletProjectManager.getKeyType.selector, _projectId),
            abi.encode(_keyType)
        );
    }

    function _mockGetWalletStatus(IWalletManager.WalletStatus _status) internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IWalletManager.getWalletStatus.selector, walletId),
            abi.encode(_status)
        );
    }

    function _mockGetCurrentRewardEpochId(uint24 _rewardEpochId) internal {
        vm.mockCall(
            mockFSM,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(_rewardEpochId)
        );
    }

    function _mockReceivingTeesAndKeys() internal {
        TeeIdKeyIdPair[] memory teeIdKeyIdPairs = new TeeIdKeyIdPair[](1);
        teeIdKeyIdPairs[0] = TeeIdKeyIdPair({ teeId: makeAddr("teeId"), keyId: 1 });
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IWalletKeyManager.receivingTeesAndKeys.selector),
            abi.encode(teeIdKeyIdPairs)
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

    function _lastMessageBatchEndTs() internal view returns (uint64) {
        bytes memory raw = SendInstructionsSpy(flareTeeManager).lastMessage();
        ITeePaymentsUtxo.UtxoPaymentInstructionMessage memory message =
            abi.decode(raw, (ITeePaymentsUtxo.UtxoPaymentInstructionMessage));
        return message.batchEndTs;
    }
}
