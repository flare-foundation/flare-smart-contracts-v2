// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test, Vm } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IExtensionPausing } from "../../../../contracts/userInterfaces/tee/IExtensionPausing.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { Signature } from "../../../../contracts/userInterfaces/ISignature.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ExtensionPausingFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;

    address private realOwnerExtension1;
    address private realOwnerExtension2;

    address private initialGovernance;
    address private addressUpdater;

    uint256 private extensionId;
    uint256 private extensionId2;

    address[] private pausingAddresses;
    address[] private signers;
    uint256[] private privateKeys;

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
            defaultFee: 1000,
            publicExtensionCreationEnabled: true
        }));
        vm.startPrank(initialGovernance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();

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

        address instructionsSender1 = makeAddr("instructionsSender1");
        address instructionsSender2 = makeAddr("instructionsSender2");
        ITeeExtensionStateVerifier verifier = ITeeExtensionStateVerifier(address(0));

        vm.prank(realOwnerExtension1);
        extensionId = flareTeeManager.register(verifier, instructionsSender1);

        vm.prank(realOwnerExtension2);
        extensionId2 = flareTeeManager.register(verifier, instructionsSender2);

        signers = new address[](2);
        privateKeys = new uint256[](2);
        (signers[0], privateKeys[0]) = makeAddrAndKey("signer1");
        (signers[1], privateKeys[1]) = makeAddrAndKey("signer2");

        pausingAddresses = new address[](2);
        pausingAddresses[0] = makeAddr("pausingAddresses1");
        pausingAddresses[1] = makeAddr("pausingAddresses2");
    }

    // =========================================================================
    // setTeePausingAddresses
    // =========================================================================

    function testSetTeePausingAddressesRevertOnlyExtensionOwner() public {
        bytes32[] memory hashes = _setGovernanceAndReturnHash(extensionId, signers, 1);
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.setTeePausingAddresses(extensionId, hashes, pausingAddresses);
    }

    function testSetTeePausingAddressesRevertNoGovernanceHashes() public {
        vm.prank(realOwnerExtension1);
        vm.expectRevert(IExtensionPausing.NoGovernanceHashes.selector);
        flareTeeManager.setTeePausingAddresses(extensionId, new bytes32[](0), pausingAddresses);
    }

    function testSetTeePausingAddressesRevertInvalidGovernanceHashUnknown() public {
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("not a real hash");
        vm.prank(realOwnerExtension1);
        vm.expectRevert(ITeeCommonErrors.InvalidGovernanceHash.selector);
        flareTeeManager.setTeePausingAddresses(extensionId, hashes, pausingAddresses);
    }

    function testSetTeePausingAddressesRevertInvalidGovernanceHashZero() public {
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = bytes32(0);
        vm.prank(realOwnerExtension1);
        vm.expectRevert(ITeeCommonErrors.InvalidGovernanceHash.selector);
        flareTeeManager.setTeePausingAddresses(extensionId, hashes, pausingAddresses);
    }

    function testSetTeePausingAddressesRevertDuplicateGovernanceHash() public {
        bytes32[] memory hashes = _setGovernanceAndReturnHash(extensionId, signers, 1);
        bytes32[] memory duped = new bytes32[](2);
        duped[0] = hashes[0];
        duped[1] = hashes[0];
        vm.prank(realOwnerExtension1);
        vm.expectRevert(IExtensionPausing.DuplicateGovernanceHash.selector);
        flareTeeManager.setTeePausingAddresses(extensionId, duped, pausingAddresses);
    }

    function testSetTeePausingAddressesRevertPausingAddressAlreadyExists() public {
        bytes32[] memory hashes = _setGovernanceAndReturnHash(extensionId, signers, 1);
        pausingAddresses[1] = pausingAddresses[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                IExtensionPausing.PausingAddressAlreadyExists.selector,
                pausingAddresses[0]
            )
        );
        vm.prank(realOwnerExtension1);
        flareTeeManager.setTeePausingAddresses(extensionId, hashes, pausingAddresses);
    }

    function testSetTeePausingAddresses() public {
        bytes32[] memory hashes = _setGovernanceAndReturnHash(extensionId, signers, 1);
        address[] memory emptyPausingAddresses = new address[](0);

        vm.startPrank(realOwnerExtension1);
        // empty
        vm.expectEmit();
        emit IExtensionPausing.NewPausingAddressesSet(extensionId, 0, hashes, emptyPausingAddresses);
        flareTeeManager.setTeePausingAddresses(extensionId, hashes, emptyPausingAddresses);

        // new list
        vm.expectEmit();
        emit IExtensionPausing.NewPausingAddressesSet(extensionId, 1, hashes, pausingAddresses);
        flareTeeManager.setTeePausingAddresses(extensionId, hashes, pausingAddresses);

        vm.stopPrank();
    }

    // =========================================================================
    // signTeePausingAddresses
    // =========================================================================

    function testSignTeePausingAddressesRevertInvalidNonce() public {
        // no record at nonce 0
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("unused");
        Signature memory signature = _signRecord(extensionId, 0, hashes, pausingAddresses, privateKeys[0]);
        vm.expectRevert(ITeeCommonErrors.InvalidNonce.selector);
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);
    }

    function testSignTeePausingAddressesRevertNotASigner() public {
        bytes32[] memory hashes = _setGovernanceAndReturnHash(extensionId, signers, 1);
        vm.prank(realOwnerExtension1);
        flareTeeManager.setTeePausingAddresses(extensionId, hashes, pausingAddresses);

        // sign with a key that's not in the governance signer set
        uint256 outsiderKey;
        (, outsiderKey) = makeAddrAndKey("outsider");
        Signature memory signature = _signRecord(extensionId, 0, hashes, pausingAddresses, outsiderKey);

        address outsider;
        (outsider, ) = makeAddrAndKey("outsider");
        vm.expectRevert(
            abi.encodeWithSelector(IExtensionPausing.NotASigner.selector, outsider)
        );
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);
    }

    function testSignTeePausingAddressesAlreadySigned() public {
        bytes32[] memory hashes = _setGovernanceAndReturnHash(extensionId, signers, 1);
        vm.prank(realOwnerExtension1);
        flareTeeManager.setTeePausingAddresses(extensionId, hashes, pausingAddresses);

        Signature memory signature = _signRecord(extensionId, 0, hashes, pausingAddresses, privateKeys[0]);
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);
        vm.expectRevert(
            abi.encodeWithSelector(IExtensionPausing.AlreadySigned.selector, signers[0])
        );
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);
    }

    function testSignTeePausingAddresses() public {
        bytes32[] memory hashes = _setGovernanceAndReturnHash(extensionId, signers, 1);
        vm.prank(realOwnerExtension1);
        flareTeeManager.setTeePausingAddresses(extensionId, hashes, pausingAddresses);

        Signature memory signature = _signRecord(extensionId, 0, hashes, pausingAddresses, privateKeys[0]);
        vm.expectEmit();
        emit IExtensionPausing.NewPausingAddressesSigned(extensionId, 0, hashes[0], signers[0], signature);
        vm.expectEmit();
        emit IExtensionPausing.TeePausingAddressesThresholdMet(extensionId, 0, hashes[0]);
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);
    }

    function testSignTeePausingAddressesAcrossMultipleHashesDepositsIntoEveryMatchingApproval() public {
        // Two governance configs share signers[0]. signers[0] signs once; the signature should
        // be deposited into BOTH approval buckets.
        address[] memory signersAlt = new address[](2);
        signersAlt[0] = signers[0]; // shared signer
        signersAlt[1] = makeAddr("otherSigner");

        bytes32 hashA;
        bytes32 hashB;
        vm.startPrank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 2);
        hashA = flareTeeManager.getLatestTeeGovernanceHash(extensionId);
        flareTeeManager.setNewTeeGovernance(extensionId, signersAlt, 2);
        hashB = flareTeeManager.getLatestTeeGovernanceHash(extensionId);

        bytes32[] memory hashes = new bytes32[](2);
        hashes[0] = hashA;
        hashes[1] = hashB;

        flareTeeManager.setTeePausingAddresses(extensionId, hashes, pausingAddresses);
        vm.stopPrank();

        Signature memory signature = _signRecord(extensionId, 0, hashes, pausingAddresses, privateKeys[0]);
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);

        assertTrue(flareTeeManager.hasSignedTeePausingAddresses(extensionId, 0, hashA, signers[0]));
        assertTrue(flareTeeManager.hasSignedTeePausingAddresses(extensionId, 0, hashB, signers[0]));

        // Storage is deduplicated (one push to record.signatures) but the view redistributes
        // the signature into BOTH per-approval buckets via ECDSA recovery + hasSigned lookup.
        (, , Signature[][] memory sigsPerHash, ) = flareTeeManager.getTeePausingAddresses(extensionId, 0);
        assertEq(sigsPerHash.length, 2);
        assertEq(sigsPerHash[0].length, 1, "hashA bucket has the signature");
        assertEq(sigsPerHash[1].length, 1, "hashB bucket has the signature");
        assertTrue(_areSignaturesEq(sigsPerHash[0][0], signature));
        assertTrue(_areSignaturesEq(sigsPerHash[1][0], signature));
    }

    function testSignTeePausingAddressesRotatedSignerStillSigns() public {
        // Pin record under hash X (signers); rotate governance to hash Y (different signers);
        // signer[0] from hash X can still sign the record since hash X is pinned forever.
        bytes32[] memory hashes = _setGovernanceAndReturnHash(extensionId, signers, 1);
        vm.prank(realOwnerExtension1);
        flareTeeManager.setTeePausingAddresses(extensionId, hashes, pausingAddresses);

        // Rotate governance to a new config that excludes signers[0]
        address[] memory newSigners = new address[](1);
        newSigners[0] = makeAddr("newSigner");
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, newSigners, 1);

        // signers[0] should still successfully sign the pinned record
        Signature memory signature = _signRecord(extensionId, 0, hashes, pausingAddresses, privateKeys[0]);
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);
        assertTrue(flareTeeManager.hasSignedTeePausingAddresses(extensionId, 0, hashes[0], signers[0]));
    }

    function testSignTeePausingAddressesThresholdMetEmittedOncePerApproval() public {
        // Threshold = 2. First signature: no event. Second signature: event fires. Third
        // signature: NO event (already met).
        bytes32[] memory hashes = _setGovernanceAndReturnHash(extensionId, signers, 2);
        // Need a third signer in the same governance to exercise post-met collection.
        address[] memory threeSigners = new address[](3);
        uint256[] memory threeKeys = new uint256[](3);
        (threeSigners[0], threeKeys[0]) = (signers[0], privateKeys[0]);
        (threeSigners[1], threeKeys[1]) = (signers[1], privateKeys[1]);
        (threeSigners[2], threeKeys[2]) = makeAddrAndKey("signer3");
        vm.startPrank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, threeSigners, 2);
        bytes32 latestHash = flareTeeManager.getLatestTeeGovernanceHash(extensionId);
        hashes = new bytes32[](1);
        hashes[0] = latestHash;
        flareTeeManager.setTeePausingAddresses(extensionId, hashes, pausingAddresses);
        vm.stopPrank();

        // First sig: no threshold event yet
        Signature memory sig1 = _signRecord(extensionId, 0, hashes, pausingAddresses, threeKeys[0]);
        flareTeeManager.signTeePausingAddresses(extensionId, 0, sig1);

        // Second sig: threshold event fires
        Signature memory sig2 = _signRecord(extensionId, 0, hashes, pausingAddresses, threeKeys[1]);
        vm.expectEmit();
        emit IExtensionPausing.TeePausingAddressesThresholdMet(extensionId, 0, latestHash);
        flareTeeManager.signTeePausingAddresses(extensionId, 0, sig2);

        // Third sig: no further threshold event (already met). vm.recordLogs to verify only
        // the Signed event fires.
        vm.recordLogs();
        Signature memory sig3 = _signRecord(extensionId, 0, hashes, pausingAddresses, threeKeys[2]);
        flareTeeManager.signTeePausingAddresses(extensionId, 0, sig3);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 thresholdMetTopic = IExtensionPausing.TeePausingAddressesThresholdMet.selector;
        for (uint256 i = 0; i < logs.length; i++) {
            assertFalse(logs[i].topics[0] == thresholdMetTopic, "threshold event re-emitted");
        }
    }

    function testReplaySafetyDifferentExtensionRejected() public {
        // Set up the same governance config + pausing-addresses record on both extensions, with
        // the same nonce (0). The signed messageHash differs because extensionId is in the
        // preimage. A signature collected on extension 1 should NOT validate on extension 2.

        // Use a governance where signers[0] is valid on both extensions.
        bytes32[] memory hashes1;
        bytes32[] memory hashes2;
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);
        hashes1 = new bytes32[](1);
        hashes1[0] = flareTeeManager.getLatestTeeGovernanceHash(extensionId);

        vm.prank(realOwnerExtension2);
        flareTeeManager.setNewTeeGovernance(extensionId2, signers, 1);
        hashes2 = new bytes32[](1);
        hashes2[0] = flareTeeManager.getLatestTeeGovernanceHash(extensionId2);

        // Same governance hash content → same hash (since hashes are content-derived).
        assertEq(hashes1[0], hashes2[0]);

        vm.prank(realOwnerExtension1);
        flareTeeManager.setTeePausingAddresses(extensionId, hashes1, pausingAddresses);
        vm.prank(realOwnerExtension2);
        flareTeeManager.setTeePausingAddresses(extensionId2, hashes2, pausingAddresses);

        // Sign for extension 1
        Signature memory sigForExt1 =
            _signRecord(extensionId, 0, hashes1, pausingAddresses, privateKeys[0]);

        // Replay against extension 2 — should fail. The recovered signer differs from signers[0]
        // because the preimage differs; the test asserts the function reverts, not the specific
        // recovered address.
        vm.expectRevert();
        flareTeeManager.signTeePausingAddresses(extensionId2, 0, sigForExt1);
    }

    // =========================================================================
    // getTeePausingAddresses
    // =========================================================================

    function testGetTeePausingAddressesRevertInvalidNonce() public {
        vm.expectRevert(ITeeCommonErrors.InvalidNonce.selector);
        flareTeeManager.getTeePausingAddresses(extensionId, 5);
    }

    function testGetTeePausingAddresses() public {
        bytes32[] memory hashes = _setGovernanceAndReturnHash(extensionId, signers, 1);
        vm.prank(realOwnerExtension1);
        flareTeeManager.setTeePausingAddresses(extensionId, hashes, pausingAddresses);

        (
            address[] memory returnedPausingAddresses,
            bytes32[] memory returnedHashes,
            Signature[][] memory returnedSigsPerHash,
            bool[] memory returnedThresholdMet
        ) = flareTeeManager.getTeePausingAddresses(extensionId, 0);
        assertEq(returnedPausingAddresses[0], pausingAddresses[0]);
        assertEq(returnedPausingAddresses[1], pausingAddresses[1]);
        assertEq(returnedHashes.length, 1);
        assertEq(returnedHashes[0], hashes[0]);
        assertEq(returnedSigsPerHash.length, 1);
        assertEq(returnedSigsPerHash[0].length, 0);
        assertEq(returnedThresholdMet.length, 1);
        assertFalse(returnedThresholdMet[0]);

        // signers[0] signs (threshold=1 → flips immediately)
        Signature memory signature = _signRecord(extensionId, 0, hashes, pausingAddresses, privateKeys[0]);
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);

        (returnedPausingAddresses, returnedHashes, returnedSigsPerHash, returnedThresholdMet) =
            flareTeeManager.getTeePausingAddresses(extensionId, 0);
        assertEq(returnedSigsPerHash[0].length, 1);
        assertTrue(returnedThresholdMet[0]);
    }

    // =========================================================================
    // getLatestTeePausingAddresses
    // =========================================================================

    function testGetLatestTeePausingAddressesRevertPausingAddressesNotSet() public {
        vm.expectRevert(IExtensionPausing.PausingAddressesNotSet.selector);
        flareTeeManager.getLatestTeePausingAddresses(extensionId);
    }

    function testGetLatestTeePausingAddresses() public {
        bytes32[] memory hashes = _setGovernanceAndReturnHash(extensionId, signers, 1);
        vm.prank(realOwnerExtension1);
        flareTeeManager.setTeePausingAddresses(extensionId, hashes, pausingAddresses);

        (
            uint256 returnedNonce,
            address[] memory returnedPausingAddresses,
            bytes32[] memory returnedHashes,
            Signature[][] memory returnedSigsPerHash,
            bool[] memory returnedThresholdMet
        ) = flareTeeManager.getLatestTeePausingAddresses(extensionId);

        assertEq(returnedNonce, 0);
        assertEq(returnedPausingAddresses[0], pausingAddresses[0]);
        assertEq(returnedPausingAddresses[1], pausingAddresses[1]);
        assertEq(returnedHashes[0], hashes[0]);
        assertEq(returnedSigsPerHash[0].length, 0);
        assertFalse(returnedThresholdMet[0]);

        Signature memory signature = _signRecord(extensionId, 0, hashes, pausingAddresses, privateKeys[0]);
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);

        (returnedNonce, returnedPausingAddresses, returnedHashes, returnedSigsPerHash, returnedThresholdMet) =
            flareTeeManager.getLatestTeePausingAddresses(extensionId);
        assertEq(returnedNonce, 0);
        assertEq(returnedSigsPerHash[0].length, 1);
        assertTrue(returnedThresholdMet[0]);
        assertTrue(_areSignaturesEq(returnedSigsPerHash[0][0], signature));
    }

    // =========================================================================
    // hasSignedTeePausingAddresses
    // =========================================================================

    function testHasSignedTeePausingAddressesRevertInvalidNonce() public {
        vm.expectRevert(ITeeCommonErrors.InvalidNonce.selector);
        flareTeeManager.hasSignedTeePausingAddresses(extensionId, 0, bytes32(0), realOwnerExtension1);
    }

    function testHasSignedTeePausingAddresses() public {
        bytes32[] memory hashes = _setGovernanceAndReturnHash(extensionId, signers, 1);
        vm.prank(realOwnerExtension1);
        flareTeeManager.setTeePausingAddresses(extensionId, hashes, pausingAddresses);

        Signature memory signature = _signRecord(extensionId, 0, hashes, pausingAddresses, privateKeys[0]);
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);

        assertTrue(flareTeeManager.hasSignedTeePausingAddresses(extensionId, 0, hashes[0], signers[0]));
        assertFalse(flareTeeManager.hasSignedTeePausingAddresses(extensionId, 0, hashes[0], signers[1]));
        // Querying an unrelated hash returns false.
        assertFalse(flareTeeManager.hasSignedTeePausingAddresses(extensionId, 0, bytes32(0), signers[0]));
    }

    // =========================================================================
    // helpers
    // =========================================================================

    function _setGovernanceAndReturnHash(
        uint256 _extensionId,
        address[] memory _governanceSigners,
        uint64 _threshold
    )
        private
        returns (bytes32[] memory _hashes)
    {
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(_extensionId, _governanceSigners, _threshold);
        _hashes = new bytes32[](1);
        _hashes[0] = flareTeeManager.getLatestTeeGovernanceHash(_extensionId);
    }

    function _signRecord(
        uint256 _extensionId,
        uint256 _nonce,
        bytes32[] memory _governanceHashes,
        address[] memory _pausingAddresses,
        uint256 _privateKey
    )
        private view
        returns (Signature memory)
    {
        bytes32 messageHash = keccak256(abi.encode(
            "TEE_PAUSING_ADDRESSES",
            block.chainid,
            _extensionId,
            _nonce,
            _governanceHashes,
            _pausingAddresses
        ));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, signedMessageHash);
        return Signature(v, r, s);
    }

    function _areSignaturesEq(
        Signature memory _sig1,
        Signature memory _sig2
    )
        private pure
        returns (bool)
    {
        return _sig1.v == _sig2.v && _sig1.r == _sig2.r && _sig1.s == _sig2.s;
    }
}
