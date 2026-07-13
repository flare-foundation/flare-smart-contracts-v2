// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { SignatureHelper } from "../../../utils/SignatureHelper.sol";

import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IExtensionManager } from "../../../../contracts/userInterfaces/tee/IExtensionManager.sol";
import { IMachinePathManager, TEE_MACHINE_PATH_LIST }
    from "../../../../contracts/userInterfaces/tee/IMachinePathManager.sol";
import { SignedPayload } from "../../../../contracts/utils/lib/SignedPayload.sol";
import { IMachineManager } from "../../../../contracts/userInterfaces/tee/IMachineManager.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { Signature } from "../../../../contracts/userInterfaces/ISignature.sol";
import { PublicKey } from "../../../../contracts/userInterfaces/IPublicKey.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

import { IDiamond } from "../../../../contracts/diamond/interfaces/IDiamond.sol";
import { IDiamondCut } from "../../../../contracts/diamond/interfaces/IDiamondCut.sol";
import { MachineManager } from "../../../../contracts/tee/library/MachineManager.sol";

interface ITestMachinePathHelper {
    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform,
        bytes32 _governanceHash,
        IMachineManager.TeeStatus _status
    ) external;
}

/**
 * @notice Test-only facet that writes TEE machine state directly into MachineManager storage,
 *         bypassing the production registration + attestation flow. Mirrors the helper pattern
 *         used in WalletKeyManagerFacet.t.sol but specialised for machine-path tests where the
 *         codeHash, platform and governance hash must be controllable.
 */
contract TestMachinePathHelperFacet is ITestMachinePathHelper {

    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform,
        bytes32 _governanceHash,
        IMachineManager.TeeStatus _status
    )
        external
    {
        MachineManager.State storage s = MachineManager.getState();
        // owner must be non-zero — MachineManager.getTeeMachineState reverts TeeNotFound otherwise.
        s.teeMachineStates[_teeId] = MachineManager.TeeMachineState({
            extensionId: _extensionId,
            teePublicKey: PublicKey(bytes32(0), bytes32(0)),
            initialTeeId: _teeId,
            initialSigningPolicyId: 0,
            owner: address(uint160(uint256(uint160(_teeId)) ^ 1)),
            teeProxyId: _teeId,
            status: _status,
            lastStatusChangeTs: uint64(block.timestamp),
            codeHash: _codeHash,
            platform: _platform,
            governanceHash: _governanceHash,
            url: ""
        });
    }
}

