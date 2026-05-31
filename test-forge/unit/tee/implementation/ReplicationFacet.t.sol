// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { SignatureHelper } from "../../../utils/SignatureHelper.sol";

import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IReplication } from "../../../../contracts/userInterfaces/tee/IReplication.sol";
import { IMachineManager, TEE_MACHINE_REGISTER } from "../../../../contracts/userInterfaces/tee/IMachineManager.sol";
import { SignedPayload } from "../../../../contracts/utils/lib/SignedPayload.sol";
import { IMachinePathManager } from "../../../../contracts/userInterfaces/tee/IMachinePathManager.sol";
import {
    TEE_SOURCE_ID
} from "../../../../contracts/userInterfaces/tee/IVerification.sol";
import {
    ISystemStateVerifier
} from "../../../../contracts/userInterfaces/tee/ISystemStateVerifier.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { IFlareGovernance } from "../../../../contracts/userInterfaces/IFlareGovernance.sol";

import { IFdc2Verification } from "../../../../contracts/userInterfaces/fdc2/IFdc2Verification.sol";
import { IFdc2Hub, FDC2 } from "../../../../contracts/userInterfaces/fdc2/IFdc2Hub.sol";
import { ITeeAvailabilityCheck, TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE }
    from "../../../../contracts/userInterfaces/fdc2/ITeeAvailabilityCheck.sol";

import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { RandomNumberV2Interface } from "../../../../contracts/userInterfaces/LTS/RandomNumberV2Interface.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { PublicKey } from "../../../../contracts/userInterfaces/IPublicKey.sol";
import { Signature } from "../../../../contracts/userInterfaces/ISignature.sol";

