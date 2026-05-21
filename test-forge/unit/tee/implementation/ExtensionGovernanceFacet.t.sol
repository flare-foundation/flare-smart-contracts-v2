// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
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

        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 6,
            challengeValidityDurationSeconds: 600,
            defaultFee: 1000
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
        (address[] memory returnedSigners, uint64 returnedThreshold) =
            flareTeeManager.getTeeGovernance(extensionId, governanceHash);

        assertEq(returnedSigners[0], signers[0]);
        assertEq(returnedSigners[1], signers[1]);
        assertEq(returnedThreshold, 1);
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
        (returnedSigners, returnedThreshold) = flareTeeManager.getLatestTeeGovernance(extensionId);

        assertEq(returnedSigners[0], signers[0]);
        assertEq(returnedSigners[1], signers[1]);
        assertEq(returnedThreshold, 2);
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
}
