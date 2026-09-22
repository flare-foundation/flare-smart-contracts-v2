// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IInstructions } from "../../../../contracts/userInterfaces/tee/IInstructions.sol";
import { IMachineEmergencyPause } from "../../../../contracts/userInterfaces/tee/IMachineEmergencyPause.sol";
import { IMachineManager } from "../../../../contracts/userInterfaces/tee/IMachineManager.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { IFlareGovernance } from "../../../../contracts/userInterfaces/IFlareGovernance.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { IDiamond } from "../../../../contracts/diamond/interfaces/IDiamond.sol";
import { IDiamondCut } from "../../../../contracts/diamond/interfaces/IDiamondCut.sol";
import { MachineManager } from "../../../../contracts/tee/library/MachineManager.sol";
import { PublicKey } from "../../../../contracts/userInterfaces/IPublicKey.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface ITestEmHelper {
    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        IMachineManager.TeeStatus _status,
        string calldata _url
    ) external;
}

/// @dev Test-only facet to write TEE machine state directly into ERC-7201 storage,
///      bypassing the full registration/attestation flow.
contract TestEmHelperFacet is ITestEmHelper {
    using EnumerableSet for EnumerableSet.AddressSet;

    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        IMachineManager.TeeStatus _status,
        string calldata _url
    )
        external
    {
        MachineManager.State storage s = MachineManager.getState();
        s.teeMachineStates[_teeId] = MachineManager.TeeMachineState({
            extensionId: _extensionId,
            teePublicKey: PublicKey(bytes32(0), bytes32(0)),
            initialTeeId: _teeId,
            initialSigningPolicyId: 0,
            owner: _owner,
            teeProxyId: _teeId,
            status: _status,
            lastStatusChangeTs: uint64(block.timestamp),
            codeHash: bytes32(0),
            platform: bytes32(0),
            governanceHash: bytes32(0),
            url: _url
        });
        if (_status == IMachineManager.TeeStatus.PRODUCTION) {
            s.activeTeeIds.add(_teeId);
            s.extensionActiveTeeIds[_extensionId].add(_teeId);
        }
    }
}

