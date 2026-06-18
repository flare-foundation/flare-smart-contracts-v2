// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IWalletManager } from "../../../../contracts/userInterfaces/tee/IWalletManager.sol";
import { IWalletProjectPause } from "../../../../contracts/userInterfaces/tee/IWalletProjectPause.sol";
import { IWalletKeyManager, TEE_KEY_EXISTENCE } from "../../../../contracts/userInterfaces/tee/IWalletKeyManager.sol";
import { SignedPayload } from "../../../../contracts/utils/lib/SignedPayload.sol";
import { IMachineManager } from "../../../../contracts/userInterfaces/tee/IMachineManager.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { PublicKey } from "../../../../contracts/userInterfaces/IPublicKey.sol";
import { Signature } from "../../../../contracts/userInterfaces/ISignature.sol";
import { PublicKeyHelper } from "../../../utils/PublicKeyHelper.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { IDiamond } from "../../../../contracts/diamond/interfaces/IDiamond.sol";
import { IDiamondCut } from "../../../../contracts/diamond/interfaces/IDiamondCut.sol";
import { MachineManager } from "../../../../contracts/tee/library/MachineManager.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title TestTeeMachineHelperFacet
 * @notice Test-only facet added to the diamond to write TEE machine state directly
 *         into ERC-7201 storage, bypassing the full registration/attestation flow.
 */
interface ITestTeeMachineHelper {
    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        IMachineManager.TeeStatus _status,
        string calldata _url
    ) external;
}

