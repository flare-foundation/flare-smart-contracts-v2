// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import {
    TeePaymentsFeeScheduleManager
} from "../../../../contracts/tee/implementation/TeePaymentsFeeScheduleManager.sol";
import {
    TeePaymentsFeeScheduleManagerProxy
} from "../../../../contracts/tee/proxy/TeePaymentsFeeScheduleManagerProxy.sol";
import { TeePaymentsRegistry } from "../../../../contracts/tee/implementation/TeePaymentsRegistry.sol";
import { TeePaymentsRegistryProxy } from "../../../../contracts/tee/proxy/TeePaymentsRegistryProxy.sol";
import {
    ITeePaymentsFeeScheduleManager
} from "../../../../contracts/userInterfaces/tee/ITeePaymentsFeeScheduleManager.sol";
import { ITeePaymentsRegistry } from "../../../../contracts/userInterfaces/tee/ITeePaymentsRegistry.sol";
import { ITeePayments } from "../../../../contracts/userInterfaces/tee/ITeePayments.sol";
import {
    IWalletProjectManager
} from "../../../../contracts/userInterfaces/tee/IWalletProjectManager.sol";
import {
    IWalletManager
} from "../../../../contracts/userInterfaces/tee/IWalletManager.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { IFlareGovernance } from "../../../../contracts/userInterfaces/IFlareGovernance.sol";

