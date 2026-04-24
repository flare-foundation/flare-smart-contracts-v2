// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import {
    TeePaymentsLimitsManager
} from "../../../../contracts/tee/implementation/TeePaymentsLimitsManager.sol";
import {
    TeePaymentsLimitsManagerProxy
} from "../../../../contracts/tee/proxy/TeePaymentsLimitsManagerProxy.sol";
import { TeePaymentsRegistry } from "../../../../contracts/tee/implementation/TeePaymentsRegistry.sol";
import { TeePaymentsRegistryProxy } from "../../../../contracts/tee/proxy/TeePaymentsRegistryProxy.sol";
import {
    ITeePaymentsLimitsManager
} from "../../../../contracts/userInterfaces/tee/ITeePaymentsLimitsManager.sol";
import { ITeePaymentsRegistry } from "../../../../contracts/userInterfaces/tee/ITeePaymentsRegistry.sol";
import { ITeePayments } from "../../../../contracts/userInterfaces/tee/ITeePayments.sol";
import {
    IWalletProjectManager
} from "../../../../contracts/userInterfaces/tee/IWalletProjectManager.sol";
import {
    IWalletManager
} from "../../../../contracts/userInterfaces/tee/IWalletManager.sol";
import {
    IWalletKeyManager
} from "../../../../contracts/userInterfaces/tee/IWalletKeyManager.sol";
import { IInstructions } from "../../../../contracts/userInterfaces/tee/IInstructions.sol";
import { TeeIdKeyIdPair } from "../../../../contracts/userInterfaces/tee/ITeeIdKeyIdPair.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