contract TestTeeMachineHelperFacet is ITestTeeMachineHelper {
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

contract WalletManagerFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;
    ITestTeeMachineHelper private teeMachineHelper;

    address private mockFSM;
    address private mockRewardManager;

    address private initialGovernance;
    address private addressUpdater;

    address private projectOwner;
    bytes32 private projectId;
    bytes32 private walletId;

    uint256 private extensionId;

    function setUp() public {
        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        mockFSM = makeAddr("FlareSystemsManager");
        mockRewardManager = makeAddr("RewardManager");

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

        // Add TestTeeMachineHelperFacet to the diamond
        TestTeeMachineHelperFacet helperImpl = new TestTeeMachineHelperFacet();
        bytes4[] memory helperSelectors = new bytes4[](1);
        helperSelectors[0] = ITestTeeMachineHelper.setTeeMachineState.selector;

        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](1);
        cuts[0] = IDiamond.FacetCut(
            address(helperImpl),
            IDiamond.FacetCutAction.Add,
            helperSelectors
        );

        vm.prank(initialGovernance);
        IDiamondCut(address(flareTeeManager)).diamondCut(cuts, address(0), "");

        teeMachineHelper = ITestTeeMachineHelper(address(flareTeeManager));

        // Update contract addresses
        bytes32[] memory nameHashes = new bytes32[](6);
        nameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        nameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        nameHashes[2] = keccak256(abi.encode("RewardManager"));
        nameHashes[3] = keccak256(abi.encode("Relay"));
        nameHashes[4] = keccak256(abi.encode("Fdc2Hub"));
        nameHashes[5] = keccak256(abi.encode("Fdc2Verification"));
        address[] memory addresses = new address[](6);
        addresses[0] = addressUpdater;
        addresses[1] = mockFSM;
        addresses[2] = mockRewardManager;
        addresses[3] = makeAddr("Relay");
        addresses[4] = makeAddr("Fdc2Hub");
        addresses[5] = makeAddr("Fdc2Verification");
        vm.prank(addressUpdater);
        flareTeeManager.updateContractAddresses(nameHashes, addresses);

        // Register an extension via the diamond
        address extensionOwner = makeAddr("extensionOwner");
        address instructionsSender = makeAddr("instructionsSender");
        vm.prank(extensionOwner);
        extensionId = flareTeeManager.register(ITeeExtensionStateVerifier(address(0)), instructionsSender);

        // Add supported key types and signing algos
        bytes32 keyType = keccak256(abi.encode("keyType1"));
        bytes32 signingAlgo = keccak256(abi.encode("signingAlgo1"));
        bytes32[] memory keyTypes = new bytes32[](1);
        keyTypes[0] = keyType;
        bytes32[][] memory signingAlgosByKeyType = new bytes32[][](1);
        signingAlgosByKeyType[0] = new bytes32[](1);
        signingAlgosByKeyType[0][0] = signingAlgo;
        vm.prank(initialGovernance);
        flareTeeManager.addSystemSupportedKeyTypesAndSigningAlgos(keyTypes, signingAlgosByKeyType);

        // Add supported key types to extension
        vm.prank(extensionOwner);
        flareTeeManager.addSupportedKeyTypes(extensionId, keyTypes);

        // Allowlist project owner
        projectOwner = makeAddr("projectOwner");
        address[] memory owners = new address[](1);
        owners[0] = projectOwner;
        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeWalletProjectOwners(extensionId, owners);

        // Create project
        vm.prank(projectOwner);
        projectId = flareTeeManager.createProject(extensionId, keyType, signingAlgo);

        walletId = keccak256(abi.encode("WALLET", projectOwner, 1));

        // Fund project owner
        vm.deal(projectOwner, 1 ether);

        _mockGetCurrentRewardEpochId(10);
        _mockReceiveRewards();
    }

    function testCreateWallet() public {
        vm.prank(projectOwner);
        vm.expectEmit();
        emit IWalletManager.WalletCreated(projectId, walletId);
        flareTeeManager.createWallet(projectId);

        assertEq(flareTeeManager.getWalletProjectId(walletId), projectId);
        assertEq(uint8(flareTeeManager.getWalletStatus(walletId)), uint8(IWalletManager.WalletStatus.CREATED));
        assertEq(flareTeeManager.getProjectWalletIds(projectId).length, 1);
        assertEq(flareTeeManager.getProjectWalletIds(projectId)[0], walletId);
    }

    function testCreateWalletRevert() public {
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.createWallet(projectId);
    }

    function testGetWalletStatusNoneForNonExistentWallet() public {
        // A wallet id that was never created reads back the NONE sentinel (not a real status),
        // so the default storage slot is distinguishable from a genuine CREATED wallet.
        assertEq(
            uint8(flareTeeManager.getWalletStatus(keccak256("neverCreated"))),
            uint8(IWalletManager.WalletStatus.NONE)
        );
    }

    // not enough admins
    function testSetAdminsRevert1() public {
        testCreateWallet();
        PublicKey[] memory admins = new PublicKey[](2);
        admins[0] = PublicKeyHelper.getRandomPublicKey(vm);
        admins[1] = PublicKeyHelper.getRandomPublicKey(vm);

        vm.prank(projectOwner);
        vm.expectRevert(IWalletManager.NotEnoughAdmins.selector);
        flareTeeManager.setAdmins(walletId, admins, 3);
    }

    // invalid admins threshold
    function testSetAdminsRevert2() public {
        testCreateWallet();
        PublicKey[] memory admins = new PublicKey[](2);
        admins[0] = PublicKeyHelper.getRandomPublicKey(vm);
        admins[1] = PublicKeyHelper.getRandomPublicKey(vm);

        vm.prank(projectOwner);
        vm.expectRevert(IWalletManager.InvalidAdminsThreshold.selector);
        flareTeeManager.setAdmins(walletId, admins, 0);
    }

    // invalid public key
    function testSetAdminsRevert3() public {
        testCreateWallet();
        PublicKey[] memory admins = new PublicKey[](2);
        admins[0] = PublicKeyHelper.getRandomPublicKey(vm);

        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IWalletManager.InvalidAdminPublicKey.selector,
                admins[1]
            )
        );
        flareTeeManager.setAdmins(walletId, admins, 1);
    }

    // duplicated public key
    function testSetAdminsRevert4() public {
        testCreateWallet();
        PublicKey[] memory admins = new PublicKey[](2);
        admins[0] = PublicKeyHelper.getRandomPublicKey(vm);
        admins[1] = admins[0]; // duplicate

        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IWalletManager.DuplicatedPublicKey.selector,
                admins[0]
            )
        );
        flareTeeManager.setAdmins(walletId, admins, 1);
    }

    // only owner
    function testSetAdminsRevert5() public {
        testCreateWallet();
        PublicKey[] memory admins = new PublicKey[](2);
        admins[0] = PublicKeyHelper.getRandomPublicKey(vm);
        admins[1] = PublicKeyHelper.getRandomPublicKey(vm);

        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.setAdmins(walletId, admins, 1);
    }

    function testSetAdmins() public returns (PublicKey[] memory) {
        testCreateWallet();
        PublicKey[] memory admins = new PublicKey[](2);
        admins[0] = PublicKeyHelper.getRandomPublicKey(vm);
        admins[1] = PublicKeyHelper.getRandomPublicKey(vm);

        vm.prank(projectOwner);
        flareTeeManager.setAdmins(walletId, admins, 1);
        (PublicKey[] memory _adminsPublicKeys, uint64 _adminsThreshold) =
            flareTeeManager.getWalletAdminsPublicKeysAndThreshold(walletId);
        assertEq(_adminsPublicKeys.length, 2);
        assertEq(_adminsPublicKeys[0].x, admins[0].x);
        assertEq(_adminsPublicKeys[0].y, admins[0].y);
        assertEq(_adminsPublicKeys[1].x, admins[1].x);
        assertEq(_adminsPublicKeys[1].y, admins[1].y);
        assertEq(_adminsThreshold, 1);
        return admins;
    }

    function testSetAdminsAgain() public {
        testSetAdmins();
        PublicKey[] memory admins = new PublicKey[](1);
        admins[0] = PublicKeyHelper.getRandomPublicKey(vm);
        vm.prank(projectOwner);
        flareTeeManager.setAdmins(walletId, admins, 1);
        // old admins should be removed
        (PublicKey[] memory _adminsPublicKeys, uint64 _adminsThreshold) =
            flareTeeManager.getWalletAdminsPublicKeysAndThreshold(walletId);
        assertEq(_adminsPublicKeys.length, 1);
        assertEq(_adminsPublicKeys[0].x, admins[0].x);
        assertEq(_adminsPublicKeys[0].y, admins[0].y);
        assertEq(_adminsThreshold, 1);
    }

    function testConfirmAdmins() public {
        PublicKey[] memory admins = testSetAdmins();
        // confirm first admin
        address admin1 = PublicKeyHelper.getAddress(admins[0]);
        vm.prank(admin1);
        vm.expectEmit();
        emit IWalletManager.WalletAdminConfirmed(walletId, admin1);
        flareTeeManager.confirmAdmin(walletId);

        // confirm second admin
        address admin2 = PublicKeyHelper.getAddress(admins[1]);
        vm.prank(admin2);
        vm.expectEmit();
        emit IWalletManager.WalletAdminConfirmed(walletId, admin2);
        flareTeeManager.confirmAdmin(walletId);
    }

    // invalid admin
    function testConfirmAdminsRevert1() public {
        // The wallet was never created, so its status is NONE; the wallet-status guard rejects
        // the confirmation before the admin-membership check is reached.
        vm.expectRevert(ITeeCommonErrors.InvalidWalletStatus.selector);
        flareTeeManager.confirmAdmin(walletId);
    }

    function testConfirmAdminRevertInvalidAdmin() public {
        // Real CREATED wallet with admins set; a caller who is not an admin cannot confirm.
        testSetAdmins();
        address nonAdmin = makeAddr("nonAdmin");
        vm.prank(nonAdmin);
        vm.expectRevert(IWalletManager.InvalidAdmin.selector);
        flareTeeManager.confirmAdmin(walletId);
    }

    // invalid threshold
    function testSetCosignersRevert1() public {
        testCreateWallet();
        address[] memory cosigners = new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");

        vm.prank(projectOwner);
        vm.expectRevert(IWalletManager.InvalidCosignersThreshold.selector);
        flareTeeManager.setCosigners(walletId, cosigners, 0);
    }

    // invalid address
    function testSetCosignersRevert2() public {
        testCreateWallet();
        address[] memory cosigners = new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = address(0);

        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeCommonErrors.InvalidCosigner.selector,
                cosigners[1]
            )
        );
        flareTeeManager.setCosigners(walletId, cosigners, 1);
    }

    // duplicated cosigner
    function testSetCosignersRevert3() public {
        testCreateWallet();
        address[] memory cosigners = new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = cosigners[0]; // duplicate

        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeCommonErrors.DuplicatedCosigner.selector,
                cosigners[1]
            )
        );
        flareTeeManager.setCosigners(walletId, cosigners, 1);
    }

    // only owner
    function testSetCosignersRevert4() public {
        testCreateWallet();
        address[] memory cosigners = new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");

        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.setCosigners(walletId, cosigners, 1);
    }

    function testSetCosigners() public returns (address[] memory) {
        testConfirmAdmins();
        address[] memory cosigners = new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");

        vm.prank(projectOwner);
        flareTeeManager.setCosigners(walletId, cosigners, 1);
        (address[] memory _cosigners, uint64 _cosignersThreshold) =
            flareTeeManager.getWalletCosignersAndThreshold(walletId);
        assertEq(_cosigners.length, 2);
        assertEq(_cosigners[0], cosigners[0]);
        assertEq(_cosigners[1], cosigners[1]);
        assertEq(_cosignersThreshold, 1);

        return cosigners;
    }

    function testConfirmCosigner() public {
        address[] memory cosigners = testSetCosigners();
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");

        // confirm first cosigner
        vm.prank(cosigners[0]);
        vm.expectEmit();
        emit IWalletManager.WalletCosignerConfirmed(walletId, cosigners[0]);
        flareTeeManager.confirmCosigner(walletId);
        // confirm second cosigner
        vm.prank(cosigners[1]);
        vm.expectEmit();
        emit IWalletManager.WalletCosignerConfirmed(walletId, cosigners[1]);
        flareTeeManager.confirmCosigner(walletId);
    }

    function testConfirmCosignerRevert() public {
        // The wallet was never created, so its status is NONE; the wallet-status guard rejects
        // the confirmation before the cosigner-membership check is reached.
        vm.expectRevert(ITeeCommonErrors.InvalidWalletStatus.selector);
        flareTeeManager.confirmCosigner(walletId);
    }

    function testConfirmCosignerRevertInvalidCosigner() public {
        // Real CREATED wallet with cosigners set; a caller who is not a cosigner cannot confirm.
        testSetCosigners();
        address nonCosigner = makeAddr("nonCosigner");
        vm.prank(nonCosigner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeCommonErrors.InvalidCosigner.selector,
                nonCosigner
            )
        );
        flareTeeManager.confirmCosigner(walletId);
    }

    // only owner
    function testCloseWalletInitializationRevert1() public {
        testCreateWallet();
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.closeWalletInitialization(walletId);
    }

    // admins not set
    function testCloseWalletInitializationRevert2() public {
        testCreateWallet();
        vm.prank(projectOwner);
        vm.expectRevert(IWalletManager.AdminsNotSet.selector);
        flareTeeManager.closeWalletInitialization(walletId);
    }

    // not all admins confirmed
    function testCloseWalletInitializationRevert3() public {
        PublicKey[] memory adminsPublicKeys = testSetAdmins();
        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IWalletManager.NotAllAdminsConfirmed.selector,
                PublicKeyHelper.getAddress(adminsPublicKeys[0])
            )
        );
        flareTeeManager.closeWalletInitialization(walletId);
    }

    // not all cosigners confirmed
    function testCloseWalletInitializationRevert4() public {
        address[] memory cosigners = testSetCosigners();
        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IWalletManager.NotAllCosignersConfirmed.selector,
                cosigners[0]
            )
        );
        flareTeeManager.closeWalletInitialization(walletId);
    }

    function testCloseWalletInitialization() public {
        testConfirmCosigner();
        vm.prank(projectOwner);
        flareTeeManager.closeWalletInitialization(walletId);
        assertEq(
            uint8(flareTeeManager.getWalletStatus(walletId)),
            uint8(IWalletManager.WalletStatus.INITIALIZED)
        );
    }

    // wrong status
    function testSetAdminsRevert6() public {
        testCloseWalletInitialization();
        PublicKey[] memory admins = new PublicKey[](2);
        admins[0] = PublicKeyHelper.getRandomPublicKey(vm);
        admins[1] = PublicKeyHelper.getRandomPublicKey(vm);

        vm.prank(projectOwner);
        vm.expectRevert(ITeeCommonErrors.InvalidWalletStatus.selector);
        flareTeeManager.setAdmins(walletId, admins, 1);
    }

    function testSetCosignersRevert5() public {
        testCloseWalletInitialization();
        address[] memory cosigners = new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");

        vm.prank(projectOwner);
        vm.expectRevert(ITeeCommonErrors.InvalidWalletStatus.selector);
        flareTeeManager.setCosigners(walletId, cosigners, 1);
    }

    function testConfirmAdminsRevert2() public {
        testCloseWalletInitialization();
        vm.expectRevert(ITeeCommonErrors.InvalidWalletStatus.selector);
        flareTeeManager.confirmAdmin(walletId);
    }

    function testEnableWalletRevert1() public {
        testCloseWalletInitialization();
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.enableWallet(walletId);
    }

    // invalid wallet status
    function testEnableWalletRevert2() public {
        testCreateWallet();
        vm.prank(projectOwner);
        vm.expectRevert(ITeeCommonErrors.InvalidWalletStatus.selector);
        flareTeeManager.enableWallet(walletId);
    }

    // multisig threshold not set
    function testEnableWalletRevert3() public {
        testCloseWalletInitialization();
        vm.prank(projectOwner);
        vm.expectRevert(IWalletManager.MultisigThresholdNotSet.selector);
        flareTeeManager.enableWallet(walletId);
    }

    // not enough keys - need to set multisig threshold but have no keys
    function testEnableWalletRevert4() public {
        testCloseWalletInitialization();
        // Set multisig threshold
        vm.prank(projectOwner);
        flareTeeManager.setMultisigThreshold(walletId, 2);
        vm.prank(projectOwner);
        vm.expectRevert(IWalletManager.NotEnoughKeys.selector);
        flareTeeManager.enableWallet(walletId);
    }

    function testEnableWallet() public {
        _setupProductionWallet();
        assertEq(
            uint8(flareTeeManager.getWalletStatus(walletId)),
            uint8(IWalletManager.WalletStatus.PRODUCTION)
        );
    }

    function testPauseWallet() public {
        _setupProductionWallet();
        bytes32[] memory walletIds = new bytes32[](1);
        walletIds[0] = walletId;
        vm.expectEmit();
        emit IWalletProjectPause.WalletsPaused(walletIds);
        vm.prank(projectOwner);
        flareTeeManager.pauseWallets(walletIds);
        assertEq(uint8(flareTeeManager.getWalletStatus(walletId)), uint8(IWalletManager.WalletStatus.PAUSED));
    }

    function testPauseWalletRevert() public {
        testCloseWalletInitialization();
        bytes32[] memory walletIds = new bytes32[](1);
        walletIds[0] = walletId;
        vm.prank(projectOwner);
        vm.expectRevert(ITeeCommonErrors.InvalidWalletStatus.selector); // only production
        flareTeeManager.pauseWallets(walletIds);
    }

    function testEnableWalletRevertFromPaused() public {
        // After narrowing: enableWallet only accepts INITIALIZED, not PAUSED.
        _setupProductionWallet();
        bytes32[] memory walletIds = new bytes32[](1);
        walletIds[0] = walletId;
        vm.prank(projectOwner);
        flareTeeManager.pauseWallets(walletIds);
        vm.prank(projectOwner);
        vm.expectRevert(ITeeCommonErrors.InvalidWalletStatus.selector);
        flareTeeManager.enableWallet(walletId);
    }

    function testPauseWalletsByDelegatedPauser() public {
        _setupProductionWallet();
        address pauser = makeAddr("delegatedPauser");
        address[] memory pausers = new address[](1);
        pausers[0] = pauser;
        vm.prank(projectOwner);
        flareTeeManager.addWalletProjectPausers(projectId, pausers);

        bytes32[] memory walletIds = new bytes32[](1);
        walletIds[0] = walletId;
        vm.expectEmit();
        emit IWalletProjectPause.WalletsPaused(walletIds);
        vm.prank(pauser);
        flareTeeManager.pauseWallets(walletIds);

        assertEq(uint8(flareTeeManager.getWalletStatus(walletId)), uint8(IWalletManager.WalletStatus.PAUSED));
    }

    function testUnpauseWalletsByDelegatedUnpauser() public {
        _setupProductionWallet();
        address unpauser = makeAddr("delegatedUnpauser");
        address[] memory unpausers = new address[](1);
        unpausers[0] = unpauser;
        vm.prank(projectOwner);
        flareTeeManager.addWalletProjectUnpausers(projectId, unpausers);

        bytes32[] memory walletIds = new bytes32[](1);
        walletIds[0] = walletId;
        // Owner pauses first
        vm.prank(projectOwner);
        flareTeeManager.pauseWallets(walletIds);
        // Delegated unpauser resumes
        vm.expectEmit();
        emit IWalletProjectPause.WalletsUnpaused(walletIds);
        vm.prank(unpauser);
        flareTeeManager.unpauseWallets(walletIds);

        assertEq(uint8(flareTeeManager.getWalletStatus(walletId)), uint8(IWalletManager.WalletStatus.PRODUCTION));
    }

    function testPauserCannotUnpause() public {
        _setupProductionWallet();
        address pauser = makeAddr("delegatedPauser");
        address[] memory pausers = new address[](1);
        pausers[0] = pauser;
        vm.prank(projectOwner);
        flareTeeManager.addWalletProjectPausers(projectId, pausers);

        bytes32[] memory walletIds = new bytes32[](1);
        walletIds[0] = walletId;
        vm.prank(pauser);
        flareTeeManager.pauseWallets(walletIds);

        // Pauser is NOT an unpauser
        vm.prank(pauser);
        vm.expectRevert(
            abi.encodeWithSelector(ITeeCommonErrors.NotOwnerOrUnpauser.selector, pauser)
        );
        flareTeeManager.unpauseWallets(walletIds);
    }

    function testUnpauserCannotPause() public {
        _setupProductionWallet();
        address unpauser = makeAddr("delegatedUnpauser");
        address[] memory unpausers = new address[](1);
        unpausers[0] = unpauser;
        vm.prank(projectOwner);
        flareTeeManager.addWalletProjectUnpausers(projectId, unpausers);

        bytes32[] memory walletIds = new bytes32[](1);
        walletIds[0] = walletId;
        vm.prank(unpauser);
        vm.expectRevert(
            abi.encodeWithSelector(ITeeCommonErrors.NotOwnerOrPauser.selector, unpauser)
        );
        flareTeeManager.pauseWallets(walletIds);
    }

    function testUnpauseWalletsRevertWrongStatus() public {
        // INITIALIZED -> unpause must revert (only PAUSED allowed)
        testCloseWalletInitialization();
        bytes32[] memory walletIds = new bytes32[](1);
        walletIds[0] = walletId;
        vm.prank(projectOwner);
        vm.expectRevert(ITeeCommonErrors.InvalidWalletStatus.selector);
        flareTeeManager.unpauseWallets(walletIds);
    }

    //// helper functions

    function _setupProductionWallet() internal {
        testCloseWalletInitialization();

        // Set multisig threshold
        vm.prank(projectOwner);
        flareTeeManager.setMultisigThreshold(walletId, 1);

        // Add and confirm a key using a TEE machine with a known private key
        _addAndConfirmKey(walletId);

        vm.prank(projectOwner);
        flareTeeManager.enableWallet(walletId);
    }

    function _addAndConfirmKey(bytes32 _walletId) internal {
        (address teeAddr, uint256 teeKey) = makeAddrAndKey("productionTee");

        // Set up TEE machine state directly in ERC-7201 storage via the helper facet
        teeMachineHelper.setTeeMachineState(
            teeAddr,
            extensionId,
            makeAddr("teeMachineOwner"),
            IMachineManager.TeeStatus.PRODUCTION,
            "https://tee.url"
        );

        vm.prank(projectOwner);
        uint64 keyId = flareTeeManager.addKey{value: 1000}(teeAddr, _walletId, address(0));

        // Build proof
        (PublicKey[] memory adminsPublicKeys, uint64 adminsThreshold) =
            flareTeeManager.getWalletAdminsPublicKeysAndThreshold(_walletId);
        (address[] memory cosigners, uint64 cosignersThreshold) =
            flareTeeManager.getWalletCosignersAndThreshold(_walletId);
        bytes32 keyType = flareTeeManager.getKeyType(flareTeeManager.getWalletProjectId(_walletId));
        bytes32 signingAlgo = flareTeeManager.getSigningAlgo(flareTeeManager.getWalletProjectId(_walletId));

        IWalletKeyManager.KeyExistence memory proof;
        proof.teeId = teeAddr;
        proof.walletId = _walletId;
        proof.nonce = 0;
        proof.keyType = keyType;
        proof.signingAlgo = signingAlgo;
        proof.configConstants.adminsPublicKeys = adminsPublicKeys;
        proof.configConstants.adminsThreshold = adminsThreshold;
        proof.configConstants.cosigners = cosigners;
        proof.configConstants.cosignersThreshold = cosignersThreshold;
        proof.publicKey = abi.encode("publicKey");
        proof.restored = false;
        proof.keyId = keyId;
        proof.settingsVersion = bytes32(0);
        proof.settings = bytes("");

        // Sign the proof
        bytes32 signedMessageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                SignedPayload.messageHash(TEE_KEY_EXISTENCE, keccak256(abi.encode(proof)))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(teeKey, signedMessageHash);
        Signature memory sig = Signature(v, r, s);

        vm.prank(projectOwner);
        flareTeeManager.confirmKey(proof, sig);
    }

    function _mockReceiveRewards() internal {
        vm.mockCall(
            mockRewardManager,
            abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
            abi.encode()
        );
    }

    function _mockGetCurrentRewardEpochId(uint24 _rewardEpochId) internal {
        vm.mockCall(
            mockFSM,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(_rewardEpochId)
        );
    }
}
