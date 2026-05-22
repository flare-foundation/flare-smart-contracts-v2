// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";

import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";

import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IMachineManager } from "../../../../contracts/userInterfaces/tee/IMachineManager.sol";
import {
    TEE_SOURCE_ID
} from "../../../../contracts/userInterfaces/tee/IVerification.sol";
import {
    ISystemStateVerifier
} from "../../../../contracts/userInterfaces/tee/ISystemStateVerifier.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";

import { IFdc2Verification } from "../../../../contracts/userInterfaces/fdc2/IFdc2Verification.sol";
import { IFdc2Hub } from "../../../../contracts/userInterfaces/fdc2/IFdc2Hub.sol";
import { ITeeAvailabilityCheck, TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE }
    from "../../../../contracts/userInterfaces/fdc2/ITeeAvailabilityCheck.sol";

import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { RandomNumberV2Interface } from "../../../../contracts/userInterfaces/LTS/RandomNumberV2Interface.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";

import { PublicKey } from "../../../../contracts/userInterfaces/IPublicKey.sol";
import { Signature } from "../../../../contracts/userInterfaces/ISignature.sol";
import { PublicKeyHelper } from "../../../utils/PublicKeyHelper.sol";
import { SignatureHelper } from "../../../utils/SignatureHelper.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