// solhint-disable-next-line max-states-count
contract TeePaymentsFeeScheduleManagerTest is Test {

    bytes32 private constant SOURCE_ID = bytes32("XRP");
    bytes32 private constant OTHER_SOURCE_ID = bytes32("BTC");
    bytes32 private constant PROJECT_ID = bytes32("projectId");
    bytes32 private constant OTHER_PROJECT_ID = bytes32("otherProjectId");
    bytes32 private constant WALLET_ID = bytes32("walletId");
    bytes32 private constant OTHER_WALLET_ID = bytes32("otherWalletId");

    TeePaymentsFeeScheduleManager private manager;
    TeePaymentsFeeScheduleManager private managerImpl;
    TeePaymentsRegistry private registry;

    address private governance;
    address private addressUpdater;
    address private flareTeeManager;
    address private teePayments;
    address private projectOwner;
    address private otherUser;

    string private accountAddress = "accountAddress";
    ITeePayments.PMWMultisigAccount private account;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        flareTeeManager = makeAddr("flareTeeManager");
        teePayments = makeAddr("teePayments");
        // Registry enforces that teePayments has deployed code.
        vm.etch(teePayments, hex"01");
        projectOwner = makeAddr("projectOwner");
        otherUser = makeAddr("otherUser");

        managerImpl = new TeePaymentsFeeScheduleManager();
        TeePaymentsFeeScheduleManagerProxy proxy = new TeePaymentsFeeScheduleManagerProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(managerImpl)
        );
        manager = TeePaymentsFeeScheduleManager(address(proxy));

        // Deploy Registry
        TeePaymentsRegistry registryImpl = new TeePaymentsRegistry();
        TeePaymentsRegistryProxy registryProxy = new TeePaymentsRegistryProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(registryImpl)
        );
        registry = TeePaymentsRegistry(address(registryProxy));

        // Register SOURCE_ID + OTHER_SOURCE_ID -> teePayments mock
        ITeePaymentsRegistry.SourceRegistration[] memory regs =
            new ITeePaymentsRegistry.SourceRegistration[](2);
        regs[0] = ITeePaymentsRegistry.SourceRegistration(SOURCE_ID, teePayments);
        regs[1] = ITeePaymentsRegistry.SourceRegistration(OTHER_SOURCE_ID, teePayments);
        vm.prank(governance);
        registry.registerSources(regs);

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

        _mockGetOwner(PROJECT_ID, projectOwner);
        _mockGetOwner(OTHER_PROJECT_ID, otherUser);
        // Default: account -> WALLET_ID -> PROJECT_ID owned by projectOwner
        _mockGetWalletId(teePayments, WALLET_ID);
        _mockGetWalletProjectId(WALLET_ID, PROJECT_ID);
    }

    //// setFeeScheduleConfigs ////
    function testSetFeeScheduleConfig() public {
        ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[] memory inputs =
            new ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[](2);
        inputs[0] = ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput(3600, 5, SOURCE_ID);
        inputs[1] = ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput(7200, 10, OTHER_SOURCE_ID);

        vm.expectEmit();
        emit ITeePaymentsFeeScheduleManager.FeeScheduleConfigsSet(inputs);

        vm.prank(governance);
        manager.setFeeScheduleConfigs(inputs);

        ITeePaymentsFeeScheduleManager.FeeScheduleConfig memory config =
            manager.getFeeScheduleConfig(SOURCE_ID);
        assertEq(config.maxSchedules, 5);
        assertEq(config.maxDelaySeconds, 3600);
        config = manager.getFeeScheduleConfig(OTHER_SOURCE_ID);
        assertEq(config.maxSchedules, 10);
        assertEq(config.maxDelaySeconds, 7200);
    }

    function testSetFeeScheduleConfigRevertOnlyGovernance() public {
        ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[] memory inputs =
            new ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[](1);
        inputs[0] = ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput(3600, 5, SOURCE_ID);
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        manager.setFeeScheduleConfigs(inputs);
    }

    function testSetFeeScheduleConfigRevertMaxSchedulesZero() public {
        ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[] memory inputs =
            new ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[](1);
        inputs[0] = ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput(3600, 0, SOURCE_ID);
        vm.prank(governance);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeePaymentsFeeScheduleManager.InvalidFeeScheduleConfig.selector, SOURCE_ID, uint8(0), uint16(3600)
            )
        );
        manager.setFeeScheduleConfigs(inputs);
    }

    function testSetFeeScheduleConfigRevertMaxDelayTooSmall() public {
        ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[] memory inputs =
            new ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[](1);
        // maxSchedules = 10, maxDelaySeconds = 3 -> can't fit 10 strictly-ascending delays in [0, 3]
        inputs[0] = ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput(3, 10, SOURCE_ID);
        vm.prank(governance);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeePaymentsFeeScheduleManager.InvalidFeeScheduleConfig.selector, SOURCE_ID, uint8(10), uint16(3)
            )
        );
        manager.setFeeScheduleConfigs(inputs);
    }

    function testSetFeeScheduleConfigAtBoundary() public {
        // maxSchedules - 1 == maxDelaySeconds (tight boundary, must pass)
        ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[] memory inputs =
            new ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[](1);
        inputs[0] = ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput(4, 5, SOURCE_ID);
        vm.prank(governance);
        manager.setFeeScheduleConfigs(inputs);
        ITeePaymentsFeeScheduleManager.FeeScheduleConfig memory config =
            manager.getFeeScheduleConfig(SOURCE_ID);
        assertEq(config.maxSchedules, 5);
        assertEq(config.maxDelaySeconds, 4);
    }

    function testSetFeeScheduleConfigRevertUnregisteredSource() public {
        bytes32 unregisteredSourceId = bytes32("UNKNOWN");
        ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[] memory inputs =
            new ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[](1);
        inputs[0] = ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput(3600, 5, unregisteredSourceId);
        vm.prank(governance);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeePaymentsFeeScheduleManager.UnsupportedSourceId.selector, unregisteredSourceId
            )
        );
        manager.setFeeScheduleConfigs(inputs);
    }

    //// clearFeeScheduleConfigs ////
    function testClearFeeScheduleConfig() public {
        _setConfig(SOURCE_ID, 5, 3600);
        _setConfig(OTHER_SOURCE_ID, 10, 600);

        bytes32[] memory sourceIds = new bytes32[](2);
        sourceIds[0] = SOURCE_ID;
        sourceIds[1] = OTHER_SOURCE_ID;

        vm.expectEmit();
        emit ITeePaymentsFeeScheduleManager.FeeScheduleConfigsCleared(sourceIds);
        vm.prank(governance);
        manager.clearFeeScheduleConfigs(sourceIds);

        assertEq(manager.getFeeScheduleConfig(SOURCE_ID).maxSchedules, 0);
        assertEq(manager.getFeeScheduleConfig(SOURCE_ID).maxDelaySeconds, 0);
        assertEq(manager.getFeeScheduleConfig(OTHER_SOURCE_ID).maxSchedules, 0);
    }

    function testClearFeeScheduleConfigWorksForUnregisteredSource() public {
        _setConfig(SOURCE_ID, 5, 3600);
        // Unregister the source in the Registry; clear must still succeed.
        bytes32[] memory remove = new bytes32[](1);
        remove[0] = SOURCE_ID;
        vm.prank(governance);
        registry.unregisterSources(remove);

        bytes32[] memory sourceIds = new bytes32[](1);
        sourceIds[0] = SOURCE_ID;
        vm.prank(governance);
        manager.clearFeeScheduleConfigs(sourceIds);
        assertEq(manager.getFeeScheduleConfig(SOURCE_ID).maxSchedules, 0);
    }

    function testClearFeeScheduleConfigRevertOnlyGovernance() public {
        bytes32[] memory sourceIds = new bytes32[](1);
        sourceIds[0] = SOURCE_ID;
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        manager.clearFeeScheduleConfigs(sourceIds);
    }

    function testClearFeeScheduleConfigRevertNotSet() public {
        bytes32[] memory sourceIds = new bytes32[](1);
        sourceIds[0] = SOURCE_ID;
        vm.prank(governance);
        vm.expectRevert(
            abi.encodeWithSelector(ITeePaymentsFeeScheduleManager.FeeScheduleConfigNotSet.selector, SOURCE_ID)
        );
        manager.clearFeeScheduleConfigs(sourceIds);
    }

    //// setProjectFeeSchedule ////
    function testSetProjectFeeSchedule() public {
        _setConfig(SOURCE_ID, 5, 3600);
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule =
            _makeSchedulePair(10000, 0, 5000, 1800);

        vm.expectEmit();
        emit ITeePaymentsFeeScheduleManager.ProjectFeeScheduleSet(PROJECT_ID, SOURCE_ID, schedule);
        vm.prank(projectOwner);
        manager.setProjectFeeSchedule(PROJECT_ID, SOURCE_ID, schedule);

        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory out =
            manager.getProjectFeeSchedule(PROJECT_ID, SOURCE_ID);
        assertEq(out.length, 2);
        assertEq(out[0].factorBIPS, 10000);
        assertEq(out[1].factorBIPS, 5000);
        assertEq(out[0].delaySeconds, 0);
        assertEq(out[1].delaySeconds, 1800);
    }

    function testSetProjectFeeScheduleRevertOnlyProjectOwner() public {
        _setConfig(SOURCE_ID, 5, 3600);
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule = _makeSchedule(10000, 0);
        vm.expectRevert(ITeePaymentsFeeScheduleManager.OnlyProjectOwner.selector);
        manager.setProjectFeeSchedule(PROJECT_ID, SOURCE_ID, schedule);
    }

    function testSetProjectFeeScheduleRevertUnknownSourceId() public {
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule = _makeSchedule(10000, 0);
        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ITeePaymentsFeeScheduleManager.SourceLimitsNotConfigured.selector, SOURCE_ID)
        );
        manager.setProjectFeeSchedule(PROJECT_ID, SOURCE_ID, schedule);
    }

    function testSetProjectFeeScheduleRevertTooManySchedules() public {
        _setConfig(SOURCE_ID, 1, 3600);
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule =
            _makeSchedulePair(10000, 0, 5000, 1800);
        vm.prank(projectOwner);
        vm.expectRevert(ITeePaymentsFeeScheduleManager.TooManySchedules.selector);
        manager.setProjectFeeSchedule(PROJECT_ID, SOURCE_ID, schedule);
    }

    function testSetProjectFeeScheduleRevertInvalidFactor() public {
        _setConfig(SOURCE_ID, 5, 3600);
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule = _makeSchedule(0, 0);
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(ITeePaymentsFeeScheduleManager.InvalidFeeFactor.selector, 0));
        manager.setProjectFeeSchedule(PROJECT_ID, SOURCE_ID, schedule);
    }

    function testSetProjectFeeScheduleRevertInvalidFactorTooHigh() public {
        _setConfig(SOURCE_ID, 5, 3600);
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule = _makeSchedule(10001, 0);
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(ITeePaymentsFeeScheduleManager.InvalidFeeFactor.selector, 0));
        manager.setProjectFeeSchedule(PROJECT_ID, SOURCE_ID, schedule);
    }

    function testSetProjectFeeScheduleRevertInvalidFactorTooLow() public {
        _setConfig(SOURCE_ID, 5, 3600);
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule = _makeSchedule(-10001, 0);
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(ITeePaymentsFeeScheduleManager.InvalidFeeFactor.selector, 0));
        manager.setProjectFeeSchedule(PROJECT_ID, SOURCE_ID, schedule);
    }

    function testSetProjectFeeScheduleRevertNonAscendingDelays() public {
        _setConfig(SOURCE_ID, 5, 3600);
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule =
            _makeSchedulePair(10000, 1800, 5000, 1800); // delays not ascending
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(ITeePaymentsFeeScheduleManager.InvalidFeeDelay.selector, 1));
        manager.setProjectFeeSchedule(PROJECT_ID, SOURCE_ID, schedule);
    }

    function testSetProjectFeeScheduleRevertDelayTooLarge() public {
        _setConfig(SOURCE_ID, 5, 3600);
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule = _makeSchedule(10000, 3601);
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(ITeePaymentsFeeScheduleManager.DelayTooLarge.selector, 3601, 3600));
        manager.setProjectFeeSchedule(PROJECT_ID, SOURCE_ID, schedule);
    }

    function testSetProjectFeeScheduleRevertEmpty() public {
        _setConfig(SOURCE_ID, 5, 3600);
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule =
            new ITeePaymentsFeeScheduleManager.FeeSchedule[](0);
        vm.prank(projectOwner);
        vm.expectRevert(ITeePaymentsFeeScheduleManager.EmptyScheduleNotAllowed.selector);
        manager.setProjectFeeSchedule(PROJECT_ID, SOURCE_ID, schedule);
    }

    //// clearProjectFeeSchedule ////
    function testClearProjectFeeSchedule() public {
        _setConfig(SOURCE_ID, 5, 3600);
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule = _makeSchedule(5000, 600);
        vm.prank(projectOwner);
        manager.setProjectFeeSchedule(PROJECT_ID, SOURCE_ID, schedule);

        vm.expectEmit();
        emit ITeePaymentsFeeScheduleManager.ProjectFeeScheduleCleared(PROJECT_ID, SOURCE_ID);
        vm.prank(projectOwner);
        manager.clearProjectFeeSchedule(PROJECT_ID, SOURCE_ID);

        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory out =
            manager.getProjectFeeSchedule(PROJECT_ID, SOURCE_ID);
        assertEq(out.length, 0);
    }

    function testClearProjectFeeScheduleRevertOnlyProjectOwner() public {
        vm.prank(otherUser);
        vm.expectRevert(ITeePaymentsFeeScheduleManager.OnlyProjectOwner.selector);
        manager.clearProjectFeeSchedule(PROJECT_ID, SOURCE_ID);
    }

    function testClearProjectFeeScheduleRevertNotSet() public {
        vm.prank(projectOwner);
        vm.expectRevert(ITeePaymentsFeeScheduleManager.FeeScheduleNotSet.selector);
        manager.clearProjectFeeSchedule(PROJECT_ID, SOURCE_ID);
    }

    //// setAccountFeeSchedule / clearAccountFeeSchedule ////
    function testSetAccountFeeSchedule() public {
        _setConfig(SOURCE_ID, 5, 3600);
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule = _makeSchedule(7500, 0);

        bytes32 accountHash = keccak256(abi.encode(SOURCE_ID, accountAddress));
        vm.expectEmit();
        emit ITeePaymentsFeeScheduleManager.AccountFeeScheduleSet(
            PROJECT_ID, SOURCE_ID, accountAddress, accountHash, schedule
        );
        vm.prank(projectOwner);
        manager.setAccountFeeSchedule(account, schedule);

        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory out =
            manager.getAccountFeeSchedule(account);
        assertEq(out.length, 1);
        assertEq(out[0].factorBIPS, 7500);
        assertEq(out[0].delaySeconds, 0);
    }

    function testSetAccountFeeScheduleRevertUnsupportedSourceId() public {
        _setConfig(SOURCE_ID, 5, 3600);
        // Unregister the SOURCE_ID so registry returns address(0)
        bytes32[] memory remove = new bytes32[](1);
        remove[0] = SOURCE_ID;
        vm.prank(governance);
        registry.unregisterSources(remove);

        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule = _makeSchedule(7500, 0);
        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ITeePaymentsFeeScheduleManager.UnsupportedSourceId.selector, SOURCE_ID)
        );
        manager.setAccountFeeSchedule(account, schedule);
    }

    function testSetAccountFeeScheduleRevertAccountNotRegistered() public {
        _setConfig(SOURCE_ID, 5, 3600);
        _mockGetWalletId(teePayments, bytes32(0));
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule = _makeSchedule(7500, 0);
        vm.prank(projectOwner);
        vm.expectRevert(ITeePaymentsFeeScheduleManager.AccountNotRegistered.selector);
        manager.setAccountFeeSchedule(account, schedule);
    }

    // SECURITY REGRESSION: Bob owns project B; Alice's account belongs to project A.
    // Bob must NOT be able to set a schedule for Alice's account.
    function testSetAccountFeeScheduleRevertNotProjectOwner() public {
        _setConfig(SOURCE_ID, 5, 3600);
        // account resolves to PROJECT_ID, owned by projectOwner (Alice).
        // otherUser (Bob) owns OTHER_PROJECT_ID.
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule = _makeSchedule(7500, 0);
        vm.prank(otherUser);
        vm.expectRevert(ITeePaymentsFeeScheduleManager.OnlyProjectOwner.selector);
        manager.setAccountFeeSchedule(account, schedule);
    }

    function testClearAccountFeeSchedule() public {
        testSetAccountFeeSchedule();
        bytes32 accountHash = keccak256(abi.encode(SOURCE_ID, accountAddress));
        vm.expectEmit();
        emit ITeePaymentsFeeScheduleManager.AccountFeeScheduleCleared(
            PROJECT_ID, SOURCE_ID, accountAddress, accountHash
        );
        vm.prank(projectOwner);
        manager.clearAccountFeeSchedule(account);

        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory out =
            manager.getAccountFeeSchedule(account);
        assertEq(out.length, 0);
    }

    function testClearAccountFeeScheduleRevertNotProjectOwner() public {
        vm.prank(otherUser);
        vm.expectRevert(ITeePaymentsFeeScheduleManager.OnlyProjectOwner.selector);
        manager.clearAccountFeeSchedule(account);
    }

    function testClearAccountFeeScheduleRevertNotSet() public {
        vm.prank(projectOwner);
        vm.expectRevert(ITeePaymentsFeeScheduleManager.FeeScheduleNotSet.selector);
        manager.clearAccountFeeSchedule(account);
    }

    function testSetAccountFeeScheduleRevertEmpty() public {
        _setConfig(SOURCE_ID, 5, 3600);
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule =
            new ITeePaymentsFeeScheduleManager.FeeSchedule[](0);
        vm.prank(projectOwner);
        vm.expectRevert(ITeePaymentsFeeScheduleManager.EmptyScheduleNotAllowed.selector);
        manager.setAccountFeeSchedule(account, schedule);
    }

    //// getEffectiveSchedule — precedence order ////
    function testGetEffectiveScheduleDefault() public {
        bytes32 accountHash = keccak256(abi.encode(SOURCE_ID, accountAddress));
        bytes memory schedule = manager.getEffectiveSchedule(PROJECT_ID, SOURCE_ID, accountHash);
        assertEq(schedule, hex"27100000");
    }

    function testGetEffectiveScheduleProject() public {
        _setConfig(SOURCE_ID, 5, 3600);
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule = _makeSchedule(5000, 600);
        vm.prank(projectOwner);
        manager.setProjectFeeSchedule(PROJECT_ID, SOURCE_ID, schedule);

        bytes32 accountHash = keccak256(abi.encode(SOURCE_ID, accountAddress));
        bytes memory result = manager.getEffectiveSchedule(PROJECT_ID, SOURCE_ID, accountHash);
        // factor 5000 = 0x1388, delay 600 = 0x0258
        assertEq(result, hex"13880258");
    }

    function testGetEffectiveSchedulePrecedence() public {
        _setConfig(SOURCE_ID, 5, 3600);
        // project schedule
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory projectSchedule = _makeSchedule(5000, 600);
        vm.prank(projectOwner);
        manager.setProjectFeeSchedule(PROJECT_ID, SOURCE_ID, projectSchedule);

        // account override
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory accountSchedule = _makeSchedule(8000, 1200);
        vm.prank(projectOwner);
        manager.setAccountFeeSchedule(account, accountSchedule);

        bytes32 accountHash = keccak256(abi.encode(SOURCE_ID, accountAddress));
        bytes memory result = manager.getEffectiveSchedule(PROJECT_ID, SOURCE_ID, accountHash);
        // factor 8000 = 0x1F40, delay 1200 = 0x04B0
        assertEq(result, hex"1F4004B0");
    }

    //// validateAndEncodeSchedules ////
    function testValidateAndEncodeSchedules() public {
        _setConfig(SOURCE_ID, 5, 3600);
        int16[][] memory factorsPerPayment = new int16[][](2);
        int16[] memory f0 = new int16[](2);
        f0[0] = 10000;
        f0[1] = 5000;
        int16[] memory f1 = new int16[](2);
        f1[0] = 8000;
        f1[1] = -5000;
        factorsPerPayment[0] = f0;
        factorsPerPayment[1] = f1;
        uint16[] memory delays = new uint16[](2);
        delays[0] = 0;
        delays[1] = 1800;

        bytes[] memory encoded =
            manager.validateAndEncodeSchedules(SOURCE_ID, factorsPerPayment, delays);
        assertEq(encoded.length, 2);
        // payment 0: factor 10000 = 0x2710, delay 0 = 0x0000, factor 5000 = 0x1388, delay 1800 = 0x0708
        assertEq(encoded[0], hex"2710000013880708");
        // payment 1: factor 8000 = 0x1F40, delay 0 = 0x0000, factor -5000 = 0xEC78, delay 1800 = 0x0708
        assertEq(encoded[1], hex"1F400000EC780708");
    }

    function testValidateAndEncodeSchedulesUnconfiguredAllowsSingleInvalidation() public {
        // Source not configured; reissue must still be able to invalidate via a single
        // zero-delay entry with a negative factor.
        int16[][] memory factorsPerPayment = new int16[][](1);
        int16[] memory f0 = new int16[](1);
        f0[0] = -10000;
        factorsPerPayment[0] = f0;
        uint16[] memory delays = new uint16[](1);
        delays[0] = 0;

        bytes[] memory encoded =
            manager.validateAndEncodeSchedules(SOURCE_ID, factorsPerPayment, delays);
        assertEq(encoded.length, 1);
        // factor -10000 = 0xD8F0, delay 0 = 0x0000
        assertEq(encoded[0], hex"D8F00000");
    }

    function testValidateAndEncodeSchedulesUnconfiguredRejectsMultipleEntries() public {
        int16[][] memory factorsPerPayment = new int16[][](1);
        int16[] memory f0 = new int16[](2);
        f0[0] = 10000;
        f0[1] = -5000;
        factorsPerPayment[0] = f0;
        uint16[] memory delays = new uint16[](2);
        delays[0] = 0;
        delays[1] = 1;
        vm.expectRevert(ITeePaymentsFeeScheduleManager.TooManySchedules.selector);
        manager.validateAndEncodeSchedules(SOURCE_ID, factorsPerPayment, delays);
    }

    function testValidateAndEncodeSchedulesUnconfiguredRejectsNonZeroDelay() public {
        int16[][] memory factorsPerPayment = new int16[][](1);
        int16[] memory f0 = new int16[](1);
        f0[0] = -10000;
        factorsPerPayment[0] = f0;
        uint16[] memory delays = new uint16[](1);
        delays[0] = 1;
        vm.expectRevert(abi.encodeWithSelector(ITeePaymentsFeeScheduleManager.DelayTooLarge.selector, 1, 0));
        manager.validateAndEncodeSchedules(SOURCE_ID, factorsPerPayment, delays);
    }

    function testValidateAndEncodeSchedulesRevertLengthsMismatch() public {
        _setConfig(SOURCE_ID, 5, 3600);
        int16[][] memory factorsPerPayment = new int16[][](1);
        int16[] memory f0 = new int16[](2);
        f0[0] = 10000;
        f0[1] = 5000;
        factorsPerPayment[0] = f0;
        uint16[] memory delays = new uint16[](1);
        delays[0] = 0;
        vm.expectRevert(ITeePaymentsFeeScheduleManager.LengthsMismatch.selector);
        manager.validateAndEncodeSchedules(SOURCE_ID, factorsPerPayment, delays);
    }

    function testValidateAndEncodeSchedulesRevertTooManySchedules() public {
        _setConfig(SOURCE_ID, 1, 3600);
        int16[][] memory factorsPerPayment = new int16[][](1);
        int16[] memory f0 = new int16[](2);
        f0[0] = 10000;
        f0[1] = 5000;
        factorsPerPayment[0] = f0;
        uint16[] memory delays = new uint16[](2);
        delays[0] = 0;
        delays[1] = 1800;
        vm.expectRevert(ITeePaymentsFeeScheduleManager.TooManySchedules.selector);
        manager.validateAndEncodeSchedules(SOURCE_ID, factorsPerPayment, delays);
    }

    function testValidateAndEncodeSchedulesRevertNonAscendingDelays() public {
        _setConfig(SOURCE_ID, 5, 3600);
        int16[][] memory factorsPerPayment = new int16[][](1);
        int16[] memory f0 = new int16[](2);
        f0[0] = 10000;
        f0[1] = 5000;
        factorsPerPayment[0] = f0;
        uint16[] memory delays = new uint16[](2);
        delays[0] = 1800;
        delays[1] = 1800;
        vm.expectRevert(abi.encodeWithSelector(ITeePaymentsFeeScheduleManager.InvalidFeeDelay.selector, 1));
        manager.validateAndEncodeSchedules(SOURCE_ID, factorsPerPayment, delays);
    }

    function testValidateAndEncodeSchedulesRevertDelayTooLarge() public {
        _setConfig(SOURCE_ID, 5, 3600);
        int16[][] memory factorsPerPayment = new int16[][](1);
        int16[] memory f0 = new int16[](1);
        f0[0] = 10000;
        factorsPerPayment[0] = f0;
        uint16[] memory delays = new uint16[](1);
        delays[0] = 3601;
        vm.expectRevert(abi.encodeWithSelector(ITeePaymentsFeeScheduleManager.DelayTooLarge.selector, 3601, 3600));
        manager.validateAndEncodeSchedules(SOURCE_ID, factorsPerPayment, delays);
    }

    function testValidateAndEncodeSchedulesRevertInvalidFactor() public {
        _setConfig(SOURCE_ID, 5, 3600);
        int16[][] memory factorsPerPayment = new int16[][](1);
        int16[] memory f0 = new int16[](1);
        f0[0] = 10001;
        factorsPerPayment[0] = f0;
        uint16[] memory delays = new uint16[](1);
        delays[0] = 0;
        vm.expectRevert(abi.encodeWithSelector(ITeePaymentsFeeScheduleManager.InvalidFeeFactor.selector, 0));
        manager.validateAndEncodeSchedules(SOURCE_ID, factorsPerPayment, delays);
    }

    //// Upgrade ////
    function testUpgradeProxy() public {
        assertEq(manager.implementation(), address(managerImpl));
        TeePaymentsFeeScheduleManager newImpl = new TeePaymentsFeeScheduleManager();
        vm.prank(governance);
        manager.upgradeToAndCall(address(newImpl), bytes(""));
        assertEq(manager.implementation(), address(newImpl));
    }

    function testUpgradeProxyRevertOnlyGovernance() public {
        TeePaymentsFeeScheduleManager newImpl = new TeePaymentsFeeScheduleManager();
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        manager.upgradeToAndCall(address(newImpl), bytes(""));
    }

    //// Helpers ////
    function _setConfig(bytes32 _sourceId, uint8 _maxSchedules, uint16 _maxDelaySeconds) internal {
        ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[] memory inputs =
            new ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[](1);
        inputs[0] = ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput(
            _maxDelaySeconds, _maxSchedules, _sourceId
        );
        vm.prank(governance);
        manager.setFeeScheduleConfigs(inputs);
    }

    function _mockGetOwner(bytes32 _projectId, address _owner) internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IWalletProjectManager.getOwner.selector, _projectId),
            abi.encode(_owner)
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

    function _makeSchedule(
        int16 _factor,
        uint16 _delay
    )
        internal pure
        returns (ITeePaymentsFeeScheduleManager.FeeSchedule[] memory)
    {
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule =
            new ITeePaymentsFeeScheduleManager.FeeSchedule[](1);
        schedule[0] = ITeePaymentsFeeScheduleManager.FeeSchedule({
            factorBIPS: _factor,
            delaySeconds: _delay
        });
        return schedule;
    }

    function _makeSchedulePair(
        int16 _f0,
        uint16 _d0,
        int16 _f1,
        uint16 _d1
    )
        internal pure
        returns (ITeePaymentsFeeScheduleManager.FeeSchedule[] memory)
    {
        ITeePaymentsFeeScheduleManager.FeeSchedule[] memory schedule =
            new ITeePaymentsFeeScheduleManager.FeeSchedule[](2);
        schedule[0] = ITeePaymentsFeeScheduleManager.FeeSchedule({
            factorBIPS: _f0,
            delaySeconds: _d0
        });
        schedule[1] = ITeePaymentsFeeScheduleManager.FeeSchedule({
            factorBIPS: _f1,
            delaySeconds: _d1
        });
        return schedule;
    }
}
