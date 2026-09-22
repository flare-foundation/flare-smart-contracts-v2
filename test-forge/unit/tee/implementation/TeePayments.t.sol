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
import { ITeePaymentsBase } from "../../../../contracts/userInterfaces/tee/ITeePaymentsBase.sol";
import {
    ITeePaymentsConfigVerifier
} from "../../../../contracts/userInterfaces/tee/ITeePaymentsConfigVerifier.sol";
import { ITeePaymentsRegistry } from "../../../../contracts/userInterfaces/tee/ITeePaymentsRegistry.sol";
import { IAddressValidator } from "../../../../contracts/userInterfaces/tee/IAddressValidator.sol";
import { PaymentModel } from "../../../../contracts/userInterfaces/tee/ITeePaymentsModel.sol";
import {
    ITeePaymentsFeeScheduleManager
} from "../../../../contracts/userInterfaces/tee/ITeePaymentsFeeScheduleManager.sol";
import {
    IWalletProjectManager
} from "../../../../contracts/userInterfaces/tee/IWalletProjectManager.sol";
import { IWalletKeyManager } from "../../../../contracts/userInterfaces/tee/IWalletKeyManager.sol";
import { IOperationFees } from "../../../../contracts/userInterfaces/tee/IOperationFees.sol";
import { TeeIdKeyIdPair } from "../../../../contracts/userInterfaces/tee/ITeeIdKeyIdPair.sol";
import {
    IPMWMultisigAccountConfigured,
    PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE
} from "../../../../contracts/userInterfaces/fdc2/IPMWMultisigAccountConfigured.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

