// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test, stdError } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { SignatureHelper } from "../../../utils/SignatureHelper.sol";
import { MockSafe } from "../../../mock/MockSafe.sol";

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

    /// Bundle of a Safe-backed governance under test whose owners have known private keys
    /// (sorted ascending by owner address — the packed-blob order the Safe encoding requires).
    struct SafeCtx {
        MockSafe safe;
        bytes32 govHash;
        address teeS1;
        address teeS2;
        address[] owners;
        uint256[] keys;
    }

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

    function testSignMachinePathListAfterActivationAccepted() public {
        // Signatures may still be recorded after activation (evidence collection for off-chain
        // verifiers, e.g. snapshot owners bridging an old governance hash); activation and
        // promotion happened once and the list simply stays signed.
        (address o1, uint256 k1) = makeAddrAndKey("ownerP1");
        (address o2, uint256 k2) = makeAddrAndKey("ownerP2");
        address[] memory owners = new address[](2);
        owners[0] = o1;
        owners[1] = o2;
        (, bytes32 govHashS, address teeS1, address teeS2) = _setupSafeGovernance(owners, 1, "P");
        uint256 nonce = _newFinalizedList(teeS1, teeS2);
        bytes32 hash = _listMessageHash(extensionId, nonce);

        flareTeeManager.signMachinePathList(extensionId, nonce, _sign(hash, k1));
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));

        flareTeeManager.signMachinePathList(extensionId, nonce, _sign(hash, k2));
        assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, govHashS), 2);
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
        (,, Signature[] memory sigs,) = flareTeeManager.getMachinePathList(extensionId, nonce);
        assertEq(sigs.length, 2);
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
    // approveMachinePathList (Safe-backed governance)
    // =========================================================================

    function testApproveMachinePathListRecordsWithoutSatisfying() public {
        // The approval is step one of two: it screens the snapshots, consumes the Safe nonce and
        // records the artifact pointer, but satisfies NOTHING — activation waits for the on-chain
        // owner-signature verification in confirmMachinePathListSafeApproval.
        (MockSafe safe, bytes32 govHashS, address teeS1, address teeS2) =
            _setupSafeGovernance(_makeOwners("S", 3), 2, "S");
        uint256 nonce = _newFinalizedList(teeS1, teeS2);
        bytes32 hash = _listMessageHash(extensionId, nonce);

        vm.expectEmit();
        // MockSafe starts at nonce 1 and pre-increments in exec — the signed nonce is 1.
        emit IMachinePathManager.MachinePathListApproved(
            extensionId, nonce, address(safe), 1, _h1(govHashS)
        );
        // Realistic caller: the Safe contract itself executes the approval call.
        safe.exec(
            address(flareTeeManager),
            abi.encodeCall(IMachinePathManager.approveMachinePathList, (extensionId, nonce, hash))
        );

        assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
        assertFalse(flareTeeManager.isMachinePathListSafeApproved(extensionId, nonce, govHashS));
        assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, govHashS), 0);
        assertEq(flareTeeManager.getMachinePathListApprovals(extensionId, nonce).length, 1);
        vm.expectRevert(IMachinePathManager.NoActiveMachinePathList.selector);
        flareTeeManager.getActiveMachinePathListNonce(extensionId);
    }

    function testApproveMachinePathListMixedGovernancesRequiresAll() public {
        // Path spanning plain governance A (teeA1) and a Safe governance: the plain signature
        // satisfies A, the Safe approval alone satisfies nothing — the list signs only once the
        // Safe approval is confirmed on-chain.
        SafeCtx memory c = _setupSafeGovernanceCtx("S", 3, 2);
        uint256 nonce = _newFinalizedList(teeA1, c.teeS1);
        bytes32 hash = _listMessageHash(extensionId, nonce);

        uint256 signedNonce = _execApproval(c.safe, nonce);
        flareTeeManager.signMachinePathList(extensionId, nonce, _sign(hash, privKeysA[0]));
        assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));

        _confirm(c, nonce, signedNonce, 2);
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
    }

    function testSignMachinePathListOwnerDirectSignatureCounts() public {
        // The Safe owners are stored as ordinary signers: direct EIP-191 signatures alone satisfy
        // a Safe-backed governance without any Safe transaction (the rotation bridge).
        (address o1, uint256 k1) = makeAddrAndKey("ownerDirect1");
        (address o2, uint256 k2) = makeAddrAndKey("ownerDirect2");
        address[] memory owners = new address[](2);
        owners[0] = o1;
        owners[1] = o2;
        (, bytes32 govHashS, address teeS1, address teeS2) = _setupSafeGovernance(owners, 2, "S");
        uint256 nonce = _newFinalizedList(teeS1, teeS2);
        bytes32 hash = _listMessageHash(extensionId, nonce);

        flareTeeManager.signMachinePathList(extensionId, nonce, _sign(hash, k1));
        assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
        flareTeeManager.signMachinePathList(extensionId, nonce, _sign(hash, k2));
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
        assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, govHashS), 2);
    }

    function testApproveThenConfirmAllFeasibleSameSafeGovernances() public {
        // Same Safe, small rotation (1 of 4 owners swapped, threshold unchanged): both snapshots
        // are screened by the single approval, and one signature blob — signed by owners in the
        // snapshots' intersection — confirms each snapshot separately (coordination rule).
        SafeCtx memory c = _setupSafeGovernanceCtx("R", 4, 2);      // old snapshot
        bytes32 govHashOld = c.govHash;
        address teeOld = c.teeS1;
        address[] memory rotated = new address[](4);
        rotated[0] = c.owners[0];
        rotated[1] = c.owners[1];
        rotated[2] = c.owners[2];
        rotated[3] = makeAddr("ownerR_replacement");
        c.safe.setOwners(rotated);
        (bytes32 govHashNew, address teeNew,) = _registerSafeGovernance(c.safe, "Rnew");

        uint256 nonce = _newFinalizedList(teeOld, teeNew);

        vm.expectEmit();
        emit IMachinePathManager.MachinePathListApproved(
            extensionId, nonce, address(c.safe), 1, _h2(govHashOld, govHashNew)
        );
        uint256 signedNonce = _execApproval(c.safe, nonce);
        // Screening only — nothing satisfied yet.
        assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));

        // owners[0..1] (sorted keys) belong to BOTH snapshots: the same blob confirms each hash.
        bytes memory blob = _packSignatures(
            _approvalSafeTxHash(address(c.safe), nonce, signedNonce), _firstKeys(c.keys, 2)
        );
        flareTeeManager.confirmMachinePathListSafeApproval(
            extensionId, nonce, govHashOld, signedNonce, blob
        );
        assertTrue(flareTeeManager.isMachinePathListSafeApproved(extensionId, nonce, govHashOld));
        assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));

        flareTeeManager.confirmMachinePathListSafeApproval(
            extensionId, nonce, govHashNew, signedNonce, blob
        );
        assertTrue(flareTeeManager.isMachinePathListSafeApproved(extensionId, nonce, govHashNew));
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
        assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, govHashOld), 0);
        assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, govHashNew), 0);
    }

    function testApproveMachinePathListSkipsUnsatisfiableSnapshot() public {
        // Full owner replacement: the old snapshot is no longer satisfiable by the live quorum, so
        // the approval screens only the new snapshot; the new one is then confirmed on-chain and
        // the old one is bridged by direct signatures from the snapshot owners.
        (address o1, uint256 k1) = makeAddrAndKey("ownerU1");
        (address o2, uint256 k2) = makeAddrAndKey("ownerU2");
        uint256 nonce;
        bytes32 hash;
        // Scope the setup locals in a block so they are freed before the signing calls below; keeps
        // the coverage build (optimizer + viaIR off) under the EVM stack limit.
        {
            address[] memory owners = new address[](2);
            owners[0] = o1;
            owners[1] = o2;
            SafeCtx memory c;
            bytes32 govHashOld;
            address teeOld;
            (c.safe, govHashOld, teeOld,) = _setupSafeGovernance(owners, 2, "Uold");
            (c.owners, c.keys) = _makeOwnerKeys("Unew", 2);
            c.safe.setOwners(c.owners);
            (c.govHash, c.teeS1, c.teeS2) = _registerSafeGovernance(c.safe, "Unew");

            nonce = _newFinalizedList(teeOld, c.teeS1);
            hash = _listMessageHash(extensionId, nonce);

            // Only the satisfiable (current) snapshot is screened; the stale one is skipped.
            vm.expectEmit();
            emit IMachinePathManager.MachinePathListApproved(
                extensionId, nonce, address(c.safe), 1, _h1(c.govHash)
            );
            uint256 signedNonce = _execApproval(c.safe, nonce);

            assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
            // Screening marks nothing — the new snapshot needs its confirmation.
            assertFalse(flareTeeManager.isMachinePathListSafeApproved(extensionId, nonce, c.govHash));
            _confirm(c, nonce, signedNonce, 2);
            assertTrue(flareTeeManager.isMachinePathListSafeApproved(extensionId, nonce, c.govHash));
            assertFalse(flareTeeManager.isMachinePathListSafeApproved(extensionId, nonce, govHashOld));
            assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
            assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, govHashOld), 0);
        }

        // Snapshot owners bridge the old governance with direct signatures.
        flareTeeManager.signMachinePathList(extensionId, nonce, _sign(hash, k1));
        flareTeeManager.signMachinePathList(extensionId, nonce, _sign(hash, k2));
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
    }

    function testApproveMachinePathListRevertSafeGovernanceStale() public {
        // Only an unsatisfiable snapshot involved → SafeGovernanceStale.
        (MockSafe safe,, address teeS1, address teeS2) = _setupSafeGovernance(_makeOwners("V", 2), 2, "V");
        uint256 nonce = _newFinalizedList(teeS1, teeS2);
        bytes32 hash = _listMessageHash(extensionId, nonce);

        // Variant 1: owners fully replaced — overlap 0 < snapshot threshold 2.
        safe.setOwners(_makeOwners("Vnew", 2));
        vm.prank(address(safe));
        vm.expectRevert(IMachinePathManager.SafeGovernanceStale.selector);
        flareTeeManager.approveMachinePathList(extensionId, nonce, hash);

        // Variant 2: owners restored but live threshold lowered below the snapshot threshold.
        safe.setOwners(_makeOwners("V", 2));
        safe.setThreshold(1);
        vm.prank(address(safe));
        vm.expectRevert(IMachinePathManager.SafeGovernanceStale.selector);
        flareTeeManager.approveMachinePathList(extensionId, nonce, hash);
    }

    function testApproveMachinePathListRevertListNotFinalized() public {
        (MockSafe safe,, address teeS1, address teeS2) = _setupSafeGovernance(_makeOwners("S", 2), 2, "S");
        uint256 nonce = _newListWithPath(teeS1, teeS2);
        vm.prank(address(safe));
        vm.expectRevert(IMachinePathManager.ListNotFinalized.selector);
        flareTeeManager.approveMachinePathList(extensionId, nonce, bytes32(0));
    }

    function testApproveMachinePathListAfterActivationAccepted() public {
        // Approvals may still be recorded after activation — a refreshed Safe transaction gives
        // relays a newer artifact (e.g. after an owner rotation). Activation happened once and the
        // list simply stays signed; no second MachinePathListSigned.
        SafeCtx memory c = _setupSafeGovernanceCtx("S", 2, 2);
        uint256 nonce = _newFinalizedList(c.teeS1, c.teeS2);

        uint256 signedNonce = _execApproval(c.safe, nonce);
        _confirm(c, nonce, signedNonce, 2);
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
        assertEq(flareTeeManager.getActiveMachinePathListNonce(extensionId), nonce);

        vm.roll(vm.getBlockNumber() + 100);
        // The refreshed approval carries the newer Safe nonce (5 signed → nonce() reads 6).
        c.safe.setNonce(5);
        vm.expectEmit();
        emit IMachinePathManager.MachinePathListApproved(
            extensionId, nonce, address(c.safe), 5, _h1(c.govHash)
        );
        uint256 signedNonce2 = _execApproval(c.safe, nonce);
        assertEq(signedNonce2, 5);

        IMachinePathManager.Approval[] memory approvals =
            flareTeeManager.getMachinePathListApprovals(extensionId, nonce);
        assertEq(approvals.length, 2);
        assertTrue(approvals[1].blockNumber > approvals[0].blockNumber);
        assertEq(approvals[1].safeNonce, 5);
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
        assertEq(flareTeeManager.getActiveMachinePathListNonce(extensionId), nonce);
    }

    function testApproveMachinePathListRevertMessageHashMismatch() public {
        (MockSafe safe,, address teeS1, address teeS2) = _setupSafeGovernance(_makeOwners("S", 2), 2, "S");
        uint256 nonce1 = _newFinalizedList(teeS1, teeS2);
        uint256 nonce2 = _newFinalizedList(teeS1, teeS2);
        bytes32 hash1 = _listMessageHash(extensionId, nonce1);

        // Arbitrary wrong hash.
        vm.prank(address(safe));
        vm.expectRevert(IMachinePathManager.MessageHashMismatch.selector);
        flareTeeManager.approveMachinePathList(extensionId, nonce1, keccak256("wrong"));

        // Cross-list replay: list 1's hash submitted for list 2 (nonce is bound into the hash).
        vm.prank(address(safe));
        vm.expectRevert(IMachinePathManager.MessageHashMismatch.selector);
        flareTeeManager.approveMachinePathList(extensionId, nonce2, hash1);
    }

    function testApproveMachinePathListRevertUnrecognizedSigner() public {
        address[] memory owners = _makeOwners("S", 2);
        (,, address teeS1, address teeS2) = _setupSafeGovernance(owners, 2, "S");
        uint256 nonce = _newFinalizedList(teeS1, teeS2);
        bytes32 hash = _listMessageHash(extensionId, nonce);

        // Random EOA.
        vm.prank(makeAddr("randomEoa"));
        vm.expectRevert(IMachinePathManager.UnrecognizedSigner.selector);
        flareTeeManager.approveMachinePathList(extensionId, nonce, hash);

        // Contract that is not the registered Safe of any involved governance.
        MockSafe strangerSafe = new MockSafe(owners, 2);
        vm.expectRevert(IMachinePathManager.UnrecognizedSigner.selector);
        strangerSafe.exec(
            address(flareTeeManager),
            abi.encodeCall(IMachinePathManager.approveMachinePathList, (extensionId, nonce, hash))
        );

        // An owner calling directly: owners are signers for the signature path, not approvers.
        vm.prank(owners[0]);
        vm.expectRevert(IMachinePathManager.UnrecognizedSigner.selector);
        flareTeeManager.approveMachinePathList(extensionId, nonce, hash);
    }

    function testApproveMachinePathListRevertUnrecognizedSignerPlainOnlyList() public {
        // A list involving ONLY plain governances cannot be approved via msg.sender — even by a
        // registered Safe of the extension.
        (MockSafe safe,,,) = _setupSafeGovernance(_makeOwners("S", 2), 2, "S");
        uint256 nonce = _newFinalizedList(teeA1, teeA2);
        bytes32 hash = _listMessageHash(extensionId, nonce);
        vm.prank(address(safe));
        vm.expectRevert(IMachinePathManager.UnrecognizedSigner.selector);
        flareTeeManager.approveMachinePathList(extensionId, nonce, hash);
    }

    function testApproveMachinePathListRepeatApprovalAllowed() public {
        // No per-signer dedup on the approval path: repeat approvals are permitted and each
        // appends another Approval entry (fresher artifact pointer for relays). None of them
        // satisfies anything — the safeApproved flag is set only by the confirmation.
        (MockSafe safe, bytes32 govHashS, address teeS1,) = _setupSafeGovernance(_makeOwners("S", 2), 2, "S");
        // Mixed list (plain governance A + Safe governance).
        uint256 nonce = _newFinalizedList(teeA1, teeS1);
        bytes32 hash = _listMessageHash(extensionId, nonce);

        vm.prank(address(safe));
        flareTeeManager.approveMachinePathList(extensionId, nonce, hash);
        vm.prank(address(safe));
        flareTeeManager.approveMachinePathList(extensionId, nonce, hash);

        assertFalse(flareTeeManager.isMachinePathListSafeApproved(extensionId, nonce, govHashS));
        assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, govHashS), 0);
        assertEq(flareTeeManager.getMachinePathListApprovals(extensionId, nonce).length, 2);
        assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));

        // Plain governance A signs as usual; the list still waits for the Safe confirmation.
        flareTeeManager.signMachinePathList(extensionId, nonce, _sign(hash, privKeysA[0]));
        assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
    }

    function testApproveMachinePathListMixedWithOwnerSignatures() public {
        // Partial direct owner signatures followed by the confirmed Safe approval: the two
        // satisfaction paths are independent — the signature count keeps its honest value and the
        // confirmed safeApproved flag satisfies the governance for activation.
        SafeCtx memory c = _setupSafeGovernanceCtx("M", 2, 2);
        uint256 nonce = _newFinalizedList(c.teeS1, c.teeS2);
        bytes32 hash = _listMessageHash(extensionId, nonce);

        flareTeeManager.signMachinePathList(extensionId, nonce, _sign(hash, c.keys[0]));
        assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, c.govHash), 1);
        assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));

        uint256 signedNonce = _execApproval(c.safe, nonce);
        assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
        _confirm(c, nonce, signedNonce, 2);
        assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, c.govHash), 1);
        assertTrue(flareTeeManager.isMachinePathListSafeApproved(extensionId, nonce, c.govHash));
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
    }

    function testApproveMachinePathListAfterOwnerThresholdReached() public {
        // Owners individually reach the snapshot threshold first; a subsequent Safe approval still
        // records the Approval entry, and the honest count is untouched.
        (address o1, uint256 k1) = makeAddrAndKey("ownerN1");
        (address o2, uint256 k2) = makeAddrAndKey("ownerN2");
        address[] memory owners = new address[](2);
        owners[0] = o1;
        owners[1] = o2;
        (MockSafe safe, bytes32 govHashS, address teeS1,) = _setupSafeGovernance(owners, 2, "N");
        // Mixed list (plain governance A + Safe governance) so owner signatures don't activate it.
        uint256 nonce = _newFinalizedList(teeA1, teeS1);
        bytes32 hash = _listMessageHash(extensionId, nonce);

        flareTeeManager.signMachinePathList(extensionId, nonce, _sign(hash, k1));
        flareTeeManager.signMachinePathList(extensionId, nonce, _sign(hash, k2));
        assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, govHashS), 2);
        assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));

        vm.expectEmit();
        emit IMachinePathManager.MachinePathListApproved(
            extensionId, nonce, address(safe), 0, _h1(govHashS)
        );
        vm.prank(address(safe));
        flareTeeManager.approveMachinePathList(extensionId, nonce, hash);

        assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, govHashS), 2);
        // The unconfirmed approval sets no flag; the governance is satisfied by the count alone.
        assertFalse(flareTeeManager.isMachinePathListSafeApproved(extensionId, nonce, govHashS));
        assertEq(flareTeeManager.getMachinePathListApprovals(extensionId, nonce).length, 1);
        assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
    }

    function testGetMachinePathListApprovals() public {
        (MockSafe safe,, address teeS1, address teeS2) = _setupSafeGovernance(_makeOwners("S", 2), 2, "S");
        uint256 nonce = _newFinalizedList(teeS1, teeS2);
        bytes32 hash = _listMessageHash(extensionId, nonce);

        assertEq(flareTeeManager.getMachinePathListApprovals(extensionId, nonce).length, 0);

        vm.roll(12345);
        safe.setNonce(42);
        // Realistic path: the Safe executes the approval, incrementing its nonce to 43 before the
        // inner call — the recorded safeNonce must be the SIGNED nonce, 42.
        safe.exec(
            address(flareTeeManager),
            abi.encodeCall(IMachinePathManager.approveMachinePathList, (extensionId, nonce, hash))
        );

        IMachinePathManager.Approval[] memory approvals =
            flareTeeManager.getMachinePathListApprovals(extensionId, nonce);
        assertEq(approvals.length, 1);
        assertEq(approvals[0].signer, address(safe));
        // Read the expected block via cheatcode — direct block.number reads are constant-folded
        // under viaIR and go stale across vm.roll.
        assertEq(approvals[0].blockNumber, uint64(vm.getBlockNumber()));
        assertEq(approvals[0].safeNonce, 42);

        // ECDSA signatures are stored separately and stay empty for the approval path.
        (,, Signature[] memory sigs,) = flareTeeManager.getMachinePathList(extensionId, nonce);
        assertEq(sigs.length, 0);
    }

    function testGetMachinePathListApprovalsRevertInvalidNonce() public {
        vm.expectRevert(ITeeCommonErrors.InvalidNonce.selector);
        flareTeeManager.getMachinePathListApprovals(extensionId, 999);
    }

    function testApproveMachinePathListRevertZeroSafeNonce() public {
        // A responder reporting nonce 0 is impossible for a genuine Safe mid-execTransaction (the
        // nonce is incremented before the inner call); the safeNonce capture underflows.
        (MockSafe safe,, address teeS1, address teeS2) = _setupSafeGovernance(_makeOwners("S", 2), 2, "S");
        uint256 nonce = _newFinalizedList(teeS1, teeS2);
        bytes32 hash = _listMessageHash(extensionId, nonce);

        safe.setNonce(0);
        vm.prank(address(safe));
        vm.expectRevert(stdError.arithmeticError);
        flareTeeManager.approveMachinePathList(extensionId, nonce, hash);
    }

    // =========================================================================
    // confirmMachinePathListSafeApproval
    // =========================================================================

    function testConfirmMachinePathListSafeApprovalActivates() public {
        SafeCtx memory c = _setupSafeGovernanceCtx("S", 3, 2);
        uint256 nonce = _newFinalizedList(c.teeS1, c.teeS2);
        uint256 signedNonce = _execApproval(c.safe, nonce);

        bytes memory blob = _packSignatures(
            _approvalSafeTxHash(address(c.safe), nonce, signedNonce), _firstKeys(c.keys, 2)
        );
        vm.expectEmit();
        emit IMachinePathManager.MachinePathListSafeApprovalConfirmed(
            extensionId, nonce, c.govHash, address(c.safe), signedNonce
        );
        vm.expectEmit();
        emit IMachinePathManager.MachinePathListSigned(extensionId, nonce);
        // Anyone may relay the blob — the signatures carry the authority.
        vm.prank(makeAddr("anyRelayer"));
        flareTeeManager.confirmMachinePathListSafeApproval(
            extensionId, nonce, c.govHash, signedNonce, blob
        );

        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
        assertTrue(flareTeeManager.isMachinePathListSafeApproved(extensionId, nonce, c.govHash));
        assertEq(flareTeeManager.getActiveMachinePathListNonce(extensionId), nonce);
        // Honest signature count: the confirmation never touches it.
        assertEq(flareTeeManager.getMachinePathListSignatureCount(extensionId, nonce, c.govHash), 0);
        // The verified artifact is chain-served for relays.
        IMachinePathManager.SafeApprovalArtifact memory artifact =
            flareTeeManager.getMachinePathListSafeApprovalArtifact(extensionId, nonce, c.govHash);
        assertEq(artifact.safeNonce, signedNonce);
        assertEq(artifact.signatures, blob);
    }

    function testConfirmMachinePathListSafeApprovalEthSignVariant() public {
        // v in {31,32}: eth_sign-flow chunks recover over the EIP-191-prefixed SafeTxHash with v-4.
        SafeCtx memory c = _setupSafeGovernanceCtx("E", 2, 2);
        uint256 nonce = _newFinalizedList(c.teeS1, c.teeS2);
        uint256 signedNonce = _execApproval(c.safe, nonce);

        bytes32 prefixed = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32", _approvalSafeTxHash(address(c.safe), nonce, signedNonce)
        ));
        bytes memory blob;
        for (uint256 i = 0; i < 2; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(c.keys[i], prefixed);
            blob = abi.encodePacked(blob, r, s, v + 4);
        }
        flareTeeManager.confirmMachinePathListSafeApproval(
            extensionId, nonce, c.govHash, signedNonce, blob
        );
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
    }

    function testConfirmMachinePathListSafeApprovalSkipsNonMemberSigners() public {
        // The blob may include valid signatures from signers outside this snapshot (e.g. live
        // owners admitted after a rotation): they are skipped, not rejected — only snapshot
        // members count toward the threshold.
        (address[] memory all, uint256[] memory keys) = _makeOwnerKeys("NM", 3);
        address[] memory members = new address[](2);
        members[0] = all[0];
        members[1] = all[2];
        (MockSafe safe, bytes32 govHash, address teeS1, address teeS2) =
            _setupSafeGovernance(members, 2, "NM");
        uint256 nonce = _newFinalizedList(teeS1, teeS2);
        uint256 signedNonce = _execApproval(safe, nonce);

        // All three (sorted) signatures; all[1] is not a snapshot member.
        bytes memory blob = _packSignatures(_approvalSafeTxHash(address(safe), nonce, signedNonce), keys);
        flareTeeManager.confirmMachinePathListSafeApproval(
            extensionId, nonce, govHash, signedNonce, blob
        );
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
    }

    function testConfirmMachinePathListSafeApprovalRevertThresholdNotReached() public {
        SafeCtx memory c = _setupSafeGovernanceCtx("T", 2, 2);
        uint256 nonce = _newFinalizedList(c.teeS1, c.teeS2);
        uint256 signedNonce = _execApproval(c.safe, nonce);

        bytes memory blob = _packSignatures(
            _approvalSafeTxHash(address(c.safe), nonce, signedNonce), _firstKeys(c.keys, 1)
        );
        vm.expectRevert(abi.encodeWithSelector(IMachinePathManager.ThresholdNotReached.selector, 2, 1));
        flareTeeManager.confirmMachinePathListSafeApproval(
            extensionId, nonce, c.govHash, signedNonce, blob
        );
    }

    function testConfirmMachinePathListSafeApprovalRevertOwnerRotationAttack() public {
        // The auditors' owner-rotation sequence: a Safe fully taken over AFTER the snapshot can
        // pass the advisory screening in approveMachinePathList by reconfiguring itself, but it
        // cannot produce the snapshot owners' signatures — satisfaction is gated by the on-chain
        // confirmation, which fails.
        SafeCtx memory c = _setupSafeGovernanceCtx("H", 3, 2);          // snapshot {A,B,C}, threshold 2
        (address[] memory attackers, uint256[] memory attackerKeys) = _makeOwnerKeys("D", 3);

        // D holds sole control and stages the screen: owners {D, D1, D2, A, B} with threshold 3 —
        // the live threshold is not below 2 and two snapshot signers are live owners.
        address[] memory staged = new address[](5);
        staged[0] = attackers[0];
        staged[1] = attackers[1];
        staged[2] = attackers[2];
        staged[3] = c.owners[0];
        staged[4] = c.owners[1];
        c.safe.setOwners(staged);
        c.safe.setThreshold(3);

        uint256 nonce = _newFinalizedList(c.teeS1, c.teeS2);
        uint256 signedNonce = _execApproval(c.safe, nonce);    // succeeds: the screen is advisory

        // ...but satisfies nothing.
        assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
        assertFalse(flareTeeManager.isMachinePathListSafeApproved(extensionId, nonce, c.govHash));

        // D confirms with the keys it actually holds — zero snapshot members recover.
        bytes memory attackerBlob = _packSignatures(
            _approvalSafeTxHash(address(c.safe), nonce, signedNonce), attackerKeys
        );
        vm.expectRevert(abi.encodeWithSelector(IMachinePathManager.ThresholdNotReached.selector, 2, 0));
        flareTeeManager.confirmMachinePathListSafeApproval(
            extensionId, nonce, c.govHash, signedNonce, attackerBlob
        );
        assertFalse(flareTeeManager.isMachinePathListSigned(extensionId, nonce));

        // Contrast: signatures from the genuine snapshot owners — exactly what the attacker
        // lacks — do confirm.
        bytes memory ownerBlob = _packSignatures(
            _approvalSafeTxHash(address(c.safe), nonce, signedNonce), _firstKeys(c.keys, 2)
        );
        flareTeeManager.confirmMachinePathListSafeApproval(
            extensionId, nonce, c.govHash, signedNonce, ownerBlob
        );
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
    }

    function testConfirmMachinePathListSafeApprovalRevertSafeApprovalNotRecorded() public {
        SafeCtx memory c = _setupSafeGovernanceCtx("P", 2, 2);
        uint256 nonce = _newFinalizedList(c.teeS1, c.teeS2);
        bytes memory blob = _packSignatures(
            _approvalSafeTxHash(address(c.safe), nonce, 1), _firstKeys(c.keys, 2)
        );

        // No approval executed at all: a blob collected off-chain but never executed by the Safe
        // (cancelled, replaced, or leaked from the Safe Transaction Service) can never confirm.
        vm.expectRevert(IMachinePathManager.SafeApprovalNotRecorded.selector);
        flareTeeManager.confirmMachinePathListSafeApproval(extensionId, nonce, c.govHash, 1, blob);

        // Approval executed at Safe nonce 1; confirming with a different claimed nonce fails too.
        uint256 signedNonce = _execApproval(c.safe, nonce);
        assertEq(signedNonce, 1);
        vm.expectRevert(IMachinePathManager.SafeApprovalNotRecorded.selector);
        flareTeeManager.confirmMachinePathListSafeApproval(extensionId, nonce, c.govHash, 2, blob);
    }

    function testConfirmMachinePathListSafeApprovalRevertListNotFinalized() public {
        SafeCtx memory c = _setupSafeGovernanceCtx("L", 2, 2);
        uint256 nonce = _newListWithPath(c.teeS1, c.teeS2);
        vm.expectRevert(IMachinePathManager.ListNotFinalized.selector);
        flareTeeManager.confirmMachinePathListSafeApproval(extensionId, nonce, c.govHash, 1, "");
    }

    function testConfirmMachinePathListSafeApprovalRevertUnrecognizedSigner() public {
        SafeCtx memory c = _setupSafeGovernanceCtx("U", 2, 2);
        // Plain-only list: govHashA is involved but has no Safe behind it.
        uint256 plainNonce = _newFinalizedList(teeA1, teeA2);
        vm.expectRevert(IMachinePathManager.UnrecognizedSigner.selector);
        flareTeeManager.confirmMachinePathListSafeApproval(extensionId, plainNonce, govHashA, 1, "");

        // Safe-governance hash that is NOT involved on the list.
        vm.expectRevert(IMachinePathManager.UnrecognizedSigner.selector);
        flareTeeManager.confirmMachinePathListSafeApproval(extensionId, plainNonce, c.govHash, 1, "");
    }

    function testConfirmMachinePathListSafeApprovalRevertInvalidSignaturesLength() public {
        SafeCtx memory c = _setupSafeGovernanceCtx("IL", 2, 2);
        uint256 nonce = _newFinalizedList(c.teeS1, c.teeS2);
        uint256 signedNonce = _execApproval(c.safe, nonce);

        vm.expectRevert(IMachinePathManager.InvalidSignaturesLength.selector);
        flareTeeManager.confirmMachinePathListSafeApproval(
            extensionId, nonce, c.govHash, signedNonce, ""
        );
        vm.expectRevert(IMachinePathManager.InvalidSignaturesLength.selector);
        flareTeeManager.confirmMachinePathListSafeApproval(
            extensionId, nonce, c.govHash, signedNonce, new bytes(64)
        );
    }

    function testConfirmMachinePathListSafeApprovalRevertInvalidSignatureType() public {
        // Approved-hash (v=1) and contract-signature (v=0) chunks carry no ECDSA signature to
        // verify: they appear when an owner executes the Safe transaction itself — execute from a
        // non-owner account instead.
        SafeCtx memory c = _setupSafeGovernanceCtx("IT", 2, 2);
        uint256 nonce = _newFinalizedList(c.teeS1, c.teeS2);
        uint256 signedNonce = _execApproval(c.safe, nonce);

        // r = padded owner address, like a real approved-hash / contract-signature chunk.
        bytes32 rOwner = bytes32(uint256(uint160(c.owners[0])));
        vm.expectRevert(IMachinePathManager.InvalidSignatureType.selector);
        flareTeeManager.confirmMachinePathListSafeApproval(
            extensionId, nonce, c.govHash, signedNonce,
            abi.encodePacked(rOwner, bytes32(0), uint8(1))
        );
        vm.expectRevert(IMachinePathManager.InvalidSignatureType.selector);
        flareTeeManager.confirmMachinePathListSafeApproval(
            extensionId, nonce, c.govHash, signedNonce,
            abi.encodePacked(rOwner, bytes32(0), uint8(0))
        );
    }

    function testConfirmMachinePathListSafeApprovalRevertUnorderedSignatures() public {
        SafeCtx memory c = _setupSafeGovernanceCtx("UO", 2, 2);
        uint256 nonce = _newFinalizedList(c.teeS1, c.teeS2);
        uint256 signedNonce = _execApproval(c.safe, nonce);
        bytes32 safeTxHash = _approvalSafeTxHash(address(c.safe), nonce, signedNonce);

        // Descending signer order.
        uint256[] memory reversed = new uint256[](2);
        reversed[0] = c.keys[1];
        reversed[1] = c.keys[0];
        vm.expectRevert(IMachinePathManager.UnorderedSignatures.selector);
        flareTeeManager.confirmMachinePathListSafeApproval(
            extensionId, nonce, c.govHash, signedNonce, _packSignatures(safeTxHash, reversed)
        );

        // Duplicate signer (equal is not strictly ascending) — one signature cannot count twice.
        uint256[] memory duplicated = new uint256[](2);
        duplicated[0] = c.keys[0];
        duplicated[1] = c.keys[0];
        vm.expectRevert(IMachinePathManager.UnorderedSignatures.selector);
        flareTeeManager.confirmMachinePathListSafeApproval(
            extensionId, nonce, c.govHash, signedNonce, _packSignatures(safeTxHash, duplicated)
        );
    }

    function testConfirmMachinePathListSafeApprovalRevertWrongPayloadSignature() public {
        // A signature over anything but the exact reconstructed SafeTxHash (here: the owners
        // signed Safe nonce 99, not the executed nonce) recovers to a non-member address.
        SafeCtx memory c = _setupSafeGovernanceCtx("WP", 2, 2);
        uint256 nonce = _newFinalizedList(c.teeS1, c.teeS2);
        uint256 signedNonce = _execApproval(c.safe, nonce);

        bytes memory blob = _packSignatures(
            _approvalSafeTxHash(address(c.safe), nonce, 99), _firstKeys(c.keys, 1)
        );
        vm.expectRevert(abi.encodeWithSelector(IMachinePathManager.ThresholdNotReached.selector, 2, 0));
        flareTeeManager.confirmMachinePathListSafeApproval(
            extensionId, nonce, c.govHash, signedNonce, blob
        );
    }

    function testConfirmMachinePathListSafeApprovalRevertAlreadyConfirmed() public {
        // Confirmation is one-shot per governance hash: the artifact verifies against the frozen
        // snapshot and stays valid forever, so a replacement could never be fresher — the stored
        // artifact is immutable and consumers may cache it. Repeat APPROVALS stay permitted (the
        // pre-confirm recovery path), but a second confirmation reverts and changes nothing.
        SafeCtx memory c = _setupSafeGovernanceCtx("RO", 3, 2);
        uint256 nonce = _newFinalizedList(c.teeS1, c.teeS2);
        uint256 firstNonce = _execApproval(c.safe, nonce);
        _confirm(c, nonce, firstNonce, 2);
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
        IMachinePathManager.SafeApprovalArtifact memory artifact =
            flareTeeManager.getMachinePathListSafeApprovalArtifact(extensionId, nonce, c.govHash);

        // A later approval at a newer Safe nonce is recorded, but its confirmation is rejected.
        c.safe.setNonce(7);
        uint256 secondNonce = _execApproval(c.safe, nonce);
        assertEq(secondNonce, 7);
        uint256[] memory subset = new uint256[](2);
        subset[0] = c.keys[1];
        subset[1] = c.keys[2];
        bytes memory blob2 = _packSignatures(_approvalSafeTxHash(address(c.safe), nonce, 7), subset);
        vm.expectRevert(IMachinePathManager.SafeApprovalAlreadyConfirmed.selector);
        flareTeeManager.confirmMachinePathListSafeApproval(extensionId, nonce, c.govHash, 7, blob2);

        // The stored artifact is untouched.
        IMachinePathManager.SafeApprovalArtifact memory unchanged =
            flareTeeManager.getMachinePathListSafeApprovalArtifact(extensionId, nonce, c.govHash);
        assertEq(unchanged.safeNonce, artifact.safeNonce);
        assertEq(unchanged.signatures, artifact.signatures);
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, nonce));
        assertEq(flareTeeManager.getActiveMachinePathListNonce(extensionId), nonce);
    }

    function testGetMachinePathListSafeApprovalArtifactEmptyBeforeConfirm() public {
        SafeCtx memory c = _setupSafeGovernanceCtx("G", 2, 2);
        uint256 nonce = _newFinalizedList(c.teeS1, c.teeS2);
        IMachinePathManager.SafeApprovalArtifact memory artifact =
            flareTeeManager.getMachinePathListSafeApprovalArtifact(extensionId, nonce, c.govHash);
        assertEq(artifact.safeNonce, 0);
        assertEq(artifact.signatures.length, 0);
    }

    function testGetMachinePathListSafeApprovalArtifactRevertInvalidNonce() public {
        vm.expectRevert(ITeeCommonErrors.InvalidNonce.selector);
        flareTeeManager.getMachinePathListSafeApprovalArtifact(extensionId, 999, govHashA);
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

    /**
     * @dev Deploys a MockSafe with the given owners/threshold, registers it as a Safe-backed
     *      governance and binds two fresh TEE machines to the resulting governance hash.
     */
    function _setupSafeGovernance(
        address[] memory _owners,
        uint256 _threshold,
        string memory _seed
    )
        private
        returns (
            MockSafe _safe,
            bytes32 _govHash,
            address _teeS1,
            address _teeS2
        )
    {
        _safe = new MockSafe(_owners, _threshold);
        (_govHash, _teeS1, _teeS2) = _registerSafeGovernance(_safe, _seed);
    }

    /**
     * @dev Registers the MockSafe's CURRENT owners/threshold as a (possibly new) Safe-backed
     *      governance snapshot and binds two fresh TEE machines to its hash. Reused after owner
     *      rotation to mint the post-rotation snapshot.
     */
    function _registerSafeGovernance(
        MockSafe _safe,
        string memory _seed
    )
        private
        returns (
            bytes32 _govHash,
            address _teeS1,
            address _teeS2
        )
    {
        bytes32[] memory plats = new bytes32[](1);
        plats[0] = platform;
        vm.prank(owner);
        flareTeeManager.setNewTeeGovernanceSafe(extensionId, address(_safe));
        _govHash = flareTeeManager.getLatestTeeGovernanceHash(extensionId);
        bytes32 codeHashS = keccak256(abi.encodePacked("codeHash", _seed));
        vm.prank(owner);
        flareTeeManager.addTeeVersion(
            extensionId, keccak256(abi.encodePacked("v", _seed)), codeHashS, plats
        );
        _teeS1 = makeAddr(string.concat("teeS1_", _seed));
        _teeS2 = makeAddr(string.concat("teeS2_", _seed));
        helper.setTeeMachineState(
            _teeS1, extensionId, codeHashS, platform, _govHash, IMachineManager.TeeStatus.PRODUCTION
        );
        helper.setTeeMachineState(
            _teeS2, extensionId, codeHashS, platform, _govHash, IMachineManager.TeeStatus.PRODUCTION
        );
    }

    /**
     * @dev Deploys + registers a Safe-backed governance whose owners have known private keys
     *      (sorted ascending by owner address — the packed-blob order the Safe encoding requires)
     *      and binds two fresh TEE machines to its hash.
     */
    function _setupSafeGovernanceCtx(
        string memory _seed,
        uint256 _ownerCount,
        uint256 _threshold
    )
        private
        returns (SafeCtx memory _c)
    {
        (_c.owners, _c.keys) = _makeOwnerKeys(_seed, _ownerCount);
        (_c.safe, _c.govHash, _c.teeS1, _c.teeS2) = _setupSafeGovernance(_c.owners, _threshold, _seed);
    }

    /// @dev Keyed owner addresses, sorted ascending (insertion sort) so blobs packed from `_keys`
    ///      prefixes recover in the strictly-ascending order the confirmation requires.
    function _makeOwnerKeys(
        string memory _seed,
        uint256 _count
    )
        private
        returns (
            address[] memory _owners,
            uint256[] memory _keys
        )
    {
        _owners = new address[](_count);
        _keys = new uint256[](_count);
        for (uint256 i = 0; i < _count; i++) {
            (_owners[i], _keys[i]) = makeAddrAndKey(string.concat("keyedOwner", _seed, "_", vm.toString(i)));
        }
        for (uint256 i = 1; i < _count; i++) {
            for (uint256 j = i; j > 0 && _owners[j - 1] > _owners[j]; j--) {
                (_owners[j - 1], _owners[j]) = (_owners[j], _owners[j - 1]);
                (_keys[j - 1], _keys[j]) = (_keys[j], _keys[j - 1]);
            }
        }
    }

    /// @dev Executes the approval through the Safe (msg.sender == the Safe) at its current nonce
    ///      and returns the SIGNED nonce — the pre-execution value; MockSafe pre-increments in
    ///      `exec`, mirroring the real Safe.
    function _execApproval(MockSafe _safe, uint256 _listNonce) private returns (uint256 _signedNonce) {
        _signedNonce = _safe.nonce();
        _safe.exec(
            address(flareTeeManager),
            abi.encodeCall(
                IMachinePathManager.approveMachinePathList,
                (extensionId, _listNonce, _listMessageHash(extensionId, _listNonce))
            )
        );
    }

    /// @dev Confirms `_c.govHash` on the list with the first `_numSigs` owner signatures.
    function _confirm(SafeCtx memory _c, uint256 _listNonce, uint256 _signedNonce, uint256 _numSigs) private {
        bytes memory blob = _packSignatures(
            _approvalSafeTxHash(address(_c.safe), _listNonce, _signedNonce),
            _firstKeys(_c.keys, _numSigs)
        );
        flareTeeManager.confirmMachinePathListSafeApproval(
            extensionId, _listNonce, _c.govHash, _signedNonce, blob
        );
    }

    function _newList() private returns (uint256 _nonce) {
        vm.prank(owner);
        _nonce = flareTeeManager.createNewMachinePathList(extensionId);
    }

    function _newFinalizedList(address _src, address _dst) private returns (uint256 _nonce) {
        _nonce = _newListWithPath(_src, _dst);
        vm.prank(owner);
        flareTeeManager.finalizeMachinePathList(extensionId, _nonce);
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

    /// @dev Deterministic owner addresses `owner<seed>_0..n-1` (no private keys needed).
    function _makeOwners(string memory _seed, uint256 _count) private returns (address[] memory _r) {
        _r = new address[](_count);
        for (uint256 i = 0; i < _count; i++) {
            _r[i] = makeAddr(string.concat("owner", _seed, "_", vm.toString(i)));
        }
    }

    function _listMessageHash(uint256 _extensionId, uint256 _nonce) private view returns (bytes32) {
        (IMachinePathManager.MachinePath[] memory paths,,,) =
            flareTeeManager.getMachinePathList(_extensionId, _nonce);
        return SignedPayload.messageHash(
            TEE_MACHINE_PATH_LIST,
            keccak256(abi.encode(_extensionId, _nonce, paths))
        );
    }

    /// @dev Independent reimplementation of the on-chain SafeTxHash reconstruction (test oracle):
    ///      a plain single CALL to the diamond carrying the approval calldata, zero value/gas
    ///      fields, under the Safe >= 1.3.0 domain (chainId + Safe address).
    function _approvalSafeTxHash(
        address _safe,
        uint256 _listNonce,
        uint256 _safeNonce
    )
        private view
        returns (bytes32)
    {
        bytes memory data = abi.encodeCall(
            IMachinePathManager.approveMachinePathList,
            (extensionId, _listNonce, _listMessageHash(extensionId, _listNonce))
        );
        bytes32 safeTxHash = keccak256(abi.encode(
            keccak256(
                "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,"
                "uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
            ),
            address(flareTeeManager),
            uint256(0),
            keccak256(data),
            uint8(0),
            uint256(0),
            uint256(0),
            uint256(0),
            address(0),
            address(0),
            _safeNonce
        ));
        bytes32 domainSep = keccak256(abi.encode(
            keccak256("EIP712Domain(uint256 chainId,address verifyingContract)"),
            block.chainid,
            _safe
        ));
        return keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSep, safeTxHash));
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

    function _h1(bytes32 _a) private pure returns (bytes32[] memory _r) {
        _r = new bytes32[](1);
        _r[0] = _a;
    }

    function _h2(bytes32 _a, bytes32 _b) private pure returns (bytes32[] memory _r) {
        _r = new bytes32[](2);
        _r[0] = _a;
        _r[1] = _b;
    }

    /// @dev Packs `{r,s,v}` chunks in key order (keys must be pre-sorted by signer address).
    function _packSignatures(bytes32 _hash, uint256[] memory _keys) private pure returns (bytes memory _blob) {
        for (uint256 i = 0; i < _keys.length; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(_keys[i], _hash);
            _blob = abi.encodePacked(_blob, r, s, v);
        }
    }

    function _firstKeys(uint256[] memory _keys, uint256 _n) private pure returns (uint256[] memory _r) {
        _r = new uint256[](_n);
        for (uint256 i = 0; i < _n; i++) {
            _r[i] = _keys[i];
        }
    }

    function _sign(bytes32 _hash, uint256 _privKey) private pure returns (Signature memory) {
        return SignatureHelper.createSignature(vm, _hash, _privKey);
    }
}