// solhint-disable-next-line max-states-count
contract TeePaymentsLimitsManagerTest is Test {

    bytes32 private constant SOURCE_ID = bytes32("XRP");
    bytes32 private constant OP_TYPE = bytes32("F_XRP");
    bytes32 private constant SET_PAYMENT_LIMITS = bytes32("SET_PAYMENT_LIMITS");
    bytes32 private constant PROJECT_ID = bytes32("projectId");
    bytes32 private constant WALLET_ID = bytes32("walletId");

    TeePaymentsLimitsManager private manager;
    TeePaymentsLimitsManager private managerImpl;
    TeePaymentsRegistry private registry;

    address private governance;
    address private addressUpdater;
    address private flareTeeManager;
    address private teePayments;
    address private walletOwner;
    address private otherUser;

    string private accountAddress = "accountAddress";
    ITeePayments.PMWMultisigAccount private account;

    address[] private admins;
    uint64 private adminsThreshold;
    TeeIdKeyIdPair[] private teeIdKeyIdPairs;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        flareTeeManager = makeAddr("flareTeeManager");
        teePayments = makeAddr("teePayments");
        // Registry enforces that teePayments has deployed code.
        vm.etch(teePayments, hex"01");
        walletOwner = makeAddr("walletOwner");
        otherUser = makeAddr("otherUser");

        managerImpl = new TeePaymentsLimitsManager();
        TeePaymentsLimitsManagerProxy proxy = new TeePaymentsLimitsManagerProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(managerImpl)
        );
        manager = TeePaymentsLimitsManager(address(proxy));

        // Deploy Registry
        TeePaymentsRegistry registryImpl = new TeePaymentsRegistry();
        TeePaymentsRegistryProxy registryProxy = new TeePaymentsRegistryProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(registryImpl)
        );
        registry = TeePaymentsRegistry(address(registryProxy));

        vm.startPrank(addressUpdater);
        bytes32[] memory names = new bytes32[](3);
        address[] memory addrs = new address[](3);
        names[0] = keccak256(abi.encode("AddressUpdater"));
        names[1] = keccak256(abi.encode("FlareTeeManager"));
        names[2] = keccak256(abi.encode("TeePaymentsRegistry"));
        addrs[0] = addressUpdater;
        addrs[1] = flareTeeManager;
        addrs[2] = address(registry);
        manager.updateContractAddresses(names, addrs);
        vm.stopPrank();

        account.sourceId = SOURCE_ID;
        account.accountAddress = accountAddress;

        admins = new address[](2);
        admins[0] = makeAddr("admin1");
        admins[1] = makeAddr("admin2");
        adminsThreshold = 2;

        teeIdKeyIdPairs.push(TeeIdKeyIdPair({ teeId: makeAddr("teeId"), keyId: 1 }));

        _mockGetOpType(teePayments, OP_TYPE);
        _mockGetWalletId(teePayments, WALLET_ID);
        _mockGetWalletProjectId(WALLET_ID, PROJECT_ID);
        _mockGetOwner(PROJECT_ID, walletOwner);
        _mockGetWalletAdminsAndThreshold(WALLET_ID);
        _mockReceivingTeesAndKeys();
        _mockSendInstructions();

        vm.deal(walletOwner, 1 ether);
        vm.deal(otherUser, 1 ether);
    }

    //// setPaymentLimits ////
    function testSetPaymentLimits() public {
        _registerSource();
        vm.expectEmit();
        emit ITeePaymentsLimitsManager.PaymentLimitsSet(WALLET_ID, SOURCE_ID, accountAddress, 1000, 10000);
        vm.prank(walletOwner);
        manager.setPaymentLimits{value: 988}(account, 1000, 10000, address(0));

        assertEq(manager.getPaymentLimitsNonce(account), 1);
    }

    function testSetPaymentLimitsWithClaimBackAddress() public {
        _registerSource();
        vm.prank(walletOwner);
        manager.setPaymentLimits{value: 988}(account, 1000, 10000, makeAddr("claimBack"));
    }

    function testSetPaymentLimitsNonceIncrements() public {
        _registerSource();
        assertEq(manager.getPaymentLimitsNonce(account), 0);
        vm.prank(walletOwner);
        manager.setPaymentLimits{value: 988}(account, 1000, 10000, address(0));
        assertEq(manager.getPaymentLimitsNonce(account), 1);
        vm.prank(walletOwner);
        manager.setPaymentLimits{value: 988}(account, 1000, 10000, address(0));
        assertEq(manager.getPaymentLimitsNonce(account), 2);
    }

    function testSetPaymentLimitsRevertDailyBelowTransaction() public {
        _registerSource();
        vm.prank(walletOwner);
        vm.expectRevert(ITeePaymentsLimitsManager.DailyLimitBelowTransactionLimit.selector);
        manager.setPaymentLimits{value: 988}(account, 1000, 500, address(0));
    }

    function testSetPaymentLimitsRevertUnsupportedSourceId() public {
        // Registry has no entry for SOURCE_ID
        vm.prank(walletOwner);
        vm.expectRevert(ITeePaymentsLimitsManager.UnsupportedSourceId.selector);
        manager.setPaymentLimits{value: 988}(account, 1000, 10000, address(0));
    }

    function testSetPaymentLimitsRevertAccountNotRegistered() public {
        _registerSource();
        _mockGetWalletId(teePayments, bytes32(0));
        vm.prank(walletOwner);
        vm.expectRevert(ITeePaymentsLimitsManager.AccountNotRegistered.selector);
        manager.setPaymentLimits{value: 988}(account, 1000, 10000, address(0));
    }

    function testSetPaymentLimitsRevertOnlyWalletOwner() public {
        _registerSource();
        vm.prank(otherUser);
        vm.expectRevert(ITeePaymentsLimitsManager.OnlyWalletOwner.selector);
        manager.setPaymentLimits{value: 988}(account, 1000, 10000, address(0));
    }

    function testSetPaymentLimitsSendsInstructionWithCorrectOpType() public {
        _registerSource();
        // Expect the call to sendInstructions with the expected opType / opCommand / admins / threshold
        ITeePaymentsLimitsManager.SetPaymentLimitsMessage memory message =
            ITeePaymentsLimitsManager.SetPaymentLimitsMessage({
                walletId: WALLET_ID,
                sourceId: SOURCE_ID,
                accountAddress: accountAddress,
                nonce: 0,
                teeIdKeyIdPairs: teeIdKeyIdPairs,
                transactionLimit: 1000,
                dailyLimit: 10000
            });
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeIdKeyIdPairs[0].teeId;

        vm.expectCall(
            flareTeeManager,
            abi.encodeWithSelector(
                IInstructions.sendInstructions.selector,
                teeIds,
                IInstructions.TeeInstructionParams(
                    OP_TYPE,
                    SET_PAYMENT_LIMITS,
                    abi.encode(message),
                    admins,
                    adminsThreshold,
                    address(0)
                )
            )
        );
        vm.prank(walletOwner);
        manager.setPaymentLimits{value: 988}(account, 1000, 10000, address(0));
        assertEq(manager.getPaymentLimitsNonce(account), 1);
    }

    //// Upgrade ////
    function testUpgradeProxy() public {
        assertEq(manager.implementation(), address(managerImpl));
        TeePaymentsLimitsManager newImpl = new TeePaymentsLimitsManager();
        vm.prank(governance);
        manager.upgradeToAndCall(address(newImpl), bytes(""));
        assertEq(manager.implementation(), address(newImpl));
    }

    function testUpgradeProxyRevertOnlyGovernance() public {
        TeePaymentsLimitsManager newImpl = new TeePaymentsLimitsManager();
        vm.expectRevert("only governance");
        manager.upgradeToAndCall(address(newImpl), bytes(""));
    }

    //// Helpers ////
    function _registerSource() internal {
        ITeePaymentsRegistry.SourceRegistration[] memory inputs =
            new ITeePaymentsRegistry.SourceRegistration[](1);
        inputs[0] = ITeePaymentsRegistry.SourceRegistration(SOURCE_ID, teePayments);
        vm.prank(governance);
        registry.registerSources(inputs);
    }

    function _mockGetOpType(address _teePayments, bytes32 _opType) internal {
        vm.mockCall(
            _teePayments,
            abi.encodeWithSelector(ITeePayments.getOpType.selector),
            abi.encode(_opType)
        );
    }

    function _mockGetWalletId(address _teePayments, bytes32 _walletId) internal {
        vm.mockCall(
            _teePayments,
            abi.encodeWithSelector(ITeePayments.getWalletId.selector),
            abi.encode(_walletId)
        );
    }

    function _mockGetWalletProjectId(bytes32 _walletId, bytes32 _projectId) internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IWalletManager.getWalletProjectId.selector, _walletId),
            abi.encode(_projectId)
        );
    }

    function _mockGetOwner(bytes32 _projectId, address _owner) internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IWalletProjectManager.getOwner.selector, _projectId),
            abi.encode(_owner)
        );
    }

    function _mockGetWalletAdminsAndThreshold(bytes32 _walletId) internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IWalletManager.getWalletAdminsAndThreshold.selector, _walletId),
            abi.encode(admins, adminsThreshold)
        );
    }

    function _mockReceivingTeesAndKeys() internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IWalletKeyManager.receivingTeesAndKeys.selector),
            abi.encode(teeIdKeyIdPairs)
        );
    }

    function _mockSendInstructions() internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IInstructions.sendInstructions.selector),
            abi.encode(bytes32(uint256(1)))
        );
    }
}