contract MachineEmergencyPauseFacetTest is Test {

    uint256 private constant GRACE_SECONDS = 7200;

    IIFlareTeeManager private flareTeeManager;
    ITestEmHelper private helper;

    address private initialGovernance;
    address private addressUpdater;
    address private extensionOwner;

    uint256 private extensionId;

    address[] private addrs;

    function setUp() public {
        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        extensionOwner = makeAddr("extensionOwner");
        addrs = new address[](2);
        addrs[0] = makeAddr("addr1");
        addrs[1] = makeAddr("addr2");

        flareTeeManager = FlareTeeManagerDeployer.deployFacets(FlareTeeManagerDeployer.DeployParams({
            governanceSettings: IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 6,
            challengeValidityDurationSeconds: 600,
            defaultFee: 1000,
            publicExtensionCreationEnabled: true,
            emergencyUnpauseGracePeriodSeconds: GRACE_SECONDS
        }));

        // Add a test helper facet to inject TEE machine state directly
        TestEmHelperFacet helperImpl = new TestEmHelperFacet();
        bytes4[] memory helperSelectors = new bytes4[](1);
        helperSelectors[0] = ITestEmHelper.setTeeMachineState.selector;
        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](1);
        cuts[0] = IDiamond.FacetCut(address(helperImpl), IDiamond.FacetCutAction.Add, helperSelectors);
        vm.prank(initialGovernance);
        IDiamondCut(address(flareTeeManager)).diamondCut(cuts, address(0), "");
        helper = ITestEmHelper(address(flareTeeManager));

        // Wire address updater so the diamond resolves it
        bytes32[] memory nameHashes = new bytes32[](6);
        nameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        nameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        nameHashes[2] = keccak256(abi.encode("RewardManager"));
        nameHashes[3] = keccak256(abi.encode("Relay"));
        nameHashes[4] = keccak256(abi.encode("Fdc2Hub"));
        nameHashes[5] = keccak256(abi.encode("Fdc2Verification"));
        address[] memory addresses = new address[](6);
        addresses[0] = addressUpdater;
        addresses[1] = makeAddr("FlareSystemsManager");
        addresses[2] = makeAddr("RewardManager");
        addresses[3] = makeAddr("Relay");
        addresses[4] = makeAddr("Fdc2Hub");
        addresses[5] = makeAddr("Fdc2Verification");
        vm.prank(addressUpdater);
        flareTeeManager.updateContractAddresses(nameHashes, addresses);

        // Register an extension
        vm.prank(extensionOwner);
        extensionId = flareTeeManager.register(ITeeExtensionStateVerifier(address(0)), makeAddr("instructionsSender"));
    }

    // =========================================================================
    // Init param
    // =========================================================================

    function testInitGracePeriodApplied() public {
        assertEq(flareTeeManager.getEmergencyUnpauseGracePeriodSeconds(), GRACE_SECONDS);
    }

    // =========================================================================
    // addExtensionEmergencyPausers / Unpausers
    // =========================================================================

    function testAddExtensionEmergencyPausers() public {
        vm.expectEmit();
        emit IMachineEmergencyPause.ExtensionEmergencyPausersAdded(extensionId, addrs);
        vm.prank(extensionOwner);
        flareTeeManager.addExtensionEmergencyPausers(extensionId, addrs);
        assertTrue(flareTeeManager.isExtensionEmergencyPauser(extensionId, addrs[0]));
        assertTrue(flareTeeManager.isExtensionEmergencyPauser(extensionId, addrs[1]));
        assertEq(flareTeeManager.getExtensionEmergencyPausers(extensionId).length, 2);
    }

    function testAddExtensionEmergencyPausersRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.addExtensionEmergencyPausers(extensionId, addrs);
    }

    function testAddExtensionEmergencyPausersRevertNoAddresses() public {
        vm.prank(extensionOwner);
        vm.expectRevert(ITeeCommonErrors.NoAddresses.selector);
        flareTeeManager.addExtensionEmergencyPausers(extensionId, new address[](0));
    }

    function testAddExtensionEmergencyPausersRevertInvalidAddress() public {
        address[] memory bad = new address[](1);
        bad[0] = address(0);
        vm.prank(extensionOwner);
        vm.expectRevert(ITeeCommonErrors.InvalidAddress.selector);
        flareTeeManager.addExtensionEmergencyPausers(extensionId, bad);
    }

    function testAddExtensionEmergencyPausersRevertAlreadyInSet() public {
        vm.prank(extensionOwner);
        flareTeeManager.addExtensionEmergencyPausers(extensionId, addrs);
        vm.prank(extensionOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ITeeCommonErrors.AddressAlreadyInSet.selector, addrs[0])
        );
        flareTeeManager.addExtensionEmergencyPausers(extensionId, addrs);
    }

    function testRemoveExtensionEmergencyPausers() public {
        vm.prank(extensionOwner);
        flareTeeManager.addExtensionEmergencyPausers(extensionId, addrs);
        vm.expectEmit();
        emit IMachineEmergencyPause.ExtensionEmergencyPausersRemoved(extensionId, addrs);
        vm.prank(extensionOwner);
        flareTeeManager.removeExtensionEmergencyPausers(extensionId, addrs);
        assertEq(flareTeeManager.getExtensionEmergencyPausers(extensionId).length, 0);
    }

    function testRemoveExtensionEmergencyPausersRevertNotInSet() public {
        vm.prank(extensionOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ITeeCommonErrors.AddressNotInSet.selector, addrs[0])
        );
        flareTeeManager.removeExtensionEmergencyPausers(extensionId, addrs);
    }

    function testAddExtensionEmergencyUnpausers() public {
        vm.expectEmit();
        emit IMachineEmergencyPause.ExtensionEmergencyUnpausersAdded(extensionId, addrs);
        vm.prank(extensionOwner);
        flareTeeManager.addExtensionEmergencyUnpausers(extensionId, addrs);
        assertTrue(flareTeeManager.isExtensionEmergencyUnpauser(extensionId, addrs[0]));
    }

    function testRemoveExtensionEmergencyUnpausers() public {
        vm.prank(extensionOwner);
        flareTeeManager.addExtensionEmergencyUnpausers(extensionId, addrs);
        vm.expectEmit();
        emit IMachineEmergencyPause.ExtensionEmergencyUnpausersRemoved(extensionId, addrs);
        vm.prank(extensionOwner);
        flareTeeManager.removeExtensionEmergencyUnpausers(extensionId, addrs);
        assertEq(flareTeeManager.getExtensionEmergencyUnpausers(extensionId).length, 0);
    }

    // =========================================================================
    // emergencyPauseExtension / emergencyUnpauseExtension
    // =========================================================================

    function testEmergencyPauseByExtensionOwner() public {
        vm.expectEmit();
        emit IMachineEmergencyPause.ExtensionEmergencyPaused(extensionId);
        vm.prank(extensionOwner);
        flareTeeManager.emergencyPauseExtension(extensionId);
        assertTrue(flareTeeManager.isExtensionEmergencyPaused(extensionId));
    }

    function testEmergencyPauseByPauser() public {
        address pauser = makeAddr("p");
        address[] memory list = new address[](1);
        list[0] = pauser;
        vm.prank(extensionOwner);
        flareTeeManager.addExtensionEmergencyPausers(extensionId, list);
        vm.prank(pauser);
        flareTeeManager.emergencyPauseExtension(extensionId);
        assertTrue(flareTeeManager.isExtensionEmergencyPaused(extensionId));
    }

    function testEmergencyPauseRevertNotOwnerOrPauser() public {
        address stranger = makeAddr("stranger");
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(ITeeCommonErrors.NotOwnerOrPauser.selector, stranger)
        );
        flareTeeManager.emergencyPauseExtension(extensionId);
    }

    function testEmergencyPauseRevertAlreadyPaused() public {
        vm.prank(extensionOwner);
        flareTeeManager.emergencyPauseExtension(extensionId);
        vm.prank(extensionOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IMachineEmergencyPause.ExtensionAlreadyEmergencyPaused.selector, extensionId)
        );
        flareTeeManager.emergencyPauseExtension(extensionId);
    }

    function testEmergencyUnpauseSetsLastUnpauseTs() public {
        vm.prank(extensionOwner);
        flareTeeManager.emergencyPauseExtension(extensionId);
        uint64 expectedTs = uint64(vm.getBlockTimestamp());
        vm.expectEmit();
        emit IMachineEmergencyPause.ExtensionEmergencyUnpaused(extensionId, expectedTs);
        vm.prank(extensionOwner);
        flareTeeManager.emergencyUnpauseExtension(extensionId);
        assertFalse(flareTeeManager.isExtensionEmergencyPaused(extensionId));
        assertEq(flareTeeManager.getLastUnpauseTs(extensionId), expectedTs);
    }

    function testEmergencyUnpauseByUnpauser() public {
        address unpauser = makeAddr("u");
        address[] memory list = new address[](1);
        list[0] = unpauser;
        vm.prank(extensionOwner);
        flareTeeManager.addExtensionEmergencyUnpausers(extensionId, list);
        vm.prank(extensionOwner);
        flareTeeManager.emergencyPauseExtension(extensionId);
        vm.prank(unpauser);
        flareTeeManager.emergencyUnpauseExtension(extensionId);
        assertFalse(flareTeeManager.isExtensionEmergencyPaused(extensionId));
    }

    function testEmergencyUnpauseRevertNotOwnerOrUnpauser() public {
        vm.prank(extensionOwner);
        flareTeeManager.emergencyPauseExtension(extensionId);
        address stranger = makeAddr("stranger2");
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(ITeeCommonErrors.NotOwnerOrUnpauser.selector, stranger)
        );
        flareTeeManager.emergencyUnpauseExtension(extensionId);
    }

    function testEmergencyUnpauseRevertNotPaused() public {
        vm.prank(extensionOwner);
        vm.expectRevert(
            abi.encodeWithSelector(IMachineEmergencyPause.ExtensionNotEmergencyPaused.selector, extensionId)
        );
        flareTeeManager.emergencyUnpauseExtension(extensionId);
    }

    // =========================================================================
    // Governance grace setter
    // =========================================================================

    function testSetGracePeriod() public {
        vm.expectEmit();
        emit IMachineEmergencyPause.EmergencyUnpauseGracePeriodSet(3600);
        vm.prank(initialGovernance);
        flareTeeManager.setEmergencyUnpauseGracePeriodSeconds(3600);
        assertEq(flareTeeManager.getEmergencyUnpauseGracePeriodSeconds(), 3600);
    }

    function testSetGracePeriodRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        flareTeeManager.setEmergencyUnpauseGracePeriodSeconds(3600);
    }

    function testSetGracePeriodRevertTooLong() public {
        vm.prank(initialGovernance);
        vm.expectRevert(
            abi.encodeWithSelector(IMachineEmergencyPause.GracePeriodTooLong.selector, 86401)
        );
        flareTeeManager.setEmergencyUnpauseGracePeriodSeconds(86401);
    }

    function testSetGracePeriodRevertTooShort() public {
        // 30 minutes - 1 second is below MIN_GRACE_PERIOD_SECONDS.
        uint256 tooShort = 30 minutes - 1;
        vm.prank(initialGovernance);
        vm.expectRevert(
            abi.encodeWithSelector(IMachineEmergencyPause.GracePeriodTooShort.selector, tooShort)
        );
        flareTeeManager.setEmergencyUnpauseGracePeriodSeconds(tooShort);
    }

    // =========================================================================
    // Read getters are not filtered by the emergency overlay
    // =========================================================================

    function testGetActiveTeeMachinesNotFiltered() public {
        address teeId = makeAddr("tee2");
        helper.setTeeMachineState(teeId, extensionId, makeAddr("owner2"), IMachineManager.TeeStatus.PRODUCTION, "url");

        vm.prank(extensionOwner);
        flareTeeManager.emergencyPauseExtension(extensionId);

        // Per plan: informational getters are NOT filtered.
        (address[] memory ids,) = flareTeeManager.getActiveTeeMachines(extensionId);
        assertEq(ids.length, 1);
        assertEq(ids[0], teeId);
    }

    function testGetRandomTeeIdsNotFiltered() public {
        // Consistent with the other informational getters: returns the raw active set
        // even during emergency pause. The actual "no work dispatched" guarantee is
        // enforced one frame later, by the Instructions.sendInstructions gate.
        address teeId = makeAddr("tee1");
        helper.setTeeMachineState(teeId, extensionId, makeAddr("owner1"), IMachineManager.TeeStatus.PRODUCTION, "url");

        // Mock the relay's randomness source — getRandomTeeIds reads it.
        vm.mockCall(
            makeAddr("Relay"),
            abi.encodeWithSignature("getRandomNumber()"),
            abi.encode(uint256(42), true, uint256(0))
        );

        vm.prank(extensionOwner);
        flareTeeManager.emergencyPauseExtension(extensionId);

        address[] memory ids = flareTeeManager.getRandomTeeIds(extensionId, 1);
        assertEq(ids.length, 1);
        assertEq(ids[0], teeId);
    }

    // =========================================================================
    // pause() grace protection
    // =========================================================================

    function testThirdPartyPauseBlockedDuringEmergencyPause() public {
        address teeId = makeAddr("tee3");
        helper.setTeeMachineState(teeId, extensionId, makeAddr("owner3"), IMachineManager.TeeStatus.PRODUCTION, "url");

        vm.prank(extensionOwner);
        flareTeeManager.emergencyPauseExtension(extensionId);

        address stranger = makeAddr("stranger3");
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IMachineEmergencyPause.EmergencyProtectionActive.selector, extensionId)
        );
        flareTeeManager.pause(teeId);
    }

    function testThirdPartyPauseBlockedDuringGraceWindow() public {
        address teeId = makeAddr("tee4");
        helper.setTeeMachineState(teeId, extensionId, makeAddr("owner4"), IMachineManager.TeeStatus.PRODUCTION, "url");

        vm.prank(extensionOwner);
        flareTeeManager.emergencyPauseExtension(extensionId);
        vm.prank(extensionOwner);
        flareTeeManager.emergencyUnpauseExtension(extensionId);

        // Immediately after unpause: still protected
        address stranger = makeAddr("stranger4");
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IMachineEmergencyPause.EmergencyProtectionActive.selector, extensionId)
        );
        flareTeeManager.pause(teeId);

        // Halfway through the grace: still protected
        vm.warp(vm.getBlockTimestamp() + GRACE_SECONDS / 2);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IMachineEmergencyPause.EmergencyProtectionActive.selector, extensionId)
        );
        flareTeeManager.pause(teeId);

        // 1 second before grace ends: still protected
        vm.warp(vm.getBlockTimestamp() + GRACE_SECONDS / 2 - 1);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IMachineEmergencyPause.EmergencyProtectionActive.selector, extensionId)
        );
        flareTeeManager.pause(teeId);

        // At the grace boundary: protection lifted, third-party pause succeeds.
        vm.warp(vm.getBlockTimestamp() + 1);
        vm.prank(stranger);
        flareTeeManager.pause(teeId);
        assertEq(
            uint8(flareTeeManager.getTeeMachineStatus(teeId)),
            uint8(IMachineManager.TeeStatus.SUSPENDED)
        );
    }

    function testThirdPartyPauseBlockedWhileSystemExtensionPaused() public {
        // A machine in non-system extension N — extension 0 is NOT paused yet.
        address teeId = makeAddr("teeSysA");
        helper.setTeeMachineState(
            teeId, extensionId, makeAddr("ownerSysA"), IMachineManager.TeeStatus.PRODUCTION, "url"
        );

        // Pause the system extension (id 0). Caller must be its owner — Flare governance.
        vm.prank(initialGovernance);
        flareTeeManager.emergencyPauseExtension(0);

        // Third-party pause on the extension-N machine must now revert because
        // availability refresh requires the system extension and it's paused.
        address stranger = makeAddr("strangerSysA");
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IMachineEmergencyPause.EmergencyProtectionActive.selector, extensionId)
        );
        flareTeeManager.pause(teeId);
    }

    function testThirdPartyPauseBlockedDuringSystemExtensionGrace() public {
        address teeId = makeAddr("teeSysB");
        helper.setTeeMachineState(
            teeId, extensionId, makeAddr("ownerSysB"), IMachineManager.TeeStatus.PRODUCTION, "url"
        );

        vm.prank(initialGovernance);
        flareTeeManager.emergencyPauseExtension(0);
        vm.prank(initialGovernance);
        flareTeeManager.emergencyUnpauseExtension(0);

        // Immediately after system unpause: still in grace, third-party pause blocked.
        address stranger = makeAddr("strangerSysB");
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IMachineEmergencyPause.EmergencyProtectionActive.selector, extensionId)
        );
        flareTeeManager.pause(teeId);

        // After the system extension's grace ends (N was never paused), third-party
        // pause works again (machine's availability is stale by default, owner had time).
        vm.warp(vm.getBlockTimestamp() + GRACE_SECONDS);
        vm.prank(stranger);
        flareTeeManager.pause(teeId);
        assertEq(
            uint8(flareTeeManager.getTeeMachineStatus(teeId)),
            uint8(IMachineManager.TeeStatus.SUSPENDED)
        );
    }

    function testOwnerCanPauseDuringEmergencyPause() public {
        address teeOwner = makeAddr("owner5");
        address teeId = makeAddr("tee5");
        helper.setTeeMachineState(teeId, extensionId, teeOwner, IMachineManager.TeeStatus.PRODUCTION, "url");

        vm.prank(extensionOwner);
        flareTeeManager.emergencyPauseExtension(extensionId);

        // Owner branch is unaffected by the emergency overlay.
        vm.prank(teeOwner);
        flareTeeManager.pause(teeId);
        assertEq(
            uint8(flareTeeManager.getTeeMachineStatus(teeId)),
            uint8(IMachineManager.TeeStatus.PAUSED)
        );
    }

    // =========================================================================
    // Instructions.sendInstructions extension-emergency gate
    // =========================================================================

    function testSendInstructionsRevertsWhenExtensionEmergencyPaused() public {
        address teeId = makeAddr("tee6");
        helper.setTeeMachineState(teeId, extensionId, makeAddr("owner6"), IMachineManager.TeeStatus.PRODUCTION, "url");

        vm.prank(extensionOwner);
        flareTeeManager.emergencyPauseExtension(extensionId);

        // Build a minimal sendInstructions payload.
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeId;
        IInstructions.TeeInstructionParams memory params = IInstructions.TeeInstructionParams({
            opType: bytes32("OPTYPE"),
            opCommand: bytes32("CMD"),
            message: hex"01",
            cosigners: new address[](0),
            cosignersThreshold: 0,
            claimBackAddress: address(0)
        });

        // Caller must be the extension's registered instructions sender (set in setUp).
        address instructionsSender = makeAddr("instructionsSender");
        vm.deal(instructionsSender, 1 ether);
        vm.prank(instructionsSender);
        vm.expectRevert(
            abi.encodeWithSelector(IMachineEmergencyPause.EmergencyPauseActive.selector, extensionId)
        );
        flareTeeManager.sendInstructions{value: 0}(teeIds, params);
    }

    function testSendSystemInstructionsRevertsWhenExtensionEmergencyPaused() public {
        // Register a system-instructions sender so we can reach the system-op path.
        address[] memory senders = new address[](1);
        senders[0] = address(this);
        vm.prank(initialGovernance);
        flareTeeManager.registerSystemInstructionsSenders(senders);

        address teeId = makeAddr("tee7");
        helper.setTeeMachineState(teeId, extensionId, makeAddr("owner7"), IMachineManager.TeeStatus.PRODUCTION, "url");

        vm.prank(extensionOwner);
        flareTeeManager.emergencyPauseExtension(extensionId);

        address[] memory teeIds = new address[](1);
        teeIds[0] = teeId;
        IInstructions.TeeInstructionParams memory params = IInstructions.TeeInstructionParams({
            opType: bytes32("F_SYS"), // system opType — would otherwise skip status check
            opCommand: bytes32("CMD"),
            message: hex"01",
            cosigners: new address[](0),
            cosignersThreshold: 0,
            claimBackAddress: address(0)
        });

        vm.expectRevert(
            abi.encodeWithSelector(IMachineEmergencyPause.EmergencyPauseActive.selector, extensionId)
        );
        flareTeeManager.sendSystemInstructions(bytes32(0), teeIds, params);
    }
}
