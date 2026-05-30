// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";

import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import {
    IWalletBackupManager
} from "../../../../contracts/userInterfaces/tee/IWalletBackupManager.sol";
import { IMachineManager } from "../../../../contracts/userInterfaces/tee/IMachineManager.sol";
import { IWalletManager } from "../../../../contracts/userInterfaces/tee/IWalletManager.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";
import { PublicKey } from "../../../../contracts/userInterfaces/IPublicKey.sol";

import { IDiamond } from "../../../../contracts/diamond/interfaces/IDiamond.sol";
import { IDiamondCut } from "../../../../contracts/diamond/interfaces/IDiamondCut.sol";

import { MachineManager } from "../../../../contracts/tee/library/MachineManager.sol";
import { WalletProjectManager } from "../../../../contracts/tee/library/WalletProjectManager.sol";
import { WalletManager } from "../../../../contracts/tee/library/WalletManager.sol";
import { WalletKeyManager } from "../../../../contracts/tee/library/WalletKeyManager.sol";
import { MachinePathManager } from "../../../../contracts/tee/library/MachinePathManager.sol";
import { IMachinePathManager } from "../../../../contracts/userInterfaces/tee/IMachinePathManager.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface ITestStateHelper {
    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        IMachineManager.TeeStatus _status,
        PublicKey calldata _publicKey,
        uint32 _initialSigningPolicyId,
        string calldata _url
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
        address[] calldata _teeIds,
        uint64 _keyIdCounter
    ) external;

    function setExtensionInstructionCounter(
        uint256 _extensionId,
        uint256 _counter
    ) external;

    function setActiveMachinePath(
        uint256 _extensionId,
        address _sourceTeeId,
        address _destinationTeeId
    ) external;
}

/**
 * @title TestStateHelperFacet
 * @notice A test-only facet added to the diamond to write internal state directly,
 *         bypassing the complex registration, attestation, and wallet lifecycle flows.
 */