//solhint-disable-next-line max-states-count
contract TeePaymentsTest is Test {

    bytes32 private constant OP_TYPE = bytes32("F_XRP");
    bytes32 private constant KEY_TYPE = bytes32("XRP_KEY");
    bytes32 private constant SOURCE_ID = bytes32("XRP");
    bytes32 private constant PAY = bytes32("PAY");
    bytes32 private constant REISSUE = bytes32("REISSUE");
    bytes private constant DEFAULT_FEE_SCHEDULE = hex"27100000";
    uint64 private constant INITIAL_NONCE = 11;

    TeePayments private teePayments;
    TeePayments private teePaymentsImpl;
    TeePaymentsProxy private teePaymentsProxy;
    TeePaymentsRegistry private teePaymentsRegistry;

    address private mockFSM;

    address private flareTeeManager;
    address private teePaymentsFeeScheduleManager;
    address private teePaymentsConfigVerifier;
    address private addressValidator;

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
    ITeePaymentsBase.PMWMultisigAccount private pmwMultisigAccount;
    IPMWMultisigAccountConfigured.Proof private proof;
    address[] private cosigners;
    uint64 private cosignersThreshold;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        mockFSM = makeAddr("mockFlareSystemsManager");

        teePaymentsImpl = new TeePayments();
        teePaymentsProxy = new TeePaymentsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
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

        // Register test sourceId -> this TeePayments (account model) in the registry
        ITeePaymentsRegistry.SourceRegistration[] memory regs =
            new ITeePaymentsRegistry.SourceRegistration[](1);
        regs[0] = ITeePaymentsRegistry.SourceRegistration({
            keyType: KEY_TYPE,
            opType: OP_TYPE,
            paymentModel: PaymentModel.ACCOUNT,
            sourceId: SOURCE_ID,
            teePayments: address(teePayments)
        });
        vm.prank(governance);
        teePaymentsRegistry.registerSources(regs);

        flareTeeManager = makeAddr("flareTeeManager");
        teePaymentsFeeScheduleManager = makeAddr("teePaymentsFeeScheduleManager");
        teePaymentsConfigVerifier = makeAddr("teePaymentsConfigVerifier");
        addressValidator = makeAddr("addressValidator");

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](7);
        contractAddresses = new address[](7);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareTeeManager"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("TeePaymentsFeeScheduleManager"));
        contractNameHashes[4] = keccak256(abi.encode("TeePaymentsRegistry"));
        contractNameHashes[5] = keccak256(abi.encode("TeePaymentsConfigVerifier"));
        contractNameHashes[6] = keccak256(abi.encode("AddressValidator"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = flareTeeManager;
        contractAddresses[2] = mockFSM;
        contractAddresses[3] = teePaymentsFeeScheduleManager;
        contractAddresses[4] = address(teePaymentsRegistry);
        contractAddresses[5] = teePaymentsConfigVerifier;
        contractAddresses[6] = addressValidator;
        teePayments.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        _mockIsValidAddress(true);

        _mockGetWalletProjectId(walletId, projectId);
        _mockGetExtensionId(projectId, 0);
        _mockGetOwner(projectId, walletOwner);
        _mockGetCurrentRewardEpochId(10);
        _mockGetKeyType(projectId, KEY_TYPE);
        _mockGetWalletStatus(IWalletManager.WalletStatus.PRODUCTION);
        _mockReceivingTeesAndKeys();
        _mockSendSystemInstructions();
        _mockGetEffectiveSchedule(DEFAULT_FEE_SCHEDULE);
        _mockValidateAndEncodeSchedules();

        pmwMultisigAccount.sourceId = SOURCE_ID;
        pmwMultisigAccount.accountAddress = senderAddress;

        proof.header.attestationType = PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE;
        proof.header.sourceId = SOURCE_ID;
        proof.requestBody.accountAddress = senderAddress;
        proof.responseBody.status = IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.OK;
        proof.responseBody.sequence = INITIAL_NONCE;
        _mockVerifyAccountConfiguredProof();

        cosigners = new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");
        cosignersThreshold = 1;
        _mockGetWalletCosignersAndThreshold(walletId, cosigners, cosignersThreshold);

        vm.deal(authorizationAddress, 1 ether);
        vm.deal(walletOwner, 1 ether);
        vm.warp(500);
    }

    //// addPMWMultisigAccount ////

    function testAddPMWMultisigAccount() public {
        assertEq(teePayments.getWalletId(pmwMultisigAccount), bytes32(0));
        vm.expectEmit();
        emit ITeePayments.PMWMultisigAccountAdded(
            walletId, SOURCE_ID, senderAddress, authorizationAddress, INITIAL_NONCE);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        assertEq(teePayments.getWalletId(pmwMultisigAccount), walletId);
        assertEq(teePayments.getAuthorizationAddress(pmwMultisigAccount), authorizationAddress);
        ITeePaymentsBase.PMWMultisigAccount[] memory accounts = teePayments.getWalletAccounts(walletId);
        assertEq(accounts.length, 1);
        assertEq(accounts[0].accountAddress, senderAddress);
    }

    function testAddPMWMultisigAccountRevertOnlyWalletOwner() public {
        vm.expectRevert(ITeePaymentsBase.OnlyWalletOwner.selector);
        vm.prank(makeAddr("notOwner"));
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    function testAddPMWMultisigAccountRevertExtensionId() public {
        _mockGetExtensionId(projectId, 1);
        vm.expectRevert(ITeePaymentsBase.OnlySystemExtensionId.selector);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    function testAddPMWMultisigAccountRevertWrongKeyType() public {
        _mockGetKeyType(projectId, bytes32("OTHER"));
        vm.expectRevert(ITeePaymentsBase.WrongKeyType.selector);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    function testAddPMWMultisigAccountRevertAuthZero() public {
        vm.expectRevert(ITeePaymentsBase.AuthorizationAddressZero.selector);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, address(0));
    }

    function testAddPMWMultisigAccountRevertAlreadySet() public {
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        vm.expectRevert(ITeePaymentsBase.PMWMultisigAccountAddressAlreadySet.selector);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    function testAddPMWMultisigAccountRevertWalletStatus() public {
        _mockGetWalletStatus(IWalletManager.WalletStatus.CREATED);
        vm.expectRevert(ITeePaymentsBase.OnlyProductionOrPausedStatus.selector);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    function testAddPMWMultisigAccountRevertInvalidProof() public {
        vm.mockCallRevert(
            teePaymentsConfigVerifier,
            abi.encodeWithSelector(ITeePaymentsConfigVerifier.verifyAccountConfiguredProof.selector),
            abi.encodeWithSelector(ITeePaymentsConfigVerifier.InvalidProof.selector)
        );
        vm.expectRevert(ITeePaymentsConfigVerifier.InvalidProof.selector);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    //// pay ////

    function testPay() public {
        _addAccount();
        vm.prank(authorizationAddress);
        uint64 paymentId = teePayments.pay{value: fee}(
            pmwMultisigAccount,
            _createPaymentInstruction(bytes32("ref1")),
            address(0)
        );
        assertEq(paymentId, 1);
    }

    function testPayRevertsInvalidRecipientAddress() public {
        _addAccount();
        _mockIsValidAddress(false);
        vm.expectRevert(ITeePaymentsBase.InvalidRecipientAddress.selector);
        vm.prank(authorizationAddress);
        teePayments.pay{value: fee}(
            pmwMultisigAccount,
            _createPaymentInstruction(bytes32("ref1")),
            address(0)
        );
    }

    function testPayIncrementsPaymentId() public {
        _addAccount();
        vm.prank(authorizationAddress);
        uint64 first = teePayments.pay{value: fee}(
            pmwMultisigAccount, _createPaymentInstruction(bytes32("ref1")), address(0));
        vm.prank(authorizationAddress);
        uint64 second = teePayments.pay{value: fee}(
            pmwMultisigAccount, _createPaymentInstruction(bytes32("ref2")), address(0));
        assertEq(first, 1);
        assertEq(second, 2);
    }

    function testGetNextPaymentId() public {
        _addAccount();
        // No payment made yet: next id starts at 1.
        assertEq(teePayments.getNextPaymentId(pmwMultisigAccount), 1, "starts at 1");
        vm.prank(authorizationAddress);
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref1")), address(0));
        assertEq(teePayments.getNextPaymentId(pmwMultisigAccount), 2, "advances after a payment");
        vm.prank(authorizationAddress);
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref2")), address(0));
        assertEq(teePayments.getNextPaymentId(pmwMultisigAccount), 3, "advances again");
    }

    function testPayRevertAmountZero() public {
        _addAccount();
        ITeePaymentsBase.PaymentInstruction memory instruction = _createPaymentInstruction(bytes32("ref1"));
        instruction.amount = 0;
        vm.expectRevert(ITeePaymentsBase.PaymentAmountZero.selector);
        vm.prank(authorizationAddress);
        teePayments.pay{value: fee}(pmwMultisigAccount, instruction, address(0));
    }

    function testPayRevertOnlyAuthorizationAddress() public {
        _addAccount();
        // No value sent: the authorization check must reject the caller regardless of fee.
        vm.expectRevert(ITeePaymentsBase.OnlyAuthorizationAddress.selector);
        vm.prank(makeAddr("notAuth"));
        teePayments.pay(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref1")), address(0));
    }

    function testPayRevertWalletNotInProduction() public {
        _addAccount();
        _mockGetWalletStatus(IWalletManager.WalletStatus.PAUSED);
        vm.expectRevert(ITeePaymentsBase.WalletNotInProduction.selector);
        vm.prank(authorizationAddress);
        teePayments.pay{value: fee}(pmwMultisigAccount, _createPaymentInstruction(bytes32("ref1")), address(0));
    }

    //// getPaymentFee ////

    function testGetPaymentFeePay() public {
        _addAccount();
        uint256 expectedFee = 500;
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IOperationFees.calculateFeeByWalletId.selector, walletId, OP_TYPE, PAY),
            abi.encode(expectedFee)
        );
        assertEq(teePayments.getPaymentFee(pmwMultisigAccount, PAY), expectedFee);
    }

    function testGetPaymentFeeReissue() public {
        _addAccount();
        uint256 expectedFee = 700;
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IOperationFees.calculateFeeByWalletId.selector, walletId, OP_TYPE, REISSUE),
            abi.encode(expectedFee)
        );
        assertEq(teePayments.getPaymentFee(pmwMultisigAccount, REISSUE), expectedFee);
    }

    function testGetPaymentFeeRevertNotRegistered() public {
        // Account never registered -> walletId resolves to 0.
        vm.expectRevert(ITeePaymentsBase.PMWMultisigAccountNotRegistered.selector);
        teePayments.getPaymentFee(pmwMultisigAccount, PAY);
    }

    //// reissue ////

    function testReissue() public {
        _addAccount();
        ITeePaymentsBase.PaymentInstruction memory instruction = _createPaymentInstruction(bytes32("ref1"));
        vm.prank(authorizationAddress);
        uint64 paymentId = teePayments.pay{value: fee}(pmwMultisigAccount, instruction, address(0));

        ITeePaymentsBase.PaymentInstruction[] memory instructions = new ITeePaymentsBase.PaymentInstruction[](1);
        instructions[0] = instruction;
        vm.prank(authorizationAddress);
        bool finalized = teePayments.reissue{value: fee}(
            pmwMultisigAccount,
            paymentId,
            instructions,
            _emptyReissueFeeParams(),
            true,
            address(0)
        );
        assertTrue(finalized, "account reissue always finalizes");
    }

    // Account reissue is single-shot: startNew must be true; false reverts.
    function testReissueRevertStartNewRequired() public {
        _addAccount();
        ITeePaymentsBase.PaymentInstruction memory instruction = _createPaymentInstruction(bytes32("ref1"));
        vm.prank(authorizationAddress);
        uint64 paymentId = teePayments.pay{value: fee}(pmwMultisigAccount, instruction, address(0));

        ITeePaymentsBase.PaymentInstruction[] memory instructions = new ITeePaymentsBase.PaymentInstruction[](1);
        instructions[0] = instruction;
        vm.expectRevert(ITeePayments.StartNewRequired.selector);
        vm.prank(authorizationAddress);
        teePayments.reissue{value: fee}(
            pmwMultisigAccount, paymentId, instructions, _emptyReissueFeeParams(), false, address(0));
    }

    function testReissueRevertInvalidCount() public {
        _addAccount();
        ITeePaymentsBase.PaymentInstruction[] memory instructions = new ITeePaymentsBase.PaymentInstruction[](2);
        instructions[0] = _createPaymentInstruction(bytes32("ref1"));
        instructions[1] = _createPaymentInstruction(bytes32("ref2"));
        vm.expectRevert(ITeePayments.InvalidPaymentInstructionCount.selector);
        vm.prank(authorizationAddress);
        teePayments.reissue{value: fee}(
            pmwMultisigAccount, 1, instructions, _emptyReissueFeeParams(), true, address(0));
    }

    function testReissueRevertHashMismatch() public {
        _addAccount();
        vm.prank(authorizationAddress);
        uint64 paymentId = teePayments.pay{value: fee}(
            pmwMultisigAccount, _createPaymentInstruction(bytes32("ref1")), address(0));

        // different instruction than the one paid -> hash mismatch
        ITeePaymentsBase.PaymentInstruction[] memory instructions = new ITeePaymentsBase.PaymentInstruction[](1);
        instructions[0] = _createPaymentInstruction(bytes32("DIFFERENT"));
        vm.expectRevert(ITeePaymentsBase.PaymentHashMismatch.selector);
        vm.prank(authorizationAddress);
        teePayments.reissue{value: fee}(
            pmwMultisigAccount, paymentId, instructions, _emptyReissueFeeParams(), true, address(0));
    }

    //// misc ////

    function testPaymentModel() public {
        assertEq(uint256(teePayments.paymentModel()), uint256(PaymentModel.ACCOUNT));
    }

    function testGetAuthorizationAddressUnset() public {
        assertEq(teePayments.getAuthorizationAddress(pmwMultisigAccount), address(0));
    }

    function testGetInitialNonce() public {
        _addAccount();
        assertEq(teePayments.getInitialNonce(pmwMultisigAccount), INITIAL_NONCE);
    }

    function testGetInitialNonceRevertNotRegistered() public {
        vm.expectRevert(ITeePaymentsBase.PMWMultisigAccountNotRegistered.selector);
        teePayments.getInitialNonce(pmwMultisigAccount);
    }

    function testGetInitialNonceZeroSequence() public {
        proof.responseBody.sequence = 0;
        vm.expectEmit();
        emit ITeePayments.PMWMultisigAccountAdded(walletId, SOURCE_ID, senderAddress, authorizationAddress, 0);
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
        assertEq(teePayments.getInitialNonce(pmwMultisigAccount), 0);
    }

    //// helpers ////

    function _addAccount() internal {
        vm.prank(walletOwner);
        teePayments.addPMWMultisigAccount(walletId, proof, authorizationAddress);
    }

    // verifyAccountConfiguredProof is validate-only (returns nothing); the contract reads the verified
    // fields from the proof. Mock it to simply not revert.
    function _mockVerifyAccountConfiguredProof() internal {
        vm.mockCall(
            teePaymentsConfigVerifier,
            abi.encodeWithSelector(ITeePaymentsConfigVerifier.verifyAccountConfiguredProof.selector),
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

    function _mockGetKeyType(bytes32 _projectId, bytes32 _keyType) internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IWalletProjectManager.getKeyType.selector, _projectId),
            abi.encode(_keyType)
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

    function _mockSendSystemInstructions() internal {
        bytes4 sel = bytes4(keccak256(
            "sendSystemInstructions(bytes32,address[],(bytes32,bytes32,bytes,address[],uint64,address))"
        ));
        vm.mockCall(flareTeeManager, abi.encodePacked(sel), abi.encode(bytes32(uint256(1))));
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

    function _emptyReissueFeeParams()
        internal pure
        returns (ITeePaymentsBase.ReissueFeeParams memory)
    {
        uint256[] memory maxFeePerPayment = new uint256[](1);
        maxFeePerPayment[0] = 10;
        return ITeePaymentsBase.ReissueFeeParams({
            maxFeePerPayment: maxFeePerPayment,
            factorsBIPSPerPayment: new int16[][](0),
            delaysSeconds: new uint16[](0)
        });
    }

    function _createPaymentInstruction(
        bytes32 _paymentReference
    )
        internal pure returns (ITeePaymentsBase.PaymentInstruction memory)
    {
        return ITeePaymentsBase.PaymentInstruction({
            recipientAddress: "recipientAddress",
            tokenId: bytes(""),
            amount: 100,
            maxFee: 10,
            paymentReference: _paymentReference
        });
    }

    function _mockIsValidAddress(bool _valid) private {
        vm.mockCall(
            addressValidator,
            abi.encodeWithSelector(IAddressValidator.isValidAddress.selector),
            abi.encode(_valid)
        );
    }
}
