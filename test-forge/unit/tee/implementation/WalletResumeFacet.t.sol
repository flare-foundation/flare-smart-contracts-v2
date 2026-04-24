// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IWalletManager } from "../../../../contracts/userInterfaces/tee/IWalletManager.sol";
import { IWalletResume } from "../../../../contracts/userInterfaces/tee/IWalletResume.sol";
import { IWalletKeyManager } from "../../../../contracts/userInterfaces/tee/IWalletKeyManager.sol";
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

contract TestTeeMachineHelperFacetForResume is ITestTeeMachineHelper {
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
            lastStatusChangeTs: block.timestamp,
            codeHash: bytes32(0),
            platform: bytes32(0),
            url: _url
        });
        if (_status == IMachineManager.TeeStatus.PRODUCTION) {
            s.activeTeeIds.add(_teeId);
            s.extensionActiveTeeIds[_extensionId].add(_teeId);
        }
    }
}

contract WalletResumeFacetTest is Test {

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

        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 6,
            challengeValidityDurationSeconds: 600,
            defaultFee: 0
        }));
        vm.startPrank(initialGovernance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();

        // Add TestTeeMachineHelperFacet to the diamond
        TestTeeMachineHelperFacetForResume helperImpl = new TestTeeMachineHelperFacetForResume();
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

    function testSetPausingAddressesRevertOnlyWalletOwner() public {
        _setupProductionWallet();
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.setPausingAddresses(walletId, new address[](2), address(0));
    }

    function testSetPausingAddressesRevertWrongStatus() public {
        _createWallet();
        vm.prank(projectOwner);
        vm.expectRevert(ITeeCommonErrors.OnlyProductionOrPausedStatus.selector);
        flareTeeManager.setPausingAddresses(walletId, new address[](2), address(0));
    }

    function testResumeRevertWrongStatus() public {
        _createWallet();
        vm.expectRevert(ITeeCommonErrors.OnlyProductionOrPausedStatus.selector);
        vm.prank(projectOwner);
        flareTeeManager.resume(walletId, new IWalletResume.ResumeKeyData[](0), address(0));
    }

    function testResumeRevertOnlyOwner() public {
        _setupProductionWallet();
        vm.prank(projectOwner);
        flareTeeManager.pauseWallet(walletId);
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.resume(walletId, new IWalletResume.ResumeKeyData[](0), address(0));
    }

    //// helper functions

    function _createWallet() internal {
        vm.prank(projectOwner);
        flareTeeManager.createWallet(projectId);
    }

    function _setupProductionWallet() internal {
        _createWallet();

        // Set admins
        PublicKey[] memory admins = new PublicKey[](2);
        admins[0] = PublicKeyHelper.getRandomPublicKey(vm);
        admins[1] = PublicKeyHelper.getRandomPublicKey(vm);
        vm.prank(projectOwner);
        flareTeeManager.setAdmins(walletId, admins, 1);

        // Confirm admins
        address admin1 = PublicKeyHelper.getAddress(admins[0]);
        vm.prank(admin1);
        flareTeeManager.confirmAdmin(walletId);
        address admin2 = PublicKeyHelper.getAddress(admins[1]);
        vm.prank(admin2);
        flareTeeManager.confirmAdmin(walletId);

        // Set cosigners
        address[] memory cosigners = new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");
        vm.prank(projectOwner);
        flareTeeManager.setCosigners(walletId, cosigners, 1);

        // Confirm cosigners
        vm.prank(cosigners[0]);
        flareTeeManager.confirmCosigner(walletId);
        vm.prank(cosigners[1]);
        flareTeeManager.confirmCosigner(walletId);

        // Close initialization
        vm.prank(projectOwner);
        flareTeeManager.closeWalletInitialization(walletId);

        // Set multisig threshold
        vm.prank(projectOwner);
        flareTeeManager.setMultisigThreshold(walletId, 1);

        // Add and confirm a key
        _addAndConfirmKey(walletId);

        vm.prank(projectOwner);
        flareTeeManager.enableWallet(walletId);
    }

    function _addAndConfirmKey(bytes32 _walletId) internal {
        (address teeAddr, uint256 teeKey) = makeAddrAndKey("productionTee");

        teeMachineHelper.setTeeMachineState(
            teeAddr,
            extensionId,
            makeAddr("teeMachineOwner"),
            IMachineManager.TeeStatus.PRODUCTION,
            "https://tee.url"
        );

        vm.prank(projectOwner);
        uint64 keyId = flareTeeManager.addKey{value: 0}(teeAddr, _walletId, address(0));

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

        bytes32 signedMessageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encode(proof))
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