// solhint-disable-next-line max-states-count
contract MachinePathManagerFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;
    ITestMachinePathHelper private helper;

    address private initialGovernance;
    address private addressUpdater;
    address private owner;
    address private otherOwner;            // owner of a second extension

    uint256 private extensionId;            // primary test extension
    uint256 private otherExtensionId;       // used to verify per-extension isolation + extension mismatch

    // Three coexisting governance configurations under `extensionId`.
    address[] private signersA;
    uint256[] private privKeysA;
    bytes32 private govHashA;

    address[] private signersB;
    uint256[] private privKeysB;
    bytes32 private govHashB;

    address[] private signersC;
    uint256[] private privKeysC;
    bytes32 private govHashC;

    // Code hashes — one per governance.
    bytes32 private codeHashA;
    bytes32 private codeHashB;
    bytes32 private codeHashC;
    bytes32 private platform;

    // Pre-registered TEE machine ids.
    address private teeA1;
    address private teeA2;
    address private teeB1;
    address private teeC1;
    address private teeA1Other;            // teeId under `otherExtensionId`

    function setUp() public {
        owner = makeAddr("owner");
        otherOwner = makeAddr("otherOwner");
        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("addressUpdater");

        platform = keccak256("platform");
        codeHashA = keccak256("codeHashA");
        codeHashB = keccak256("codeHashB");
        codeHashC = keccak256("codeHashC");

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

        // Wire external addresses through the addressUpdater.
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

        // Attach test-only helper facet via governance diamondCut.
        helper = ITestMachinePathHelper(address(flareTeeManager));
        _addHelperFacet();

        // Register two extensions.
        ITeeExtensionStateVerifier verifier = ITeeExtensionStateVerifier(address(0));
        vm.prank(owner);
        extensionId = flareTeeManager.register(verifier, makeAddr("instructionsSender"));
        vm.prank(otherOwner);
        otherExtensionId = flareTeeManager.register(verifier, makeAddr("instructionsSender2"));

        // Whitelist the platform.
        bytes32[] memory platforms = new bytes32[](1);
        platforms[0] = platform;
        vm.prank(initialGovernance);
        flareTeeManager.addSystemSupportedPlatforms(platforms);

        // Set up three governance configurations under `extensionId`.
        // signersA/B/C each have a single signer for easy threshold = 1 testing,
        // but the cross-governance-signer test below adds a fourth signer that overlaps B and C.
        signersA = new address[](1);
        privKeysA = new uint256[](1);
        (signersA[0], privKeysA[0]) = makeAddrAndKey("signerA1");
        govHashA = keccak256(abi.encode(signersA, uint64(1)));
        vm.prank(owner);
        flareTeeManager.setNewTeeGovernance(extensionId, signersA, 1);
        vm.prank(owner);
        flareTeeManager.addTeeVersion(extensionId, "vA", codeHashA, platforms);

        signersB = new address[](1);
        privKeysB = new uint256[](1);
        (signersB[0], privKeysB[0]) = makeAddrAndKey("signerB1");
        govHashB = keccak256(abi.encode(signersB, uint64(1)));
        vm.prank(owner);
        flareTeeManager.setNewTeeGovernance(extensionId, signersB, 1);
        vm.prank(owner);
        flareTeeManager.addTeeVersion(extensionId, "vB", codeHashB, platforms);

        signersC = new address[](1);
        privKeysC = new uint256[](1);
        (signersC[0], privKeysC[0]) = makeAddrAndKey("signerC1");
        govHashC = keccak256(abi.encode(signersC, uint64(1)));
        vm.prank(owner);
        flareTeeManager.setNewTeeGovernance(extensionId, signersC, 1);
        vm.prank(owner);
        flareTeeManager.addTeeVersion(extensionId, "vC", codeHashC, platforms);

        // Set up a governance under `otherExtensionId` so `extensionId` ≠ `otherExtensionId`
        // machines can be mismatch-tested.
        vm.prank(otherOwner);
        flareTeeManager.setNewTeeGovernance(otherExtensionId, signersA, 1);
        bytes32 govHashAOther = keccak256(abi.encode(signersA, uint64(1)));
        vm.prank(otherOwner);
        flareTeeManager.addTeeVersion(otherExtensionId, "vAOther", codeHashA, platforms);

        // Pre-register TEE machines (PRODUCTION) bound to their codeHashes + governance hashes
        // (the governance hash is now stored per-machine, not per-codeHash).
        teeA1 = makeAddr("teeA1");
        teeA2 = makeAddr("teeA2");
        teeB1 = makeAddr("teeB1");
        teeC1 = makeAddr("teeC1");
        teeA1Other = makeAddr("teeA1Other");
        helper.setTeeMachineState(
            teeA1, extensionId, codeHashA, platform, govHashA, IMachineManager.TeeStatus.PRODUCTION
        );
        helper.setTeeMachineState(
            teeA2, extensionId, codeHashA, platform, govHashA, IMachineManager.TeeStatus.PRODUCTION
        );
        helper.setTeeMachineState(
            teeB1, extensionId, codeHashB, platform, govHashB, IMachineManager.TeeStatus.PRODUCTION
        );
        helper.setTeeMachineState(
            teeC1, extensionId, codeHashC, platform, govHashC, IMachineManager.TeeStatus.PRODUCTION
        );
        helper.setTeeMachineState(
            teeA1Other, otherExtensionId, codeHashA, platform, govHashAOther,
            IMachineManager.TeeStatus.PRODUCTION
        );
    }

    // =========================================================================
    // createNewMachinePathList
    // =========================================================================

    function testCreateNewMachinePathListRevertOnlyExtensionOwnerOrOperator() public {
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwnerOrOperator.selector);
        flareTeeManager.createNewMachinePathList(extensionId);
    }

    function testCreateNewMachinePathListHappyPath() public {
        vm.prank(owner);
        vm.expectEmit();
        emit IMachinePathManager.MachinePathListStarted(extensionId, 1);
        uint256 nonce = flareTeeManager.createNewMachinePathList(extensionId);
        assertEq(nonce, 1, "first allocated nonce must be 1");
        assertEq(flareTeeManager.getMachinePathListsCount(extensionId), 1);
    }

    function testCreateNewMachinePathListMonotonicNonces() public {
        vm.startPrank(owner);
        uint256 n1 = flareTeeManager.createNewMachinePathList(extensionId);
        uint256 n2 = flareTeeManager.createNewMachinePathList(extensionId);
        uint256 n3 = flareTeeManager.createNewMachinePathList(extensionId);
        vm.stopPrank();
        assertEq(n1, 1);
        assertEq(n2, 2);
        assertEq(n3, 3);
        assertEq(flareTeeManager.getMachinePathListsCount(extensionId), 3);
    }

    function testCreateNewMachinePathListIndependentExtensions() public {
        vm.prank(owner);
        uint256 nE1 = flareTeeManager.createNewMachinePathList(extensionId);
        vm.prank(otherOwner);
        uint256 nE2 = flareTeeManager.createNewMachinePathList(otherExtensionId);
        // Both start at 1 — nonce sequences are per-extension.
        assertEq(nE1, 1);
        assertEq(nE2, 1);
    }

    // =========================================================================
    // addMachinePaths
    // =========================================================================

    function testAddMachinePathsRevertInvalidNonceZero() public {
        IMachinePathManager.MachinePath[] memory paths = _onePath(teeA1, teeA2);
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidNonce.selector);
        flareTeeManager.addMachinePaths(extensionId, 0, paths);
    }

    function testAddMachinePathsRevertInvalidNonceOutOfRange() public {
        IMachinePathManager.MachinePath[] memory paths = _onePath(teeA1, teeA2);
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidNonce.selector);
        flareTeeManager.addMachinePaths(extensionId, 999, paths);
    }

    function testAddMachinePathsRevertOnlyExtensionOwnerOrOperator() public {
        uint256 nonce = _newList();
        IMachinePathManager.MachinePath[] memory paths = _onePath(teeA1, teeA2);
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwnerOrOperator.selector);
        flareTeeManager.addMachinePaths(extensionId, nonce, paths);
    }

    function testAddMachinePathsRevertListAlreadyFinalized() public {
        uint256 nonce = _newList();
        vm.prank(owner);
        flareTeeManager.addMachinePaths(extensionId, nonce, _onePath(teeA1, teeA2));
        vm.prank(owner);
        flareTeeManager.finalizeMachinePathList(extensionId, nonce);
        vm.prank(owner);
        vm.expectRevert(IMachinePathManager.ListAlreadyFinalized.selector);
        flareTeeManager.addMachinePaths(extensionId, nonce, _onePath(teeA1, teeA2));
    }

    function testAddMachinePathsRevertNoPaths() public {
        uint256 nonce = _newList();
        IMachinePathManager.MachinePath[] memory paths = new IMachinePathManager.MachinePath[](0);
        vm.prank(owner);
        vm.expectRevert(IMachinePathManager.NoPaths.selector);
        flareTeeManager.addMachinePaths(extensionId, nonce, paths);
    }

    function testAddMachinePathsRevertNoSourceTeeIds() public {
        uint256 nonce = _newList();
        IMachinePathManager.MachinePath[] memory paths = new IMachinePathManager.MachinePath[](1);
        paths[0].sourceTeeIds = new address[](0);
        paths[0].destinationTeeIds = _arr1(teeA2);
        vm.prank(owner);
        vm.expectRevert(IMachinePathManager.NoSourceTeeIds.selector);
        flareTeeManager.addMachinePaths(extensionId, nonce, paths);
    }

    function testAddMachinePathsRevertNoDestinationTeeIds() public {
        uint256 nonce = _newList();
        IMachinePathManager.MachinePath[] memory paths = new IMachinePathManager.MachinePath[](1);
        paths[0].sourceTeeIds = _arr1(teeA1);
        paths[0].destinationTeeIds = new address[](0);
        vm.prank(owner);
        vm.expectRevert(IMachinePathManager.NoDestinationTeeIds.selector);
        flareTeeManager.addMachinePaths(extensionId, nonce, paths);
    }

    function testAddMachinePathsRevertGovernanceHashZero() public {
        // teeA1 has its governance hash cleared — not eligible regardless of status.
        helper.setTeeMachineState(
            teeA1, extensionId, codeHashA, platform, bytes32(0), IMachineManager.TeeStatus.PRODUCTION
        );
        uint256 nonce = _newList();
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IMachinePathManager.GovernanceHashZero.selector, teeA1)
        );
        flareTeeManager.addMachinePaths(extensionId, nonce, _onePath(teeA1, teeA2));
    }

    function testAddMachinePathsAcceptsAllStatuses() public {
        // Every status is accepted by the path-manager helper as long as a governance hash is set;
        // status checks are the caller's responsibility (e.g. directBackup requires PRODUCTION).
        IMachineManager.TeeStatus[] memory statuses = new IMachineManager.TeeStatus[](5);
        statuses[0] = IMachineManager.TeeStatus.INITIALIZED;
        statuses[1] = IMachineManager.TeeStatus.PRODUCTION;
        statuses[2] = IMachineManager.TeeStatus.SUSPENDED;
        statuses[3] = IMachineManager.TeeStatus.PAUSED;
        statuses[4] = IMachineManager.TeeStatus.BANNED;

        for (uint256 i = 0; i < statuses.length; i++) {
            helper.setTeeMachineState(teeA1, extensionId, codeHashA, platform, govHashA, statuses[i]);
            uint256 nonce = _newList();
            vm.prank(owner);
            flareTeeManager.addMachinePaths(extensionId, nonce, _onePath(teeA1, teeA2));
        }
    }

    function testAddMachinePathsRevertExtensionIdMismatch() public {
        // teeA1Other is registered under otherExtensionId; trying to add it to a list for
        // `extensionId` must revert with the shared ExtensionIdMismatch error.
        uint256 nonce = _newList();
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.ExtensionIdMismatch.selector);
        flareTeeManager.addMachinePaths(extensionId, nonce, _onePath(teeA1Other, teeA2));
    }

    function testAddMachinePathsRevertSourceTeeIdAlreadyExists() public {
        uint256 nonce = _newList();
        IMachinePathManager.MachinePath[] memory paths = new IMachinePathManager.MachinePath[](1);
        paths[0].sourceTeeIds = new address[](2);
        paths[0].sourceTeeIds[0] = teeA1;
        paths[0].sourceTeeIds[1] = teeA1;             // duplicate within the same path
        paths[0].destinationTeeIds = _arr1(teeA2);
        vm.prank(owner);
        vm.expectRevert(IMachinePathManager.SourceTeeIdAlreadyExists.selector);
        flareTeeManager.addMachinePaths(extensionId, nonce, paths);
    }

    function testAddMachinePathsRevertDestinationTeeIdAlreadyExists() public {
        uint256 nonce = _newList();
        IMachinePathManager.MachinePath[] memory paths = new IMachinePathManager.MachinePath[](1);
        paths[0].sourceTeeIds = _arr1(teeA1);
        paths[0].destinationTeeIds = new address[](2);
        paths[0].destinationTeeIds[0] = teeA2;
        paths[0].destinationTeeIds[1] = teeA2;        // duplicate
        vm.prank(owner);
        vm.expectRevert(IMachinePathManager.DestinationTeeIdAlreadyExists.selector);
        flareTeeManager.addMachinePaths(extensionId, nonce, paths);
    }

    function testAddMachinePathsHappyPath() public {
        uint256 nonce = _newList();
        IMachinePathManager.MachinePath[] memory paths = _onePath(teeA1, teeA2);
        vm.prank(owner);
        vm.expectEmit();
        emit IMachinePathManager.MachinePathsAdded(extensionId, nonce, paths);
        flareTeeManager.addMachinePaths(extensionId, nonce, paths);

        (
            IMachinePathManager.MachinePath[] memory storedPaths,
            bytes32[] memory involved,
            Signature[] memory sigs,
            bool signed
        ) = flareTeeManager.getMachinePathList(extensionId, nonce);
        assertEq(storedPaths.length, 1);
        assertEq(storedPaths[0].sourceTeeIds[0], teeA1);
        assertEq(storedPaths[0].destinationTeeIds[0], teeA2);
        // teeA1 and teeA2 are both under govHashA — single entry in the involved set.
        assertEq(involved.length, 1);
        assertEq(involved[0], govHashA);
        assertEq(sigs.length, 0);
        assertFalse(signed);
    }

    function testAddMachinePathsMixedGovernancesWithinSinglePath() public {
        // Source list mixes A + B; destination list mixes B + C → involved set = {A, B, C}.
        uint256 nonce = _newList();
        IMachinePathManager.MachinePath[] memory paths = new IMachinePathManager.MachinePath[](1);
        paths[0].sourceTeeIds = new address[](2);
        paths[0].sourceTeeIds[0] = teeA1;
        paths[0].sourceTeeIds[1] = teeB1;
        paths[0].destinationTeeIds = new address[](2);
        paths[0].destinationTeeIds[0] = teeB1;
        paths[0].destinationTeeIds[1] = teeC1;
        vm.prank(owner);
        flareTeeManager.addMachinePaths(extensionId, nonce, paths);

        (, bytes32[] memory involved,,) = flareTeeManager.getMachinePathList(extensionId, nonce);
        assertEq(involved.length, 3);
        // Set membership (order is insertion-order; for the assembled path that is A, B, C).
        bool foundA;
        bool foundB;
        bool foundC;
        for (uint256 i = 0; i < involved.length; i++) {
            if (involved[i] == govHashA) foundA = true;
            if (involved[i] == govHashB) foundB = true;
            if (involved[i] == govHashC) foundC = true;
        }
        assertTrue(foundA && foundB && foundC);
    }

    function testAddMachinePathsSameGovernanceBothRolesSingleEntry() public {
        // teeA1 → teeA2 — both under govHashA. Set must collapse to one entry.
        uint256 nonce = _newList();
        vm.prank(owner);
        flareTeeManager.addMachinePaths(extensionId, nonce, _onePath(teeA1, teeA2));
        (, bytes32[] memory involved,,) = flareTeeManager.getMachinePathList(extensionId, nonce);
        assertEq(involved.length, 1);
        assertEq(involved[0], govHashA);
    }

    // =========================================================================
    // finalizeMachinePathList
    // =========================================================================

    function testFinalizeMachinePathListRevertInvalidNonce() public {
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidNonce.selector);
        flareTeeManager.finalizeMachinePathList(extensionId, 999);
    }

    function testFinalizeMachinePathListRevertOnlyExtensionOwnerOrOperator() public {
        uint256 nonce = _newListWithPath(teeA1, teeA2);
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwnerOrOperator.selector);
        flareTeeManager.finalizeMachinePathList(extensionId, nonce);
    }

    function testFinalizeMachinePathListRevertListAlreadyFinalized() public {
        uint256 nonce = _newListWithPath(teeA1, teeA2);
        vm.prank(owner);
        flareTeeManager.finalizeMachinePathList(extensionId, nonce);
        vm.prank(owner);
        vm.expectRevert(IMachinePathManager.ListAlreadyFinalized.selector);
        flareTeeManager.finalizeMachinePathList(extensionId, nonce);
    }

    function testFinalizeMachinePathListRevertNoPaths() public {
        uint256 nonce = _newList();
        vm.prank(owner);
        vm.expectRevert(IMachinePathManager.NoPaths.selector);
        flareTeeManager.finalizeMachinePathList(extensionId, nonce);
    }

    function testFinalizeMachinePathListHappyPath() public {
        uint256 nonce = _newListWithPath(teeA1, teeA2);
        vm.prank(owner);
        bytes32[] memory expectedInvolved = new bytes32[](1);
        expectedInvolved[0] = govHashA;
        vm.expectEmit();
        emit IMachinePathManager.MachinePathListFinalized(extensionId, nonce, expectedInvolved);
        flareTeeManager.finalizeMachinePathList(extensionId, nonce);
        assertTrue(flareTeeManager.isMachinePathListFinalized(extensionId, nonce));
        assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
    }

    // =========================================================================
    // operator can drive the full prep lifecycle
    // =========================================================================

    function testOperatorCanDriveListLifecycle() public {
        address operator = makeAddr("operator");
        vm.prank(owner);
        IExtensionManager(address(flareTeeManager)).setExtensionOperator(extensionId, operator);

        vm.startPrank(operator);
        uint256 nonce = flareTeeManager.createNewMachinePathList(extensionId);
        flareTeeManager.addMachinePaths(extensionId, nonce, _onePath(teeA1, teeA2));
        flareTeeManager.finalizeMachinePathList(extensionId, nonce);
        vm.stopPrank();

        assertTrue(flareTeeManager.isMachinePathListFinalized(extensionId, nonce));
        // The downstream governance signature is unaffected by who prepped the list.
        Signature memory sig = _sign(_listMessageHash(extensionId, nonce), privKeysA[0]);
        flareTeeManager.signMachinePathList(extensionId, nonce, sig);
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
    }

    function testClearedOperatorCannotDriveListLifecycle() public {
        address operator = makeAddr("operator");
        vm.startPrank(owner);
        IExtensionManager(address(flareTeeManager)).setExtensionOperator(extensionId, operator);
        IExtensionManager(address(flareTeeManager)).setExtensionOperator(extensionId, address(0));
        vm.stopPrank();

        vm.prank(operator);
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwnerOrOperator.selector);
        flareTeeManager.createNewMachinePathList(extensionId);
    }

    // =========================================================================
    // signMachinePathList
    // =========================================================================

    function testSignMachinePathListRevertListNotFinalized() public {
        uint256 nonce = _newListWithPath(teeA1, teeA2);
        Signature memory sig = _sign(_listMessageHash(extensionId, nonce), privKeysA[0]);
        vm.expectRevert(IMachinePathManager.ListNotFinalized.selector);
        flareTeeManager.signMachinePathList(extensionId, nonce, sig);
    }

    function testSignMachinePathListRevertListAlreadySigned() public {
        uint256 nonce = _newSignedList(teeA1, teeA2, privKeysA[0]);
        // The same signer can't replay — but we want to assert the "already signed" gate.
        Signature memory sig = _sign(_listMessageHash(extensionId, nonce), privKeysA[0]);
        vm.expectRevert(IMachinePathManager.ListAlreadySigned.selector);
        flareTeeManager.signMachinePathList(extensionId, nonce, sig);
    }

    function testSignMachinePathListRevertUnrecognizedSigner() public {
        uint256 nonce = _newListWithPath(teeA1, teeA2);
        vm.prank(owner);
        flareTeeManager.finalizeMachinePathList(extensionId, nonce);
        // Sign with a key that is in NO involved governance.
        (, uint256 strangerKey) = makeAddrAndKey("stranger");
        Signature memory sig = _sign(_listMessageHash(extensionId, nonce), strangerKey);
        vm.expectRevert(IMachinePathManager.UnrecognizedSigner.selector);
        flareTeeManager.signMachinePathList(extensionId, nonce, sig);
    }

    function testSignMachinePathListRevertSignerAlreadySigned() public {
        // Multi-governance list so the first signature does not immediately activate; then the
        // same signer (signerA1) tries to sign again before the list reaches threshold across
        // every governance — must revert SignerAlreadySigned.
        uint256 nonce = _newMultiGovernanceList();
        vm.prank(owner);
        flareTeeManager.finalizeMachinePathList(extensionId, nonce);
        bytes32 hash = _listMessageHash(extensionId, nonce);
        Signature memory sigA = _sign(hash, privKeysA[0]);
        flareTeeManager.signMachinePathList(extensionId, nonce, sigA);

        Signature memory sigA2 = _sign(hash, privKeysA[0]);
        vm.expectRevert(IMachinePathManager.SignerAlreadySigned.selector);
        flareTeeManager.signMachinePathList(extensionId, nonce, sigA2);
    }

    function testSignMachinePathListSingleGovernanceActivates() public {
        // Single-governance list — one signature meets the threshold and activates the list.
        uint256 nonce = _newListWithPath(teeA1, teeA2);
        vm.prank(owner);
        flareTeeManager.finalizeMachinePathList(extensionId, nonce);
        Signature memory sig = _sign(_listMessageHash(extensionId, nonce), privKeysA[0]);

        bytes32[] memory expectedCounted = new bytes32[](1);
        expectedCounted[0] = govHashA;
        vm.expectEmit();
        emit IMachinePathManager.MachinePathListSignatureAdded(extensionId, nonce, signersA[0], expectedCounted);
        vm.expectEmit();
        emit IMachinePathManager.MachinePathListSigned(extensionId, nonce);
        flareTeeManager.signMachinePathList(extensionId, nonce, sig);

        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
        assertEq(flareTeeManager.getActiveMachinePathListNonce(extensionId), nonce);
        assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, govHashA), 1);
    }

    function testSignMachinePathListMultiGovernanceRequiresAll() public {
        uint256 nonce = _newMultiGovernanceList();
        vm.prank(owner);
        flareTeeManager.finalizeMachinePathList(extensionId, nonce);
        bytes32 hash = _listMessageHash(extensionId, nonce);

        // A signs first — list not yet activated.
        flareTeeManager.signMachinePathList(extensionId, nonce, _sign(hash, privKeysA[0]));
        assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));

        // B signs — still not enough.
        flareTeeManager.signMachinePathList(extensionId, nonce, _sign(hash, privKeysB[0]));
        assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));

        // C signs — now all thresholds met → activation.
        vm.expectEmit();
        emit IMachinePathManager.MachinePathListSigned(extensionId, nonce);
        flareTeeManager.signMachinePathList(extensionId, nonce, _sign(hash, privKeysC[0]));
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
        assertEq(flareTeeManager.getActiveMachinePathListNonce(extensionId), nonce);
    }

    function testSignMachinePathListCrossGovernanceSignerCountsBoth() public {
        // Two governances X and Y share one signer. A single signature submitted to the list
        // must count toward BOTH involved governances; the raw signature is stored only once globally.
        (address sharedSigner, uint256 sharedKey) = makeAddrAndKey("sharedXY");
        (bytes32 govHashX, bytes32 govHashY, bytes32 codeHashX, bytes32 codeHashY) =
            _setupTwoOverlappingGovernances(sharedSigner);

        address teeX = makeAddr("teeX");
        address teeY = makeAddr("teeY");
        helper.setTeeMachineState(
            teeX, extensionId, codeHashX, platform, govHashX, IMachineManager.TeeStatus.PRODUCTION
        );
        helper.setTeeMachineState(
            teeY, extensionId, codeHashY, platform, govHashY, IMachineManager.TeeStatus.PRODUCTION
        );

        uint256 nonce = _newListWithPath(teeX, teeY);
        vm.prank(owner);
        flareTeeManager.finalizeMachinePathList(extensionId, nonce);

        flareTeeManager.signMachinePathList(
            extensionId, nonce, _sign(_listMessageHash(extensionId, nonce), sharedKey)
        );

        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
        assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, govHashX), 1);
        assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, govHashY), 1);

        (,, Signature[] memory sigs,) = flareTeeManager.getMachinePathList(extensionId, nonce);
        assertEq(sigs.length, 1, "raw signature is stored once globally, not duplicated per governance");
    }

    function testSignMachinePathListRejectsReplayAcrossLists() public {
        // Build two distinct lists (different nonces) with IDENTICAL paths and IDENTICAL involved
        // governances. A signature collected for list 1 must NOT recover to a valid signer on list 2
        // because the nonce is bound into the messageHash.
        uint256 nonce1 = _newListWithPath(teeA1, teeA2);
        vm.prank(owner);
        flareTeeManager.finalizeMachinePathList(extensionId, nonce1);

        uint256 nonce2 = _newListWithPath(teeA1, teeA2);
        vm.prank(owner);
        flareTeeManager.finalizeMachinePathList(extensionId, nonce2);

        // Sign nonce1 with signerA1's key, capture the signature.
        Signature memory sigForList1 = _sign(_listMessageHash(extensionId, nonce1), privKeysA[0]);

        // Replay against nonce2 — recovers a different (garbage) address, none in any involved gov.
        vm.expectRevert(IMachinePathManager.UnrecognizedSigner.selector);
        flareTeeManager.signMachinePathList(extensionId, nonce2, sigForList1);
    }

    function testSignMachinePathListOlderNonceDoesNotDemoteNewer() public {
        // Create lists 1 and 2 (single-governance). Sign list 2 first → it becomes active.
        // Then sign list 1 → it becomes signed-but-not-active; the active pointer stays at 2.
        uint256 nonce1 = _newListWithPath(teeA1, teeA2);
        vm.prank(owner);
        flareTeeManager.finalizeMachinePathList(extensionId, nonce1);

        uint256 nonce2 = _newListWithPath(teeA1, teeA2);
        vm.prank(owner);
        flareTeeManager.finalizeMachinePathList(extensionId, nonce2);

        flareTeeManager.signMachinePathList(
            extensionId, nonce2, _sign(_listMessageHash(extensionId, nonce2), privKeysA[0])
        );
        assertEq(flareTeeManager.getActiveMachinePathListNonce(extensionId), nonce2);

        flareTeeManager.signMachinePathList(
            extensionId, nonce1, _sign(_listMessageHash(extensionId, nonce1), privKeysA[0])
        );
        // Active stays at the higher nonce.
        assertEq(flareTeeManager.getActiveMachinePathListNonce(extensionId), nonce2);
        // But list 1 is signed.
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce1));
    }

    // =========================================================================
    // View methods
    // =========================================================================

    function testGetActiveMachinePathListNonceRevertNoActive() public {
        vm.expectRevert(IMachinePathManager.NoActiveMachinePathList.selector);
        flareTeeManager.getActiveMachinePathListNonce(extensionId);
    }

    function testIsMachinePathValid() public {
        // No active list yet → probe returns false (never reverts).
        assertFalse(flareTeeManager.isMachinePathValid(extensionId, teeA1, teeA2));

        uint256 nonce = _newSignedList(teeA1, teeA2, privKeysA[0]);

        // Valid pair in the just-signed list.
        assertTrue(flareTeeManager.isMachinePathValid(extensionId, teeA1, teeA2));
        // Reversed direction → not present.
        assertFalse(flareTeeManager.isMachinePathValid(extensionId, teeA2, teeA1));
        // Pair where one side isn't in the list → false.
        assertFalse(flareTeeManager.isMachinePathValid(extensionId, teeA1, teeB1));
        // Different extension → false (active list pointer is per-extension and otherExtensionId has none).
        assertFalse(flareTeeManager.isMachinePathValid(otherExtensionId, teeA1, teeA2));

        // Suppress unused-variable warning.
        nonce;
    }

    function testIsMachinePathListFinalizedRevertInvalidNonce() public {
        vm.expectRevert(ITeeCommonErrors.InvalidNonce.selector);
        flareTeeManager.isMachinePathListFinalized(extensionId, 999);
    }

    function testIsMachinePathListSignedRevertInvalidNonce() public {
        vm.expectRevert(ITeeCommonErrors.InvalidNonce.selector);
        flareTeeManager.isMachinePathListSigned(extensionId, 999);
    }

    function testGetMachinePathListsCount() public {
        assertEq(flareTeeManager.getMachinePathListsCount(extensionId), 0);
        _newList();
        _newList();
        _newList();
        assertEq(flareTeeManager.getMachinePathListsCount(extensionId), 3);
        // Other extension's count is independent.
        assertEq(flareTeeManager.getMachinePathListsCount(otherExtensionId), 0);
    }

    function testGetMachinePathListSignatureCount() public {
        uint256 nonce = _newSignedList(teeA1, teeA2, privKeysA[0]);
        assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, govHashA), 1);
        // Querying with a non-involved governance hash returns 0.
        assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, govHashB), 0);
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    /**
     * @dev Creates two distinct governance configurations whose signer sets BOTH contain
     *      `_sharedSigner`. Returns the two governance hashes and a fresh codeHash for each so
     *      callers can spin up TEE machines that derive to each governance.
     */
    function _setupTwoOverlappingGovernances(address _sharedSigner)
        private
        returns (
            bytes32 _govHashX,
            bytes32 _govHashY,
            bytes32 _codeHashX,
            bytes32 _codeHashY
        )
    {
        bytes32[] memory plats = new bytes32[](1);
        plats[0] = platform;

        // Governance X: [shared, fillerX]
        (address fillerX, ) = makeAddrAndKey("fillerX");
        address[] memory setX = new address[](2);
        setX[0] = _sharedSigner;
        setX[1] = fillerX;
        _govHashX = keccak256(abi.encode(setX, uint64(1)));
        vm.prank(owner);
        flareTeeManager.setNewTeeGovernance(extensionId, setX, 1);
        _codeHashX = keccak256("codeHashX");
        vm.prank(owner);
        flareTeeManager.addTeeVersion(extensionId, "vX", _codeHashX, plats);

        // Governance Y: [shared, fillerY] — different set → different hash, same shared signer.
        (address fillerY, ) = makeAddrAndKey("fillerY");
        address[] memory setY = new address[](2);
        setY[0] = _sharedSigner;
        setY[1] = fillerY;
        _govHashY = keccak256(abi.encode(setY, uint64(1)));
        vm.prank(owner);
        flareTeeManager.setNewTeeGovernance(extensionId, setY, 1);
        _codeHashY = keccak256("codeHashY");
        vm.prank(owner);
        flareTeeManager.addTeeVersion(extensionId, "vY", _codeHashY, plats);
    }

    function _newList() private returns (uint256 _nonce) {
        vm.prank(owner);
        _nonce = flareTeeManager.createNewMachinePathList(extensionId);
    }

    function _newListWithPath(address _src, address _dst) private returns (uint256 _nonce) {
        _nonce = _newList();
        vm.prank(owner);
        flareTeeManager.addMachinePaths(extensionId, _nonce, _onePath(_src, _dst));
    }

    function _newSignedList(
        address _src,
        address _dst,
        uint256 _signerKey
    )
        private
        returns (uint256 _nonce)
    {
        _nonce = _newListWithPath(_src, _dst);
        vm.prank(owner);
        flareTeeManager.finalizeMachinePathList(extensionId, _nonce);
        Signature memory sig = _sign(_listMessageHash(extensionId, _nonce), _signerKey);
        flareTeeManager.signMachinePathList(extensionId, _nonce, sig);
    }

    function _newMultiGovernanceList() private returns (uint256 _nonce) {
        // Single path spanning governances A, B, C.
        _nonce = _newList();
        IMachinePathManager.MachinePath[] memory paths = new IMachinePathManager.MachinePath[](1);
        paths[0].sourceTeeIds = new address[](2);
        paths[0].sourceTeeIds[0] = teeA1;
        paths[0].sourceTeeIds[1] = teeB1;
        paths[0].destinationTeeIds = new address[](2);
        paths[0].destinationTeeIds[0] = teeA2;
        paths[0].destinationTeeIds[1] = teeC1;
        vm.prank(owner);
        flareTeeManager.addMachinePaths(extensionId, _nonce, paths);
    }

    function _addHelperFacet() private {
        TestMachinePathHelperFacet helperFacet = new TestMachinePathHelperFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = ITestMachinePathHelper.setTeeMachineState.selector;
        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](1);
        cuts[0] = IDiamond.FacetCut(address(helperFacet), IDiamond.FacetCutAction.Add, selectors);
        vm.prank(initialGovernance);
        IDiamondCut(address(flareTeeManager)).diamondCut(cuts, address(0), "");
    }

    function _listMessageHash(uint256 _extensionId, uint256 _nonce) private view returns (bytes32) {
        (IMachinePathManager.MachinePath[] memory paths,,,) =
            flareTeeManager.getMachinePathList(_extensionId, _nonce);
        return SignedPayload.messageHash(
            TEE_MACHINE_PATH_LIST,
            keccak256(abi.encode(_extensionId, _nonce, paths))
        );
    }

    function _onePath(address _src, address _dst)
        private pure
        returns (IMachinePathManager.MachinePath[] memory _paths)
    {
        _paths = new IMachinePathManager.MachinePath[](1);
        _paths[0].sourceTeeIds = _arr1(_src);
        _paths[0].destinationTeeIds = _arr1(_dst);
    }

    function _arr1(address _a) private pure returns (address[] memory _r) {
        _r = new address[](1);
        _r[0] = _a;
    }

    function _sign(bytes32 _hash, uint256 _privKey) private pure returns (Signature memory) {
        return SignatureHelper.createSignature(vm, _hash, _privKey);
    }
}