contract TestStateHelperFacet is ITestStateHelper {
    using EnumerableSet for EnumerableSet.AddressSet;

    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        IMachineManager.TeeStatus _status,
        PublicKey calldata _publicKey,
        uint32 _initialSigningPolicyId,
        string calldata _url
    )
        external
    {
        MachineManager.State storage s = MachineManager.getState();
        s.teeMachineStates[_teeId] = MachineManager.TeeMachineState({
            extensionId: _extensionId,
            teePublicKey: _publicKey,
            initialTeeId: _teeId,
            initialSigningPolicyId: _initialSigningPolicyId,
            owner: _owner,
            teeProxyId: _teeId,
            status: _status,
            lastStatusChangeTs: block.timestamp,
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
        WalletProjectManager.State storage s = WalletProjectManager.getState();
        s.projects[_projectId] = WalletProjectManager.TeeWalletProjectState({
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
        WalletManager.State storage s = WalletManager.getState();
        WalletManager.TeeWalletState storage wallet = s.wallets[_walletId];
        wallet.projectId = _projectId;
        wallet.status = IWalletManager.WalletStatus.PRODUCTION;
        wallet.adminsThreshold = _adminsThreshold;
        while (wallet.adminsPublicKeys.length > 0) {
            wallet.adminsPublicKeys.pop();
        }
        for (uint256 i = 0; i < _adminsPublicKeys.length; i++) {
            wallet.adminsPublicKeys.push(_adminsPublicKeys[i]);
        }
    }

    function setKeyState(
        bytes32 _walletId,
        uint64 _keyId,
        bytes calldata _publicKey,
        address[] calldata _teeIds,
        uint64 _keyIdCounter
    )
        external
    {
        WalletKeyManager.State storage s = WalletKeyManager.getState();
        WalletKeyManager.TeeWalletKeysState storage keys = s.walletKeys[_walletId];
        keys.keyIdCounter = _keyIdCounter;
        WalletKeyManager.KeyDefinition storage keyDef = keys.keyDefinitions[_keyId];
        keyDef.publicKey = _publicKey;
        // clear existing teeIds
        while (keyDef.teeIds.length > 0) {
            keyDef.teeIds.pop();
        }
        for (uint256 i = 0; i < _teeIds.length; i++) {
            keyDef.teeIds.push(_teeIds[i]);
        }
    }

    function setExtensionInstructionCounter(
        uint256 _extensionId,
        uint256 _counter
    )
        external
    {
        // instructionCounter was removed from TeeExtension struct
        (_extensionId, _counter); // suppress unused variable warning
    }

    /**
     * @notice Writes a synthetic active machine-path list with a single (src, dst) path directly
     *         into storage, bypassing the governance / signing flow. Lets WalletBackupManager
     *         tests focus on directBackup/directRestore behaviour given a valid or absent path.
     *
     * @dev INVARIANT GAP: this helper sets `listSigned = true` but leaves `involvedGovernanceHashes`
     *      empty and `signatureCount` at zero — in the production sign flow, those are populated
     *      before activation. The current backup/restore call sites only consult
     *      `requireActiveListNonceForPath` (which walks `paths` only), so the synthetic shape is
     *      sufficient. If a future read site touches the involved-governance set or the per-
     *      governance signature counts of the active list, this helper must be extended.
     */
    function setActiveMachinePath(
        uint256 _extensionId,
        address _sourceTeeId,
        address _destinationTeeId
    )
        external
    {
        MachinePathManager.State storage s = MachinePathManager.getState();
        uint256 nonce = s.lists[_extensionId].length + 1;
        MachinePathManager.MachinePathList storage list = s.lists[_extensionId].push();
        MachinePathManager.MachinePathState storage pathState = list.paths.push();
        pathState.path.sourceTeeIds.push(_sourceTeeId);
        pathState.path.destinationTeeIds.push(_destinationTeeId);
        pathState.sourceTeeIdExists[_sourceTeeId] = true;
        pathState.destinationTeeIdExists[_destinationTeeId] = true;
        list.messageHash = keccak256("synthetic-test-message-hash");
        list.listSigned = true;
        s.extensionActiveListNonce[_extensionId] = nonce;
    }
}

// solhint-disable-next-line max-states-count
contract WalletBackupManagerFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;

    address private owner;
    address private backupManager;

    address private initialGovernance;
    address private addressUpdater;
    IGovernanceSettings private governanceSettings;
    address private flareSystemsManager;
    address private rewardManager;

    address private teeId;
    address private backupTeeId;
    address private teeMachineOwner;
    bytes32 private projectId;
    bytes32 private walletId;
    IWalletBackupManager.BackupId private backupId;
    string private backupUrl;
    uint64 private keyId;
    bytes private publicKey;
    address private keyHolderTeeId;
    uint32 private rewardEpochId;
    bytes32 private keyType;
    bytes32 private signingAlgo;
    uint256 private extensionId;
    uint256 private nonce;

    PublicKey private adminPk1;
    PublicKey private adminPk2;
    uint64 private adminsThreshold;

    function setUp() public {
        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        governanceSettings = IGovernanceSettings(makeAddr("governanceSettings"));
        flareSystemsManager = makeAddr("FlareSystemsManager");
        rewardManager = makeAddr("RewardManager");

        owner = makeAddr("owner");
        backupManager = makeAddr("backupManager");
        teeMachineOwner = makeAddr("teeMachineOwner");

        teeId = makeAddr("teeId");
        backupTeeId = makeAddr("backupTeeId");
        keyHolderTeeId = makeAddr("keyHolderTeeId");
        projectId = keccak256("projectId");
        walletId = keccak256("walletId");
        keyId = 1;
        publicKey = bytes("publicKey");
        rewardEpochId = 1;
        nonce = 1;
        backupUrl = "backupUrl";
        extensionId = 10;

        keyType = keccak256("keyType");
        signingAlgo = keccak256("signingAlgo");

        // Use valid ec points for admin public keys
        VmSafe.Wallet memory w1 = vm.createWallet("admin1");
        adminPk1 = PublicKey(bytes32(w1.publicKeyX), bytes32(w1.publicKeyY));
        VmSafe.Wallet memory w2 = vm.createWallet("admin2");
        adminPk2 = PublicKey(bytes32(w2.publicKeyX), bytes32(w2.publicKeyY));
        adminsThreshold = 2;

        backupId = IWalletBackupManager.BackupId(
            backupTeeId,
            walletId,
            keyId,
            keyType,
            signingAlgo,
            publicKey,
            rewardEpochId,
            bytes32("randomNonce")
        );

        // =====================================================================
        // Deploy FlareTeeManager Diamond
        // =====================================================================

        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: governanceSettings,
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 6,
            challengeValidityDurationSeconds: 600,
            defaultFee: 0,
            publicExtensionCreationEnabled: true,
            emergencyUnpauseGracePeriodSeconds: 7200
        }));
        vm.startPrank(initialGovernance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();

        // =====================================================================
        // Add TestStateHelperFacet to the diamond
        // =====================================================================

        TestStateHelperFacet helperImpl = new TestStateHelperFacet();
        bytes4[] memory helperSelectors = new bytes4[](6);
        helperSelectors[0] = ITestStateHelper.setTeeMachineState.selector;
        helperSelectors[1] = ITestStateHelper.setProjectState.selector;
        helperSelectors[2] = ITestStateHelper.setWalletState.selector;
        helperSelectors[3] = ITestStateHelper.setKeyState.selector;
        helperSelectors[4] = ITestStateHelper.setExtensionInstructionCounter.selector;
        helperSelectors[5] = ITestStateHelper.setActiveMachinePath.selector;

        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](1);
        cuts[0] = IDiamond.FacetCut(
            address(helperImpl),
            IDiamond.FacetCutAction.Add,
            helperSelectors
        );

        vm.prank(initialGovernance);
        IDiamondCut(address(flareTeeManager)).diamondCut(cuts, address(0), "");

        // =====================================================================
        // Update external contract addresses
        // =====================================================================

        bytes32[] memory nameHashes = new bytes32[](6);
        address[] memory addresses = new address[](6);
        nameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        nameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        nameHashes[2] = keccak256(abi.encode("RewardManager"));
        nameHashes[3] = keccak256(abi.encode("Relay"));
        nameHashes[4] = keccak256(abi.encode("Fdc2Hub"));
        nameHashes[5] = keccak256(abi.encode("Fdc2Verification"));
        addresses[0] = addressUpdater;
        addresses[1] = flareSystemsManager;
        addresses[2] = rewardManager;
        addresses[3] = makeAddr("Relay");
        addresses[4] = makeAddr("Fdc2Hub");
        addresses[5] = makeAddr("Fdc2Verification");
        vm.prank(addressUpdater);
        flareTeeManager.updateContractAddresses(nameHashes, addresses);

        // =====================================================================
        // Set up diamond state through the helper facet
        // =====================================================================

        ITestStateHelper helper = ITestStateHelper(address(flareTeeManager));

        // Set teeId as PRODUCTION TEE machine
        helper.setTeeMachineState(
            teeId,
            extensionId,
            teeMachineOwner,
            IMachineManager.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1, // initialSigningPolicyId
            "https://tee.url"
        );

        // Set backupTeeId as PRODUCTION TEE machine (not INITIALIZED)
        helper.setTeeMachineState(
            backupTeeId,
            extensionId,
            teeMachineOwner,
            IMachineManager.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://backup.tee.url"
        );

        // Set up keyHolderTeeId as PRODUCTION TEE machine (separate from teeId)
        helper.setTeeMachineState(
            keyHolderTeeId,
            extensionId,
            teeMachineOwner,
            IMachineManager.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://keyholder.tee.url"
        );

        // Set up project state
        helper.setProjectState(
            projectId,
            owner,
            extensionId,
            keyType,
            signingAlgo,
            backupManager
        );

        // Set up wallet state with admin public keys
        PublicKey[] memory adminsPublicKeys = new PublicKey[](2);
        adminsPublicKeys[0] = adminPk1;
        adminsPublicKeys[1] = adminPk2;
        helper.setWalletState(walletId, projectId, adminsPublicKeys, adminsThreshold);

        // Set up key state: keyHolderTeeId holds the key (not teeId)
        address[] memory keyTeeIds = new address[](1);
        keyTeeIds[0] = keyHolderTeeId;
        helper.setKeyState(walletId, keyId, publicKey, keyTeeIds, keyId + 1);

        // Set extension instruction counter so generateInstructionId works
        helper.setExtensionInstructionCounter(extensionId, 1);

        // =====================================================================
        // Mock external contracts
        // =====================================================================

        vm.mockCall(
            flareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(uint24(15))
        );

        vm.mockCall(
            rewardManager,
            abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
            abi.encode("")
        );
    }

    // =========================================================================
    // backupRestore - revert tests
    // =========================================================================

    function testBackupRestoreRevertOnlyOwnerOrBackupManager() public {
        vm.expectRevert(ITeeCommonErrors.OnlyOwnerOrBackupManager.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertTeeMachineNotAvailable() public {
        // Set teeId to INITIALIZED status
        ITestStateHelper(address(flareTeeManager)).setTeeMachineState(
            teeId,
            extensionId,
            teeMachineOwner,
            IMachineManager.TeeStatus.INITIALIZED,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://tee.url"
        );
        vm.expectRevert(ITeeCommonErrors.TeeMachineNotAvailable.selector);
        vm.prank(owner);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertInvalidTeeMachine() public {
        // Set backupTeeId to INITIALIZED status
        ITestStateHelper(address(flareTeeManager)).setTeeMachineState(
            backupTeeId,
            extensionId,
            teeMachineOwner,
            IMachineManager.TeeStatus.INITIALIZED,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://backup.tee.url"
        );
        vm.expectRevert(IWalletBackupManager.InvalidTeeMachine.selector);
        vm.prank(owner);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertKeyAlreadyAvailable() public {
        // Set key held by teeId (the target restore TEE)
        address[] memory keyTeeIds = new address[](1);
        keyTeeIds[0] = teeId;
        ITestStateHelper(address(flareTeeManager)).setKeyState(
            walletId, keyId, publicKey, keyTeeIds, keyId + 1
        );
        vm.prank(owner);
        vm.expectRevert(IWalletBackupManager.KeyAlreadyAvailable.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertKeyNotConfirmed() public {
        // Set key with empty public key
        address[] memory keyTeeIds = new address[](1);
        keyTeeIds[0] = keyHolderTeeId;
        ITestStateHelper(address(flareTeeManager)).setKeyState(
            walletId, keyId, bytes(""), keyTeeIds, keyId + 1
        );
        vm.prank(owner);
        vm.expectRevert(IWalletBackupManager.KeyNotConfirmed.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertInvalidPublicKey() public {
        // Set key with different public key than backupId.publicKey
        address[] memory keyTeeIds = new address[](1);
        keyTeeIds[0] = keyHolderTeeId;
        ITestStateHelper(address(flareTeeManager)).setKeyState(
            walletId, keyId, bytes("invalidKey"), keyTeeIds, keyId + 1
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidPublicKey.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertUnsupportedRewardEpochId() public {
        backupId.rewardEpochId = 0;
        vm.prank(owner);
        vm.expectRevert(IWalletBackupManager.UnsupportedRewardEpochId.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertInvalidRewardEpochId() public {
        backupId.rewardEpochId = 20;
        vm.prank(owner);
        vm.expectRevert(IWalletBackupManager.InvalidRewardEpochId.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertInvalidKeyType() public {
        backupId.keyType = keccak256("InvalidKeyType");
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidKeyType.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertInvalidSigningAlgo() public {
        backupId.signingAlgo = keccak256("InvalidSigningAlgo");
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidSigningAlgo.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertExtensionIdMismatch1() public {
        // Set backupTeeId to a different extensionId
        ITestStateHelper(address(flareTeeManager)).setTeeMachineState(
            backupTeeId,
            extensionId + 1,
            teeMachineOwner,
            IMachineManager.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://backup.tee.url"
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.ExtensionIdMismatch.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));

        // Restore backupTeeId, set teeId to a different extensionId
        ITestStateHelper(address(flareTeeManager)).setTeeMachineState(
            backupTeeId,
            extensionId,
            teeMachineOwner,
            IMachineManager.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://backup.tee.url"
        );
        ITestStateHelper(address(flareTeeManager)).setTeeMachineState(
            teeId,
            extensionId + 1,
            teeMachineOwner,
            IMachineManager.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://tee.url"
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.ExtensionIdMismatch.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    // =========================================================================
    // backupRestore - happy path
    // =========================================================================

    function testBackupRestore() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IWalletBackupManager.BackupRestoreTriggered(
            teeId,
            walletId,
            keyId,
            1 // nonce (increaseKeyNonce returns ++nonce, first call = 1)
        );
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreByBackupManager() public {
        vm.prank(backupManager);
        vm.expectEmit(true, true, true, true);
        emit IWalletBackupManager.BackupRestoreTriggered(
            teeId,
            walletId,
            keyId,
            1
        );
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    // =========================================================================
    // directBackup
    // =========================================================================
    // Source = keyHolderTeeId (holds the key); destination = teeId (does not).
    // _registerPath() installs a synthetic active machine-path list with this pair so directBackup
    // can succeed; tests that exercise revert paths omit it.
    // =========================================================================

    function testDirectBackupRevertOnlyOwnerOrBackupManager() public {
        _registerPath(keyHolderTeeId, teeId);
        vm.expectRevert(ITeeCommonErrors.OnlyOwnerOrBackupManager.selector);
        flareTeeManager.directBackup(keyHolderTeeId, teeId, walletId, keyId, address(0));
    }

    function testDirectBackupRevertSourceNotInProduction() public {
        _registerPath(keyHolderTeeId, teeId);
        // Move source out of PRODUCTION → checkTeeMachineInProduction reverts.
        ITestStateHelper(address(flareTeeManager)).setTeeMachineState(
            keyHolderTeeId,
            extensionId,
            teeMachineOwner,
            IMachineManager.TeeStatus.SUSPENDED,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://keyholder.tee.url"
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.TeeMachineNotAvailable.selector);
        flareTeeManager.directBackup(keyHolderTeeId, teeId, walletId, keyId, address(0));
    }

    function testDirectBackupRevertDestinationNotInProduction() public {
        _registerPath(keyHolderTeeId, teeId);
        // Destination in any non-PRODUCTION status reverts at backup-creation time. Both source
        // and destination need to be live to produce + receive a meaningful backup blob.
        IMachineManager.TeeStatus[] memory nonProd = new IMachineManager.TeeStatus[](6);
        nonProd[0] = IMachineManager.TeeStatus.INITIALIZED;
        nonProd[1] = IMachineManager.TeeStatus.SUSPENDED;
        nonProd[2] = IMachineManager.TeeStatus.PAUSED;
        nonProd[3] = IMachineManager.TeeStatus.PAUSED_FOR_UPGRADE;
        nonProd[4] = IMachineManager.TeeStatus.REPLICATING;
        nonProd[5] = IMachineManager.TeeStatus.BANNED;
        for (uint256 i = 0; i < nonProd.length; i++) {
            ITestStateHelper(address(flareTeeManager)).setTeeMachineState(
                teeId,
                extensionId,
                teeMachineOwner,
                nonProd[i],
                PublicKey(bytes32(0), bytes32(0)),
                1,
                "https://tee.url"
            );
            vm.prank(owner);
            vm.expectRevert(ITeeCommonErrors.TeeMachineNotAvailable.selector);
            flareTeeManager.directBackup(keyHolderTeeId, teeId, walletId, keyId, address(0));
        }
    }

    function testDirectBackupRevertExtensionIdMismatchSource() public {
        _registerPath(keyHolderTeeId, teeId);
        // Move source to a different extension; the project's extension stays at `extensionId`.
        ITestStateHelper(address(flareTeeManager)).setTeeMachineState(
            keyHolderTeeId,
            extensionId + 1,
            teeMachineOwner,
            IMachineManager.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://keyholder.tee.url"
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.ExtensionIdMismatch.selector);
        flareTeeManager.directBackup(keyHolderTeeId, teeId, walletId, keyId, address(0));
    }

    function testDirectBackupRevertNoActiveMachinePathList() public {
        // No path registered → NoActiveMachinePathList.
        vm.prank(owner);
        vm.expectRevert(IMachinePathManager.NoActiveMachinePathList.selector);
        flareTeeManager.directBackup(keyHolderTeeId, teeId, walletId, keyId, address(0));
    }

    function testDirectBackupRevertInvalidMachinePath() public {
        // Active list exists but contains a different pair → InvalidMachinePath.
        _registerPath(backupTeeId, teeId);
        vm.prank(owner);
        vm.expectRevert(IMachinePathManager.InvalidMachinePath.selector);
        flareTeeManager.directBackup(keyHolderTeeId, teeId, walletId, keyId, address(0));
    }

    function testDirectBackupRevertKeyNotConfirmed() public {
        _registerPath(keyHolderTeeId, teeId);
        // Erase the stored public key → KeyNotConfirmed.
        address[] memory keyTeeIds = new address[](1);
        keyTeeIds[0] = keyHolderTeeId;
        ITestStateHelper(address(flareTeeManager)).setKeyState(
            walletId, keyId, bytes(""), keyTeeIds, keyId + 1
        );
        vm.prank(owner);
        vm.expectRevert(IWalletBackupManager.KeyNotConfirmed.selector);
        flareTeeManager.directBackup(keyHolderTeeId, teeId, walletId, keyId, address(0));
    }

    function testDirectBackupRevertSourceTeeDoesNotHoldKey() public {
        _registerPath(backupTeeId, teeId);
        // The active path's "source" (backupTeeId) does not hold the key — keyHolderTeeId does.
        vm.prank(owner);
        vm.expectRevert(IWalletBackupManager.SourceTeeDoesNotHoldKey.selector);
        flareTeeManager.directBackup(backupTeeId, teeId, walletId, keyId, address(0));
    }

    function testDirectBackupRevertKeyAlreadyAvailable() public {
        // Move the key onto BOTH source and destination (e.g. a concurrent restore already
        // landed). directBackup must fail fast rather than producing a useless blob.
        address[] memory keyTeeIds = new address[](2);
        keyTeeIds[0] = keyHolderTeeId;
        keyTeeIds[1] = teeId;
        ITestStateHelper(address(flareTeeManager)).setKeyState(
            walletId, keyId, publicKey, keyTeeIds, keyId + 1
        );
        _registerPath(keyHolderTeeId, teeId);
        vm.prank(owner);
        vm.expectRevert(IWalletBackupManager.KeyAlreadyAvailable.selector);
        flareTeeManager.directBackup(keyHolderTeeId, teeId, walletId, keyId, address(0));
    }

    function testDirectBackupHappyPath() public {
        _registerPath(keyHolderTeeId, teeId);
        // Sanity: destination's per-key nonce is 0 before the call.
        (uint256 nonceBefore, bool teeHoldsKey) =
            flareTeeManager.getKeyNonce(teeId, walletId, keyId);
        assertEq(nonceBefore, 0);
        assertFalse(teeHoldsKey);

        // We don't assert the exact instructionId (it is derived from a counter + blockhash). We
        // assert the topic shape: indexed(source, destination, walletId) match, keyId in data.
        vm.prank(owner);
        vm.expectEmit(true, true, true, false);
        emit IWalletBackupManager.DirectBackupTriggered(
            keyHolderTeeId, teeId, walletId, keyId, bytes32(0)
        );
        bytes32 instructionId =
            flareTeeManager.directBackup(keyHolderTeeId, teeId, walletId, keyId, address(0));
        assertTrue(instructionId != bytes32(0), "directBackup must return a non-zero instructionId");

        // Critical contract: directBackup must NOT mutate the destination's nonce.
        (uint256 nonceAfter, ) = flareTeeManager.getKeyNonce(teeId, walletId, keyId);
        assertEq(nonceAfter, nonceBefore, "directBackup must not bump destination nonce");
    }

    function testDirectBackupByBackupManager() public {
        _registerPath(keyHolderTeeId, teeId);
        vm.prank(backupManager);
        bytes32 instructionId =
            flareTeeManager.directBackup(keyHolderTeeId, teeId, walletId, keyId, address(0));
        assertTrue(instructionId != bytes32(0));
    }

    // =========================================================================
    // directRestore
    // =========================================================================
    // Destination = teeId; source = backupTeeId (matches backupId.teeId from setUp).
    // The shared `_validateRestoreInputs` is exercised in detail by the legacy `backupRestore`
    // tests above — the directRestore tests below focus on path-list gating and nonce mutation.
    // =========================================================================

    function testDirectRestoreRevertNoActiveMachinePathList() public {
        vm.prank(owner);
        vm.expectRevert(IMachinePathManager.NoActiveMachinePathList.selector);
        flareTeeManager.directRestore(teeId, backupId, bytes32("instructionId"), address(0));
    }

    function testDirectRestoreRevertInvalidMachinePath() public {
        // Active path contains a different pair.
        _registerPath(keyHolderTeeId, backupTeeId);
        vm.prank(owner);
        vm.expectRevert(IMachinePathManager.InvalidMachinePath.selector);
        flareTeeManager.directRestore(teeId, backupId, bytes32("instructionId"), address(0));
    }

    function testDirectRestoreRevertOnlyOwnerOrBackupManager() public {
        _registerPath(backupTeeId, teeId);
        vm.expectRevert(ITeeCommonErrors.OnlyOwnerOrBackupManager.selector);
        flareTeeManager.directRestore(teeId, backupId, bytes32("instructionId"), address(0));
    }

    function testDirectRestoreRevertKeyAlreadyAvailable() public {
        _registerPath(backupTeeId, teeId);
        // Destination already holds the key → reverts (re-asserts legacy gate is reached).
        address[] memory keyTeeIds = new address[](1);
        keyTeeIds[0] = teeId;
        ITestStateHelper(address(flareTeeManager)).setKeyState(
            walletId, keyId, publicKey, keyTeeIds, keyId + 1
        );
        vm.prank(owner);
        vm.expectRevert(IWalletBackupManager.KeyAlreadyAvailable.selector);
        flareTeeManager.directRestore(teeId, backupId, bytes32("instructionId"), address(0));
    }

    function testDirectRestoreHappyPath() public {
        _registerPath(backupTeeId, teeId);
        // Pre-condition: destination's nonce is 0; directRestore must bump it to exactly 1.
        (uint256 nonceBefore, ) = flareTeeManager.getKeyNonce(teeId, walletId, keyId);
        assertEq(nonceBefore, 0);

        vm.prank(owner);
        bytes32 backupInstrId = bytes32("backupInstr");
        vm.expectEmit(true, true, true, false);
        emit IWalletBackupManager.DirectRestoreTriggered(teeId, walletId, keyId, 1, backupInstrId);
        flareTeeManager.directRestore(teeId, backupId, backupInstrId, address(0));

        (uint256 nonceAfter, ) = flareTeeManager.getKeyNonce(teeId, walletId, keyId);
        assertEq(nonceAfter, 1, "directRestore must bump destination nonce by exactly 1");
    }

    function testDirectBackupRestoreEndToEndNonceContract() public {
        // Full flow: directBackup does not touch the destination nonce; directRestore bumps it
        // by exactly +1.
        _registerPath(keyHolderTeeId, teeId);

        // backupId.teeId is `backupTeeId` from setUp; for this end-to-end we want directBackup's
        // source (= path source = keyHolderTeeId) to match the BackupId we pass to directRestore.
        // Patch the backupId.teeId locally to keyHolderTeeId and re-register the matching path.
        IWalletBackupManager.BackupId memory bid = backupId;
        bid.teeId = keyHolderTeeId;

        vm.prank(owner);
        bytes32 backupInstrId =
            flareTeeManager.directBackup(keyHolderTeeId, teeId, walletId, keyId, address(0));

        (uint256 nonceBetween, ) = flareTeeManager.getKeyNonce(teeId, walletId, keyId);
        assertEq(nonceBetween, 0, "destination nonce stays 0 between directBackup and directRestore");

        vm.prank(owner);
        flareTeeManager.directRestore(teeId, bid, backupInstrId, address(0));

        (uint256 nonceAfter, ) = flareTeeManager.getKeyNonce(teeId, walletId, keyId);
        assertEq(nonceAfter, 1, "directRestore bumps destination nonce by exactly +1");
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    function _registerPath(address _src, address _dst) private {
        ITestStateHelper(address(flareTeeManager)).setActiveMachinePath(extensionId, _src, _dst);
    }
}