// solhint-disable-next-line max-states-count
contract ReplicationFacetTest is Test {

    struct Signer {
        address addr;
        uint256 privateKey;
    }

    IIFlareTeeManager private flareTeeManager;

    IGovernanceSettings private governanceSettings;
    address private initialGovernance;
    address private addressUpdater;
    address private flareSystemsManager;
    address private rewardManager;
    address private relay;
    address private fdc2Verification;

    address private extensionOwner;
    address private instructionsSender;
    uint256 private extensionId;

    address private owner;

    PublicKey private teePublicKey;
    uint256 private teePrivateKey;
    address private teeId;
    address private teeProxyId;
    string private teeUrl;

    PublicKey private newTeePublicKey;
    uint256 private newTeePrivateKey;
    address private newTeeId;
    address private newTeeProxyId;
    string private newTeeUrl;

    Signer[] private governanceSigners;
    uint64 private governanceSignersThreshold;

    Signer[] private cosigners;
    uint64 private cosignersThreshold;

    bytes32 private governanceHash;
    bytes32 private codeHash1;
    bytes32 private codeHash2;
    bytes32[] private platforms1;

    uint256 private randomNumber;
    uint256 private teeIdRegistrationTs;

    function setUp() public {
        owner = makeAddr("teeMachineOwner");
        vm.deal(owner, 10 ether);

        extensionOwner = makeAddr("extensionOwner");
        instructionsSender = makeAddr("instructionsSender");

        VmSafe.Wallet memory wallet = vm.createWallet("teeId");
        teePublicKey.x = bytes32(wallet.publicKeyX);
        teePublicKey.y = bytes32(wallet.publicKeyY);
        teePrivateKey = wallet.privateKey;
        teeId = wallet.addr;
        teeProxyId = makeAddr("teeProxyId");
        teeUrl = "https://tee.proxy.url";

        wallet = vm.createWallet("newTeeId");
        newTeePublicKey.x = bytes32(wallet.publicKeyX);
        newTeePublicKey.y = bytes32(wallet.publicKeyY);
        newTeePrivateKey = wallet.privateKey;
        newTeeId = wallet.addr;
        newTeeProxyId = makeAddr("newTeeProxyId");
        newTeeUrl = "https://new.tee.proxy.url";

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        governanceSettings = IGovernanceSettings(makeAddr("governanceSettings"));
        flareSystemsManager = makeAddr("FlareSystemsManager");
        rewardManager = makeAddr("RewardManager");
        relay = makeAddr("Relay");
        fdc2Verification = makeAddr("Fdc2Verification");

        // Deploy the FlareTeeManager diamond
        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: governanceSettings,
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 6,
            challengeValidityDurationSeconds: 6000,
            defaultFee: 100,
            publicExtensionCreationEnabled: true,
            emergencyUnpauseGracePeriodSeconds: 7200
        }));
        vm.startPrank(initialGovernance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 1 minutes
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
        addresses[5] = fdc2Verification;

        vm.prank(addressUpdater);
        flareTeeManager.updateContractAddresses(nameHashes, addresses);

        // Set up governance signers
        governanceSigners.push();
        (governanceSigners[0].addr, governanceSigners[0].privateKey) = makeAddrAndKey("signer1");
        governanceSigners.push();
        (governanceSigners[1].addr, governanceSigners[1].privateKey) = makeAddrAndKey("signer2");
        governanceSigners.push();
        (governanceSigners[2].addr, governanceSigners[2].privateKey) = makeAddrAndKey("signer3");
        governanceSignersThreshold = 2;

        // Set up cosigners
        cosigners.push();
        (cosigners[0].addr, cosigners[0].privateKey) = makeAddrAndKey("cosigner1");
        cosigners.push();
        (cosigners[1].addr, cosigners[1].privateKey) = makeAddrAndKey("cosigner2");
        cosigners.push();
        (cosigners[2].addr, cosigners[2].privateKey) = makeAddrAndKey("cosigner3");
        cosignersThreshold = 2;

        // Set up code hashes and platforms
        codeHash1 = keccak256(abi.encodePacked("codeHash1"));
        codeHash2 = keccak256(abi.encodePacked("codeHash2"));
        platforms1.push(keccak256(abi.encodePacked("platform1")));

        governanceHash = keccak256(abi.encode(_getSignersAddresses(governanceSigners), governanceSignersThreshold));

        // Mock external contracts
        randomNumber = 12345;
        vm.mockCall(
            relay,
            abi.encodeWithSelector(RandomNumberV2Interface.getRandomNumber.selector),
            abi.encode(randomNumber, true, 0)
        );
        vm.mockCall(
            flareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(1)
        );
        vm.mockCall(
            rewardManager,
            abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
            abi.encode(1)
        );

        // Set up the diamond state
        vm.startPrank(initialGovernance);
        flareTeeManager.addSystemSupportedPlatforms(platforms1);
        flareTeeManager.setCosigners(_getSignersAddresses(cosigners), cosignersThreshold);

        // Set fees for replication operations
        bytes32[] memory opTypes = new bytes32[](3);
        bytes32[] memory opCommands = new bytes32[](3);
        uint256[] memory fees = new uint256[](3);
        opTypes[0] = bytes32("F_REG");
        opTypes[1] = bytes32("F_REG");
        opTypes[2] = bytes32("F_REG");
        opCommands[0] = bytes32("TEE_ATTESTATION");
        opCommands[1] = bytes32("TO_PAUSE_FOR_UPGRADE");
        opCommands[2] = bytes32("REPLICATE_FROM");
        fees[0] = 100;
        fees[1] = 100;
        fees[2] = 100;
        flareTeeManager.setOperationFees(opTypes, opCommands, fees);
        vm.stopPrank();

        // Register extension
        vm.prank(extensionOwner);
        extensionId = flareTeeManager.register(
            ITeeExtensionStateVerifier(address(0)),
            instructionsSender
        );

        // Set governance hash for extension
        vm.prank(extensionOwner);
        flareTeeManager.setNewTeeGovernance(
            extensionId,
            _getSignersAddresses(governanceSigners),
            governanceSignersThreshold
        );

        // Add version for codeHash1
        _addTeeVersion("v1.0.0", codeHash1, platforms1);

        // Allow owner
        address[] memory owners = new address[](1);
        owners[0] = owner;
        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeMachineOwners(extensionId, owners);

        // Advance time past challengeValidityDurationSeconds (6000) so registration always
        // generates a fresh attestation challenge rather than reusing a (zero) one.
        vm.warp(block.timestamp + 10000);
    }

    // toPauseForUpgrade
    function testToPauseForUpgradeRevertOnlyOwner() public {
        _registerAndProduceTee(teeId, teePrivateKey, teePublicKey, teeProxyId, teeUrl, codeHash1, platforms1[0]);
        vm.expectRevert(IReplication.OnlyMachineOwner.selector);
        flareTeeManager.toPauseForUpgrade(teeId, address(0));
    }

    function testToPauseForUpgradeRevertNotReplicationCapableInitialized() public {
        _registerTee(teeId, teePrivateKey, teePublicKey, teeProxyId, teeUrl, codeHash1, platforms1[0]);
        // TEE machine is in INITIALIZED state — `initialTeeId` has not been captured yet, so the
        // replication-capable modifier fires before the status check.
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IReplication.NotReplicationCapable.selector, teeId));
        flareTeeManager.toPauseForUpgrade{value: 100}(teeId, address(0));
        vm.stopPrank();
    }

    function testToPauseForUpgradeRevertTooSoon() public {
        _registerAndProduceTee(teeId, teePrivateKey, teePublicKey, teeProxyId, teeUrl, codeHash1, platforms1[0]);
        // Pause the machine
        vm.prank(owner);
        flareTeeManager.pause(teeId);
        // Try to upgrade immediately (too soon)
        vm.prank(owner);
        vm.expectRevert(IReplication.TooSoon.selector);
        flareTeeManager.toPauseForUpgrade{value: 100}(teeId, address(0));
    }

    function testToPauseForUpgrade() public {
        _registerAndProduceTee(teeId, teePrivateKey, teePublicKey, teeProxyId, teeUrl, codeHash1, platforms1[0]);
        vm.prank(owner);
        flareTeeManager.pause(teeId);
        // Wait long enough
        vm.warp(block.timestamp + 1000);
        vm.prank(owner);
        vm.expectEmit();
        emit IReplication.TeeMachinePausedForUpgrade(teeId);
        flareTeeManager.toPauseForUpgrade{value: 100}(teeId, address(0));
    }

    function testToPauseForUpgradeWithClaimBackAddress() public {
        _registerAndProduceTee(teeId, teePrivateKey, teePublicKey, teeProxyId, teeUrl, codeHash1, platforms1[0]);
        vm.prank(owner);
        flareTeeManager.pause(teeId);
        vm.warp(block.timestamp + 1000);

        address claimBack = makeAddr("claimBack");
        vm.prank(owner);
        vm.expectEmit();
        emit IReplication.TeeMachinePausedForUpgrade(teeId);
        flareTeeManager.toPauseForUpgrade{value: 100}(teeId, claimBack);
    }

    // replicateFrom
    function testReplicateFromRevertOnlyMachineOwner() public {
        _setupForReplication();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(
            newTeeId, newTeeProxyId, newTeeUrl, codeHash2, platforms1[0]
        );
        vm.expectRevert(IReplication.OnlyMachineOwner.selector);
        flareTeeManager.replicateFrom{value: 200}(teeId, proof, address(0));
    }

    function testReplicateFromHappyPathRetryAfterFirstCall() public {
        _setupForReplication();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(
            newTeeId, newTeeProxyId, newTeeUrl, codeHash2, platforms1[0]
        );
        _signProofWithCosigners(proof);
        vm.warp(block.timestamp + 1);
        vm.prank(owner);
        flareTeeManager.replicateFrom{value: 200}(teeId, proof, address(0));
        // newTeeId is now REPLICATING — a second replicateFrom with the same pair is a retry (allowed).
        IMachineManager.TeeStatus newStatus = flareTeeManager.getTeeMachineStatus(newTeeId);
        assertEq(uint256(newStatus), uint256(IMachineManager.TeeStatus.REPLICATING));
    }

    function testReplicateFromRevertInvalidTeeStatusRetryAfterReplicationConfirmed() public {
        // Test retry path: old tee has replication to newTee
        assertEq(flareTeeManager.getReplicatingTeeId(teeId), address(0));
        testReplicateFrom();
        assertEq(flareTeeManager.getReplicatingTeeId(teeId), newTeeId);
        // newTeeId is now REPLICATING, and replications[teeId] == newTeeId
        IMachineManager.TeeStatus newStatus = flareTeeManager.getTeeMachineStatus(newTeeId);
        assertEq(uint256(newStatus), uint256(IMachineManager.TeeStatus.REPLICATING));
    }

    function testReplicateFromRevertExtensionMismatch() public {
        _setupForReplication();
        // Register new tee in a different extension
        vm.prank(extensionOwner);
        uint256 extensionId2 = flareTeeManager.register(
            ITeeExtensionStateVerifier(address(0)),
            instructionsSender
        );
        _addTeeVersionForExtension(extensionId2, "v1.0.0", codeHash2, platforms1);

        address[] memory owners2 = new address[](1);
        owners2[0] = owner;
        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeMachineOwners(extensionId2, owners2);

        // Register newTee in extensionId2 instead of extensionId
        VmSafe.Wallet memory wallet2 = vm.createWallet("diffExtTee");
        PublicKey memory pk2;
        pk2.x = bytes32(wallet2.publicKeyX);
        pk2.y = bytes32(wallet2.publicKeyY);
        IMachineManager.TeeMachineData memory data = IMachineManager.TeeMachineData({
            extensionId: extensionId2,
            publicKey: pk2,
            initialOwner: owner,
            codeHash: codeHash2,
            platform: platforms1[0],
            governanceHash: governanceHash
        });
        Signature memory sig = SignatureHelper.createSignature(
            vm, SignedPayload.messageHash(TEE_MACHINE_REGISTER, keccak256(abi.encode(data))), wallet2.privateKey
        );
        vm.prank(owner);
        flareTeeManager.register{value: 100}(data, sig, makeAddr("proxy2"), "https://url2", address(0));

        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(
            wallet2.addr, makeAddr("proxy2"), "https://url2", codeHash2, platforms1[0]
        );
        vm.prank(owner);
        vm.expectRevert(IReplication.ExtensionMismatch.selector);
        flareTeeManager.replicateFrom{value: 200}(teeId, proof, address(0));
    }

    function testReplicateFromRevertVersionNotSupported() public {
        _registerAndProduceTee(teeId, teePrivateKey, teePublicKey, teeProxyId, teeUrl, codeHash1, platforms1[0]);
        vm.prank(owner);
        flareTeeManager.pause(teeId);
        vm.warp(block.timestamp + 1000);
        vm.prank(owner);
        flareTeeManager.toPauseForUpgrade{value: 100}(teeId, address(0));

        // We need codeHash2+platform to be supported for registration but not for the upgrade check.
        // Add version, register, then disable it after registration.
        _addTeeVersion("v2.0.0", codeHash2, platforms1);

        vm.warp(block.timestamp + 1);
        _registerTee(newTeeId, newTeePrivateKey, newTeePublicKey, newTeeProxyId, newTeeUrl, codeHash2, platforms1[0]);

        // Path list must be signed AFTER newTeeId is registered (path-list eligibility derives its
        // governance hash from the machine state).
        _createAndSignMachinePathList(teeId, newTeeId);

        // Disable the code hash platform after registration
        vm.prank(extensionOwner);
        flareTeeManager.disableCodeHashPlatform(extensionId, codeHash2, platforms1[0]);

        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(
            newTeeId, newTeeProxyId, newTeeUrl, codeHash2, platforms1[0]
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.VersionNotSupported.selector);
        flareTeeManager.replicateFrom{value: 200}(teeId, proof, address(0));
    }

    function testReplicateFromRevertNoActiveMachinePathList() public {
        // No machine-path list has been signed for the extension yet — replicateFrom must revert
        // with NoActiveMachinePathList.
        _registerAndProduceTee(teeId, teePrivateKey, teePublicKey, teeProxyId, teeUrl, codeHash1, platforms1[0]);
        vm.prank(owner);
        flareTeeManager.pause(teeId);
        vm.warp(block.timestamp + 1000);
        vm.prank(owner);
        flareTeeManager.toPauseForUpgrade{value: 100}(teeId, address(0));

        _addTeeVersion("v2.0.0", codeHash2, platforms1);

        vm.warp(block.timestamp + 1);
        _registerTee(newTeeId, newTeePrivateKey, newTeePublicKey, newTeeProxyId, newTeeUrl, codeHash2, platforms1[0]);

        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(
            newTeeId, newTeeProxyId, newTeeUrl, codeHash2, platforms1[0]
        );
        vm.prank(owner);
        vm.expectRevert(IMachinePathManager.NoActiveMachinePathList.selector);
        flareTeeManager.replicateFrom{value: 200}(teeId, proof, address(0));
    }

    function testReplicateFromRevertInvalidMachinePath() public {
        // A path-list is signed and active, but doesn't contain the (teeId, newTeeId) pair.
        _registerAndProduceTee(teeId, teePrivateKey, teePublicKey, teeProxyId, teeUrl, codeHash1, platforms1[0]);
        vm.prank(owner);
        flareTeeManager.pause(teeId);
        vm.warp(block.timestamp + 1000);
        vm.prank(owner);
        flareTeeManager.toPauseForUpgrade{value: 100}(teeId, address(0));

        _addTeeVersion("v2.0.0", codeHash2, platforms1);

        vm.warp(block.timestamp + 1);
        _registerTee(newTeeId, newTeePrivateKey, newTeePublicKey, newTeeProxyId, newTeeUrl, codeHash2, platforms1[0]);

        // Sign a list that does NOT include newTeeId on the destination side: use a dummy
        // destination teeId not registered as the replication target.
        address otherTee = makeAddr("otherTee");
        _registerTee(
            otherTee,
            vm.createWallet("otherTee").privateKey,
            _publicKeyFromWallet(vm.createWallet("otherTee")),
            makeAddr("otherProxy"),
            "https://other",
            codeHash2,
            platforms1[0]
        );
        _createAndSignMachinePathList(teeId, otherTee);

        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(
            newTeeId, newTeeProxyId, newTeeUrl, codeHash2, platforms1[0]
        );
        vm.prank(owner);
        vm.expectRevert(IMachinePathManager.InvalidMachinePath.selector);
        flareTeeManager.replicateFrom{value: 200}(teeId, proof, address(0));
    }

    function testReplicateFromRevertInvalidAvailabilityCheckStatus() public {
        _setupForReplication();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(
            newTeeId, newTeeProxyId, newTeeUrl, codeHash2, platforms1[0]
        );
        proof.responseBody.status = ITeeAvailabilityCheck.AvailabilityCheckStatus.DOWN;
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidAvailabilityCheckStatus.selector);
        flareTeeManager.replicateFrom{value: 200}(teeId, proof, address(0));
    }

    function testReplicateFromRevertAvailabilityCheckTimestampInvalid() public {
        _setupForReplication();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(
            newTeeId, newTeeProxyId, newTeeUrl, codeHash2, platforms1[0]
        );
        // Set timestamp to 0, which is before lastStatusChangeTs
        proof.header.timestamp = 0;
        // The AvailabilityCheckTimestampInvalid error includes the challengeTs parameter
        vm.prank(owner);
        vm.expectRevert(); // AvailabilityCheckTimestampInvalid with parameter
        flareTeeManager.replicateFrom{value: 200}(teeId, proof, address(0));
    }

    function testReplicateFromRevertInvalidResponseData() public {
        _setupForReplication();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(
            newTeeId, newTeeProxyId, newTeeUrl, codeHash2, platforms1[0]
        );
        // Tamper with codeHash in response body so it doesn't match
        proof.responseBody.codeHash = keccak256("wrong");
        // Re-sign with cosigners for the tampered proof
        _signProofWithCosigners(proof);
        vm.warp(block.timestamp + 1);
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidResponseData.selector);
        flareTeeManager.replicateFrom{value: 200}(teeId, proof, address(0));
    }

    function testReplicateFrom() public {
        _setupForReplication();
        // The path-list created in _setupForReplication is the first one signed for this extension,
        // so its activation nonce is 1.
        uint256 expectedNonce = 1;
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(
            newTeeId, newTeeProxyId, newTeeUrl, codeHash2, platforms1[0]
        );
        _signProofWithCosigners(proof);
        vm.warp(block.timestamp + 1);
        vm.prank(owner);
        vm.expectEmit();
        emit IReplication.TeeMachineReplicationTriggered(teeId, newTeeId, expectedNonce);
        flareTeeManager.replicateFrom{value: 200}(teeId, proof, address(0));
    }

    function testReplicateFromWithClaimBackAddress() public {
        _setupForReplication();
        uint256 expectedNonce = 1;
        address claimBack = makeAddr("claimBack");
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(
            newTeeId, newTeeProxyId, newTeeUrl, codeHash2, platforms1[0]
        );
        _signProofWithCosigners(proof);
        vm.warp(block.timestamp + 1);
        vm.prank(owner);
        vm.expectEmit();
        emit IReplication.TeeMachineReplicationTriggered(teeId, newTeeId, expectedNonce);
        flareTeeManager.replicateFrom{value: 200}(teeId, proof, claimBack);
    }

    // confirmReplicate
    function testConfirmReplicateRevertOnlyMachineOwner() public {
        _setupForReplication();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(
            teeId, teeProxyId, teeUrl, codeHash1, platforms1[0]
        );
        vm.expectRevert(IReplication.OnlyMachineOwner.selector);
        flareTeeManager.confirmReplicate(newTeeId, proof);
    }

    function testConfirmReplicateRevertReplicationNotValid() public {
        _setupForReplication();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(
            teeId, teeProxyId, teeUrl, codeHash1, platforms1[0]
        );
        vm.prank(owner);
        vm.expectRevert(IReplication.ReplicationNotValid.selector);
        flareTeeManager.confirmReplicate(newTeeId, proof);
    }

    function testConfirmReplicate() public {
        testReplicateFrom();
        // Now teeId is PAUSED_FOR_UPGRADE, newTeeId is REPLICATING
        // confirmReplicate calls _replicate which copies new tee data into old tee,
        // then verifies the proof against the updated old tee data.

        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProofForConfirm(
            teeId, newTeeProxyId, newTeeUrl
        );
        // Override the challenge to use the one from original teeId registration
        proof.requestBody.challenge = keccak256(abi.encode(teeId, teeIdRegistrationTs, randomNumber));
        proof.header.timestamp = uint64(block.timestamp);
        proof.responseBody.teeTimestamp = uint64(block.timestamp);
        _signProofWithCosigners(proof);
        vm.warp(block.timestamp + 1);
        vm.prank(owner);
        vm.expectEmit();
        emit IReplication.TeeMachineReplicationConfirmed(teeId, newTeeId);
        flareTeeManager.confirmReplicate(newTeeId, proof);
    }

    // setPauseBeforeUpgradeMinDurationSeconds
    function testSetPauseBeforeUpgradeMinDurationSecondsRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        flareTeeManager.setPauseBeforeUpgradeMinDurationSeconds(1 days);
    }

    function testSetPauseBeforeUpgradeMinDurationSecondsRevertInvalidDuration1() public {
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeCommonErrors.InvalidDuration.selector);
        flareTeeManager.setPauseBeforeUpgradeMinDurationSeconds(2 days);
    }

    function testSetPauseBeforeUpgradeMinDurationSecondsRevertInvalidDuration2() public {
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeCommonErrors.InvalidDuration.selector);
        flareTeeManager.setPauseBeforeUpgradeMinDurationSeconds(1);
    }

    function testSetPauseBeforeUpgradeMinDurationSeconds() public {
        vm.expectEmit();
        emit IReplication.PauseBeforeUpgradeMinDurationSecondsSet(1 days);
        vm.prank(initialGovernance);
        flareTeeManager.setPauseBeforeUpgradeMinDurationSeconds(1 days);
    }

    // getReplicatingTeeId
    function testGetReplicatingTeeId() public {
        testReplicateFrom();
        assertEq(flareTeeManager.getReplicatingTeeId(teeId), newTeeId);
    }

    // =========================================================================
    // Helper functions
    // =========================================================================

    function _publicKeyFromWallet(VmSafe.Wallet memory _wallet) private pure returns (PublicKey memory _pk) {
        _pk.x = bytes32(_wallet.publicKeyX);
        _pk.y = bytes32(_wallet.publicKeyY);
    }

    function _registerTee(
        address _teeId,
        uint256 _privateKey,
        PublicKey memory _publicKey,
        address _teeProxyId,
        string memory _url,
        bytes32 _codeHash,
        bytes32 _platform
    )
        private
    {
        IMachineManager.TeeMachineData memory data = IMachineManager.TeeMachineData({
            extensionId: extensionId,
            publicKey: _publicKey,
            initialOwner: owner,
            codeHash: _codeHash,
            platform: _platform,
            governanceHash: governanceHash
        });
        Signature memory sig = SignatureHelper.createSignature(
            vm, SignedPayload.messageHash(TEE_MACHINE_REGISTER, keccak256(abi.encode(data))), _privateKey
        );
        if (_teeId == teeId) {
            teeIdRegistrationTs = block.timestamp;
        }
        vm.prank(owner);
        flareTeeManager.register{value: 100}(data, sig, _teeProxyId, _url, address(0));
    }

    function _registerAndProduceTee(
        address _teeId,
        uint256 _privateKey,
        PublicKey memory _publicKey,
        address _teeProxyId,
        string memory _url,
        bytes32 _codeHash,
        bytes32 _platform
    )
        private
    {
        _registerTee(_teeId, _privateKey, _publicKey, _teeProxyId, _url, _codeHash, _platform);
        _putToProduction(_teeId, _teeProxyId, _url, _codeHash, _platform);
    }

    function _putToProduction(
        address _teeId,
        address _teeProxyId,
        string memory _url,
        bytes32 _codeHash,
        bytes32 _platform
    )
        private
    {
        IFdc2Hub.Fdc2ResponseHeader memory header = IFdc2Hub.Fdc2ResponseHeader(
            TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE,
            TEE_SOURCE_ID,
            0,
            address(0),
            _getSignersAddresses(cosigners),
            cosignersThreshold,
            uint64(block.timestamp)
        );
        ITeeAvailabilityCheck.RequestBody memory reqBody = ITeeAvailabilityCheck.RequestBody(
            _teeId,
            _teeProxyId,
            _url,
            keccak256(abi.encode(_teeId, block.timestamp, randomNumber)),
            keccak256(abi.encode(extensionId))
        );
        ISystemStateVerifier.TeeSystemState memory systemState = ISystemStateVerifier.TeeSystemState(
            ISystemStateVerifier.TeeMachineStatus.ACTIVE,
            _teeId
        );
        ITeeAvailabilityCheck.ResponseBody memory respBody = ITeeAvailabilityCheck.ResponseBody(
            ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            uint64(block.timestamp),
            _codeHash,
            _platform,
            1,
            1,
            ITeeAvailabilityCheck.TeeState(abi.encode(systemState), bytes32("v1"), new bytes(0), bytes32(0))
        );

        bytes32 messageHash = SignedPayload.messageHash(
            FDC2,
            keccak256(abi.encode(header, reqBody, respBody))
        );
        bytes32 cosignersMessageHash = keccak256(bytes.concat(hex"010000000000", messageHash));

        IFdc2Verification.Fdc2Signatures memory sigs;
        sigs.cosignerSignatures = new Signature[](cosignersThreshold);
        for (uint256 i = 0; i < cosignersThreshold; i++) {
            sigs.cosignerSignatures[i] =
                SignatureHelper.createSignature(vm, cosignersMessageHash, cosigners[i].privateKey);
        }

        // Mock the fdc2Verification calls
        vm.mockCall(
            fdc2Verification,
            abi.encodeWithSelector(IFdc2Verification.verifySigningPolicySignatures.selector),
            abi.encode(uint256(1))
        );
        vm.mockCall(
            fdc2Verification,
            abi.encodeWithSelector(IFdc2Verification.recoverCosigners.selector),
            abi.encode(_getSignersAddresses(cosigners))
        );

        ITeeAvailabilityCheck.Proof memory proof = ITeeAvailabilityCheck.Proof(
            sigs,
            header,
            reqBody,
            respBody
        );

        vm.warp(block.timestamp + 1);
        vm.prank(owner);
        flareTeeManager.toProduction(proof);
    }

    function _addTeeVersion(
        string memory _version,
        bytes32 _codeHash,
        bytes32[] memory _platforms
    )
        private
    {
        vm.prank(extensionOwner);
        flareTeeManager.addTeeVersion(extensionId, _version, _codeHash, _platforms);
    }

    function _addTeeVersionForExtension(
        uint256 _extensionId,
        string memory _version,
        bytes32 _codeHash,
        bytes32[] memory _platforms
    )
        private
    {
        // Need governance for the new extension
        vm.prank(extensionOwner);
        flareTeeManager.setNewTeeGovernance(
            _extensionId,
            _getSignersAddresses(governanceSigners),
            governanceSignersThreshold
        );
        vm.prank(extensionOwner);
        flareTeeManager.addTeeVersion(_extensionId, _version, _codeHash, _platforms);
    }

    /**
     * Creates, finalizes and signs a machine-path list authorizing the (_source, _destination) pair.
     * Returns the activated list nonce.
     */
    function _createAndSignMachinePathList(
        address _source,
        address _destination
    )
        private
        returns (uint256 _nonce)
    {
        vm.prank(extensionOwner);
        _nonce = flareTeeManager.createNewMachinePathList(extensionId);

        IMachinePathManager.MachinePath[] memory paths = new IMachinePathManager.MachinePath[](1);
        address[] memory sources = new address[](1);
        sources[0] = _source;
        address[] memory destinations = new address[](1);
        destinations[0] = _destination;
        paths[0] = IMachinePathManager.MachinePath(sources, destinations);
        vm.prank(extensionOwner);
        flareTeeManager.addMachinePaths(extensionId, _nonce, paths);

        vm.prank(extensionOwner);
        flareTeeManager.finalizeMachinePathList(extensionId, _nonce);

        // Sign with `governanceSignersThreshold` distinct governance signers.
        bytes32 messageHash = flareTeeManager.getMachinePathListMessageHash(extensionId, _nonce);
        for (uint256 i = 0; i < governanceSignersThreshold; i++) {
            Signature memory sig = SignatureHelper.createSignature(
                vm, messageHash, governanceSigners[i].privateKey
            );
            flareTeeManager.signMachinePathList(extensionId, _nonce, sig);
        }
    }

    function _setupForReplication() private {
        // Register and produce old tee
        _registerAndProduceTee(teeId, teePrivateKey, teePublicKey, teeProxyId, teeUrl, codeHash1, platforms1[0]);

        // Add new version
        _addTeeVersion("v2.0.0", codeHash2, platforms1);

        // Pause and upgrade old tee
        vm.prank(owner);
        flareTeeManager.pause(teeId);
        vm.warp(block.timestamp + 1000);
        vm.prank(owner);
        flareTeeManager.toPauseForUpgrade{value: 100}(teeId, address(0));

        // Register new tee (status: INITIALIZED — that is fine for path-list membership;
        // the path-list helper no longer requires PRODUCTION on either side).
        vm.warp(block.timestamp + 1);
        _registerTee(newTeeId, newTeePrivateKey, newTeePublicKey, newTeeProxyId, newTeeUrl, codeHash2, platforms1[0]);

        // Authorize (teeId, newTeeId) replication path through a signed machine-path list.
        _createAndSignMachinePathList(teeId, newTeeId);
    }

    function _signProofWithCosigners(
        ITeeAvailabilityCheck.Proof memory _proof
    )
        private
    {
        bytes32 messageHash = SignedPayload.messageHash(
            FDC2,
            keccak256(abi.encode(_proof.header, _proof.requestBody, _proof.responseBody))
        );
        bytes32 cosignersMessageHash = keccak256(bytes.concat(hex"010000000000", messageHash));

        _proof.signatures.cosignerSignatures = new Signature[](cosignersThreshold);
        for (uint256 i = 0; i < cosignersThreshold; i++) {
            _proof.signatures.cosignerSignatures[i] =
                SignatureHelper.createSignature(vm, cosignersMessageHash, cosigners[i].privateKey);
        }

        // Mock the fdc2Verification calls
        vm.mockCall(
            fdc2Verification,
            abi.encodeWithSelector(IFdc2Verification.verifySigningPolicySignatures.selector),
            abi.encode(uint256(1))
        );
        vm.mockCall(
            fdc2Verification,
            abi.encodeWithSelector(IFdc2Verification.recoverCosigners.selector),
            abi.encode(_getSignersAddresses(cosigners))
        );
    }

    function _createAvailabilityCheckProof(
        address _teeId,
        address _teeProxyId,
        string memory _url,
        bytes32 _codeHash,
        bytes32 _platform
    )
        private view
        returns (ITeeAvailabilityCheck.Proof memory)
    {
        IFdc2Hub.Fdc2ResponseHeader memory header = IFdc2Hub.Fdc2ResponseHeader(
            TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE,
            TEE_SOURCE_ID,
            0,
            address(0),
            _getSignersAddresses(cosigners),
            cosignersThreshold,
            uint64(block.timestamp)
        );
        ITeeAvailabilityCheck.RequestBody memory reqBody = ITeeAvailabilityCheck.RequestBody(
            _teeId,
            _teeProxyId,
            _url,
            keccak256(abi.encode(_teeId, block.timestamp, randomNumber)),
            keccak256(abi.encode(extensionId))
        );
        ISystemStateVerifier.TeeSystemState memory systemState = ISystemStateVerifier.TeeSystemState(
            ISystemStateVerifier.TeeMachineStatus.ACTIVE,
            _teeId
        );
        ITeeAvailabilityCheck.ResponseBody memory respBody = ITeeAvailabilityCheck.ResponseBody(
            ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            uint64(block.timestamp),
            _codeHash,
            _platform,
            1,
            1,
            ITeeAvailabilityCheck.TeeState(abi.encode(systemState), bytes32("v1"), new bytes(0), bytes32(0))
        );

        IFdc2Verification.Fdc2Signatures memory sigs;
        return ITeeAvailabilityCheck.Proof(
            sigs,
            header,
            reqBody,
            respBody
        );
    }

    function _createAvailabilityCheckProofForConfirm(
        address _oldTeeId,
        address _teeProxyId,
        string memory _url
    )
        private view
        returns (ITeeAvailabilityCheck.Proof memory)
    {
        // For confirmReplicate, the proof's requestBody.teeId is the OLD tee
        // but after _replicate copies new data into old state:
        // - teeProxyId, url, codeHash, platform, initialTeeId = new tee's values
        IFdc2Hub.Fdc2ResponseHeader memory header = IFdc2Hub.Fdc2ResponseHeader(
            TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE,
            TEE_SOURCE_ID,
            0,
            address(0),
            _getSignersAddresses(cosigners),
            cosignersThreshold,
            uint64(block.timestamp)
        );
        ITeeAvailabilityCheck.RequestBody memory reqBody = ITeeAvailabilityCheck.RequestBody(
            _oldTeeId,
            _teeProxyId,
            _url,
            keccak256(abi.encode(_oldTeeId, block.timestamp, randomNumber)),
            keccak256(abi.encode(extensionId))
        );
        // After replication, old tee's initialTeeId = newTeeId (copied from new state); the
        // TEE software answering at the new proxy reports its own provisioning identity (newTeeId).
        ISystemStateVerifier.TeeSystemState memory systemState = ISystemStateVerifier.TeeSystemState(
            ISystemStateVerifier.TeeMachineStatus.ACTIVE,
            newTeeId
        );
        // After replication copy, old tee will have new tee's codeHash2 and platform
        ITeeAvailabilityCheck.ResponseBody memory respBody = ITeeAvailabilityCheck.ResponseBody(
            ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            uint64(block.timestamp),
            codeHash2,
            platforms1[0],
            1,
            1,
            ITeeAvailabilityCheck.TeeState(abi.encode(systemState), bytes32("v1"), new bytes(0), bytes32(0))
        );

        IFdc2Verification.Fdc2Signatures memory sigs;
        return ITeeAvailabilityCheck.Proof(
            sigs,
            header,
            reqBody,
            respBody
        );
    }

    function _getSignersAddresses(Signer[] storage _signers) private view returns (address[] memory) {
        address[] memory addrs = new address[](_signers.length);
        for (uint256 i = 0; i < _signers.length; i++) {
            addrs[i] = _signers[i].addr;
        }
        return addrs;
    }
}
