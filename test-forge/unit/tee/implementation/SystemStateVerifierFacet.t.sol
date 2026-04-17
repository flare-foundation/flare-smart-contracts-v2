// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { SignatureHelper } from "../../../utils/SignatureHelper.sol";

import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import {
    ISystemStateVerifierFacet
} from "../../../../contracts/userInterfaces/tee/ISystemStateVerifierFacet.sol";
import { IMachineManagerFacet } from "../../../../contracts/userInterfaces/tee/IMachineManagerFacet.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { RandomNumberV2Interface } from "../../../../contracts/userInterfaces/LTS/RandomNumberV2Interface.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";

import { PublicKey } from "../../../../contracts/userInterfaces/IPublicKey.sol";
import { Signature } from "../../../../contracts/userInterfaces/ISignature.sol";

// solhint-disable-next-line max-states-count
contract SystemStateVerifierFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;

    address private initialGovernance;
    address private addressUpdater;
    address private flareSystemsManager;
    address private rewardManager;
    address private relay;

    address private extensionOwner;
    uint256 private extensionId;
    address private teeMachineOwner;

    PublicKey private teePublicKey;
    uint256 private teePrivateKey;
    address private teeId;
    address private teeProxyId;
    string private teeUrl;

    bytes32 private stateVersion;
    ISystemStateVerifierFacet.TeeSystemState private teeSystemState;
    bytes32 private teeGovernanceHash;

    bytes32 private codeHash;
    bytes32[] private platforms;

    address[] private governanceSigners;
    uint256[] private governanceSignerKeys;
    uint64 private governanceSignersThreshold;

    function setUp() public {
        extensionOwner = makeAddr("extensionOwner");
        teeMachineOwner = makeAddr("teeMachineOwner");
        vm.deal(teeMachineOwner, 1 ether);

        VmSafe.Wallet memory wallet = vm.createWallet("teeId");
        teePublicKey.x = bytes32(wallet.publicKeyX);
        teePublicKey.y = bytes32(wallet.publicKeyY);
        teePrivateKey = wallet.privateKey;
        teeId = wallet.addr;
        teeProxyId = makeAddr("teeProxyId");
        teeUrl = "https://tee.proxy.url";

        stateVersion = keccak256("stateVersion");

        // Governance signers
        governanceSigners = new address[](2);
        governanceSignerKeys = new uint256[](2);
        (governanceSigners[0], governanceSignerKeys[0]) = makeAddrAndKey("govSigner1");
        (governanceSigners[1], governanceSignerKeys[1]) = makeAddrAndKey("govSigner2");
        governanceSignersThreshold = 2;
        teeGovernanceHash = keccak256(abi.encode(governanceSigners, governanceSignersThreshold));

        // Code hash and platforms
        codeHash = keccak256("codeHash");
        platforms.push(keccak256("platform"));

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        flareSystemsManager = makeAddr("FlareSystemsManager");
        rewardManager = makeAddr("RewardManager");
        relay = makeAddr("Relay");

        // Deploy FlareTeeManager diamond
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

        // Update contract addresses
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
        addresses[3] = relay;
        addresses[4] = makeAddr("Fdc2Hub");
        addresses[5] = makeAddr("Fdc2Verification");

        vm.prank(addressUpdater);
        flareTeeManager.updateContractAddresses(nameHashes, addresses);

        // Mock external contract calls needed for TEE machine registration
        vm.mockCall(
            relay,
            abi.encodeWithSelector(RandomNumberV2Interface.getRandomNumber.selector),
            abi.encode(uint256(12345), true, uint256(0))
        );
        vm.mockCall(
            flareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(uint24(1))
        );
        vm.mockCall(
            rewardManager,
            abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
            abi.encode(uint256(1))
        );

        // Add supported platform (governance call)
        vm.startPrank(initialGovernance);
        flareTeeManager.addSystemSupportedPlatforms(platforms);
        vm.stopPrank();

        // Register extension
        vm.prank(extensionOwner);
        extensionId = flareTeeManager.register(
            ITeeExtensionStateVerifier(address(0)),
            makeAddr("instructionsSender")
        );

        // Set governance hash on the extension
        vm.prank(extensionOwner);
        flareTeeManager.setNewTeeGovernance(extensionId, governanceSigners, governanceSignersThreshold);

        // Add TEE version (links codeHash to governanceHash and platforms)
        vm.prank(extensionOwner);
        flareTeeManager.addTeeVersion(extensionId, "v1.0.0", codeHash, platforms, teeGovernanceHash);

        // Allow TEE machine owner
        address[] memory owners = new address[](1);
        owners[0] = teeMachineOwner;
        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeMachineOwners(extensionId, owners);

        // Register TEE machine
        IMachineManagerFacet.TeeMachineData memory teeMachineData = IMachineManagerFacet.TeeMachineData({
            extensionId: extensionId,
            publicKey: teePublicKey,
            initialOwner: teeMachineOwner,
            codeHash: codeHash,
            platform: platforms[0]
        });
        Signature memory signature = SignatureHelper.createSignature(
            vm,
            keccak256(abi.encode(teeMachineData)),
            teePrivateKey
        );
        vm.prank(teeMachineOwner);
        flareTeeManager.register(
            teeMachineData,
            signature,
            teeProxyId,
            teeUrl,
            address(0)
        );

        // Set up the expected valid system state
        teeSystemState.status = ISystemStateVerifierFacet.TeeMachineStatus.ACTIVE;
        teeSystemState.initialTeeId = teeId;
        teeSystemState.teeGovernanceHash = teeGovernanceHash;
    }

    // verifyTeeSystemState
    function testVerifyTeeSystemStateNotValid1() public {
        teeSystemState.status = ISystemStateVerifierFacet.TeeMachineStatus.PAUSED;
        bool isValid = flareTeeManager.verifyTeeSystemState(
            teeId, stateVersion, abi.encode(teeSystemState)
        );
        assertFalse(isValid);
    }

    function testVerifyTeeSystemStateNotValid2() public {
        teeSystemState.initialTeeId = makeAddr("wrongTeeId");
        bool isValid = flareTeeManager.verifyTeeSystemState(
            teeId, stateVersion, abi.encode(teeSystemState)
        );
        assertFalse(isValid);
    }

    function testVerifyTeeSystemStateNotValid3() public {
        teeSystemState.teeGovernanceHash = keccak256("wrongTeeGovernanceHash");
        bool isValid = flareTeeManager.verifyTeeSystemState(
            teeId, stateVersion, abi.encode(teeSystemState)
        );
        assertFalse(isValid);
    }

    function testVerifyTeeSystemStateReturnStateVersion() public {
        assertNotEq(teeGovernanceHash, bytes32(0));
        bool isValid = flareTeeManager.verifyTeeSystemState(
            teeId, bytes32(0), abi.encode(teeSystemState)
        );
        assertFalse(isValid);

        isValid = flareTeeManager.verifyTeeSystemState(
            teeId, bytes32(0), new bytes(0)
        );
        assertFalse(isValid);

        // Register a new extension + version with zero governance hash to test the zero case
        vm.prank(extensionOwner);
        uint256 extId2 = flareTeeManager.register(
            ITeeExtensionStateVerifier(address(0)),
            makeAddr("instructionsSender2")
        );

        // Add version with zero governance hash
        vm.prank(extensionOwner);
        flareTeeManager.addTeeVersion(extId2, "v1.0.0", keccak256("codeHash2"), platforms, bytes32(0));

        // Allow owner and register a new TEE machine on that extension
        address[] memory owners = new address[](1);
        owners[0] = teeMachineOwner;
        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeMachineOwners(extId2, owners);

        VmSafe.Wallet memory wallet2 = vm.createWallet("teeId2");
        PublicKey memory pub2;
        pub2.x = bytes32(wallet2.publicKeyX);
        pub2.y = bytes32(wallet2.publicKeyY);
        address teeId2 = wallet2.addr;

        IMachineManagerFacet.TeeMachineData memory data2 = IMachineManagerFacet.TeeMachineData({
            extensionId: extId2,
            publicKey: pub2,
            initialOwner: teeMachineOwner,
            codeHash: keccak256("codeHash2"),
            platform: platforms[0]
        });
        Signature memory sig2 = SignatureHelper.createSignature(
            vm,
            keccak256(abi.encode(data2)),
            wallet2.privateKey
        );
        vm.prank(teeMachineOwner);
        flareTeeManager.register(data2, sig2, makeAddr("proxy2"), "https://tee2.url", address(0));

        // teeGovernanceHash is zero for teeId2, stateVersion is zero, state is empty => valid
        isValid = flareTeeManager.verifyTeeSystemState(
            teeId2, bytes32(0), new bytes(0)
        );
        assertTrue(isValid);

        // teeGovernanceHash is zero but state is non-empty => invalid
        isValid = flareTeeManager.verifyTeeSystemState(
            teeId2, bytes32(0), abi.encode(teeSystemState)
        );
        assertFalse(isValid);
    }

    function testVerifyTeeSystemStateRevertEvmError() public {
        vm.expectRevert();
        flareTeeManager.verifyTeeSystemState(
            teeId, stateVersion, new bytes(0)
        );
    }

    function testVerifyTeeSystemState() public {
        bool isValid = flareTeeManager.verifyTeeSystemState(
            teeId, stateVersion, abi.encode(teeSystemState)
        );
        assertTrue(isValid);
    }
}
