// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { MockSafe } from "../../../mock/MockSafe.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IExtensionGovernance } from "../../../../contracts/userInterfaces/tee/IExtensionGovernance.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract ExtensionGovernanceFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;

    address private realOwnerExtension1;
    address private realOwnerExtension2;

    address private initialGovernance;
    address private addressUpdater;

    uint256 private extensionId;
    uint256 private extensionId2;

    address[] private signers;

    function setUp() public {
        realOwnerExtension1 = makeAddr("realOwnerExtension1");
        realOwnerExtension2 = makeAddr("realOwnerExtension2");

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("addressUpdater");

        flareTeeManager = FlareTeeManagerDeployer.deployFacets(FlareTeeManagerDeployer.DeployParams({
            governanceSettings: IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 6,
            challengeValidityDurationSeconds: 600,
            defaultFee: 1000,
            publicExtensionCreationEnabled: true,
            emergencyUnpauseGracePeriodSeconds: 7200
        }));

        bytes32[] memory nameHashes = new bytes32[](6);
        address[] memory addresses = new address[](6);
        nameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        nameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        nameHashes[2] = keccak256(abi.encode("RewardManager"));
        nameHashes[3] = keccak256(abi.encode("Relay"));
        nameHashes[4] = keccak256(abi.encode("Fdc2Hub"));
        nameHashes[5] = keccak256(abi.encode("Fdc2Verification"));
        addresses[0] = addressUpdater;
        addresses[1] = makeAddr("FlareSystemsManager");
        addresses[2] = makeAddr("RewardManager");
        addresses[3] = makeAddr("Relay");
        addresses[4] = makeAddr("Fdc2Hub");
        addresses[5] = makeAddr("Fdc2Verification");

        vm.prank(addressUpdater);
        flareTeeManager.updateContractAddresses(nameHashes, addresses);

        // Register extensions via the diamond
        address instructionsSender1 = makeAddr("instructionsSender1");
        address instructionsSender2 = makeAddr("instructionsSender2");
        ITeeExtensionStateVerifier verifier = ITeeExtensionStateVerifier(address(0));

        vm.prank(realOwnerExtension1);
        extensionId = flareTeeManager.register(verifier, instructionsSender1);

        vm.prank(realOwnerExtension2);
        extensionId2 = flareTeeManager.register(verifier, instructionsSender2);

        signers = new address[](2);
        (signers[0], ) = makeAddrAndKey("signer1");
        (signers[1], ) = makeAddrAndKey("signer2");
    }

    // =========================================================================
    // setNewTeeGovernance
    // =========================================================================

    function testSetNewTeeGovernanceRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.setNewTeeGovernance(
            extensionId,
            signers,
            1
        );
    }

    function testSetNewTeeGovernanceRevertNoSigners() public {
        vm.prank(realOwnerExtension1);
        vm.expectRevert(IExtensionGovernance.NoSigners.selector);
        flareTeeManager.setNewTeeGovernance(extensionId, new address[](0), 1);
    }

    function testSetNewTeeGovernanceRevertInvalidThreshold() public {
        vm.startPrank(realOwnerExtension1);
        vm.expectRevert(ITeeCommonErrors.InvalidThreshold.selector);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 0);
        vm.expectRevert(ITeeCommonErrors.InvalidThreshold.selector);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 3);
        vm.stopPrank();
    }

    function testSetNewTeeGovernanceRevertSignerAlreadyExists() public {
        signers[1] = signers[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                IExtensionGovernance.SignerAlreadyExists.selector,
                signers[0]
            )
        );
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);
    }

    function testSetNewTeeGovernanceRevertInvalidSigner() public {
        signers[1] = address(0);
        vm.expectRevert(IExtensionGovernance.InvalidSigner.selector);
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);
    }

    function testSetNewTeeGovernance() public {
        bytes32 governanceHash1 = keccak256(abi.encode(signers, 1));
        vm.startPrank(realOwnerExtension1);
        vm.expectEmit();
        emit IExtensionGovernance.NewTeeGovernanceSet(extensionId, governanceHash1, signers, 1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);

        bytes32 governanceHash2 = keccak256(abi.encode(signers, 2));
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 2);
        assertEq(flareTeeManager.getLatestTeeGovernanceHash(extensionId), governanceHash2);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);
        assertEq(flareTeeManager.getLatestTeeGovernanceHash(extensionId), governanceHash1);
        vm.stopPrank();
    }

    // =========================================================================
    // getLatestTeeGovernanceHash
    // =========================================================================

    function testGetLatestTeeGovernanceHash() public {
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);

        bytes32 governanceHash = keccak256(abi.encode(signers, 1));
        assertEq(flareTeeManager.getLatestTeeGovernanceHash(extensionId), governanceHash);
    }

    // =========================================================================
    // getTeeGovernanceThreshold
    // =========================================================================

    function testGetTeeGovernanceThreshold() public {
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);

        uint64 returnedThreshold =
            flareTeeManager.getTeeGovernanceThreshold(
                extensionId, flareTeeManager.getLatestTeeGovernanceHash(extensionId)
            );
        assertEq(returnedThreshold, 1);
    }

    function testGetTeeGovernanceThresholdRevertInvalidGovernanceHash() public {
        vm.expectRevert(ITeeCommonErrors.InvalidGovernanceHash.selector);
        flareTeeManager.getTeeGovernanceThreshold(extensionId2, bytes32(0));
    }

    // =========================================================================
    // isTeeGovernanceSigner
    // =========================================================================

    function testIsTeeGovernanceSigner() public {
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 2);

        bytes32 governanceHash = flareTeeManager.getLatestTeeGovernanceHash(extensionId);
        assertFalse(flareTeeManager.isTeeGovernanceSigner(extensionId, governanceHash, realOwnerExtension1));
        assertTrue(flareTeeManager.isTeeGovernanceSigner(extensionId, governanceHash, signers[0]));
        assertTrue(flareTeeManager.isTeeGovernanceSigner(extensionId, governanceHash, signers[1]));
    }

    // =========================================================================
    // getTeeGovernance
    // =========================================================================

    function testGetTeeGovernanceRevertInvalidGovernanceHash() public {
        vm.expectRevert(ITeeCommonErrors.InvalidGovernanceHash.selector);
        flareTeeManager.getTeeGovernance(extensionId2, bytes32(0));
    }

    function testGetTeeGovernance() public {
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);

        bytes32 governanceHash = flareTeeManager.getLatestTeeGovernanceHash(extensionId);
        (address[] memory returnedSigners, uint64 returnedThreshold, address returnedSafe) =
            flareTeeManager.getTeeGovernance(extensionId, governanceHash);

        assertEq(returnedSigners[0], signers[0]);
        assertEq(returnedSigners[1], signers[1]);
        assertEq(returnedThreshold, 1);
        assertEq(returnedSafe, address(0));
    }

    // =========================================================================
    // getLatestTeeGovernance
    // =========================================================================

    function testGetLatestTeeGovernanceRevertInvalidGovernanceHash() public {
        // With no governance set, latestTeeGovernanceHash == bytes32(0), and the lookup of
        // hash 0 in governanceHashToTeeGovernance returns threshold 0 — which trips
        // InvalidGovernanceHash. This replaces the previous GovernanceNotSet error.
        vm.expectRevert(ITeeCommonErrors.InvalidGovernanceHash.selector);
        flareTeeManager.getLatestTeeGovernance(extensionId);
    }

    function testGetLatestTeeGovernance() public {
        vm.startPrank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 2);
        vm.stopPrank();

        address[] memory returnedSigners;
        uint64 returnedThreshold;
        address returnedSafe;
        (returnedSigners, returnedThreshold, returnedSafe) =
            flareTeeManager.getLatestTeeGovernance(extensionId);

        assertEq(returnedSigners[0], signers[0]);
        assertEq(returnedSigners[1], signers[1]);
        assertEq(returnedThreshold, 2);
        assertEq(returnedSafe, address(0));
    }

    // =========================================================================
    // isGovernanceHashValid
    // =========================================================================

    function testIsGovernanceHashValid() public {
        bytes32 governanceHash = keccak256(abi.encode(signers, 1));
        // no governance set
        assertFalse(flareTeeManager.isGovernanceHashValid(extensionId, governanceHash));

        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);

        vm.prank(realOwnerExtension2);
        flareTeeManager.setNewTeeGovernance(extensionId2, signers, 2);

        assertFalse(flareTeeManager.isGovernanceHashValid(extensionId2, governanceHash));
        assertTrue(flareTeeManager.isGovernanceHashValid(extensionId, governanceHash));

        assertFalse(flareTeeManager.isGovernanceHashValid(extensionId, bytes32(0x0)));
        assertTrue(
            flareTeeManager.isGovernanceHashValid(
                extensionId, flareTeeManager.getLatestTeeGovernanceHash(extensionId)
            )
        );
    }

    // =========================================================================
    // setNewTeeGovernanceSafe
    // =========================================================================

    function testSetNewTeeGovernanceSafeRevertOnlyExtensionOwner() public {
        MockSafe safe = new MockSafe(signers, 1);
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.setNewTeeGovernanceSafe(extensionId, address(safe));
    }

    function testSetNewTeeGovernanceSafe() public {
        MockSafe safe = new MockSafe(signers, 2);
        bytes32 governanceHash = _safeGovernanceHash(address(safe), signers, 2);

        vm.expectEmit();
        emit IExtensionGovernance.NewTeeSafeGovernanceSet(
            extensionId, governanceHash, address(safe), signers, 2
        );
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernanceSafe(extensionId, address(safe));

        assertEq(flareTeeManager.getLatestTeeGovernanceHash(extensionId), governanceHash);
        assertTrue(flareTeeManager.isGovernanceHashValid(extensionId, governanceHash));
        assertTrue(flareTeeManager.isTeeGovernanceSigner(extensionId, governanceHash, signers[0]));
        assertTrue(flareTeeManager.isTeeGovernanceSigner(extensionId, governanceHash, signers[1]));
        assertFalse(flareTeeManager.isTeeGovernanceSigner(extensionId, governanceHash, address(safe)));

        (address[] memory returnedSigners, uint64 returnedThreshold, address returnedSafe) =
            flareTeeManager.getTeeGovernance(extensionId, governanceHash);
        assertEq(returnedSigners.length, 2);
        assertEq(returnedSigners[0], signers[0]);
        assertEq(returnedSigners[1], signers[1]);
        assertEq(returnedThreshold, 2);
        assertEq(returnedSafe, address(safe));

        (returnedSigners, returnedThreshold, returnedSafe) =
            flareTeeManager.getLatestTeeGovernance(extensionId);
        assertEq(returnedSigners.length, 2);
        assertEq(returnedThreshold, 2);
        assertEq(returnedSafe, address(safe));
    }

    function testSetNewTeeGovernanceSafeRepointsLatest() public {
        MockSafe safe = new MockSafe(signers, 1);
        bytes32 safeGovernanceHash = _safeGovernanceHash(address(safe), signers, 1);

        vm.startPrank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernanceSafe(extensionId, address(safe));
        // Point latest elsewhere, then re-point back to the (already recorded) Safe governance.
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 2);
        assertEq(flareTeeManager.getLatestTeeGovernanceHash(extensionId), keccak256(abi.encode(signers, 2)));
        flareTeeManager.setNewTeeGovernanceSafe(extensionId, address(safe));
        vm.stopPrank();

        assertEq(flareTeeManager.getLatestTeeGovernanceHash(extensionId), safeGovernanceHash);
        (address[] memory returnedSigners, uint64 returnedThreshold, address returnedSafe) =
            flareTeeManager.getTeeGovernance(extensionId, safeGovernanceHash);
        assertEq(returnedSigners.length, 2);
        assertEq(returnedThreshold, 1);
        assertEq(returnedSafe, address(safe));
    }

    function testSetNewTeeGovernanceSafeRotationChangesHash() public {
        MockSafe safe = new MockSafe(signers, 1);
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernanceSafe(extensionId, address(safe));
        bytes32 oldHash = flareTeeManager.getLatestTeeGovernanceHash(extensionId);

        address[] memory rotated = new address[](2);
        rotated[0] = signers[0];
        rotated[1] = makeAddr("rotatedSigner");
        safe.setOwners(rotated);

        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernanceSafe(extensionId, address(safe));
        bytes32 newHash = flareTeeManager.getLatestTeeGovernanceHash(extensionId);

        assertNotEq(newHash, oldHash);
        assertEq(newHash, _safeGovernanceHash(address(safe), rotated, 1));
        // Both snapshots stay recorded and immutable.
        assertTrue(flareTeeManager.isGovernanceHashValid(extensionId, oldHash));
        assertTrue(flareTeeManager.isTeeGovernanceSigner(extensionId, oldHash, signers[1]));
        assertFalse(flareTeeManager.isTeeGovernanceSigner(extensionId, newHash, signers[1]));
    }

    function testSetNewTeeGovernanceSafeRevertNoSigners() public {
        MockSafe safe = new MockSafe(new address[](0), 1);
        vm.expectRevert(IExtensionGovernance.NoSigners.selector);
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernanceSafe(extensionId, address(safe));
    }

    function testSetNewTeeGovernanceSafeRevertInvalidThreshold() public {
        MockSafe safe = new MockSafe(signers, 0);
        vm.startPrank(realOwnerExtension1);
        vm.expectRevert(ITeeCommonErrors.InvalidThreshold.selector);
        flareTeeManager.setNewTeeGovernanceSafe(extensionId, address(safe));
        safe.setThreshold(3);
        vm.expectRevert(ITeeCommonErrors.InvalidThreshold.selector);
        flareTeeManager.setNewTeeGovernanceSafe(extensionId, address(safe));
        vm.stopPrank();
    }

    function testSetNewTeeGovernanceSafeRevertSignerAlreadyExists() public {
        address[] memory duplicated = new address[](2);
        duplicated[0] = signers[0];
        duplicated[1] = signers[0];
        MockSafe safe = new MockSafe(duplicated, 1);
        vm.expectRevert(
            abi.encodeWithSelector(IExtensionGovernance.SignerAlreadyExists.selector, signers[0])
        );
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernanceSafe(extensionId, address(safe));
    }

    function testSetNewTeeGovernanceSafeRevertInvalidSigner() public {
        address[] memory withZero = new address[](2);
        withZero[0] = signers[0];
        withZero[1] = address(0);
        MockSafe safe = new MockSafe(withZero, 1);
        vm.expectRevert(IExtensionGovernance.InvalidSigner.selector);
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernanceSafe(extensionId, address(safe));
    }

    function testSetNewTeeGovernanceSafeRevertNonContract() public {
        vm.expectRevert();
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernanceSafe(extensionId, makeAddr("notAContract"));
    }

    // =========================================================================
    // Test helpers
    // =========================================================================

    function _safeGovernanceHash(
        address _safe,
        address[] memory _owners,
        uint64 _threshold
    )
        private view
        returns (bytes32)
    {
        return keccak256(abi.encode(address(flareTeeManager), _safe, _owners, _threshold));
    }
}
