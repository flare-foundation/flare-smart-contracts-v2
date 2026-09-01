// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { stdError } from "forge-std/StdError.sol";
import { Vm } from "forge-std/Vm.sol";
import {
    TeeOracleInstructionsSender
} from "../../../../../../contracts/tee/extensions/oracle/implementation/TeeOracleInstructionsSender.sol";
import {
    TeeOracleInstructionsSenderProxy
} from "../../../../../../contracts/tee/extensions/oracle/proxy/TeeOracleInstructionsSenderProxy.sol";
import {
    ITeeOracleInstructionsSender,
    TEE_ORACLE_OP_TYPE,
    GET_FEED_COMMAND,
    SET_ENDPOINTS_COMMAND,
    SET_ADMINS_COMMAND
} from "../../../../../../contracts/userInterfaces/tee/ITeeOracleInstructionsSender.sol";
import { IInstructions } from "../../../../../../contracts/userInterfaces/tee/IInstructions.sol";
import { IMachineManager } from "../../../../../../contracts/userInterfaces/tee/IMachineManager.sol";
import {
    ITeeCommonErrors
} from "../../../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import {
    IMachineEmergencyPause
} from "../../../../../../contracts/userInterfaces/tee/IMachineEmergencyPause.sol";
import { IOperationFees } from "../../../../../../contracts/userInterfaces/tee/IOperationFees.sol";
import { IFlareGovernance } from "../../../../../../contracts/userInterfaces/IFlareGovernance.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract TeeOracleInstructionsSenderTest is Test {

    uint256 private constant EXTENSION_ID = 1;
    bytes21 private constant FEED_ID = bytes21(bytes.concat(bytes1(uint8(0x20)), bytes("USDX/USD")));
    bytes21 private constant OTHER_FEED_ID = bytes21(bytes.concat(bytes1(uint8(0x21)), bytes("RAIN/MM")));
    bytes32 private constant INSTRUCTION_ID = keccak256("instructionId");
    uint256 private constant TIMELOCK = 3600;

    TeeOracleInstructionsSender private sender;
    TeeOracleInstructionsSender private senderImpl;

    address private governance;
    address private productionGovernance;
    address private executor;
    address private claimBack;
    address private addressUpdater;
    address private flareTeeManager;
    address private teeId1;
    address private teeId2;
    IGovernanceSettings private governanceSettings;

    function setUp() public {
        vm.warp(1_700_000_000);

        governance = makeAddr("governance");
        productionGovernance = makeAddr("productionGovernance");
        executor = makeAddr("executor");
        // a publication names its claim-back destination explicitly - deliberately neither the
        // governance address nor the executor, so the tests prove the ARGUMENT is what is used
        claimBack = makeAddr("claimBack");
        addressUpdater = makeAddr("addressUpdater");
        teeId1 = makeAddr("teeId1");
        teeId2 = makeAddr("teeId2");
        governanceSettings = IGovernanceSettings(makeAddr("governanceSettings"));

        senderImpl = new TeeOracleInstructionsSender();
        TeeOracleInstructionsSenderProxy proxy = new TeeOracleInstructionsSenderProxy(
            governanceSettings,
            governance,
            addressUpdater,
            EXTENSION_ID,
            address(senderImpl)
        );
        sender = TeeOracleInstructionsSender(address(proxy));

        bytes32[] memory contractNameHashes = new bytes32[](2);
        address[] memory contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareTeeManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("FlareTeeManager");
        vm.prank(addressUpdater);
        sender.updateContractAddresses(contractNameHashes, contractAddresses);

        flareTeeManager = address(sender.flareTeeManager());

        _mockSendInstructions();
        _mockGetExtensionId(teeId1, EXTENSION_ID);
        _mockGetExtensionId(teeId2, EXTENSION_ID);
        _mockGetTeeMachineStatus(teeId1, IMachineManager.TeeStatus.PRODUCTION);
        _mockGetTeeMachineStatus(teeId2, IMachineManager.TeeStatus.PRODUCTION);
        _mockGetActiveTeeMachines(_bothTees());
        _mockCalculateFeeDefault(0);
        _mockEmergencyPaused(false);
    }

    // -------------------------------------------------------------------------
    // initialization
    // -------------------------------------------------------------------------

    function testInitialState() public {
        assertEq(sender.extensionId(), EXTENSION_ID);
        assertEq(sender.endpointsVersion(FEED_ID), 0);
        assertEq(sender.adminsVersion(FEED_ID), 0);
        assertEq(sender.latestEndpointsHash(FEED_ID), bytes32(0));
        assertEq(sender.latestAdminsHash(FEED_ID), bytes32(0));
        assertEq(sender.governance(), governance);
        assertEq(sender.implementation(), address(senderImpl));
    }

    function testInitializeEmitsEvent() public {
        vm.expectEmit();
        emit ITeeOracleInstructionsSender.InstructionsSenderInitialised(EXTENSION_ID);
        new TeeOracleInstructionsSenderProxy(
            governanceSettings,
            governance,
            addressUpdater,
            EXTENSION_ID,
            address(senderImpl)
        );
    }

    function testInitializeRevertInvalidExtensionId() public {
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidExtensionId.selector);
        new TeeOracleInstructionsSenderProxy(
            governanceSettings,
            governance,
            addressUpdater,
            0,
            address(senderImpl)
        );
    }

    function testReinitializeReverts() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        sender.initialize(governanceSettings, governance, addressUpdater, EXTENSION_ID);
    }

    function testImplementationCannotBeInitialized() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        senderImpl.initialize(governanceSettings, governance, addressUpdater, EXTENSION_ID);
    }

    // -------------------------------------------------------------------------
    // setEndpoints / setAdmins - publication plus auto-dispatch
    // -------------------------------------------------------------------------

    function testSetEndpoints() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(2, 3);
        bytes memory message = _endpointsMessage(groups, 1);
        bytes32 endpointsHash = keccak256(message);

        // the publication event carries the published GROUPS in full - nothing stores them, so
        // this log is where a pusher reads them from, and what it carries is exactly what the push
        // takes back
        vm.expectEmit();
        emit ITeeOracleInstructionsSender.EndpointsPublished(FEED_ID, 1, endpointsHash, groups);
        vm.expectEmit();
        emit ITeeOracleInstructionsSender.EndpointsSet(FEED_ID, teeId1, 1, endpointsHash);
        vm.expectEmit();
        emit ITeeOracleInstructionsSender.EndpointsSet(FEED_ID, teeId2, 1, endpointsHash);
        // the publication dispatches to the LIVE active set, read inside the body, with the
        // claim-back address governance NAMED (the executed body's msg.sender is the contract,
        // so the payer cannot be identified on chain and has to be stated)
        vm.expectCall(
            flareTeeManager,
            0,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (_bothTees(), _params(SET_ENDPOINTS_COMMAND, message, claimBack))
            )
        );
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);

        assertEq(sender.endpointsVersion(FEED_ID), 1);
        assertEq(sender.latestEndpointsHash(FEED_ID), endpointsHash);
        assertEq(sender.endpointsPublishedAt(FEED_ID), uint64(vm.getBlockTimestamp()));
        // one version and hash per publication, shared by every machine dispatched to
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 1);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId2), 1);
        // the fleet has converged in the publishing transaction: nothing left to push
        assertEq(sender.getEndpointsPushTargets(FEED_ID).length, 0);
    }

    function testSetAdmins() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(2, 3);
        bytes memory message = _adminsMessage(roles, 1);
        bytes32 adminsHash = keccak256(message);

        vm.expectEmit();
        emit ITeeOracleInstructionsSender.AdminsPublished(FEED_ID, 1, adminsHash, roles);
        vm.expectEmit();
        emit ITeeOracleInstructionsSender.AdminsSet(FEED_ID, teeId1, 1, adminsHash);
        vm.expectCall(
            flareTeeManager,
            0,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (_bothTees(), _params(SET_ADMINS_COMMAND, message, claimBack))
            )
        );
        vm.prank(governance);
        sender.setAdmins(FEED_ID, roles, claimBack);

        assertEq(sender.adminsVersion(FEED_ID), 1);
        assertEq(sender.latestAdminsHash(FEED_ID), adminsHash);
        assertEq(sender.adminsPublishedAt(FEED_ID), uint64(vm.getBlockTimestamp()));
        assertEq(sender.expectedAdminsVersion(FEED_ID, teeId1), 1);
        // endpoints and admins version independently
        assertEq(sender.endpointsVersion(FEED_ID), 0);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 0);
    }

    function testSetEndpointsDispatchesTheWholeActiveSetUnfiltered() public {
        // the diamond's active set IS the extension's PRODUCTION machines - it is written only on
        // the transition to PRODUCTION and cleared on PAUSED / SUSPENDED / BANNED - so the
        // publication dispatches it verbatim and applies no predicate of its own. Per-machine
        // status and extension reads are therefore never made: mocking them to values that a
        // filter would have rejected changes nothing.
        _mockGetExtensionId(teeId2, EXTENSION_ID + 1);
        _mockGetTeeMachineStatus(teeId2, IMachineManager.TeeStatus.SUSPENDED);
        vm.expectCall(
            flareTeeManager,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (
                    _bothTees(),
                    _params(SET_ENDPOINTS_COMMAND, _endpointsMessage(_makeGroups(1, 1), 1), claimBack)
                )
            )
        );
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, _makeGroups(1, 1), claimBack);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 1);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId2), 1);
    }

    function testSetEndpointsSkipsDispatchWithNoActiveMachines() public {
        // no machine exists on the extension at all - the publication must still succeed and
        // must not dispatch anything
        _mockGetActiveTeeMachines(new address[](0));
        _mockSendInstructionsRevert();
        _publishFeed(FEED_ID);
        assertEq(sender.endpointsVersion(FEED_ID), 1);
        assertEq(sender.adminsVersion(FEED_ID), 1);
        assertEq(sender.getFeedIds().length, 1);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 0);
    }

    function testSetEndpointsSkipsDispatchWhileEmergencyPaused() public {
        // the diamond refuses every dispatch during an emergency pause; a publication must
        // degrade to "published, push later" rather than fail the governance execution - a
        // corrected configuration has to be landable while paused, since the pause may exist
        // BECAUSE the published configuration is wrong
        _mockEmergencyPaused(true);
        _mockSendInstructionsRevert();
        // the pause is checked BEFORE the active set is read: getActiveTeeMachines is an
        // unpaginated diamond call that also builds a string[] of machine URLs this contract
        // throws away, so a paused publication must not pay for it. Making that call revert is
        // how the ordering is asserted.
        _mockGetActiveTeeMachinesRevert();
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, _makeGroups(1, 1), claimBack);
        assertEq(sender.endpointsVersion(FEED_ID), 1);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 0);
        // and the fleet is pushable the moment the pause is lifted
        _mockEmergencyPaused(false);
        _mockSendInstructions();
        _mockGetActiveTeeMachines(_bothTees());
        assertEq(sender.getEndpointsPushTargets(FEED_ID).length, 2);
    }

    function testSetAdminsSkipsDispatchWhileEmergencyPausedBeforeReadingTheActiveSet() public {
        // same ordering on the admins publication
        _mockEmergencyPaused(true);
        _mockSendInstructionsRevert();
        _mockGetActiveTeeMachinesRevert();
        vm.prank(governance);
        sender.setAdmins(FEED_ID, _makeRoles(1, 1), claimBack);
        assertEq(sender.adminsVersion(FEED_ID), 1);
        assertEq(sender.expectedAdminsVersion(FEED_ID, teeId1), 0);
    }

    function testSetEndpointsRevertsWhenTheDiamondRejectsAShortFee() public {
        // a short fee is the executor's to fix, so it is NOT swallowed - but the gate is the
        // diamond's own floor (Instructions: calculatedFee <= msg.value), not a sender-side check:
        // the value is forwarded verbatim and FeeTooLow bubbles, rolling the publication back
        _mockSendInstructionsRevertWith(IInstructions.FeeTooLow.selector);
        vm.deal(governance, 9);
        vm.expectRevert(IInstructions.FeeTooLow.selector);
        vm.prank(governance);
        sender.setEndpoints{value: 9}(FEED_ID, _makeGroups(1, 1), claimBack);
        assertEq(sender.endpointsVersion(FEED_ID), 0, "nothing published");
        assertEq(governance.balance, 9, "value never left the executor");
    }

    function testSetEndpointsForwardsASurplusToTheDiamond() public {
        // accepted, not prevented: the diamond enforces only a floor and hands the WHOLE value to
        // receiveRewards in the same transaction, keeping no balance, so a surplus cannot be
        // separated from the fee afterwards: on chain it is simply part of that epoch's rewards.
        // The claim-back address is only RECORDED in the event, for the off-chain reward
        // calculation; no contract here returns anything
        _mockCalculateFee(SET_ENDPOINTS_COMMAND, _bothTees(), 10);
        (, uint256 quotedFee) = sender.getEndpointsPublicationFee();
        assertEq(quotedFee, 10);
        vm.deal(governance, quotedFee + 1);
        vm.expectCall(
            flareTeeManager,
            11,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (
                    _bothTees(),
                    _params(SET_ENDPOINTS_COMMAND, _endpointsMessage(_makeGroups(1, 1), 1), claimBack)
                )
            )
        );
        vm.prank(governance);
        sender.setEndpoints{value: quotedFee + 1}(FEED_ID, _makeGroups(1, 1), claimBack);
        assertEq(sender.endpointsVersion(FEED_ID), 1, "published");
        assertEq(governance.balance, 0, "the whole value, surplus included, left the executor");
    }

    function testSetAdminsOverpaysWhenTheFleetShrinksAfterTheFeeQuote() public {
        // L-01, accepted rather than fixed: the fee views quote the fleet as it stands when they
        // are READ, while the targets are snapshotted when the timelocked call EXECUTES. A machine
        // paused in between makes the quoted value an overpayment - the publication still goes
        // through and the surplus joins the reward pool, which is why the view must be read in the
        // block the execution lands in
        _mockCalculateFee(SET_ADMINS_COMMAND, _bothTees(), 2000);
        _mockCalculateFee(SET_ADMINS_COMMAND, _onlySecondTee(), 1000);
        (address[] memory quotedTargets, uint256 quotedFee) = sender.getAdminsPublicationFee();
        assertEq(quotedTargets.length, 2);
        assertEq(quotedFee, 2000);

        // teeId1 leaves PRODUCTION, so it leaves the extension's active set: the stale quote is
        // twice the fee of the one machine actually dispatched to, and all of it is forwarded
        _mockGetActiveTeeMachines(_onlySecondTee());
        vm.deal(governance, 2000);
        vm.expectCall(
            flareTeeManager,
            2000,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (
                    _onlySecondTee(),
                    _params(SET_ADMINS_COMMAND, _adminsMessage(_makeRoles(1, 1), 1), claimBack)
                )
            )
        );
        vm.prank(governance);
        sender.setAdmins{value: quotedFee}(FEED_ID, _makeRoles(1, 1), claimBack);
        assertEq(sender.adminsVersion(FEED_ID), 1, "published");
        assertEq(sender.expectedAdminsVersion(FEED_ID, teeId2), 1);
        assertEq(sender.expectedAdminsVersion(FEED_ID, teeId1), 0, "not a target any more");
        assertEq(governance.balance, 0, "the 1000 surplus went out with the fee");
    }

    function testSetEndpointsNeverPricesTheDispatchItself() public {
        // the sender does no fee arithmetic on the publication path at all - the diamond's floor
        // is the only fee gate - so making calculateFeeByTeeIds revert cannot break a publication,
        // dispatching or skipped
        _mockCalculateFeeRevert();
        vm.deal(governance, 10);
        vm.prank(governance);
        sender.setEndpoints{value: 10}(FEED_ID, _makeGroups(1, 1), claimBack);
        assertEq(sender.endpointsVersion(FEED_ID), 1);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 1);

        // and the two skip conditions publish without pricing anything either
        _mockGetActiveTeeMachines(new address[](0));
        _mockSendInstructionsRevert();
        vm.prank(governance);
        sender.setAdmins(FEED_ID, _makeRoles(1, 1), claimBack);
        assertEq(sender.adminsVersion(FEED_ID), 1);
    }

    function testSetEndpointsRevertsWhenNotRegisteredInstructionsSender() public {
        // the diamond only accepts a dispatch from the extension's registered sender; a lost
        // registration is a deployment mistake and must surface, not be silently skipped
        _mockSendInstructionsRevertWith(IInstructions.OnlyInstructionsSender.selector);
        vm.expectRevert(IInstructions.OnlyInstructionsSender.selector);
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, _makeGroups(1, 1), claimBack);
        assertEq(sender.endpointsVersion(FEED_ID), 0);
    }

    function testSetEndpointsRevertValueNotNeededWithNoActiveMachines() public {
        // a skipped dispatch creates NO instruction, so there is no fee to attach and nothing
        // would even record a payer (the executed body's msg.sender is the contract and the
        // governance library does not record the executor) - so value must not be attached
        _mockGetActiveTeeMachines(new address[](0));
        vm.deal(governance, 77);
        vm.expectRevert(ITeeOracleInstructionsSender.ValueNotNeeded.selector);
        vm.prank(governance);
        sender.setEndpoints{value: 77}(FEED_ID, _makeGroups(1, 1), claimBack);
        assertEq(governance.balance, 77, "value never left the executor");
        assertEq(address(sender).balance, 0, "nothing trapped here");
    }

    function testSetAdminsRevertValueNotNeededWhileEmergencyPaused() public {
        _mockEmergencyPaused(true);
        _mockGetActiveTeeMachinesRevert();
        vm.deal(governance, 5);
        vm.expectRevert(ITeeOracleInstructionsSender.ValueNotNeeded.selector);
        vm.prank(governance);
        sender.setAdmins{value: 5}(FEED_ID, _makeRoles(1, 1), claimBack);
        assertEq(governance.balance, 5);
        // re-executing with nothing attached publishes
        vm.prank(governance);
        sender.setAdmins(FEED_ID, _makeRoles(1, 1), claimBack);
        assertEq(sender.adminsVersion(FEED_ID), 1);
    }

    function testSetEndpointsForwardsTheWholeValueOnDispatch() public {
        // on the dispatch path the whole msg.value goes to the diamond, which checks it against
        // its own fee floor and forwards all of it to the reward manager
        vm.deal(governance, 10);
        vm.expectCall(
            flareTeeManager,
            10,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (
                    _bothTees(),
                    _params(SET_ENDPOINTS_COMMAND, _endpointsMessage(_makeGroups(1, 1), 1), claimBack)
                )
            )
        );
        vm.prank(governance);
        sender.setEndpoints{value: 10}(FEED_ID, _makeGroups(1, 1), claimBack);
        assertEq(governance.balance, 0, "the whole value leaves on the dispatch path");
    }

    function testSetEndpointsPerFeedIsolation() public {
        // versions and hashes are independent per feed
        vm.startPrank(governance);
        sender.setEndpoints(FEED_ID, _makeGroups(1, 1), claimBack);
        sender.setEndpoints(OTHER_FEED_ID, _makeGroups(1, 2), claimBack);
        vm.stopPrank();
        assertEq(sender.endpointsVersion(FEED_ID), 1);
        assertEq(sender.endpointsVersion(OTHER_FEED_ID), 1);
        assertNotEq(
            sender.latestEndpointsHash(FEED_ID),
            sender.latestEndpointsHash(OTHER_FEED_ID)
        );
    }

    function testSetEndpointsRevertInvalidFeedId() public {
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidFeedId.selector);
        vm.prank(governance);
        sender.setEndpoints(bytes21(0), _makeGroups(1, 1), claimBack);
    }

    function testSetEndpointsIdenticalContentGetsNewVersionAndHash() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        vm.startPrank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);
        bytes32 firstHash = sender.latestEndpointsHash(FEED_ID);
        sender.setEndpoints(FEED_ID, groups, claimBack);
        vm.stopPrank();
        assertEq(sender.endpointsVersion(FEED_ID), 2);
        // the version is inside the encoded payload, so the hash moves too
        assertNotEq(sender.latestEndpointsHash(FEED_ID), firstHash);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 2);
    }

    function testSetEndpointsVersionIsMonotonic() public {
        vm.startPrank(governance);
        for (uint64 i = 1; i <= 5; i++) {
            sender.setEndpoints(FEED_ID, _makeGroups(1, 1), claimBack);
            assertEq(sender.endpointsVersion(FEED_ID), i);
            sender.setAdmins(FEED_ID, _makeRoles(1, 1), claimBack);
            assertEq(sender.adminsVersion(FEED_ID), i);
        }
        vm.stopPrank();
    }

    /// Ordering between two pending publications is a GOVERNANCE responsibility, not something the
    /// contract enforces: the version is derived when the call executes, so of two publications
    /// pending for one feed the one executed LAST wins, whichever was proposed first. This pins
    /// that behaviour so it cannot change silently — governance must cancel a superseded call.
    function testSetEndpointsLastExecutionWins() public {
        _switchToProduction();
        ITeeOracleInstructionsSender.EndpointGroup[] memory first = _makeGroups(1, 1);
        ITeeOracleInstructionsSender.EndpointGroup[] memory second = _makeGroups(2, 1);
        bytes memory callA = abi.encodeCall(sender.setEndpoints, (FEED_ID, first, claimBack));
        bytes memory callB = abi.encodeCall(sender.setEndpoints, (FEED_ID, second, claimBack));

        // both recorded, distinct calldata so both are independently executable
        vm.startPrank(productionGovernance);
        (bool okA,) = address(sender).call(callA);
        (bool okB,) = address(sender).call(callB);
        vm.stopPrank();
        assertTrue(okA && okB);
        vm.warp(vm.getBlockTimestamp() + TIMELOCK + 1);

        // B executes first and takes version 1 ...
        vm.prank(executor);
        sender.executeGovernanceCall(callB);
        assertEq(sender.endpointsVersion(FEED_ID), 1);
        assertEq(
            sender.latestEndpointsHash(FEED_ID),
            keccak256(abi.encode(
                ITeeOracleInstructionsSender.Endpoints({version: 1, feedId: FEED_ID, groups: second})))
        );

        // ... and the OLDER call, executed afterwards, still succeeds and takes version 2
        vm.prank(executor);
        sender.executeGovernanceCall(callA);
        assertEq(sender.endpointsVersion(FEED_ID), 2);
        assertEq(
            sender.latestEndpointsHash(FEED_ID),
            keccak256(abi.encode(
                ITeeOracleInstructionsSender.Endpoints({version: 2, feedId: FEED_ID, groups: first}))),
            "the superseded publication becomes the feed's configuration - cancel it instead"
        );
    }

    function testSetEndpointsAtMaxVersionFailsSafely() public {
        // at type(uint64).max the checked increment reverts instead of wrapping round to a version
        // machines already hold
        _setStoredVersions(FEED_ID, type(uint64).max, type(uint64).max);
        assertEq(sender.endpointsVersion(FEED_ID), type(uint64).max, "slot derivation");
        assertEq(sender.adminsVersion(FEED_ID), type(uint64).max);
        _mockSendInstructionsRevert();

        vm.startPrank(governance);
        vm.expectRevert(stdError.arithmeticError);
        sender.setEndpoints(FEED_ID, _makeGroups(1, 1), claimBack);
        vm.expectRevert(stdError.arithmeticError);
        sender.setAdmins(FEED_ID, _makeRoles(1, 1), claimBack);
        vm.stopPrank();
        assertEq(sender.endpointsVersion(FEED_ID), type(uint64).max, "unchanged");
        assertEq(sender.latestEndpointsHash(FEED_ID), bytes32(0), "nothing published");
    }

    function testSetEndpointsRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        sender.setEndpoints(FEED_ID, _makeGroups(1, 1), claimBack);
    }

    function testSetAdminsRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        sender.setAdmins(FEED_ID, _makeRoles(1, 1), claimBack);
    }

    function testSetAdminsRevertInvalidFeedId() public {
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidFeedId.selector);
        vm.prank(governance);
        sender.setAdmins(bytes21(0), _makeRoles(1, 1), claimBack);
    }

    function testSetEndpointsAndSetAdminsUseTheNamedClaimBackAddress() public {
        // the claim-back address is the ARGUMENT, not the governance address and not the caller:
        // inside a timelocked body msg.sender is this contract and FlareGovernance does not
        // record who called executeGovernanceCall, so whoever funds the execution must be named
        address funder = makeAddr("publicationFunder");
        assertNotEq(funder, governance);
        assertNotEq(funder, address(this));

        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        vm.expectCall(
            flareTeeManager,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (_bothTees(), _params(SET_ENDPOINTS_COMMAND, _endpointsMessage(groups, 1), funder))
            )
        );
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, funder);

        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(1, 1);
        bytes memory adminsMessage = abi.encode(
            ITeeOracleInstructionsSender.Admins({version: 1, feedId: FEED_ID, roles: roles})
        );
        vm.expectCall(
            flareTeeManager,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (_bothTees(), _params(SET_ADMINS_COMMAND, adminsMessage, funder))
            )
        );
        vm.prank(governance);
        sender.setAdmins(FEED_ID, roles, funder);
    }

    function testRevertSetEndpointsZeroClaimBackAddress() public {
        // the diamond emits the claim-back address unvalidated, so a zero would silently leave
        // the off-chain reward calculation with no payer on record - and nothing is published
        vm.expectRevert(ITeeOracleInstructionsSender.ZeroClaimBackAddress.selector);
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, _makeGroups(1, 1), address(0));
        assertEq(sender.endpointsVersion(FEED_ID), 0);
        assertEq(sender.latestEndpointsHash(FEED_ID), bytes32(0));
    }

    function testRevertSetAdminsZeroClaimBackAddress() public {
        vm.expectRevert(ITeeOracleInstructionsSender.ZeroClaimBackAddress.selector);
        vm.prank(governance);
        sender.setAdmins(FEED_ID, _makeRoles(1, 1), address(0));
        assertEq(sender.adminsVersion(FEED_ID), 0);
        assertEq(sender.latestAdminsHash(FEED_ID), bytes32(0));
    }

    // -------------------------------------------------------------------------
    // payload validation (publication)
    // -------------------------------------------------------------------------

    function testSetEndpointsRevertNoGroups() public {
        vm.expectRevert(ITeeOracleInstructionsSender.NoGroups.selector);
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, new ITeeOracleInstructionsSender.EndpointGroup[](0), claimBack);
    }

    function testSetEndpointsRevertEmptyGroup() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        groups[0].group = bytes32(0);
        vm.expectRevert(ITeeOracleInstructionsSender.EmptyGroup.selector);
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);
    }

    function testSetEndpointsRevertDuplicateGroup() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(2, 1);
        groups[1].group = groups[0].group;
        vm.expectRevert(ITeeOracleInstructionsSender.DuplicateGroup.selector);
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);
    }

    function testSetEndpointsRevertNoEndpoints() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        groups[0].endpoints = new ITeeOracleInstructionsSender.Endpoint[](0);
        vm.expectRevert(ITeeOracleInstructionsSender.NoEndpoints.selector);
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);
    }

    function testSetEndpointsRevertZeroThreshold() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 2);
        groups[0].threshold = 0;
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidThreshold.selector);
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);
    }

    function testSetEndpointsRevertThresholdAboveEndpointCount() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 2);
        groups[0].threshold = 3;
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidThreshold.selector);
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);
    }

    function testSetEndpointsRevertPublicEndpointWithoutUrl() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        groups[0].endpoints[0].url = "";
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidEndpoint.selector);
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);
    }

    function testSetEndpointsRevertPublicEndpointWithUrlHash() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        groups[0].endpoints[0].urlHash = keccak256("hash");
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidEndpoint.selector);
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);
    }

    function testSetEndpointsRevertPrivateEndpointWithUrl() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        groups[0].endpoints[0].kind = ITeeOracleInstructionsSender.EndpointKind.PRIVATE;
        groups[0].endpoints[0].urlHash = keccak256("hash");
        // url still set - inconsistent
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidEndpoint.selector);
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);
    }

    function testSetEndpointsRevertPrivateEndpointWithoutUrlHash() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        groups[0].endpoints[0].kind = ITeeOracleInstructionsSender.EndpointKind.PRIVATE;
        groups[0].endpoints[0].url = "";
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidEndpoint.selector);
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);
    }

    function testSetEndpointsAcceptsPrivateEndpoint() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        groups[0].endpoints[0] = ITeeOracleInstructionsSender.Endpoint({
            kind: ITeeOracleInstructionsSender.EndpointKind.PRIVATE,
            url: "",
            urlHash: keccak256("salted private url"),
            secretRef: "hex_cash_url"
        });
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);
        assertEq(sender.endpointsVersion(FEED_ID), 1);
    }

    function testSetAdminsRevertNoRoles() public {
        vm.expectRevert(ITeeOracleInstructionsSender.NoRoles.selector);
        vm.prank(governance);
        sender.setAdmins(FEED_ID, new ITeeOracleInstructionsSender.AdminRole[](0), claimBack);
    }

    function testSetAdminsRevertEmptyRole() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(1, 1);
        roles[0].role = bytes32(0);
        vm.expectRevert(ITeeOracleInstructionsSender.EmptyRole.selector);
        vm.prank(governance);
        sender.setAdmins(FEED_ID, roles, claimBack);
    }

    function testSetAdminsRevertDuplicateRole() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(2, 1);
        roles[1].role = roles[0].role;
        vm.expectRevert(ITeeOracleInstructionsSender.DuplicateRole.selector);
        vm.prank(governance);
        sender.setAdmins(FEED_ID, roles, claimBack);
    }

    function testSetAdminsRevertNoAdmins() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(1, 1);
        roles[0].admins = new address[](0);
        vm.expectRevert(ITeeOracleInstructionsSender.NoAdmins.selector);
        vm.prank(governance);
        sender.setAdmins(FEED_ID, roles, claimBack);
    }

    function testSetAdminsRevertZeroThreshold() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(1, 2);
        roles[0].threshold = 0;
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidThreshold.selector);
        vm.prank(governance);
        sender.setAdmins(FEED_ID, roles, claimBack);
    }

    function testSetAdminsRevertThresholdAboveAdminCount() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(1, 2);
        roles[0].threshold = 3;
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidThreshold.selector);
        vm.prank(governance);
        sender.setAdmins(FEED_ID, roles, claimBack);
    }

    function testSetAdminsRevertZeroAdmin() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(1, 2);
        roles[0].admins[1] = address(0);
        vm.expectRevert(ITeeOracleInstructionsSender.ZeroAdmin.selector);
        vm.prank(governance);
        sender.setAdmins(FEED_ID, roles, claimBack);
    }

    function testSetAdminsRevertDuplicateAdmin() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(1, 2);
        roles[0].admins[1] = roles[0].admins[0];
        vm.expectRevert(ITeeOracleInstructionsSender.DuplicateAdmin.selector);
        vm.prank(governance);
        sender.setAdmins(FEED_ID, roles, claimBack);
    }

    /// Endpoints are deliberately NOT de-duplicated: a URL has unbounded equivalent spellings, so
    /// a string comparison would be bypassable AND would reject legitimate configurations (one
    /// host under two credentials, or two salted PRIVATE commitments for one upstream). The
    /// asymmetry with `DuplicateAdmin` is intentional - an `address` is canonical, a URL is not.
    /// Pinned here so the decision cannot be reversed by accident.
    function testSetEndpointsAcceptsRepeatedEndpointsInOneGroup() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 2);
        groups[0].endpoints[1] = groups[0].endpoints[0];
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);
        assertEq(sender.endpointsVersion(FEED_ID), 1);
    }

    function testSetEndpointsAcceptsOneHostUnderTwoCredentials() public {
        // the case an on-chain duplicate check would have wrongly rejected
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 2);
        groups[0].endpoints[1].url = groups[0].endpoints[0].url;
        groups[0].endpoints[1].secretRef = "a_different_key";
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);
        assertEq(sender.endpointsVersion(FEED_ID), 1);
    }

    function testSetEndpointsAcceptsAnEmptySecretRefAtBothKinds() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 2);
        // a PRIVATE endpoint with no credential beyond the URL itself
        groups[0].endpoints[0].kind = ITeeOracleInstructionsSender.EndpointKind.PRIVATE;
        groups[0].endpoints[0].url = "";
        groups[0].endpoints[0].urlHash = keccak256("private-endpoint");
        groups[0].endpoints[0].secretRef = "";
        // ... and a PUBLIC one whose URL carries no placeholder to substitute
        groups[0].endpoints[1].secretRef = "";
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);
        assertEq(sender.endpointsVersion(FEED_ID), 1);
    }

    function testSetEndpointsAcceptsPrivateEndpointWithSecretRef() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        groups[0].endpoints[0].kind = ITeeOracleInstructionsSender.EndpointKind.PRIVATE;
        groups[0].endpoints[0].url = "";
        groups[0].endpoints[0].urlHash = keccak256("private-endpoint");
        groups[0].endpoints[0].secretRef = "api_key";
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);
        assertEq(sender.endpointsVersion(FEED_ID), 1);
    }

    function testInitializeRevertZeroAddressUpdater() public {
        TeeOracleInstructionsSender impl = new TeeOracleInstructionsSender();
        vm.expectRevert(ITeeOracleInstructionsSender.ZeroAddressUpdater.selector);
        new TeeOracleInstructionsSenderProxy(
            governanceSettings,
            governance,
            address(0),
            EXTENSION_ID,
            address(impl)
        );
    }

    function testSetAdminsAllowsOverlappingRoles() public {
        // the same admin may appear in two different roles
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(2, 1);
        roles[1].admins[0] = roles[0].admins[0];
        vm.prank(governance);
        sender.setAdmins(FEED_ID, roles, claimBack);
        assertEq(sender.adminsVersion(FEED_ID), 1);
    }

    // -------------------------------------------------------------------------
    // requestFeedUpdate
    // -------------------------------------------------------------------------

    function testRequestFeedUpdate() public {
        _configureFeed(FEED_ID, _oneTee());

        // the entire msg.value is forwarded, the caller is the claim-back address and
        // the instruction message carries the feed id
        vm.expectCall(
            flareTeeManager,
            42,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (
                    _oneTee(),
                    _params(
                        GET_FEED_COMMAND,
                        abi.encode(ITeeOracleInstructionsSender.FeedUpdateRequest(FEED_ID)),
                        address(this)
                    )
                )
            )
        );
        vm.expectEmit();
        emit ITeeOracleInstructionsSender.FeedUpdateRequested(address(this), FEED_ID, INSTRUCTION_ID);
        bytes32 instructionId = sender.requestFeedUpdate{value: 42}(FEED_ID, _oneTee());
        assertEq(instructionId, INSTRUCTION_ID);
    }

    function testRequestFeedUpdateIsPermissionless() public {
        _configureFeed(FEED_ID, _oneTee());
        address anyone = makeAddr("anyone");
        vm.deal(anyone, 1 ether);
        vm.prank(anyone);
        sender.requestFeedUpdate{value: 1}(FEED_ID, _oneTee());
    }

    function testRequestFeedUpdateRevertInvalidFeedId() public {
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidFeedId.selector);
        sender.requestFeedUpdate(bytes21(0), _oneTee());
    }

    function testRequestFeedUpdateRevertTeeIdNotConfigured() public {
        // publishing with nothing to dispatch to is not enough - the machine must have been
        // sent both kinds
        _configureFeed(FEED_ID, new address[](0));
        vm.expectRevert(ITeeOracleInstructionsSender.TeeIdNotConfigured.selector);
        sender.requestFeedUpdate(FEED_ID, _oneTee());
    }

    function testRequestFeedUpdateRevertOnlyEndpointsDispatched() public {
        // endpoints alone are not enough - the admins must be at the latest version too
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, _makeGroups(1, 1), claimBack);
        // one kind published is still an unconfigured FEED, not a lagging machine
        vm.expectRevert(ITeeOracleInstructionsSender.FeedNotConfigured.selector);
        sender.requestFeedUpdate(FEED_ID, _oneTee());
    }

    function testRequestFeedUpdateRevertNotConfiguredForOtherFeed() public {
        // configuration is per feed - a machine configured for one feed is not
        // askable for another
        _configureFeed(FEED_ID, _oneTee());
        // OTHER_FEED_ID has no publication of its own, so this is the FEED-level error - the
        // remedy is a governance publication, not a push
        vm.expectRevert(ITeeOracleInstructionsSender.FeedNotConfigured.selector);
        sender.requestFeedUpdate(OTHER_FEED_ID, _oneTee());
    }

    function testRequestFeedUpdateRevertPartlyConfiguredFleet() public {
        // every targeted machine must be configured for the feed
        _configureFeed(FEED_ID, _oneTee());
        vm.expectRevert(ITeeOracleInstructionsSender.TeeIdNotConfigured.selector);
        sender.requestFeedUpdate(FEED_ID, _bothTees());
    }

    function testRequestFeedUpdateRevertMachineBehindLatestVersion() public {
        // the precondition is the feed's LATEST generation, not "was ever configured": the
        // store gates on the feed-level hash, so a lagging machine's answer would be rejected
        _configureFeed(FEED_ID, _oneTee());
        assertTrue(sender.isTeeIdConfigured(FEED_ID, teeId1));
        _mockGetActiveTeeMachines(new address[](0));
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, _makeGroups(1, 2), claimBack);
        assertFalse(sender.isTeeIdConfigured(FEED_ID, teeId1));
        vm.expectRevert(ITeeOracleInstructionsSender.TeeIdNotConfigured.selector);
        sender.requestFeedUpdate(FEED_ID, _oneTee());

        // one permissionless push brings it back into scope
        _mockGetActiveTeeMachines(_bothTees());
        sender.pushEndpoints(FEED_ID, _oneTee(), _makeGroups(1, 2));
        assertTrue(sender.isTeeIdConfigured(FEED_ID, teeId1));
        sender.requestFeedUpdate(FEED_ID, _oneTee());
    }

    // requestFeedUpdate keeps the revert-on-bad-id validation that the dispatch paths replaced
    // with skipping: a requester names the machines it wants an answer from, so a silently
    // dropped target would return fewer answers than were paid for.

    function testRequestFeedUpdateRevertFeedNotConfiguredUnpublishedFeed() public {
        // the feed's own versions are read once, before the loop, so a feed with nothing
        // published fails without ever touching a per-machine record - and it says so with the
        // FEED-level error, which is what tells a caller to wait for a publication rather than
        // to push
        vm.expectRevert(ITeeOracleInstructionsSender.FeedNotConfigured.selector);
        sender.requestFeedUpdate(FEED_ID, _bothTees());
        // publishing one kind only is still not enough
        _publishEndpointsUndispatched(_makeGroups(1, 1));
        sender.pushEndpoints(FEED_ID, _bothTees(), _makeGroups(1, 1));
        vm.expectRevert(ITeeOracleInstructionsSender.FeedNotConfigured.selector);
        sender.requestFeedUpdate(FEED_ID, _bothTees());
        // and the public getter reports exactly the same, unchanged
        assertFalse(sender.isTeeIdConfigured(FEED_ID, teeId1));
    }

    function testRequestFeedUpdateChecksEveryTargetAgainstTheOneFeedRead() public {
        // the hoisted feed read must not weaken the per-target check: the whole fleet is
        // configured, then one machine is left behind by a new publication
        _configureFeed(FEED_ID, _bothTees());
        sender.requestFeedUpdate(FEED_ID, _bothTees());
        _publishEndpointsUndispatched(_makeGroups(1, 2));
        sender.pushEndpoints(FEED_ID, _oneTee(), _makeGroups(1, 2));
        assertTrue(sender.isTeeIdConfigured(FEED_ID, teeId1));
        assertFalse(sender.isTeeIdConfigured(FEED_ID, teeId2));
        vm.expectRevert(ITeeOracleInstructionsSender.TeeIdNotConfigured.selector);
        sender.requestFeedUpdate(FEED_ID, _bothTees());
        sender.requestFeedUpdate(FEED_ID, _oneTee());
    }

    function testRequestFeedUpdateRevertNoTeeIds() public {
        vm.expectRevert(ITeeOracleInstructionsSender.NoTeeIds.selector);
        sender.requestFeedUpdate(FEED_ID, new address[](0));
    }

    function testRequestFeedUpdateRevertZeroTeeId() public {
        _configureFeed(FEED_ID, _oneTee());
        address[] memory teeIds = new address[](2);
        teeIds[0] = teeId1;
        teeIds[1] = address(0);
        vm.expectRevert(ITeeOracleInstructionsSender.ZeroTeeId.selector);
        sender.requestFeedUpdate(FEED_ID, teeIds);
    }

    function testRequestFeedUpdateRevertDuplicateTeeId() public {
        _configureFeed(FEED_ID, _oneTee());
        address[] memory teeIds = new address[](2);
        teeIds[0] = teeId1;
        teeIds[1] = teeId1;
        vm.expectRevert(ITeeOracleInstructionsSender.DuplicateTeeId.selector);
        sender.requestFeedUpdate(FEED_ID, teeIds);
    }

    function testRequestFeedUpdateRevertTeeIdNotInExtension() public {
        // this sender could be registered as the instructions sender of a foreign
        // extension - targets must be pinned to its own extension
        _configureFeed(FEED_ID, _oneTee());
        _mockGetExtensionId(teeId1, EXTENSION_ID + 1);
        vm.expectRevert(ITeeOracleInstructionsSender.TeeIdNotInExtension.selector);
        sender.requestFeedUpdate(FEED_ID, _oneTee());
    }

    // -------------------------------------------------------------------------
    // pushEndpoints / pushAdmins
    // -------------------------------------------------------------------------

    function testPushEndpoints() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(2, 3);
        _publishEndpointsUndispatched(groups);
        bytes memory message = _endpointsMessage(groups, 1);
        bytes32 endpointsHash = keccak256(message);

        vm.expectEmit();
        emit ITeeOracleInstructionsSender.EndpointsSet(FEED_ID, teeId1, 1, endpointsHash);
        vm.expectEmit();
        emit ITeeOracleInstructionsSender.EndpointsSet(FEED_ID, teeId2, 1, endpointsHash);
        // one instruction to all accepted machines carrying the payload the contract re-encoded
        // from the caller's groups, whole msg.value forwarded, the pusher as the claim-back address
        vm.expectCall(
            flareTeeManager,
            7,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (_bothTees(), _params(SET_ENDPOINTS_COMMAND, message, address(this)))
            )
        );
        bytes32 instructionId = sender.pushEndpoints{value: 7}(FEED_ID, _bothTees(), groups);
        assertEq(instructionId, INSTRUCTION_ID);

        // one version per publication, shared by every machine pushed to
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 1);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId2), 1);
    }

    function testPushEndpointsIsPermissionless() public {
        _publishEndpointsUndispatched(_makeGroups(1, 1));
        address anyone = makeAddr("anyone");
        vm.deal(anyone, 1 ether);
        // the pusher pays and is the claim-back address, and what is dispatched is the payload the
        // contract re-encoded from the groups it was handed, with the version from storage
        vm.expectCall(
            flareTeeManager,
            5,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (_oneTee(), _params(SET_ENDPOINTS_COMMAND, _endpointsMessage(_makeGroups(1, 1), 1), anyone))
            )
        );
        vm.prank(anyone);
        sender.pushEndpoints{value: 5}(FEED_ID, _oneTee(), _makeGroups(1, 1));
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 1);
    }

    function testPushAdmins() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(2, 3);
        _publishAdminsUndispatched(roles);
        bytes memory message = _adminsMessage(roles, 1);
        bytes32 adminsHash = keccak256(message);

        vm.expectEmit();
        emit ITeeOracleInstructionsSender.AdminsSet(FEED_ID, teeId1, 1, adminsHash);
        vm.expectCall(
            flareTeeManager,
            0,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (_oneTee(), _params(SET_ADMINS_COMMAND, message, address(this)))
            )
        );
        sender.pushAdmins(FEED_ID, _oneTee(), roles);

        assertEq(sender.expectedAdminsVersion(FEED_ID, teeId1), 1);
        // the two kinds are pushed independently
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 0);
    }

    function testPushEndpointsRevertNoConfigPublished() public {
        // the "is anything published" guard runs before anything is re-encoded, so the values
        // the caller brought are irrelevant here
        vm.expectRevert(ITeeOracleInstructionsSender.NoConfigPublished.selector);
        sender.pushEndpoints(FEED_ID, _oneTee(), _makeGroups(1, 1));
    }

    function testPushAdminsRevertNoConfigPublished() public {
        // endpoints published, admins not - the kinds are tracked separately
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, _makeGroups(1, 1), claimBack);
        vm.expectRevert(ITeeOracleInstructionsSender.NoConfigPublished.selector);
        sender.pushAdmins(FEED_ID, _oneTee(), _makeRoles(1, 1));
    }

    // A push REVERTS on a bad id rather than skipping it: the caller names and pays for the
    // machines it wants delivered to, so a silently dropped target would deliver less than was
    // paid for. The validation is the same one `requestFeedUpdate` applies.

    function testPushEndpointsRevertNoTeeIds() public {
        _publishEndpointsUndispatched(_makeGroups(1, 1));
        vm.expectRevert(ITeeOracleInstructionsSender.NoTeeIds.selector);
        sender.pushEndpoints(FEED_ID, new address[](0), _makeGroups(1, 1));
    }

    function testPushAdminsRevertNoTeeIds() public {
        _publishAdminsUndispatched(_makeRoles(1, 1));
        vm.expectRevert(ITeeOracleInstructionsSender.NoTeeIds.selector);
        sender.pushAdmins(FEED_ID, new address[](0), _makeRoles(1, 1));
    }

    function testPushEndpointsRevertTeeIdNotInExtension() public {
        _publishEndpointsUndispatched(_makeGroups(1, 1));
        // this sender could be registered as a FOREIGN extension's instructions sender, so the
        // target extension is pinned here and not left to the diamond
        _mockGetExtensionId(teeId1, EXTENSION_ID + 1);
        _mockSendInstructionsRevert();
        vm.expectRevert(ITeeOracleInstructionsSender.TeeIdNotInExtension.selector);
        sender.pushEndpoints(FEED_ID, _bothTees(), _makeGroups(1, 1));
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId2), 0, "nothing recorded");
    }

    function testPushAdminsRevertTeeIdNotInExtension() public {
        _publishAdminsUndispatched(_makeRoles(1, 1));
        _mockGetExtensionId(teeId1, EXTENSION_ID + 1);
        vm.expectRevert(ITeeOracleInstructionsSender.TeeIdNotInExtension.selector);
        sender.pushAdmins(FEED_ID, _oneTee(), _makeRoles(1, 1));
    }

    function testPushEndpointsRevertZeroTeeId() public {
        _publishEndpointsUndispatched(_makeGroups(1, 1));
        address[] memory candidates = new address[](2);
        candidates[0] = teeId1;
        candidates[1] = address(0);
        _mockSendInstructionsRevert();
        vm.expectRevert(ITeeOracleInstructionsSender.ZeroTeeId.selector);
        sender.pushEndpoints(FEED_ID, candidates, _makeGroups(1, 1));
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 0, "nothing recorded");
    }

    function testPushEndpointsRevertDuplicateTeeId() public {
        _publishEndpointsUndispatched(_makeGroups(1, 1));
        address[] memory candidates = new address[](2);
        candidates[0] = teeId1;
        candidates[1] = teeId1;
        _mockSendInstructionsRevert();
        vm.expectRevert(ITeeOracleInstructionsSender.DuplicateTeeId.selector);
        sender.pushEndpoints(FEED_ID, candidates, _makeGroups(1, 1));
    }

    function testPushAdminsRevertDuplicateTeeId() public {
        _publishAdminsUndispatched(_makeRoles(1, 1));
        address[] memory candidates = new address[](2);
        candidates[0] = teeId1;
        candidates[1] = teeId1;
        vm.expectRevert(ITeeOracleInstructionsSender.DuplicateTeeId.selector);
        sender.pushAdmins(FEED_ID, candidates, _makeRoles(1, 1));
    }

    function testPushEndpointsLeavesTheProductionCheckToTheDiamond() public {
        // PRODUCTION status is NOT pre-checked here: the diamond rejects a non-PRODUCTION target
        // with its own error, which bubbles and rolls the version record back with it. The sender
        // still passes the machine on, so the caller sees why their target was refused instead of
        // paying a fee for a quietly shortened list.
        _publishEndpointsUndispatched(_makeGroups(1, 1));
        _mockGetTeeMachineStatus(teeId1, IMachineManager.TeeStatus.PAUSED);
        _mockSendInstructionsRevertWith(ITeeCommonErrors.TeeMachineNotAvailable.selector);
        vm.expectCall(
            flareTeeManager,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (_oneTee(), _params(SET_ENDPOINTS_COMMAND, _endpointsMessage(_makeGroups(1, 1), 1), address(this)))
            )
        );
        vm.expectRevert(ITeeCommonErrors.TeeMachineNotAvailable.selector);
        sender.pushEndpoints(FEED_ID, _oneTee(), _makeGroups(1, 1));
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 0);
    }

    function testPushEndpointsRetriesWithoutCooldown() public {
        // an instruction dispatched but never received by the enclave must be fixable at once:
        // there is no cooldown and no idempotence lock-out on the caller-directed push path
        _publishEndpointsUndispatched(_makeGroups(1, 1));
        sender.pushEndpoints(FEED_ID, _oneTee(), _makeGroups(1, 1));
        bytes32 endpointsHash = sender.latestEndpointsHash(FEED_ID);

        // same block, same version, same values, accepted again - and the re-dispatch is
        // idempotent. The hash check is no replay guard: it pins WHAT is pushed, not how often
        vm.expectCall(
            flareTeeManager,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (_oneTee(), _params(SET_ENDPOINTS_COMMAND, _endpointsMessage(_makeGroups(1, 1), 1), address(this)))
            )
        );
        sender.pushEndpoints(FEED_ID, _oneTee(), _makeGroups(1, 1));
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 1);
        assertEq(sender.latestEndpointsHash(FEED_ID), endpointsHash);
        // a machine at the latest version needs nothing, so the "who is lagging" view drops it
        assertEq(sender.getEndpointsPushTargets(FEED_ID).length, 1);
        assertEq(sender.getEndpointsPushTargets(FEED_ID)[0], teeId2);
    }

    function testPushAdminsRetriesWithoutCooldown() public {
        _publishAdminsUndispatched(_makeRoles(1, 1));
        sender.pushAdmins(FEED_ID, _oneTee(), _makeRoles(1, 1));
        sender.pushAdmins(FEED_ID, _oneTee(), _makeRoles(1, 1));
        assertEq(sender.expectedAdminsVersion(FEED_ID, teeId1), 1);
    }

    function testPushEndpointsPicksUpTheNewestPublication() public {
        _publishEndpointsUndispatched(_makeGroups(1, 1));
        sender.pushEndpoints(FEED_ID, _oneTee(), _makeGroups(1, 1));
        _publishEndpointsUndispatched(_makeGroups(1, 2));
        sender.pushEndpoints(FEED_ID, _oneTee(), _makeGroups(1, 2));
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 2);
        assertEq(sender.getEndpointsPushTargets(FEED_ID).length, 1);
    }

    function testPushEndpointsPartialRollout() public {
        // a staged rollout is only possible on the push path, and only for machines the
        // publication could not reach - the auto-dispatch covers the live active set
        _publishEndpointsUndispatched(_makeGroups(1, 1));
        sender.pushEndpoints(FEED_ID, _bothTees(), _makeGroups(1, 1));
        _publishEndpointsUndispatched(_makeGroups(1, 2));
        sender.pushEndpoints(FEED_ID, _oneTee(), _makeGroups(1, 2));
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 2);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId2), 1);
    }

    function testPushEndpointsConvergesLateMachineAndSkipsVersions() public {
        // teeId1 gets v1 from the publication's auto-dispatch
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, _makeGroups(1, 1), claimBack);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 1);

        // the feed then moves to v3 while the fleet is unreachable, and a brand-new machine
        // is registered somewhere along the way
        address lateTeeId = makeAddr("lateTeeId");
        _mockGetExtensionId(lateTeeId, EXTENSION_ID);
        _mockGetTeeMachineStatus(lateTeeId, IMachineManager.TeeStatus.PRODUCTION);
        _publishEndpointsUndispatched(_makeGroups(1, 2));
        _publishEndpointsUndispatched(_makeGroups(1, 3));

        // one permissionless push from a random address brings both current - teeId1 jumps
        // v1 -> v3, and the machine registered after the publications lands on v3 directly
        address[] memory targets = new address[](2);
        targets[0] = teeId1;
        targets[1] = lateTeeId;
        address anyone = makeAddr("anyone");
        vm.prank(anyone);
        sender.pushEndpoints(FEED_ID, targets, _makeGroups(1, 3));
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 3);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, lateTeeId), 3);
    }

    function testPushEndpointsRevertsWhileEmergencyPaused() public {
        // publication succeeds during a pause and dispatches nothing at all
        _mockEmergencyPaused(true);
        _publishFeed(FEED_ID);
        assertEq(sender.endpointsVersion(FEED_ID), 1);
        // the diamond refuses every dispatch while the extension is paused, so a push reverts
        // atomically and leaves no version record behind
        vm.mockCallRevert(
            flareTeeManager,
            abi.encodeWithSelector(IInstructions.sendInstructions.selector),
            abi.encodeWithSelector(IMachineEmergencyPause.EmergencyPauseActive.selector, EXTENSION_ID)
        );
        vm.expectRevert(
            abi.encodeWithSelector(IMachineEmergencyPause.EmergencyPauseActive.selector, EXTENSION_ID)
        );
        sender.pushEndpoints(FEED_ID, _oneTee(), _makeGroups(1, 1));
        vm.expectRevert(
            abi.encodeWithSelector(IMachineEmergencyPause.EmergencyPauseActive.selector, EXTENSION_ID)
        );
        sender.pushAdmins(FEED_ID, _oneTee(), _makeRoles(1, 1));
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 0);
        assertEq(sender.expectedAdminsVersion(FEED_ID, teeId1), 0);
    }

    // The configuration VALUES are the caller's to supply; the contract re-encodes them with the
    // version it holds in storage and checks the result against the stored hash. Two things the
    // typed signature gives for free: the caller cannot name a version at all, and it cannot hand
    // an admins payload to the endpoints push - that is a compile-time type error, not a runtime
    // check, so there is no test for it here.

    function testRevertPushEndpointsWrongConfigPayloadAlteredValues() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 2);
        _publishEndpointsUndispatched(groups);
        // one character of one URL
        ITeeOracleInstructionsSender.EndpointGroup[] memory altered = _makeGroups(1, 2);
        altered[0].endpoints[0].url = "https://rpc0.example.com/{secret}X";
        _mockSendInstructionsRevert();
        vm.expectRevert(ITeeOracleInstructionsSender.WrongConfigPayload.selector);
        sender.pushEndpoints(FEED_ID, _oneTee(), altered);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 0, "nothing recorded");
        // the published values go through
        _mockSendInstructions();
        sender.pushEndpoints(FEED_ID, _oneTee(), groups);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 1);
    }

    function testRevertPushEndpointsWrongConfigPayloadDifferentGroups() public {
        // a payload that is well-formed and would have validated, but is not the published one
        _publishEndpointsUndispatched(_makeGroups(1, 2));
        vm.expectRevert(ITeeOracleInstructionsSender.WrongConfigPayload.selector);
        sender.pushEndpoints(FEED_ID, _oneTee(), _makeGroups(2, 3));
    }

    function testRevertPushEndpointsWrongConfigPayloadPreviousPublicationsValues() public {
        // the values of a superseded publication no longer hash to the commitment: the contract
        // encodes them with the CURRENT version, so a stale configuration cannot be delivered
        _publishEndpointsUndispatched(_makeGroups(1, 1));
        _publishEndpointsUndispatched(_makeGroups(1, 2));
        vm.expectRevert(ITeeOracleInstructionsSender.WrongConfigPayload.selector);
        sender.pushEndpoints(FEED_ID, _oneTee(), _makeGroups(1, 1));
        // and the current one goes through
        sender.pushEndpoints(FEED_ID, _oneTee(), _makeGroups(1, 2));
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 2);
    }

    function testPushEndpointsTakesTheVersionFromStorageNotTheCaller() public {
        // the caller supplies no version, so it can neither name a stale one nor be tricked into
        // one: republishing identical content bumps the version, and the same values then push as
        // the NEW version. This is the whole reason the push takes fields instead of raw bytes.
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 2);
        _publishEndpointsUndispatched(groups);
        bytes32 firstHash = sender.latestEndpointsHash(FEED_ID);
        _publishEndpointsUndispatched(groups);
        assertEq(sender.endpointsVersion(FEED_ID), 2);
        assertNotEq(sender.latestEndpointsHash(FEED_ID), firstHash, "the version moved the hash");
        vm.expectCall(
            flareTeeManager,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (_oneTee(), _params(SET_ENDPOINTS_COMMAND, _endpointsMessage(groups, 2), address(this)))
            )
        );
        sender.pushEndpoints(FEED_ID, _oneTee(), groups);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 2);
    }

    function testRevertPushAdminsWrongConfigPayloadAlteredValues() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(2, 3);
        _publishAdminsUndispatched(roles);
        ITeeOracleInstructionsSender.AdminRole[] memory altered = _makeRoles(2, 3);
        altered[1].admins[2] = makeAddr("intruder");
        vm.expectRevert(ITeeOracleInstructionsSender.WrongConfigPayload.selector);
        sender.pushAdmins(FEED_ID, _oneTee(), altered);
        assertEq(sender.expectedAdminsVersion(FEED_ID, teeId1), 0, "nothing recorded");
        sender.pushAdmins(FEED_ID, _oneTee(), roles);
        assertEq(sender.expectedAdminsVersion(FEED_ID, teeId1), 1);
    }

    function testRevertPushAdminsWrongConfigPayloadThresholdOnly() public {
        // every field is inside the commitment, thresholds included
        _publishAdminsUndispatched(_makeRoles(1, 3));
        ITeeOracleInstructionsSender.AdminRole[] memory altered = _makeRoles(1, 3);
        altered[0].threshold = 1;
        vm.expectRevert(ITeeOracleInstructionsSender.WrongConfigPayload.selector);
        sender.pushAdmins(FEED_ID, _oneTee(), altered);
    }

    function testPushUsesTheValuesLoggedByAPublicationThatSkippedItsDispatch() public {
        // the pause path is exactly why the publication event carries the payload: nothing is
        // dispatched, so no TeeInstructionsSent logs it either, and the publication log is the
        // ONLY record. A keeper reads the values from there and pushes them once the pause is
        // lifted - which is what this test does, taking nothing from the test's own inputs.
        _mockEmergencyPaused(true);
        _mockSendInstructionsRevert();
        vm.recordLogs();
        vm.startPrank(governance);
        sender.setEndpoints(FEED_ID, _makeGroups(2, 3), claimBack);
        sender.setAdmins(FEED_ID, _makeRoles(2, 3), claimBack);
        vm.stopPrank();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        ITeeOracleInstructionsSender.EndpointGroup[] memory loggedGroups = _groupsFromLogs(logs);
        ITeeOracleInstructionsSender.AdminRole[] memory loggedRoles = _rolesFromLogs(logs);
        // what the log carries is what the push takes - no wrapper, no extraction step. The
        // version and feed id are the event's own topics, and the push supplies them itself.
        assertEq(keccak256(_endpointsMessage(loggedGroups, 1)), sender.latestEndpointsHash(FEED_ID));
        assertEq(keccak256(_adminsMessage(loggedRoles, 1)), sender.latestAdminsHash(FEED_ID));

        _mockEmergencyPaused(false);
        _mockSendInstructions();
        vm.expectCall(
            flareTeeManager,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (
                    _bothTees(),
                    _params(SET_ENDPOINTS_COMMAND, _endpointsMessage(loggedGroups, 1), address(this))
                )
            )
        );
        sender.pushEndpoints(FEED_ID, _bothTees(), loggedGroups);
        sender.pushAdmins(FEED_ID, _bothTees(), loggedRoles);
        assertTrue(sender.isTeeIdConfigured(FEED_ID, teeId1));
        assertTrue(sender.isTeeIdConfigured(FEED_ID, teeId2));
    }

    function testPublicationEventCarriesThePayloadWhetherOrNotItDispatches() public {
        // dispatching case: the payload is in the publication log as well as in the instruction
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(2, 2);
        vm.recordLogs();
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, groups, claimBack);
        assertEq(
            keccak256(abi.encode(_groupsFromLogs(vm.getRecordedLogs()))),
            keccak256(abi.encode(groups))
        );

        // skipped case: an empty active set dispatches nothing, and the log still carries it
        _mockGetActiveTeeMachines(new address[](0));
        _mockSendInstructionsRevert();
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(2, 2);
        vm.recordLogs();
        vm.prank(governance);
        sender.setAdmins(FEED_ID, roles, claimBack);
        assertEq(
            keccak256(abi.encode(_rolesFromLogs(vm.getRecordedLogs()))),
            keccak256(abi.encode(roles))
        );
    }

    // -------------------------------------------------------------------------
    // push preview views
    // -------------------------------------------------------------------------

    function testGetEndpointsPushTargets() public {
        // nothing published yet - no machine is pushable, even though the fleet is active
        assertEq(sender.getEndpointsPushTargets(FEED_ID).length, 0);

        _publishEndpointsUndispatched(_makeGroups(1, 1));
        address[] memory targets = sender.getEndpointsPushTargets(FEED_ID);
        assertEq(targets.length, 2);
        assertEq(targets[0], teeId1);
        assertEq(targets[1], teeId2);

        // pushing to one of them removes it from the "who still needs a push" preview
        sender.pushEndpoints(FEED_ID, _oneTee(), _makeGroups(1, 1));
        targets = sender.getEndpointsPushTargets(FEED_ID);
        assertEq(targets.length, 1);
        assertEq(targets[0], teeId2);

        sender.pushEndpoints(FEED_ID, _onlySecondTee(), _makeGroups(1, 1));
        assertEq(sender.getEndpointsPushTargets(FEED_ID).length, 0);
    }

    function testGetAdminsPushTargets() public {
        assertEq(sender.getAdminsPushTargets(FEED_ID).length, 0);
        _publishAdminsUndispatched(_makeRoles(1, 1));
        assertEq(sender.getAdminsPushTargets(FEED_ID).length, 2);
        sender.pushAdmins(FEED_ID, _bothTees(), _makeRoles(1, 1));
        assertEq(sender.getAdminsPushTargets(FEED_ID).length, 0);
    }

    function testGetEndpointsPushTargetsFollowsTheDiamondsActiveSet() public {
        _publishEndpointsUndispatched(_makeGroups(1, 1));
        // the diamond's active set is authoritative and needs no predicate of its own: a machine
        // that leaves PRODUCTION leaves the set, which is what takes it out of this view
        _mockGetActiveTeeMachines(_onlySecondTee());
        address[] memory targets = sender.getEndpointsPushTargets(FEED_ID);
        assertEq(targets.length, 1);
        assertEq(targets[0], teeId2);
    }

    function testGetFeedConfigAndMachineVersions() public {
        // the packed struct views agree with the individual getters that keep the ABI stable
        ITeeOracleInstructionsSender.FeedConfig memory empty = sender.getFeedConfig(FEED_ID);
        assertEq(empty.endpointsHash, bytes32(0));
        assertEq(empty.endpointsVersion, 0);
        assertEq(empty.adminsPublishedAt, 0);

        _publishFeed(FEED_ID);
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, _makeGroups(1, 2), claimBack);

        ITeeOracleInstructionsSender.FeedConfig memory config = sender.getFeedConfig(FEED_ID);
        assertEq(config.endpointsVersion, 2);
        assertEq(config.adminsVersion, 1);
        assertEq(config.endpointsHash, sender.latestEndpointsHash(FEED_ID));
        assertEq(config.adminsHash, sender.latestAdminsHash(FEED_ID));
        assertEq(config.endpointsVersion, sender.endpointsVersion(FEED_ID));
        assertEq(config.adminsVersion, sender.adminsVersion(FEED_ID));
        assertEq(config.endpointsPublishedAt, uint64(vm.getBlockTimestamp()));
        assertEq(config.adminsPublishedAt, sender.adminsPublishedAt(FEED_ID));

        ITeeOracleInstructionsSender.MachineVersions memory versions =
            sender.getMachineVersions(FEED_ID, teeId1);
        assertEq(versions.endpointsVersion, 2);
        assertEq(versions.adminsVersion, 1);
        assertEq(versions.endpointsVersion, sender.expectedEndpointsVersion(FEED_ID, teeId1));
        assertEq(versions.adminsVersion, sender.expectedAdminsVersion(FEED_ID, teeId1));

        // per feed: another feed's slot is untouched
        assertEq(sender.getFeedConfig(OTHER_FEED_ID).endpointsVersion, 0);
        assertEq(sender.getMachineVersions(OTHER_FEED_ID, teeId1).endpointsVersion, 0);
    }

    function testGetPublicationFee() public {
        // what the governance executor attaches: the fee for the extension's WHOLE live active
        // set, since a fresh publication is new to every eligible machine
        _mockCalculateFee(SET_ENDPOINTS_COMMAND, _bothTees(), 2000);
        _mockCalculateFee(SET_ADMINS_COMMAND, _bothTees(), 1000);
        (address[] memory teeIds, uint256 fee) = sender.getEndpointsPublicationFee();
        assertEq(teeIds.length, 2);
        assertEq(fee, 2000);
        (teeIds, fee) = sender.getAdminsPublicationFee();
        assertEq(teeIds.length, 2);
        assertEq(fee, 1000);

        // unlike get*PushTargets it does NOT drop machines at the current latest version - the
        // publication about to run bumps the version, so every eligible machine is a target.
        // The quoted fee is what the executor attaches, so it is attached here
        vm.deal(governance, 2000);
        vm.prank(governance);
        sender.setEndpoints{value: 2000}(FEED_ID, _makeGroups(1, 1), claimBack);
        assertEq(sender.getEndpointsPushTargets(FEED_ID).length, 0);
        (teeIds, fee) = sender.getEndpointsPublicationFee();
        assertEq(teeIds.length, 2);
        assertEq(fee, 2000);

        // the view is the diamond's active set priced as-is: a machine that leaves PRODUCTION
        // leaves the set, and an empty set prices at zero - which is also the signal that the
        // next publication will skip its dispatch and must carry no value
        _mockGetActiveTeeMachines(_onlySecondTee());
        _mockCalculateFee(SET_ENDPOINTS_COMMAND, _onlySecondTee(), 1234);
        (teeIds, fee) = sender.getEndpointsPublicationFee();
        assertEq(teeIds.length, 1);
        assertEq(teeIds[0], teeId2);
        assertEq(fee, 1234);
        _mockGetActiveTeeMachines(new address[](0));
        (teeIds, fee) = sender.getEndpointsPublicationFee();
        assertEq(teeIds.length, 0);
        assertEq(fee, 0);

        // an emergency pause reads the same way, because the publication behaves the same way:
        // the dispatch is skipped, so the executor must attach nothing
        _mockGetActiveTeeMachines(_bothTees());
        _mockEmergencyPaused(true);
        (teeIds, fee) = sender.getEndpointsPublicationFee();
        assertEq(teeIds.length, 0);
        assertEq(fee, 0);
        (teeIds, fee) = sender.getAdminsPublicationFee();
        assertEq(teeIds.length, 0);
        assertEq(fee, 0);
    }

    function testGetAdminsPushTargetsListsOnlyStragglers() public {
        // nothing published - nothing is pushable, even though the fleet is active
        assertEq(sender.getAdminsPushTargets(FEED_ID).length, 0);

        _publishAdminsUndispatched(_makeRoles(1, 1));
        assertEq(sender.getAdminsPushTargets(FEED_ID).length, 2);

        // pushing to one leaves exactly the other as a straggler; the straggler list is a
        // ready-to-use _teeIds argument, with the values coming from the publication log
        sender.pushAdmins(FEED_ID, _oneTee(), _makeRoles(1, 1));
        address[] memory targets = sender.getAdminsPushTargets(FEED_ID);
        assertEq(targets.length, 1);
        assertEq(targets[0], teeId2);
        sender.pushAdmins(FEED_ID, targets, _makeRoles(1, 1));
        assertEq(sender.getAdminsPushTargets(FEED_ID).length, 0);

        // the up-to-date machine is gone from the view but the push still accepts it as a retry
        sender.pushAdmins(FEED_ID, _bothTees(), _makeRoles(1, 1));
        assertEq(sender.expectedAdminsVersion(FEED_ID, teeId1), 1);
        assertEq(sender.expectedAdminsVersion(FEED_ID, teeId2), 1);
        assertEq(sender.getAdminsPushTargets(FEED_ID).length, 0);
    }

    // -------------------------------------------------------------------------
    // feed discovery
    // -------------------------------------------------------------------------

    function testGetFeedIds() public {
        assertEq(sender.getFeedIds().length, 0);
        vm.startPrank(governance);
        // one kind alone does not list the feed
        sender.setAdmins(FEED_ID, _makeRoles(1, 1), claimBack);
        assertEq(sender.getFeedIds().length, 0);
        // the feed appears once both kinds are published, regardless of order
        sender.setEndpoints(FEED_ID, _makeGroups(1, 1), claimBack);
        assertEq(sender.getFeedIds().length, 1);
        sender.setEndpoints(OTHER_FEED_ID, _makeGroups(1, 1), claimBack);
        assertEq(sender.getFeedIds().length, 1);
        sender.setAdmins(OTHER_FEED_ID, _makeRoles(1, 1), claimBack);
        // repeat publications must not duplicate entries
        sender.setEndpoints(OTHER_FEED_ID, _makeGroups(1, 1), claimBack);
        sender.setAdmins(OTHER_FEED_ID, _makeRoles(1, 1), claimBack);
        vm.stopPrank();
        bytes21[] memory ids = sender.getFeedIds();
        assertEq(ids.length, 2);
        assertEq(ids[0], FEED_ID);
        assertEq(ids[1], OTHER_FEED_ID);
    }

    function testIsTeeIdConfigured() public {
        assertFalse(sender.isTeeIdConfigured(FEED_ID, teeId1));
        // publication with nothing reachable configures no machine
        _configureFeed(FEED_ID, new address[](0));
        assertFalse(sender.isTeeIdConfigured(FEED_ID, teeId1));
        sender.pushEndpoints(FEED_ID, _oneTee(), _makeGroups(1, 1));
        // endpoints alone are not enough
        assertFalse(sender.isTeeIdConfigured(FEED_ID, teeId1));
        sender.pushAdmins(FEED_ID, _oneTee(), _makeRoles(1, 1));
        assertTrue(sender.isTeeIdConfigured(FEED_ID, teeId1));
        // per feed and per machine
        assertFalse(sender.isTeeIdConfigured(OTHER_FEED_ID, teeId1));
        assertFalse(sender.isTeeIdConfigured(FEED_ID, teeId2));

        // and it tracks the LATEST version, so a new publication the machine has not been sent
        // takes it out of scope again
        _mockGetActiveTeeMachines(new address[](0));
        vm.prank(governance);
        sender.setAdmins(FEED_ID, _makeRoles(1, 2), claimBack);
        assertFalse(sender.isTeeIdConfigured(FEED_ID, teeId1));
    }

    // -------------------------------------------------------------------------
    // governance timelock (production mode)
    // -------------------------------------------------------------------------

    function testSetEndpointsTimelockedExecutesAndDispatches() public {
        _switchToProduction();

        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        bytes memory call = abi.encodeCall(sender.setEndpoints, (FEED_ID, groups, claimBack));

        // recording does not execute the body
        vm.prank(productionGovernance);
        (bool ok,) = address(sender).call(call);
        assertTrue(ok);
        assertEq(sender.endpointsVersion(FEED_ID), 0, "must not execute immediately");

        // the executor attaches the instruction fee at execution time; the executed body's
        // msg.sender is the contract itself, so the claim-back address is the one frozen into
        // the recorded call - here neither governance nor the executor
        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        vm.deal(executor, 8);
        vm.expectCall(
            flareTeeManager,
            8,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (_bothTees(), _params(SET_ENDPOINTS_COMMAND, _endpointsMessage(groups, 1), claimBack))
            )
        );
        vm.prank(executor);
        IFlareGovernance(address(sender)).executeGovernanceCall{value: 8}(call);
        assertEq(sender.endpointsVersion(FEED_ID), 1);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 1);
    }

    function testSetEndpointsTimelockedExecutionSurvivesUnreachableFleet() public {
        _switchToProduction();

        bytes memory call = abi.encodeCall(sender.setEndpoints, (FEED_ID, _makeGroups(1, 1), claimBack));
        vm.prank(productionGovernance);
        (bool ok,) = address(sender).call(call);
        assertTrue(ok);

        // every machine left PRODUCTION during the timelock, and no fee was attached: the
        // recorded call must still execute - that is the whole point of resolving the targets
        // inside the body and never letting the dispatch fail the publication
        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        _mockGetActiveTeeMachines(new address[](0));
        _mockSendInstructionsRevert();
        vm.prank(executor);
        IFlareGovernance(address(sender)).executeGovernanceCall(call);
        assertEq(sender.endpointsVersion(FEED_ID), 1);
    }

    function testSetEndpointsTimelockedExecutionRetryableAfterFeeShortfall() public {
        _switchToProduction();

        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        bytes memory call = abi.encodeCall(sender.setEndpoints, (FEED_ID, groups, claimBack));
        vm.prank(productionGovernance);
        (bool ok,) = address(sender).call(call);
        assertTrue(ok);

        // the executor attaches too little: the diamond's fee floor rejects the dispatch and the
        // execution bubbles FeeTooLow
        _mockSendInstructionsRevertWith(IInstructions.FeeTooLow.selector);
        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        vm.deal(executor, 99);
        vm.expectRevert(IInstructions.FeeTooLow.selector);
        vm.prank(executor);
        IFlareGovernance(address(sender)).executeGovernanceCall{value: 5}(call);
        assertEq(sender.endpointsVersion(FEED_ID), 0);

        // executeGovernanceCall deletes the timelock entry BEFORE the inner call and bubbles the
        // revert, so the failed execution rolled the deletion back too: the pending call is
        // still there and the executor simply retries with a sufficient fee, no re-proposal
        _mockSendInstructions();
        vm.prank(executor);
        IFlareGovernance(address(sender)).executeGovernanceCall{value: 8}(call);
        assertEq(sender.endpointsVersion(FEED_ID), 1);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 1);
        assertEq(executor.balance, 91, "only the fee of the successful execution left the executor");
    }

    function testSetEndpointsTimelockedExecutionValueNotNeededIsRetryable() public {
        _switchToProduction();

        bytes memory call = abi.encodeCall(sender.setEndpoints, (FEED_ID, _makeGroups(1, 1), claimBack));
        vm.prank(productionGovernance);
        (bool ok,) = address(sender).call(call);
        assertTrue(ok);

        // no machine is eligible, so the dispatch is skipped and the attached value has nowhere
        // to go: the executor is told to re-execute with none, which still works
        _mockGetActiveTeeMachines(new address[](0));
        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        vm.deal(executor, 7);
        vm.expectRevert(ITeeOracleInstructionsSender.ValueNotNeeded.selector);
        vm.prank(executor);
        IFlareGovernance(address(sender)).executeGovernanceCall{value: 7}(call);
        assertEq(sender.endpointsVersion(FEED_ID), 0);
        assertEq(executor.balance, 7);

        vm.prank(executor);
        IFlareGovernance(address(sender)).executeGovernanceCall(call);
        assertEq(sender.endpointsVersion(FEED_ID), 1);
    }

    function testSetEndpointsRecordingRejectsValue() public {
        _switchToProduction();
        vm.deal(productionGovernance, 1);
        // recording does not execute the body, so value sent now would be trapped
        vm.prank(productionGovernance);
        (bool ok, bytes memory returned) = address(sender).call{value: 1}(
            abi.encodeCall(sender.setEndpoints, (FEED_ID, _makeGroups(1, 1), claimBack))
        );
        assertFalse(ok);
        assertEq(bytes4(returned), IFlareGovernance.TimelockValueNotAllowed.selector);
        assertEq(sender.endpointsVersion(FEED_ID), 0);
    }

    function testUpgradeToAndCallPreservesState() public {
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, _makeGroups(1, 1), claimBack);
        bytes32 endpointsHash = sender.latestEndpointsHash(FEED_ID);

        TeeOracleInstructionsSender newImpl = new TeeOracleInstructionsSender();
        vm.prank(governance);
        sender.upgradeToAndCall(address(newImpl), "");
        assertEq(sender.implementation(), address(newImpl));
        assertEq(sender.extensionId(), EXTENSION_ID);
        assertEq(sender.endpointsVersion(FEED_ID), 1);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId1), 1);
        assertEq(sender.latestEndpointsHash(FEED_ID), endpointsHash);
        // and a push still works against the surviving commitment
        sender.pushEndpoints(FEED_ID, _oneTee(), _makeGroups(1, 1));
    }

    function testUpgradeToAndCallRevertOnlyGovernance() public {
        TeeOracleInstructionsSender newImpl = new TeeOracleInstructionsSender();
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        sender.upgradeToAndCall(address(newImpl), "");
    }

    function testUpdateContractAddressesRevertOnlyAddressUpdater() public {
        bytes32[] memory contractNameHashes = new bytes32[](0);
        address[] memory contractAddresses = new address[](0);
        vm.expectRevert("only address updater");
        sender.updateContractAddresses(contractNameHashes, contractAddresses);
    }

    // -------------------------------------------------------------------------
    // helpers
    // -------------------------------------------------------------------------

    function _oneTee() private view returns (address[] memory _teeIds) {
        _teeIds = new address[](1);
        _teeIds[0] = teeId1;
    }

    function _onlySecondTee() private view returns (address[] memory _teeIds) {
        _teeIds = new address[](1);
        _teeIds[0] = teeId2;
    }

    function _bothTees() private view returns (address[] memory _teeIds) {
        _teeIds = new address[](2);
        _teeIds[0] = teeId1;
        _teeIds[1] = teeId2;
    }

    function _params(
        bytes32 _opCommand,
        bytes memory _message,
        address _claimBackAddress
    )
        private pure
        returns (IInstructions.TeeInstructionParams memory)
    {
        return IInstructions.TeeInstructionParams({
            opType: TEE_ORACLE_OP_TYPE,
            opCommand: _opCommand,
            message: _message,
            cosigners: new address[](0),
            cosignersThreshold: 0,
            claimBackAddress: _claimBackAddress
        });
    }

    function _endpointsMessage(
        ITeeOracleInstructionsSender.EndpointGroup[] memory _groups,
        uint64 _version
    )
        private pure
        returns (bytes memory)
    {
        return abi.encode(
            ITeeOracleInstructionsSender.Endpoints({
                version: _version,
                feedId: FEED_ID,
                groups: _groups
            })
        );
    }

    function _adminsMessage(
        ITeeOracleInstructionsSender.AdminRole[] memory _roles,
        uint64 _version
    )
        private pure
        returns (bytes memory)
    {
        return abi.encode(
            ITeeOracleInstructionsSender.Admins({
                version: _version,
                feedId: FEED_ID,
                roles: _roles
            })
        );
    }

    /// The groups carried by the single `EndpointsPublished` entry in the recorded logs - exactly
    /// how a keeper obtains the values it hands back to `pushEndpoints`, since nothing on chain
    /// stores them, and passed through with no extraction step.
    function _groupsFromLogs(
        Vm.Log[] memory _logs
    )
        private pure
        returns (ITeeOracleInstructionsSender.EndpointGroup[] memory _groups)
    {
        bool found = false;
        for (uint256 i = 0; i < _logs.length; i++) {
            if (_logs[i].topics[0] == ITeeOracleInstructionsSender.EndpointsPublished.selector) {
                (, _groups) = abi.decode(
                    _logs[i].data, (bytes32, ITeeOracleInstructionsSender.EndpointGroup[]));
                found = true;
            }
        }
        require(found, "no EndpointsPublished log");
    }

    /// See `_groupsFromLogs`.
    function _rolesFromLogs(
        Vm.Log[] memory _logs
    )
        private pure
        returns (ITeeOracleInstructionsSender.AdminRole[] memory _roles)
    {
        bool found = false;
        for (uint256 i = 0; i < _logs.length; i++) {
            if (_logs[i].topics[0] == ITeeOracleInstructionsSender.AdminsPublished.selector) {
                (, _roles) = abi.decode(
                    _logs[i].data, (bytes32, ITeeOracleInstructionsSender.AdminRole[]));
                found = true;
            }
        }
        require(found, "no AdminsPublished log");
    }

    function _makeGroups(
        uint256 _groupCount,
        uint256 _endpointCount
    )
        private pure
        returns (ITeeOracleInstructionsSender.EndpointGroup[] memory _groups)
    {
        _groups = new ITeeOracleInstructionsSender.EndpointGroup[](_groupCount);
        for (uint256 i = 0; i < _groupCount; i++) {
            ITeeOracleInstructionsSender.Endpoint[] memory endpoints =
                new ITeeOracleInstructionsSender.Endpoint[](_endpointCount);
            for (uint256 j = 0; j < _endpointCount; j++) {
                endpoints[j] = ITeeOracleInstructionsSender.Endpoint({
                    kind: ITeeOracleInstructionsSender.EndpointKind.PUBLIC,
                    url: string.concat("https://rpc", vm.toString(j), ".example.com/{secret}"),
                    urlHash: bytes32(0),
                    secretRef: string.concat("api_key_", vm.toString(j))
                });
            }
            _groups[i] = ITeeOracleInstructionsSender.EndpointGroup({
                group: bytes32(uint256(i + 1)),
                threshold: uint64(_endpointCount),
                endpoints: endpoints
            });
        }
    }

    function _makeRoles(
        uint256 _roleCount,
        uint256 _adminCount
    )
        private pure
        returns (ITeeOracleInstructionsSender.AdminRole[] memory _roles)
    {
        _roles = new ITeeOracleInstructionsSender.AdminRole[](_roleCount);
        for (uint256 i = 0; i < _roleCount; i++) {
            address[] memory admins = new address[](_adminCount);
            for (uint256 j = 0; j < _adminCount; j++) {
                admins[j] = address(uint160(0x1000 * (i + 1) + j + 1));
            }
            _roles[i] = ITeeOracleInstructionsSender.AdminRole({
                role: bytes32(uint256(i + 1)),
                threshold: uint64(_adminCount),
                admins: admins
            });
        }
    }

    /// Writes a feed's two stored versions directly, the only way to reach `type(uint64).max`
    /// without 2^64 publications. `feedConfigs` is at slot 2 and the four `uint64`s share the
    /// struct's third slot, endpoints first; the callers assert the readback, so a layout change
    /// fails the test rather than passing it vacuously.
    function _setStoredVersions(bytes21 _feedId, uint64 _endpoints, uint64 _admins) private {
        bytes32 configSlot = keccak256(abi.encodePacked(bytes32(_feedId), uint256(2)));
        vm.store(
            address(sender),
            bytes32(uint256(configSlot) + 2),
            bytes32((uint256(_admins) << 64) | uint256(_endpoints))
        );
    }

    function _mockSendInstructions() private {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IInstructions.sendInstructions.selector),
            abi.encode(INSTRUCTION_ID)
        );
    }

    /// Makes any dispatch fail, so a test asserting "this path dispatches nothing" fails loudly.
    function _mockSendInstructionsRevert() private {
        vm.mockCallRevert(
            flareTeeManager,
            abi.encodeWithSelector(IInstructions.sendInstructions.selector),
            bytes("unexpected dispatch")
        );
    }

    /// Makes any dispatch fail with one of the diamond's own errors.
    function _mockSendInstructionsRevertWith(bytes4 _selector) private {
        vm.mockCallRevert(
            flareTeeManager,
            abi.encodeWithSelector(IInstructions.sendInstructions.selector),
            abi.encodeWithSelector(_selector)
        );
    }

    /// Publishes both kinds for the feed, auto-dispatching to whatever the active set is.
    /// The version is assigned by the contract, so this helper works on an already-published feed
    /// exactly as it does on a fresh one.
    function _publishFeed(bytes21 _feedId) private {
        vm.startPrank(governance);
        sender.setEndpoints(_feedId, _makeGroups(1, 1), claimBack);
        sender.setAdmins(_feedId, _makeRoles(1, 1), claimBack);
        vm.stopPrank();
    }

    /// Publishes both kinds with the active set narrowed to `_teeIds`, so exactly those
    /// machines are configured by the publication's auto-dispatch.
    function _configureFeed(bytes21 _feedId, address[] memory _teeIds) private {
        _mockGetActiveTeeMachines(_teeIds);
        _publishFeed(_feedId);
        _mockGetActiveTeeMachines(_bothTees());
    }

    /// Publishes endpoints with an empty active set, so nothing is dispatched and the push
    /// path can be exercised in isolation. The push is then handed the same groups back - that is
    /// all it takes, since it re-encodes them with the version it holds in storage.
    function _publishEndpointsUndispatched(
        ITeeOracleInstructionsSender.EndpointGroup[] memory _groups
    )
        private
    {
        _mockGetActiveTeeMachines(new address[](0));
        vm.prank(governance);
        sender.setEndpoints(FEED_ID, _groups, claimBack);
        _mockGetActiveTeeMachines(_bothTees());
    }

    /// See `_publishEndpointsUndispatched`.
    function _publishAdminsUndispatched(
        ITeeOracleInstructionsSender.AdminRole[] memory _roles
    )
        private
    {
        _mockGetActiveTeeMachines(new address[](0));
        vm.prank(governance);
        sender.setAdmins(FEED_ID, _roles, claimBack);
        _mockGetActiveTeeMachines(_bothTees());
    }

    function _mockGetExtensionId(address _teeId, uint256 _extensionId) private {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IMachineManager.getExtensionId.selector, _teeId),
            abi.encode(_extensionId)
        );
    }

    function _mockGetTeeMachineStatus(address _teeId, IMachineManager.TeeStatus _status) private {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IMachineManager.getTeeMachineStatus.selector, _teeId),
            abi.encode(_status)
        );
    }

    function _mockGetActiveTeeMachines(address[] memory _teeIds) private {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IMachineManager.getActiveTeeMachines.selector, EXTENSION_ID),
            abi.encode(_teeIds, new string[](_teeIds.length))
        );
    }

    /// Makes reading the active set fail, so a test asserting "this path never enumerates the
    /// fleet" fails loudly.
    function _mockGetActiveTeeMachinesRevert() private {
        vm.mockCallRevert(
            flareTeeManager,
            abi.encodeWithSelector(IMachineManager.getActiveTeeMachines.selector, EXTENSION_ID),
            bytes("unexpected active set read")
        );
    }

    function _mockEmergencyPaused(bool _paused) private {
        vm.mockCall(
            flareTeeManager,
            abi.encodeCall(IMachineEmergencyPause.isExtensionEmergencyPaused, (EXTENSION_ID)),
            abi.encode(_paused)
        );
    }

    function _mockCalculateFeeDefault(uint256 _fee) private {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IOperationFees.calculateFeeByTeeIds.selector),
            abi.encode(_fee)
        );
    }

    /// Makes fee pricing fail, so a test asserting "this path never prices a dispatch" fails
    /// loudly.
    function _mockCalculateFeeRevert() private {
        vm.mockCallRevert(
            flareTeeManager,
            abi.encodeWithSelector(IOperationFees.calculateFeeByTeeIds.selector),
            bytes("unexpected fee read")
        );
    }

    function _mockCalculateFee(bytes32 _opCommand, address[] memory _teeIds, uint256 _fee) private {
        vm.mockCall(
            flareTeeManager,
            abi.encodeCall(
                IOperationFees.calculateFeeByTeeIds, (TEE_ORACLE_OP_TYPE, _opCommand, _teeIds)),
            abi.encode(_fee)
        );
    }

    function _switchToProduction() private {
        vm.prank(governance);
        sender.switchToProductionMode();
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(IGovernanceSettings.getGovernanceAddress.selector),
            abi.encode(productionGovernance)
        );
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(IGovernanceSettings.getTimelock.selector),
            abi.encode(TIMELOCK)
        );
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(IGovernanceSettings.isExecutor.selector, executor),
            abi.encode(true)
        );
    }
}
