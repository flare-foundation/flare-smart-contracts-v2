// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { FlareTeeManagerDeployer } from "../utils/FlareTeeManagerDeployer.sol";
import { SignatureHelper } from "../utils/SignatureHelper.sol";

import { IIFlareTeeManager } from "../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IWalletBackupManager } from "../../contracts/userInterfaces/tee/IWalletBackupManager.sol";
import { IWalletManager } from "../../contracts/userInterfaces/tee/IWalletManager.sol";
import { IMachinePathManager, TEE_MACHINE_PATH_LIST }
    from "../../contracts/userInterfaces/tee/IMachinePathManager.sol";
import { SignedPayload } from "../../contracts/utils/lib/SignedPayload.sol";
import { IMachineManager } from "../../contracts/userInterfaces/tee/IMachineManager.sol";
import { ITeeExtensionStateVerifier }
    from "../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { ProtocolsV2Interface } from "../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IIRewardManager } from "../../contracts/protocol/interface/IIRewardManager.sol";
import { PublicKey } from "../../contracts/userInterfaces/IPublicKey.sol";
import { Signature } from "../../contracts/userInterfaces/ISignature.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

import { IDiamond } from "../../contracts/diamond/interfaces/IDiamond.sol";
import { IDiamondCut } from "../../contracts/diamond/interfaces/IDiamondCut.sol";

import { MachineManager } from "../../contracts/tee/library/MachineManager.sol";
import { WalletKeyManager } from "../../contracts/tee/library/WalletKeyManager.sol";
import { WalletManager } from "../../contracts/tee/library/WalletManager.sol";
import { WalletProjectManager } from "../../contracts/tee/library/WalletProjectManager.sol";

interface ITestSetupHelper {
    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform,
        bytes32 _governanceHash,
        PublicKey calldata _teePublicKey
    ) external;

    function setProjectState(
        bytes32 _projectId,
        address _owner,
        uint256 _extensionId,
        bytes32 _keyType,
        bytes32 _signingAlgo,
        address _backupManager
    ) external;

    function setWalletState(
        bytes32 _walletId,
        bytes32 _projectId,
        PublicKey[] calldata _adminsPublicKeys,
        uint64 _adminsThreshold
    ) external;

    function setKeyState(
        bytes32 _walletId,
        uint64 _keyId,
        bytes calldata _publicKey,
        address[] calldata _teeIds
    ) external;
}

/**
 * @notice State-writing helper that bypasses the production registration / attestation /
 *         wallet-lifecycle paths. The integration test exercises the FULL `MachinePathManager`
 *         flow (create → add → finalize → sign) through the public API, and only uses this helper
 *         to short-cut the orthogonal machine + wallet + key bootstrap.
 */
contract TestSetupHelperFacet is ITestSetupHelper {

    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform,
        bytes32 _governanceHash,
        PublicKey calldata _teePublicKey
    )
        external
    {
        MachineManager.State storage s = MachineManager.getState();
        // owner must be non-zero — MachineManager.getTeeMachineState reverts TeeNotFound otherwise.
        s.teeMachineStates[_teeId] = MachineManager.TeeMachineState({
            extensionId: _extensionId,
            teePublicKey: _teePublicKey,
            initialTeeId: _teeId,
            initialSigningPolicyId: 0,
            owner: address(uint160(uint256(uint160(_teeId)) ^ 1)),
            teeProxyId: _teeId,
            status: IMachineManager.TeeStatus.PRODUCTION,
            lastStatusChangeTs: uint64(block.timestamp),
            codeHash: _codeHash,
            platform: _platform,
            governanceHash: _governanceHash,
            url: "https://tee.url"
        });
    }

    function setProjectState(
        bytes32 _projectId,
        address _owner,
        uint256 _extensionId,
        bytes32 _keyType,
        bytes32 _signingAlgo,
        address _backupManager
    )
        external
    {
        WalletProjectManager.getState().projects[_projectId] =
            WalletProjectManager.TeeWalletProjectState({
                owner: _owner,
                extensionId: _extensionId,
                keyType: _keyType,
                signingAlgo: _signingAlgo,
                backupManager: _backupManager
            });
    }

    function setWalletState(
        bytes32 _walletId,
        bytes32 _projectId,
        PublicKey[] calldata _adminsPublicKeys,
        uint64 _adminsThreshold
    )
        external
    {
        WalletManager.TeeWalletState storage wallet = WalletManager.getState().wallets[_walletId];
        wallet.projectId = _projectId;
        wallet.status = IWalletManager.WalletStatus.PRODUCTION;
        wallet.adminsThreshold = _adminsThreshold;
        for (uint256 i = 0; i < _adminsPublicKeys.length; i++) {
            wallet.adminsPublicKeys.push(_adminsPublicKeys[i]);
        }
    }

    function setKeyState(
        bytes32 _walletId,
        uint64 _keyId,
        bytes calldata _publicKey,
        address[] calldata _teeIds
    )
        external
    {
        WalletKeyManager.TeeWalletKeysState storage keys =
            WalletKeyManager.getState().walletKeys[_walletId];
        keys.keyIdCounter = _keyId + 1;
        WalletKeyManager.KeyDefinition storage keyDef = keys.keyDefinitions[_keyId];
        keyDef.publicKey = _publicKey;
        for (uint256 i = 0; i < _teeIds.length; i++) {
            keyDef.teeIds.push(_teeIds[i]);
        }
    }
}