// solhint-disable-next-line max-states-count
contract MachineManagerFacetTest is Test {

    struct Signer {
        address addr;
        uint256 privateKey;
    }

    IIFlareTeeManager private flareTeeManager;

    address private owner;
    address private invalidOwner;

    address private initialGovernance;
    address private addressUpdater;
    address private extensionOwner;
    address private flareSystemsManager;
    address private rewardManager;
    address private relay;
    address private fdc2Hub;
    address private fdc2Verification;

    uint256 private extensionId;
    PublicKey private teePublicKey;
    uint256 private teePrivateKey;
    address private teeId;
    address private teeProxyId;
    string private url;
    bytes32 private codeHash;
    bytes32 private platform;
    bytes32 private governanceHash;
    IMachineManager.TeeMachineData private teeMachineData;
    Signature private teeMachineDataSignature;

    PublicKey private newTeePublicKey;
    uint256 private newTeePrivateKey;
    address private newTeeId;
    IMachineManager.TeeMachineData private newTeeMachineData;
    Signature private newTeeMachineDataSignature;

    Signer[] private governanceSigners;
    uint64 private governanceSignersThreshold;

    Signer[] private cosigners;
    uint64 private cosignersThreshold;

    uint256 private randomNumber;

    /// @dev Stores the block.timestamp at which register() was called, used to reconstruct the challenge.
    mapping(address teeId => uint256) private registerTimestamps;

    function setUp() public {
        owner = makeAddr("owner");
        invalidOwner = makeAddr("invalidOwner");

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        extensionOwner = makeAddr("extensionOwner");

        flareSystemsManager = makeAddr("FlareSystemsManager");
        rewardManager = makeAddr("RewardManager");
        relay = makeAddr("Relay");
        fdc2Hub = makeAddr("Fdc2Hub");
        fdc2Verification = makeAddr("Fdc2Verification");

        teePrivateKey = PublicKeyHelper.getRandomPrivateKey(vm);
        teePublicKey = PublicKeyHelper.getPublicKey(vm, teePrivateKey);
        teeId = PublicKeyHelper.getAddress(teePublicKey);
        teeProxyId = makeAddr("teeProxyId");
        url = "url";
        codeHash = keccak256("codeHash");
        platform = keccak256("platform");

        newTeePrivateKey = PublicKeyHelper.getRandomPrivateKey(vm);
        newTeePublicKey = PublicKeyHelper.getPublicKey(vm, newTeePrivateKey);
        newTeeId = PublicKeyHelper.getAddress(newTeePublicKey);

        // Set up governance signers
        governanceSigners.push();
        (governanceSigners[0].addr, governanceSigners[0].privateKey) = makeAddrAndKey("signer1");
        governanceSigners.push();
        (governanceSigners[1].addr, governanceSigners[1].privateKey) = makeAddrAndKey("signer2");
        governanceSigners.push();
        (governanceSigners[2].addr, governanceSigners[2].privateKey) = makeAddrAndKey("signer3");
        governanceSignersThreshold = 2;

        governanceHash = keccak256(abi.encode(_getSignersAddresses(governanceSigners), governanceSignersThreshold));

        // Set up cosigners
        cosigners.push();
        (cosigners[0].addr, cosigners[0].privateKey) = makeAddrAndKey("cosigner1");
        cosigners.push();
        (cosigners[1].addr, cosigners[1].privateKey) = makeAddrAndKey("cosigner2");
        cosigners.push();
        (cosigners[2].addr, cosigners[2].privateKey) = makeAddrAndKey("cosigner3");
        cosignersThreshold = 2;

        // Deploy the diamond
        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 6,
            challengeValidityDurationSeconds: 600,
            defaultFee: 0,
            publicExtensionCreationEnabled: true
        }));
        vm.startPrank(initialGovernance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();

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
        addresses[1] = flareSystemsManager;
        addresses[2] = rewardManager;
        addresses[3] = relay;
        addresses[4] = fdc2Hub;
        addresses[5] = fdc2Verification;

        vm.prank(addressUpdater);
        flareTeeManager.updateContractAddresses(nameHashes, addresses);

        // Register extension through the diamond
        vm.prank(extensionOwner);
        extensionId = flareTeeManager.register(
            ITeeExtensionStateVerifier(address(0)),
            makeAddr("instructionsSender")
        );

        // Add system supported platforms
        bytes32[] memory platforms = new bytes32[](1);
        platforms[0] = platform;
        vm.startPrank(initialGovernance);
        flareTeeManager.addSystemSupportedPlatforms(platforms);

        // Set cosigners
        flareTeeManager.setCosigners(
            _getSignersAddresses(cosigners),
            cosignersThreshold
        );
        vm.stopPrank();

        // Set governance hash for the extension
        vm.prank(extensionOwner);
        flareTeeManager.setNewTeeGovernance(
            extensionId,
            _getSignersAddresses(governanceSigners),
            governanceSignersThreshold
        );

        // Add tee version (code hash + platform)
        vm.prank(extensionOwner);
        flareTeeManager.addTeeVersion(extensionId, "v1.0.0", codeHash, platforms, governanceHash);

        // Add allowed TEE machine owners
        address[] memory owners = new address[](2);
        owners[0] = owner;
        owners[1] = invalidOwner;
        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeMachineOwners(extensionId, owners);

        // Set up TEE machine data
        teeMachineData = IMachineManager.TeeMachineData({
            extensionId: extensionId,
            publicKey: teePublicKey,
            initialOwner: owner,
            codeHash: codeHash,
            platform: platform
        });
        teeMachineDataSignature = SignatureHelper.createSignature(
            vm,
            keccak256(abi.encode(teeMachineData)),
            teePrivateKey
        );

        newTeeMachineData = IMachineManager.TeeMachineData({
            extensionId: extensionId,
            publicKey: newTeePublicKey,
            initialOwner: owner,
            codeHash: codeHash,
            platform: platform
        });
        newTeeMachineDataSignature = SignatureHelper.createSignature(
            vm,
            keccak256(abi.encode(newTeeMachineData)),
            newTeePrivateKey
        );

        // Mock external contract calls
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

        vm.mockCall(
            fdc2Hub,
            abi.encodeWithSelector(IFdc2Hub.requestAttestation.selector),
            ""
        );

        // Advance time so block.timestamp > 1
        vm.warp(block.timestamp + 1000);
    }

    // =========================================================================
    // register
    // =========================================================================

    function testRegisterRevertOwnerNotAllowed() public {
        address someOwner = makeAddr("someOwner");
        teeMachineData.initialOwner = someOwner;
        vm.prank(someOwner);
        vm.expectRevert(ITeeCommonErrors.OwnerNotAllowed.selector);
        flareTeeManager.register(teeMachineData, teeMachineDataSignature, teeProxyId, url, address(0));
    }

    function testRegisterRevertInvalidTeePublicKey() public {
        teeMachineData.publicKey = PublicKey(0, 0);
        vm.prank(owner);
        vm.expectRevert(IMachineManager.InvalidTeePublicKey.selector);
        flareTeeManager.register(teeMachineData, teeMachineDataSignature, teeProxyId, url, address(0));
    }

    function testRegisterRevertInvalidTeePublicKeyOrSignature() public {
        teeMachineData.publicKey = PublicKeyHelper.getRandomPublicKey(vm);
        vm.prank(owner);
        vm.expectRevert(IMachineManager.InvalidTeePublicKeyOrSignature.selector);
        flareTeeManager.register(teeMachineData, teeMachineDataSignature, teeProxyId, url, address(0));
    }

    function testRegisterRevertInvalidTeeProxyId() public {
        vm.prank(owner);
        vm.expectRevert(IMachineManager.InvalidTeeProxyId.selector);
        flareTeeManager.register(teeMachineData, teeMachineDataSignature, address(0), url, address(0));
    }

    function testRegisterRevertInvalidUrl() public {
        vm.prank(owner);
        vm.expectRevert(IMachineManager.InvalidUrl.selector);
        flareTeeManager.register(teeMachineData, teeMachineDataSignature, teeProxyId, "", address(0));
    }

    function testRegisterRevertAlreadyRegistered() public {
        vm.startPrank(owner);
        flareTeeManager.register(teeMachineData, teeMachineDataSignature, teeProxyId, url, address(0));
        vm.expectRevert(IMachineManager.AlreadyRegistered.selector);
        flareTeeManager.register(teeMachineData, teeMachineDataSignature, teeProxyId, url, address(0));
        vm.stopPrank();
    }

    function testRegisterRevertVersionNotSupported() public {
        // Create machine data with unsupported code hash
        teeMachineData.codeHash = keccak256("unsupported");
        teeMachineDataSignature = SignatureHelper.createSignature(
            vm,
            keccak256(abi.encode(teeMachineData)),
            teePrivateKey
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.VersionNotSupported.selector);
        flareTeeManager.register(teeMachineData, teeMachineDataSignature, teeProxyId, url, address(0));
    }

    function testRegister() public {
        vm.prank(owner);
        vm.expectEmit();
        emit IMachineManager.TeeMachineRegistered(
            teeId, teeProxyId, owner, extensionId, url, codeHash, platform
        );
        flareTeeManager.register(teeMachineData, teeMachineDataSignature, teeProxyId, url, address(0));
        registerTimestamps[teeId] = block.timestamp;
    }

    // =========================================================================
    // toProduction
    // =========================================================================

    function testToProductionRevertOnlyOwner() public {
        testRegister();
        ITeeAvailabilityCheck.Proof memory proof = _createValidAvailabilityCheckProof(teeId, teeProxyId, url);
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.toProduction(proof);
    }

    function testToProductionRevertInvalidTeeStatus() public {
        testToProduction();
        ITeeAvailabilityCheck.Proof memory proof = _createValidAvailabilityCheckProof(teeId, teeProxyId, url);
        vm.prank(owner);
        vm.expectRevert(IMachineManager.InvalidTeeStatus.selector);
        flareTeeManager.toProduction(proof);
    }

    function testToProductionRevertVersionNotSupported() public {
        testRegister();
        // Disable the code hash platform
        vm.prank(extensionOwner);
        flareTeeManager.disableCodeHashPlatform(extensionId, codeHash, platform);
        ITeeAvailabilityCheck.Proof memory proof = _createValidAvailabilityCheckProof(teeId, teeProxyId, url);
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.VersionNotSupported.selector);
        flareTeeManager.toProduction(proof);
    }

    function testToProductionRevertInvalidAvailabilityCheckStatus() public {
        testRegister();
        ITeeAvailabilityCheck.Proof memory proof = _createValidAvailabilityCheckProof(teeId, teeProxyId, url);
        proof.responseBody.status = ITeeAvailabilityCheck.AvailabilityCheckStatus.DOWN;
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidAvailabilityCheckStatus.selector);
        flareTeeManager.toProduction(proof);
    }

    function testToProductionRevertAvailabilityCheckTimestampInvalid() public {
        testRegister();
        ITeeAvailabilityCheck.Proof memory proof = _createValidAvailabilityCheckProof(teeId, teeProxyId, url);
        proof.header.timestamp = 0;
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.AvailabilityCheckTimestampInvalid.selector);
        flareTeeManager.toProduction(proof);
    }

    function testToProductionRevertInvalidResponseData() public {
        testRegister();
        ITeeAvailabilityCheck.Proof memory proof = _createValidAvailabilityCheckProof(teeId, teeProxyId, url);
        // corrupt the response body to make verification fail
        proof.responseBody.codeHash = keccak256("wrong");
        // Advance time so header.timestamp < block.timestamp (required by verifyAvailabilityCheckProof)
        vm.warp(block.timestamp + 1);
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidResponseData.selector);
        flareTeeManager.toProduction(proof);
    }

    function testToProduction() public {
        testRegister();
        _changeStateToProduction();
    }

    // =========================================================================
    // pause
    // =========================================================================

    function testPauseRevertOnlyOwnerOrExpiredAvailabilityCheckOrDisabledVersion() public {
        testToProduction();
        vm.expectRevert(IMachineManager.OnlyOwnerOrExpiredAvailabilityCheckOrDisabledVersion.selector);
        flareTeeManager.pause(teeId);
    }

    function testPause() public {
        testToProduction();
        vm.prank(owner);
        vm.expectEmit();
        emit IMachineManager.TeeMachineStatusChanged(teeId, IMachineManager.TeeStatus.PAUSED);
        flareTeeManager.pause(teeId);
    }

    function testPauseFromPausedWithProof() public {
        testPauseWithProof();
        vm.prank(owner);
        vm.expectEmit();
        emit IMachineManager.TeeMachineStatusChanged(teeId, IMachineManager.TeeStatus.PAUSED);
        flareTeeManager.pause(teeId);
    }

    function testPauseAfterExpiredAvailabilityCheck() public {
        testToProduction();
        // Advance time past availability check validity
        vm.warp(block.timestamp + 7200);
        // anyone can call pause when availability check expired
        vm.expectEmit();
        emit IMachineManager.TeeMachineStatusChanged(teeId, IMachineManager.TeeStatus.SUSPENDED);
        flareTeeManager.pause(teeId);
    }

    function testPauseWhenCodeHashPlatformDisabled() public {
        testToProduction();
        // Disable the code hash platform through the diamond
        vm.prank(extensionOwner);
        flareTeeManager.disableCodeHashPlatform(extensionId, codeHash, platform);
        // anyone can call pause when code hash platform is disabled
        vm.expectEmit();
        emit IMachineManager.TeeMachineStatusChanged(teeId, IMachineManager.TeeStatus.PAUSED);
        flareTeeManager.pause(teeId);
    }

    function testPauseRevertInvalidTeeStatus() public {
        vm.expectRevert(IMachineManager.TeeNotFound.selector);
        flareTeeManager.pause(teeId);
    }

    function testPauseRevertInvalidTeeStatus2() public {
        testPause();
        vm.expectRevert(IMachineManager.InvalidTeeStatus.selector);
        vm.prank(owner);
        flareTeeManager.pause(teeId);
    }

    // =========================================================================
    // pauseWithProof
    // =========================================================================

    function testPauseWithProofRevertInvalidTeeStatus() public {
        testRegister();
        ITeeAvailabilityCheck.Proof memory proof = _createValidAvailabilityCheckProof(teeId, teeProxyId, url);
        vm.expectRevert(IMachineManager.InvalidTeeStatus.selector);
        flareTeeManager.pauseWithProof(proof);
    }

    function testPauseWithProofRevertInvalidResponseDataOrAvailabilityCheckStatus() public {
        testToProduction();
        ITeeAvailabilityCheck.Proof memory proof = _createValidAvailabilityCheckProof(teeId, teeProxyId, url);
        // Advance time so header.timestamp < block.timestamp (required by verifyAvailabilityCheckProof)
        vm.warp(block.timestamp + 1);
        // A valid proof with OK status should revert since both are valid
        vm.expectRevert(IMachineManager.InvalidResponseDataOrAvailabilityCheckStatus.selector);
        flareTeeManager.pauseWithProof(proof);
    }

    function testPauseWithProofRevertAvailabilityCheckTimestampInvalid() public {
        testToProduction();
        ITeeAvailabilityCheck.Proof memory proof = _createValidAvailabilityCheckProof(teeId, teeProxyId, url);
        proof.header.timestamp = 0;
        vm.expectRevert(ITeeCommonErrors.AvailabilityCheckTimestampInvalid.selector);
        flareTeeManager.pauseWithProof(proof);
    }

    function testPauseWithProof() public {
        testToProduction();
        ITeeAvailabilityCheck.Proof memory proof = _createValidAvailabilityCheckProof(teeId, teeProxyId, url);
        // Make the proof invalid (wrong codeHash) so !responseDataValid is true
        proof.responseBody.codeHash = keccak256("wrong");
        // Advance time so header.timestamp < block.timestamp (required by verifyAvailabilityCheckProof)
        vm.warp(block.timestamp + 1);
        vm.expectEmit();
        emit IMachineManager.TeeMachineStatusChanged(teeId, IMachineManager.TeeStatus.SUSPENDED);
        flareTeeManager.pauseWithProof(proof);
    }

    // =========================================================================
    // ban / unban
    // =========================================================================

    function testBanRevertOnlyExtensionOwner() public {
        testToProduction();
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.ban(teeId);
    }

    function testBan() public {
        testToProduction();
        vm.prank(extensionOwner);
        vm.expectEmit();
        emit IMachineManager.TeeMachineStatusChanged(teeId, IMachineManager.TeeStatus.BANNED);
        flareTeeManager.ban(teeId);
    }

    function testBanRevertInvalidTeeStatus() public {
        testRegister();
        vm.prank(extensionOwner);
        vm.expectRevert(IMachineManager.InvalidTeeStatus.selector);
        flareTeeManager.ban(teeId);
    }

    function testUnbanRevertOnlyExtensionOwner() public {
        testBan();
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.unban(teeId);
    }

    function testUnban() public {
        testBan();
        vm.prank(extensionOwner);
        vm.expectEmit();
        emit IMachineManager.TeeMachineStatusChanged(teeId, IMachineManager.TeeStatus.PAUSED);
        flareTeeManager.unban(teeId);
    }

    function testUnbanRevertInvalidTeeStatus() public {
        testToProduction();
        vm.prank(extensionOwner);
        vm.expectRevert(IMachineManager.InvalidTeeStatus.selector);
        flareTeeManager.unban(teeId);
    }

    // =========================================================================
    // proposeNewOwner
    // =========================================================================

    function testProposeNewOwnerRevertOnlyOwner() public {
        vm.expectRevert(IMachineManager.TeeNotFound.selector);
        flareTeeManager.proposeNewOwner(teeId, address(0));
    }

    function testProposeNewOwnerRevertOwnerNotAllowed() public {
        testRegister();
        address notAllowed = makeAddr("notAllowed");
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.OwnerNotAllowed.selector);
        flareTeeManager.proposeNewOwner(teeId, notAllowed);
    }

    function testProposeNewOwner() public {
        testRegister();
        vm.prank(owner);
        vm.expectEmit();
        emit IMachineManager.NewOwnerProposed(teeId, owner, invalidOwner);
        flareTeeManager.proposeNewOwner(teeId, invalidOwner);
    }

    // =========================================================================
    // confirmOwnership
    // =========================================================================

    function testConfirmOwnershipRevertOwnerNotAllowed() public {
        testRegister();
        // Propose address(0) as new owner (allowed), then remove invalidOwner from allowlist
        vm.prank(owner);
        flareTeeManager.proposeNewOwner(teeId, address(0));
        // Calling confirmOwnership from an address not in the allowlist
        address notAllowed = makeAddr("notAllowed");
        vm.prank(notAllowed);
        vm.expectRevert(ITeeCommonErrors.OwnerNotAllowed.selector);
        flareTeeManager.confirmOwnership(teeId);
    }

    function testConfirmOwnershipRevertOnlyProposedOwner() public {
        testProposeNewOwner();
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.OnlyProposedOwner.selector);
        flareTeeManager.confirmOwnership(teeId);
    }

    function testConfirmOwnership() public {
        testProposeNewOwner();
        vm.prank(invalidOwner);
        vm.expectEmit();
        emit IMachineManager.NewOwnerConfirmed(teeId, invalidOwner);
        flareTeeManager.confirmOwnership(teeId);
    }

    // =========================================================================
    // updateTeeMachineSettings
    // =========================================================================

    function testUpdateTeeMachineSettingsRevertOnlyOwner() public {
        vm.expectRevert(IMachineManager.TeeNotFound.selector);
        flareTeeManager.updateTeeMachineSettings(teeId, address(0), "newUrl");
    }

    function testUpdateTeeMachineSettingsRevertInvalidTeeProxyId() public {
        testRegister();
        vm.expectRevert(IMachineManager.InvalidTeeProxyId.selector);
        vm.prank(owner);
        flareTeeManager.updateTeeMachineSettings(teeId, address(0), "newUrl");
    }

    function testUpdateTeeMachineSettingsRevertInvalidUrl() public {
        testRegister();
        vm.expectRevert(IMachineManager.InvalidUrl.selector);
        vm.prank(owner);
        flareTeeManager.updateTeeMachineSettings(teeId, makeAddr("newTeeProxyId"), "");
    }

    function testUpdateTeeMachineSettings() public {
        address newTeeProxyIdLocal = makeAddr("newTeeProxyId");
        string memory newUrl = "newUrl";
        testRegister();
        vm.prank(owner);
        vm.expectEmit();
        emit IMachineManager.TeeMachineSettingsUpdated(teeId, newTeeProxyIdLocal, newUrl);
        vm.recordLogs();
        flareTeeManager.updateTeeMachineSettings(teeId, newTeeProxyIdLocal, newUrl);
        assertEq(vm.getRecordedLogs().length, 1); // no other events emitted
        IMachineManager.TeeMachine memory teeMachine = flareTeeManager.getTeeMachine(teeId);
        assertEq(teeMachine.teeProxyId, newTeeProxyIdLocal);
        assertEq(keccak256(bytes(teeMachine.url)), keccak256(bytes(newUrl)));
        IMachineManager.TeeStatus status = flareTeeManager.getTeeMachineStatus(teeId);
        assert(status == IMachineManager.TeeStatus.INITIALIZED);
    }

    function testUpdateTeeMachineSettingsAndPause() public {
        address newTeeProxyIdLocal = makeAddr("newTeeProxyId");
        string memory newUrl = "newUrl";
        testToProduction();
        vm.prank(owner);
        vm.expectEmit();
        emit IMachineManager.TeeMachineStatusChanged(teeId, IMachineManager.TeeStatus.PAUSED);
        vm.expectEmit();
        emit IMachineManager.TeeMachineSettingsUpdated(teeId, newTeeProxyIdLocal, newUrl);
        flareTeeManager.updateTeeMachineSettings(teeId, newTeeProxyIdLocal, newUrl);
        IMachineManager.TeeMachine memory teeMachine = flareTeeManager.getTeeMachine(teeId);
        assertEq(teeMachine.teeProxyId, newTeeProxyIdLocal);
        assertEq(keccak256(bytes(teeMachine.url)), keccak256(bytes(newUrl)));
        IMachineManager.TeeStatus status = flareTeeManager.getTeeMachineStatus(teeId);
        assert(status == IMachineManager.TeeStatus.PAUSED);
    }

    function testUpdateTeeMachineSettingsAndPause2() public {
        address newTeeProxyIdLocal = makeAddr("newTeeProxyId");
        string memory newUrl = "newUrl";
        testPauseWithProof();
        vm.prank(owner);
        vm.expectEmit();
        emit IMachineManager.TeeMachineStatusChanged(teeId, IMachineManager.TeeStatus.PAUSED);
        vm.expectEmit();
        emit IMachineManager.TeeMachineSettingsUpdated(teeId, newTeeProxyIdLocal, newUrl);
        flareTeeManager.updateTeeMachineSettings(teeId, newTeeProxyIdLocal, newUrl);
        IMachineManager.TeeMachine memory teeMachine = flareTeeManager.getTeeMachine(teeId);
        assertEq(teeMachine.teeProxyId, newTeeProxyIdLocal);
        assertEq(keccak256(bytes(teeMachine.url)), keccak256(bytes(newUrl)));
        IMachineManager.TeeStatus status = flareTeeManager.getTeeMachineStatus(teeId);
        assert(status == IMachineManager.TeeStatus.PAUSED);
    }

    // =========================================================================
    // getTeeMachineStatus
    // =========================================================================

    function testGetTeeMachineStatusRevertTeeNotFound() public {
        vm.expectRevert(IMachineManager.TeeNotFound.selector);
        flareTeeManager.getTeeMachineStatus(teeId);
    }

    function testGetTeeMachineStatus() public {
        testRegister();
        assertTrue(flareTeeManager.getTeeMachineStatus(teeId) == IMachineManager.TeeStatus.INITIALIZED);
        _changeStateToProduction();
        assertTrue(flareTeeManager.getTeeMachineStatus(teeId) == IMachineManager.TeeStatus.PRODUCTION);
    }

    // =========================================================================
    // getTeeMachineOwner
    // =========================================================================

    function testGetTeeMachineOwnerRevertTeeNotFound() public {
        vm.expectRevert(IMachineManager.TeeNotFound.selector);
        flareTeeManager.getTeeMachineOwner(teeId);
    }

    function testGetTeeMachineOwner() public {
        testRegister();
        assertEq(flareTeeManager.getTeeMachineOwner(teeId), owner);
    }

    // =========================================================================
    // getInitialSigningPolicyId
    // =========================================================================

    function testGetInitialSigningPolicyIdRevertTeeNotFound() public {
        vm.expectRevert(IMachineManager.TeeNotFound.selector);
        flareTeeManager.getInitialSigningPolicyId(teeId);
    }

    function testGetInitialSigningPolicyId() public {
        testRegister();
        assertEq(flareTeeManager.getInitialSigningPolicyId(teeId), 0);
    }

    // =========================================================================
    // getTeeMachine
    // =========================================================================

    function testGetTeeMachineRevertTeeNotFound() public {
        vm.expectRevert(IMachineManager.TeeNotFound.selector);
        flareTeeManager.getTeeMachine(teeId);
    }

    function testGetTeeMachine() public {
        testRegister();
        IMachineManager.TeeMachine memory teeMachine = flareTeeManager.getTeeMachine(teeId);
        assertEq(teeMachine.teeId, teeId);
        assertEq(teeMachine.teeProxyId, teeProxyId);
        assertEq(teeMachine.url, url);
    }

    // =========================================================================
    // getTeeMachineWithAttestationData
    // =========================================================================

    function testGetTeeMachineWithAttestationDataRevertTeeNotFound() public {
        vm.expectRevert(IMachineManager.TeeNotFound.selector);
        flareTeeManager.getTeeMachineWithAttestationData(teeId);
    }

    function testGetTeeMachineWithAttestationData() public {
        testRegister();
        IMachineManager.TeeMachineWithAttestationData memory teeMachineAttData =
            flareTeeManager.getTeeMachineWithAttestationData(teeId);
        assertEq(teeMachineAttData.teeId, teeId);
        assertEq(teeMachineAttData.initialTeeId, teeId);
        assertEq(teeMachineAttData.url, url);
        assertEq(teeMachineAttData.codeHash, codeHash);
        assertEq(teeMachineAttData.platform, platform);
    }

    // =========================================================================
    // getRandomTeeIds
    // =========================================================================

    function testGetRandomTeeIdsRevertTooMany() public {
        vm.expectRevert(IMachineManager.TooMany.selector);
        flareTeeManager.getRandomTeeIds(extensionId, 1);
    }

    function testGetRandomTeeIds() public {
        testToProduction();
        // register and promote newTee to production
        vm.prank(owner);
        flareTeeManager.register(newTeeMachineData, newTeeMachineDataSignature, teeProxyId, url, address(0));
        registerTimestamps[newTeeId] = block.timestamp;
        _changeStateToProductionForTee(newTeeId, teeProxyId, url);

        address[] memory teeIds = flareTeeManager.getRandomTeeIds(extensionId, 1);
        assertEq(teeIds.length, 1);
        assertTrue(teeIds[0] == teeId || teeIds[0] == newTeeId);
    }

    // =========================================================================
    // getAllActiveTeeMachines
    // =========================================================================

    function testGetAllActiveTeeMachines() public {
        (address[] memory teeIds, string[] memory urls, uint256 totalLength) =
            flareTeeManager.getAllActiveTeeMachines(0, 10);
        assertEq(teeIds.length, 0);
        assertEq(urls.length, 0);
        assertEq(totalLength, 0);

        testToProduction();
        (teeIds, urls, totalLength) = flareTeeManager.getAllActiveTeeMachines(0, 10);
        assertEq(teeIds.length, 1);
        assertEq(urls.length, 1);
        assertEq(teeIds[0], teeId);
        assertEq(urls[0], url);
        assertEq(totalLength, 1);
    }

    // =========================================================================
    // getActiveTeeMachines
    // =========================================================================

    function testGetActiveTeeMachines() public {
        (address[] memory teeIds, string[] memory urls) = flareTeeManager.getActiveTeeMachines(extensionId);
        assertEq(teeIds.length, 0);
        assertEq(urls.length, 0);

        testToProduction();
        (teeIds, urls) = flareTeeManager.getActiveTeeMachines(extensionId);
        assertEq(teeIds.length, 1);
        assertEq(urls.length, 1);
        assertEq(teeIds[0], teeId);
        assertEq(urls[0], url);
    }

    // =========================================================================
    // getExtensionId
    // =========================================================================

    function testGetExtensionIdRevertTeeNotFound() public {
        vm.expectRevert(IMachineManager.TeeNotFound.selector);
        flareTeeManager.getExtensionId(teeId);
    }

    function testGetExtensionId() public {
        testRegister();
        assertEq(flareTeeManager.getExtensionId(teeId), extensionId);
    }

    // =========================================================================
    // getLastStatusChangeTs
    // =========================================================================

    function testGetLastStatusChangeTsRevertTeeNotFound() public {
        vm.expectRevert(IMachineManager.TeeNotFound.selector);
        flareTeeManager.getLastStatusChangeTs(teeId);
    }

    function testGetLastStatusChangeTs() public {
        testRegister();
        assertEq(flareTeeManager.getLastStatusChangeTs(teeId), block.timestamp);
    }

    // =========================================================================
    // Internal helpers
    // =========================================================================

    function _changeStateToProduction() private {
        _changeStateToProductionForTee(teeId, teeProxyId, url);
    }

    function _changeStateToProductionForTee(
        address _teeId,
        address _teeProxyId,
        string memory _url
    ) private {
        ITeeAvailabilityCheck.Proof memory proof = _createValidAvailabilityCheckProof(_teeId, _teeProxyId, _url);
        vm.warp(block.timestamp + 1);
        vm.prank(owner);
        vm.expectEmit();
        emit IMachineManager.TeeMachineStatusChanged(_teeId, IMachineManager.TeeStatus.PRODUCTION);
        flareTeeManager.toProduction(proof);
    }

    /**
     * Creates a valid availability check proof that will pass verification in the diamond.
     * This involves:
     * - Correct header with attestation type and source id
     * - Correct request body matching the challenge and machine data
     * - Correct response body with valid system state and code hash
     * - Cosigner signatures (for INITIALIZED status)
     * - Mock for fdc2Verification.recoverCosigners
     */
    function _createValidAvailabilityCheckProof(
        address _teeId,
        address _teeProxyId,
        string memory _url
    )
        private
        returns (ITeeAvailabilityCheck.Proof memory)
    {
        // The challenge was set during register: keccak256(abi.encode(teeId, registerTimestamp, randomNumber))
        // We use the stored register timestamp since lastStatusChangeTs may have been updated by toProduction.
        uint256 registerTs = registerTimestamps[_teeId];
        bytes32 challenge = keccak256(abi.encode(_teeId, registerTs, randomNumber));

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
            challenge,
            keccak256(abi.encode(extensionId))
        );

        ISystemStateVerifier.TeeSystemState memory systemState = ISystemStateVerifier.TeeSystemState(
            ISystemStateVerifier.TeeMachineStatus.ACTIVE,
            _teeId,
            governanceHash
        );

        ITeeAvailabilityCheck.ResponseBody memory respBody = ITeeAvailabilityCheck.ResponseBody(
            ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            uint64(block.timestamp),
            codeHash,
            platform,
            1,  // initialSigningPolicyId
            1,  // lastSigningPolicyId
            ITeeAvailabilityCheck.TeeState(abi.encode(systemState), bytes32("v1"), new bytes(0), bytes32(0))
        );

        bytes32 messageHash = keccak256(abi.encode(
            keccak256(abi.encode(header)),
            keccak256(abi.encode(reqBody)),
            keccak256(abi.encode(respBody))
        ));
        bytes32 cosignersMessageHash = keccak256(bytes.concat(hex"010000000000", messageHash));

        // Create cosigner signatures
        IFdc2Verification.Fdc2Signatures memory sigs;
        sigs.cosignerSignatures = new Signature[](cosignersThreshold);
        for (uint256 i = 0; i < cosignersThreshold; i++) {
            sigs.cosignerSignatures[i] =
                SignatureHelper.createSignature(vm, cosignersMessageHash, cosigners[i].privateKey);
        }

        // Mock fdc2Verification to return cosigner addresses for signature verification
        address[] memory cosignerAddresses = new address[](cosignersThreshold);
        for (uint256 i = 0; i < cosignersThreshold; i++) {
            cosignerAddresses[i] = cosigners[i].addr;
        }
        vm.mockCall(
            fdc2Verification,
            abi.encodeWithSelector(IFdc2Verification.recoverCosigners.selector),
            abi.encode(cosignerAddresses)
        );

        // Mock fdc2Verification.verifySigningPolicySignatures (not used when cosigners present, but mock anyway)
        vm.mockCall(
            fdc2Verification,
            abi.encodeWithSelector(IFdc2Verification.verifySigningPolicySignatures.selector),
            abi.encode(1)
        );

        return ITeeAvailabilityCheck.Proof(
            sigs,
            header,
            reqBody,
            respBody
        );
    }

    function _getSignersAddresses(Signer[] memory _signers) private pure returns (address[] memory) {
        address[] memory addrs = new address[](_signers.length);
        for (uint256 i = 0; i < _signers.length; i++) {
            addrs[i] = _signers[i].addr;
        }
        return addrs;
    }
}