// solhint-disable-next-line max-states-count
contract MachinePathDirectBackupIntegrationTest is Test {

    // --- diamond + actors ------------------------------------------------------------------------
    IIFlareTeeManager private flareTeeManager;
    ITestSetupHelper private helper;
    address private initialGovernance;
    address private addressUpdater;
    address private extensionOwner;
    address private projectOwner;

    uint256 private extensionId;
    bytes32 private platform;

    // --- three coexisting governance configurations + their TEE machines ------------------------
    address[] private signersA;
    uint256[] private privKeysA;
    bytes32 private govHashA;
    bytes32 private codeHashA;
    address private teeA;            // PRODUCTION, holds the wallet key

    address[] private signersB;
    uint256[] private privKeysB;
    bytes32 private govHashB;
    bytes32 private codeHashB;
    address private teeB;            // PRODUCTION, restore destination

    address[] private signersC;
    uint256[] private privKeysC;
    bytes32 private govHashC;
    bytes32 private codeHashC;
    address private teeC;            // PRODUCTION, alternate destination (used in deprecation test)

    // --- wallet / key ----------------------------------------------------------------------------
    bytes32 private projectId;
    bytes32 private walletId;
    uint64 private keyId;
    bytes private walletKeyPublicKey;
    bytes32 private keyType;
    bytes32 private signingAlgo;
    PublicKey private adminPk1;
    PublicKey private adminPk2;

    function setUp() public {
        // -----------------------------------------------------------------------------------------
        // Deploy diamond + helper facet
        // -----------------------------------------------------------------------------------------
        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("addressUpdater");
        extensionOwner = makeAddr("extensionOwner");
        projectOwner = makeAddr("projectOwner");
        vm.deal(projectOwner, 1 ether);

        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
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
        vm.startPrank(initialGovernance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();

        _wireExternalAddresses();
        _attachHelperFacet();
        helper = ITestSetupHelper(address(flareTeeManager));

        // -----------------------------------------------------------------------------------------
        // Register extension + three governance configurations + matching TEE versions
        // -----------------------------------------------------------------------------------------
        platform = keccak256("platform");
        bytes32[] memory platforms = new bytes32[](1);
        platforms[0] = platform;
        vm.prank(initialGovernance);
        flareTeeManager.addSystemSupportedPlatforms(platforms);

        vm.prank(extensionOwner);
        extensionId = flareTeeManager.register(
            ITeeExtensionStateVerifier(address(0)),
            makeAddr("instructionsSender")
        );

        (signersA, privKeysA, govHashA, codeHashA) =
            _registerGovernance("signerA", "codeHashA", platforms, "vA");
        (signersB, privKeysB, govHashB, codeHashB) =
            _registerGovernance("signerB", "codeHashB", platforms, "vB");
        (signersC, privKeysC, govHashC, codeHashC) =
            _registerGovernance("signerC", "codeHashC", platforms, "vC");

        // -----------------------------------------------------------------------------------------
        // Register three TEE machines — one under each governance
        // -----------------------------------------------------------------------------------------
        teeA = _registerTeeMachine("teeA", codeHashA, govHashA);
        teeB = _registerTeeMachine("teeB", codeHashB, govHashB);
        teeC = _registerTeeMachine("teeC", codeHashC, govHashC);

        // -----------------------------------------------------------------------------------------
        // Wallet + key (teeA holds the key)
        // -----------------------------------------------------------------------------------------
        projectId = keccak256("project");
        walletId = keccak256("wallet");
        keyId = 1;
        walletKeyPublicKey = bytes("walletKeyPublicKey");
        keyType = keccak256("keyType");
        signingAlgo = keccak256("signingAlgo");

        VmSafe.Wallet memory w1 = vm.createWallet("admin1");
        adminPk1 = PublicKey(bytes32(w1.publicKeyX), bytes32(w1.publicKeyY));
        VmSafe.Wallet memory w2 = vm.createWallet("admin2");
        adminPk2 = PublicKey(bytes32(w2.publicKeyX), bytes32(w2.publicKeyY));

        helper.setProjectState(projectId, projectOwner, extensionId, keyType, signingAlgo, address(0));
        PublicKey[] memory admins = new PublicKey[](2);
        admins[0] = adminPk1;
        admins[1] = adminPk2;
        helper.setWalletState(walletId, projectId, admins, 2);

        address[] memory keyHolders = new address[](1);
        keyHolders[0] = teeA;
        helper.setKeyState(walletId, keyId, walletKeyPublicKey, keyHolders);
    }

    // =============================================================================================
    // Happy path: multi-governance signing → directBackup → directRestore
    // =============================================================================================

    function testFullFlowMultiGovernanceSignedListEnablesDirectBackupAndRestore() public {
        // 1. Extension owner creates a list with a multi-governance path (sources from A,
        //    destinations from B+C). This proves that backups can be authorized across
        //    governances within a single signed list.
        IMachinePathManager.MachinePath[] memory paths = new IMachinePathManager.MachinePath[](1);
        paths[0].sourceTeeIds = new address[](1);
        paths[0].sourceTeeIds[0] = teeA;
        paths[0].destinationTeeIds = new address[](2);
        paths[0].destinationTeeIds[0] = teeB;
        paths[0].destinationTeeIds[1] = teeC;

        vm.prank(extensionOwner);
        uint256 listNonce = flareTeeManager.createNewMachinePathList(extensionId);
        assertEq(listNonce, 1);
        vm.prank(extensionOwner);
        flareTeeManager.addMachinePaths(extensionId, listNonce, paths);
        vm.prank(extensionOwner);
        flareTeeManager.finalizeMachinePathList(extensionId, listNonce);

        // 2. All three involved governances (A, B, C) must sign before the list activates.
        bytes32 hash = _messageHash(listNonce, paths);
        flareTeeManager.signMachinePathList(extensionId, listNonce, _sig(hash, privKeysA[0]));
        // Not signed yet: still missing B and C
        vm.expectRevert(IMachinePathManager.NoActiveMachinePathList.selector);
        flareTeeManager.getActiveMachinePathListNonce(extensionId);

        flareTeeManager.signMachinePathList(extensionId, listNonce, _sig(hash, privKeysB[0]));
        // Still missing C
        vm.expectRevert(IMachinePathManager.NoActiveMachinePathList.selector);
        flareTeeManager.getActiveMachinePathListNonce(extensionId);

        flareTeeManager.signMachinePathList(extensionId, listNonce, _sig(hash, privKeysC[0]));
        // Threshold across every involved governance now met → list is active.
        assertEq(flareTeeManager.getActiveMachinePathListNonce(extensionId), listNonce);

        // 3. directBackup must succeed for either of the authorized destinations and must NOT
        //    mutate teeB's per-key nonce (it just reads + 1).
        (uint256 nonceBefore, ) = flareTeeManager.getKeyNonce(teeB, walletId, keyId);
        assertEq(nonceBefore, 0);

        vm.prank(projectOwner);
        bytes32 backupInstructionId =
            flareTeeManager.directBackup{value: 1000}(teeA, teeB, walletId, keyId, address(0));
        assertTrue(backupInstructionId != bytes32(0));
        (uint256 nonceBetween, ) = flareTeeManager.getKeyNonce(teeB, walletId, keyId);
        assertEq(nonceBetween, nonceBefore, "directBackup must not bump destination nonce");

        // 4. directRestore (with the BackupId pointing back at teeA) bumps teeB's nonce by exactly 1.
        IWalletBackupManager.BackupId memory bid = _backupId(teeA);
        vm.mockCall(
            address(uint160(uint256(keccak256("mock-fsm")))),
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(uint24(15))
        );

        vm.prank(projectOwner);
        flareTeeManager.directRestore{value: 1000}(teeB, bid, backupInstructionId, address(0));
        (uint256 nonceAfter, ) = flareTeeManager.getKeyNonce(teeB, walletId, keyId);
        assertEq(nonceAfter, 1, "directRestore must bump destination nonce by exactly +1");
    }

    // =============================================================================================
    // Cross-facet revert: list exists but doesn't cover the requested pair
    // =============================================================================================

    function testDirectBackupRevertsWhenPairNotInActiveSignedList() public {
        // Sign a list containing teeA → teeB only.
        _signSingleSourceList(teeA, teeB);

        // directBackup for teeA → teeC must revert because teeC is NOT in the active list's
        // destination set (even though it is registered in the same extension).
        vm.prank(projectOwner);
        vm.expectRevert(IMachinePathManager.InvalidMachinePath.selector);
        flareTeeManager.directBackup(teeA, teeC, walletId, keyId, address(0));
    }

    // =============================================================================================
    // Cross-facet replay model: a newer signed list deprecates older paths
    // =============================================================================================

    function testNewerSignedListDeprecatesPathsFromOlderList() public {
        // List 1: authorizes teeA → teeB. Sign it (involves governances A + B) → activated.
        uint256 list1 = _signSingleSourceList(teeA, teeB);
        assertEq(flareTeeManager.getActiveMachinePathListNonce(extensionId), list1);

        // directBackup teeA → teeB works.
        vm.prank(projectOwner);
        flareTeeManager.directBackup{value: 1000}(teeA, teeB, walletId, keyId, address(0));

        // Now sign a NEWER list (list 2) authorizing teeA → teeC (governances A + C) → activates.
        uint256 list2 = _signSingleSourceList(teeA, teeC);
        assertEq(flareTeeManager.getActiveMachinePathListNonce(extensionId), list2);
        assertGt(list2, list1);

        // teeA → teeB is no longer authorized by the active list — directBackup must revert.
        vm.prank(projectOwner);
        vm.expectRevert(IMachinePathManager.InvalidMachinePath.selector);
        flareTeeManager.directBackup(teeA, teeB, walletId, keyId, address(0));

        // But teeA → teeC works via the newer list.
        vm.prank(projectOwner);
        flareTeeManager.directBackup{value: 1000}(teeA, teeC, walletId, keyId, address(0));
    }

    // =============================================================================================
    // Helpers
    // =============================================================================================

    function _registerGovernance(
        string memory _signerLabel,
        string memory _codeHashLabel,
        bytes32[] memory _platforms,
        bytes32 _versionLabel
    )
        private
        returns (
            address[] memory _signers,
            uint256[] memory _privKeys,
            bytes32 _govHash,
            bytes32 _codeHash
        )
    {
        _signers = new address[](1);
        _privKeys = new uint256[](1);
        (_signers[0], _privKeys[0]) = makeAddrAndKey(_signerLabel);
        _govHash = keccak256(abi.encode(_signers, uint64(1)));
        vm.prank(extensionOwner);
        flareTeeManager.setNewTeeGovernance(extensionId, _signers, 1);
        _codeHash = keccak256(bytes(_codeHashLabel));
        vm.prank(extensionOwner);
        flareTeeManager.addTeeVersion(extensionId, _versionLabel, _codeHash, _platforms);
    }

    function _registerTeeMachine(string memory _label, bytes32 _codeHash, bytes32 _governanceHash)
        private
        returns (address _teeId)
    {
        VmSafe.Wallet memory w = vm.createWallet(_label);
        _teeId = w.addr;
        helper.setTeeMachineState(
            _teeId,
            extensionId,
            _codeHash,
            platform,
            _governanceHash,
            PublicKey(bytes32(w.publicKeyX), bytes32(w.publicKeyY))
        );
    }

    /// Builds a single-path list authorizing `_src → _dst`, finalizes, and collects signatures from
    /// both involved governances. Returns the freshly-allocated nonce.
    function _signSingleSourceList(address _src, address _dst) private returns (uint256 _nonce) {
        IMachinePathManager.MachinePath[] memory paths = new IMachinePathManager.MachinePath[](1);
        paths[0].sourceTeeIds = new address[](1);
        paths[0].sourceTeeIds[0] = _src;
        paths[0].destinationTeeIds = new address[](1);
        paths[0].destinationTeeIds[0] = _dst;
        vm.prank(extensionOwner);
        _nonce = flareTeeManager.createNewMachinePathList(extensionId);
        vm.prank(extensionOwner);
        flareTeeManager.addMachinePaths(extensionId, _nonce, paths);
        vm.prank(extensionOwner);
        flareTeeManager.finalizeMachinePathList(extensionId, _nonce);
        bytes32 hash = _messageHash(_nonce, paths);
        // Both involved governances must sign.
        flareTeeManager.signMachinePathList(extensionId, _nonce, _sig(hash, _privKeyFor(_src)));
        if (_governanceFor(_src) != _governanceFor(_dst)) {
            flareTeeManager.signMachinePathList(extensionId, _nonce, _sig(hash, _privKeyFor(_dst)));
        }
    }

    function _wireExternalAddresses() private {
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

        vm.mockCall(
            addresses[1],
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(uint24(15))
        );
        vm.mockCall(
            addresses[2],
            abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
            abi.encode("")
        );
    }

    function _attachHelperFacet() private {
        TestSetupHelperFacet impl = new TestSetupHelperFacet();
        bytes4[] memory s = new bytes4[](4);
        s[0] = ITestSetupHelper.setTeeMachineState.selector;
        s[1] = ITestSetupHelper.setProjectState.selector;
        s[2] = ITestSetupHelper.setWalletState.selector;
        s[3] = ITestSetupHelper.setKeyState.selector;
        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](1);
        cuts[0] = IDiamond.FacetCut(address(impl), IDiamond.FacetCutAction.Add, s);
        vm.prank(initialGovernance);
        IDiamondCut(address(flareTeeManager)).diamondCut(cuts, address(0), "");
    }

    function _governanceFor(address _tee) private view returns (bytes32) {
        if (_tee == teeA) return govHashA;
        if (_tee == teeB) return govHashB;
        if (_tee == teeC) return govHashC;
        revert("unknown tee");
    }

    function _privKeyFor(address _tee) private view returns (uint256) {
        if (_tee == teeA) return privKeysA[0];
        if (_tee == teeB) return privKeysB[0];
        if (_tee == teeC) return privKeysC[0];
        revert("unknown tee");
    }

    function _messageHash(uint256 _nonce, IMachinePathManager.MachinePath[] memory _paths)
        private view
        returns (bytes32)
    {
        return SignedPayload.messageHash(
            TEE_MACHINE_PATH_LIST,
            keccak256(abi.encode(extensionId, _nonce, _paths))
        );
    }

    function _backupId(address _sourceTee) private view returns (IWalletBackupManager.BackupId memory) {
        return IWalletBackupManager.BackupId({
            teeId: _sourceTee,
            walletId: walletId,
            keyId: keyId,
            keyType: keyType,
            signingAlgo: signingAlgo,
            publicKey: walletKeyPublicKey,
            rewardEpochId: 1,
            randomNonce: bytes32("rn")
        });
    }

    function _sig(bytes32 _hash, uint256 _privKey) private pure returns (Signature memory) {
        return SignatureHelper.createSignature(vm, _hash, _privKey);
    }
}
