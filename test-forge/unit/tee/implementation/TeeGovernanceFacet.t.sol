// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { ITeeGovernanceFacet } from "../../../../contracts/userInterfaces/tee/ITeeGovernanceFacet.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { IFlareGovernance } from "../../../../contracts/userInterfaces/tee/IFlareGovernance.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { SignatureHelper } from "../../../utils/SignatureHelper.sol";
import { Signature } from "../../../../contracts/userInterfaces/ISignature.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract TeeGovernanceFacetTest is Test {

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

        flareTeeManager = FlareTeeManagerDeployer.deploy(FlareTeeManagerDeployer.DeployParams({
            governanceSettings: IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 6,
            challengeValidityDurationSeconds: 600,
            defaultFee: 1000,
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));

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

        // Register extensions via the diamond
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


    // setNewTeeGovernance
    function testSetNewTeeGovernanceRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.setNewTeeGovernance(
            extensionId,
            signers,
            1
        );
    }


    function testSetNewTeeGovernanceRevertNoSigners() public {
        vm.prank(realOwnerExtension1);
        vm.expectRevert(ITeeGovernanceFacet.NoSigners.selector);
        flareTeeManager.setNewTeeGovernance(extensionId, new address[](0), 1);
    }


    function testSetNewTeeGovernanceRevertInvalidThreshold() public {
        vm.startPrank(realOwnerExtension1);
        vm.expectRevert(ITeeCommonErrors.InvalidThreshold.selector);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 0);
        vm.expectRevert(ITeeCommonErrors.InvalidThreshold.selector);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 3);
        vm.stopPrank();
    }


    function testSetNewTeeGovernanceRevertSignerAlreadyExists() public {
        signers[1] = signers[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeGovernanceFacet.SignerAlreadyExists.selector,
                signers[0]
            )
        );
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);
    }


    function testSetNewTeeGovernance() public {
        bytes32 governanceHash1 = keccak256(abi.encode(signers, 1));
        vm.startPrank(realOwnerExtension1);
        vm.expectEmit();
        emit ITeeGovernanceFacet.NewTeeGovernanceSet(extensionId, governanceHash1, signers, 1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);

        bytes32 governanceHash2 = keccak256(abi.encode(signers, 2));
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 2);
        assertEq(flareTeeManager.getLatestTeeGovernanceHash(extensionId), governanceHash2);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);
        assertEq(flareTeeManager.getLatestTeeGovernanceHash(extensionId), governanceHash1);
        vm.stopPrank();
    }


    // setTeePausingAddresses
    function testSetTeePausingAddressesRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.setTeePausingAddresses(extensionId, pausingAddresses);
    }


    function testSetTeePausingAddressesRevertPausingAddressAlreadyExists() public {
        pausingAddresses[1] = pausingAddresses[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeGovernanceFacet.PausingAddressAlreadyExists.selector,
                pausingAddresses[0]
            )
        );
        vm.prank(realOwnerExtension1);
        flareTeeManager.setTeePausingAddresses(extensionId, pausingAddresses);
    }


    function testSetTeePausingAddresses() public {
        address[] memory emptyPausingAddresses = new address[](0);

        vm.startPrank(realOwnerExtension1);
        // empty
        vm.expectEmit();
        emit ITeeGovernanceFacet.NewPausingAddressesSet(extensionId, 0, emptyPausingAddresses);
        flareTeeManager.setTeePausingAddresses(extensionId, emptyPausingAddresses);

        // new list
        vm.expectEmit();
        emit ITeeGovernanceFacet.NewPausingAddressesSet(extensionId, 1, pausingAddresses);
        flareTeeManager.setTeePausingAddresses(extensionId, pausingAddresses);

        vm.stopPrank();
    }


    // signTeePausingAddresses
    function testSignTeePausingAddressesRevertInvalidNonce() public {
        Signature memory signature = _getSignature(0, signers, privateKeys[0]);
        vm.expectRevert(ITeeCommonErrors.InvalidNonce.selector);
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);
    }


    function testSignTeePausingAddressesRevertNotASigner() public {
        vm.prank(realOwnerExtension1);
        flareTeeManager.setTeePausingAddresses(extensionId, pausingAddresses);

        Signature memory signature = _getSignature(0, pausingAddresses, privateKeys[0]);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeGovernanceFacet.NotASigner.selector,
                signers[0]
            )
        );
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);
    }


    function testSignTeePausingAddressesAlreadySigned() public {
        Signature memory signature = _getSignature(0, pausingAddresses, privateKeys[0]);
        vm.startPrank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);
        flareTeeManager.setTeePausingAddresses(extensionId, pausingAddresses);
        vm.stopPrank();

        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeGovernanceFacet.AlreadySigned.selector,
                signers[0]
            )
        );
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);
    }


    function testSignTeePausingAddresses() public {
        Signature memory signature = _getSignature(0, pausingAddresses, privateKeys[0]);

        vm.startPrank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);
        flareTeeManager.setTeePausingAddresses(extensionId, pausingAddresses);
        vm.stopPrank();

        vm.expectEmit();
        emit ITeeGovernanceFacet.NewPausingAddressesSigned(extensionId, 0, signers[0], signature);
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);
    }


    // getLatestTeeGovernanceHash
    function testGetLatestTeeGovernanceHash() public {
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);

        bytes32 governanceHash = keccak256(abi.encode(signers, 1));
        assertEq(flareTeeManager.getLatestTeeGovernanceHash(extensionId), governanceHash);
    }


    // getTeeGovernanceThreshold
    function testGetTeeGovernanceThreshold() public {
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);

        uint64 returnedThreshold =
            flareTeeManager.getTeeGovernanceThreshold(
                extensionId, flareTeeManager.getLatestTeeGovernanceHash(extensionId)
            );
        assertEq(returnedThreshold, 1);
    }


    // isTeeGovernanceSigner
    function testIsTeeGovernanceSigner() public {
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 2);

        bytes32 governanceHash = flareTeeManager.getLatestTeeGovernanceHash(extensionId);
        assertFalse(flareTeeManager.isTeeGovernanceSigner(extensionId, governanceHash, realOwnerExtension1));
        assertTrue(flareTeeManager.isTeeGovernanceSigner(extensionId, governanceHash, signers[0]));
        assertTrue(flareTeeManager.isTeeGovernanceSigner(extensionId, governanceHash, signers[1]));
    }


    // getTeeGovernance
    function testGetTeeGovernanceRevertInvalidGovernanceHash() public {
        vm.expectRevert(ITeeCommonErrors.InvalidGovernanceHash.selector);
        flareTeeManager.getTeeGovernance(extensionId2, bytes32(0));
    }


    function testGetTeeGovernance() public {
        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);

        bytes32 governanceHash = flareTeeManager.getLatestTeeGovernanceHash(extensionId);
        (address[] memory returnedSigners, uint64 returnedThreshold) =
            flareTeeManager.getTeeGovernance(extensionId, governanceHash);

        assertEq(returnedSigners[0], signers[0]);
        assertEq(returnedSigners[1], signers[1]);
        assertEq(returnedThreshold, 1);
    }


    // getLatestTeeGovernance
    function testGetLatestTeeGovernanceRevertGovernanceNotSet() public {
        vm.expectRevert(ITeeGovernanceFacet.GovernanceNotSet.selector);
        flareTeeManager.getLatestTeeGovernance(extensionId);
    }


    function testGetLatestTeeGovernance() public {
        vm.startPrank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 2);
        vm.stopPrank();

        address[] memory returnedSigners;
        uint64 returnedThreshold;
        (returnedSigners, returnedThreshold) = flareTeeManager.getLatestTeeGovernance(extensionId);

        assertEq(returnedSigners[0], signers[0]);
        assertEq(returnedSigners[1], signers[1]);
        assertEq(returnedThreshold, 2);
    }


    // isGovernanceHashValid
    function testIsGovernanceHashValid() public {
        bytes32 governanceHash = keccak256(abi.encode(signers, 1));
        // no governance set
        assertFalse(flareTeeManager.isGovernanceHashValid(extensionId, governanceHash));

        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);

        vm.prank(realOwnerExtension2);
        flareTeeManager.setNewTeeGovernance(extensionId2, signers, 2);

        assertFalse(flareTeeManager.isGovernanceHashValid(extensionId2, governanceHash));
        assertTrue(flareTeeManager.isGovernanceHashValid(extensionId, governanceHash));

        assertFalse(flareTeeManager.isGovernanceHashValid(extensionId, bytes32(0x0)));
        assertTrue(
            flareTeeManager.isGovernanceHashValid(
                extensionId, flareTeeManager.getLatestTeeGovernanceHash(extensionId)
            )
        );
    }


    // getTeePausingAddresses
    function testGetTeePausingAddressesRevertInvalidNonce() public {
        vm.expectRevert(ITeeCommonErrors.InvalidNonce.selector);
        flareTeeManager.getTeePausingAddresses(extensionId, 5);
    }


    function testGetTeePausingAddresses() public {
        vm.prank(realOwnerExtension1);
        flareTeeManager.setTeePausingAddresses(extensionId, pausingAddresses);

        Signature[] memory returnedSignatures;
        address[] memory returnedPausingAddresses;

        (returnedPausingAddresses, returnedSignatures) = flareTeeManager.getTeePausingAddresses(extensionId, 0);
        assertEq(returnedPausingAddresses[0], pausingAddresses[0]);
        assertEq(returnedPausingAddresses[1], pausingAddresses[1]);
        assertEq(returnedSignatures.length, 0);

        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);

        Signature[] memory signatures = new Signature[](2);
        signatures[0] = _getSignature(0, pausingAddresses, privateKeys[0]);
        signatures[1] = _getSignature(0, pausingAddresses, privateKeys[1]);

        flareTeeManager.signTeePausingAddresses(extensionId, 0, signatures[0]);
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signatures[1]);

        (returnedPausingAddresses, returnedSignatures) = flareTeeManager.getTeePausingAddresses(extensionId, 0);
        assertEq(returnedPausingAddresses[0], pausingAddresses[0]);
        assertEq(returnedPausingAddresses[1], pausingAddresses[1]);
        assertEq(returnedSignatures.length, 2);
    }


    // getLatestTeePausingAddresses
    function testGetLatestTeePausingAddressesRevertPausingAddressesNotSet() public {
        vm.expectRevert(ITeeGovernanceFacet.PausingAddressesNotSet.selector);
        flareTeeManager.getLatestTeePausingAddresses(extensionId);
    }


    function testGetLatestTeePausingAddresses() public {
        vm.prank(realOwnerExtension1);
        flareTeeManager.setTeePausingAddresses(extensionId, pausingAddresses);

        uint256 returnedNonce;
        address[] memory returnedPausingAddresses;
        Signature[] memory returnedSignatures;
        (returnedNonce, returnedPausingAddresses, returnedSignatures) =
            flareTeeManager.getLatestTeePausingAddresses(extensionId);

        assertEq(returnedNonce, 0);
        assertEq(returnedPausingAddresses[0], pausingAddresses[0]);
        assertEq(returnedPausingAddresses[1], pausingAddresses[1]);
        assertEq(returnedSignatures.length, 0);

        address[] memory signer = new address[](1);
        uint256 privateKey;
        (signer[0], privateKey) = makeAddrAndKey("signer");

        vm.prank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signer, 1);

        Signature memory signature = _getSignature(0, pausingAddresses, privateKey);
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);

        (returnedNonce, returnedPausingAddresses, returnedSignatures) =
            flareTeeManager.getLatestTeePausingAddresses(extensionId);
        assertEq(returnedNonce, 0);
        assertEq(returnedPausingAddresses[0], pausingAddresses[0]);
        assertEq(returnedPausingAddresses[1], pausingAddresses[1]);
        assertEq(returnedSignatures.length, 1);
        assertTrue(_areSignaturesEq(returnedSignatures[0], signature));

    }


    // isTeePausingAddressesSigner
    function testIsTeePausingAddressesSigner() public {
        assertFalse(flareTeeManager.isTeePausingAddressesSigner(extensionId, realOwnerExtension1));

        vm.startPrank(realOwnerExtension1);
        flareTeeManager.setTeePausingAddresses(extensionId, pausingAddresses);
        assertFalse(flareTeeManager.isTeePausingAddressesSigner(extensionId, realOwnerExtension1));

        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);
        vm.stopPrank();

        assertTrue(flareTeeManager.isTeePausingAddressesSigner(extensionId, signers[0]));
        assertTrue(flareTeeManager.isTeePausingAddressesSigner(extensionId, signers[1]));
    }


    // hasSignedTeePausingAddresses
    function testHasSignedTeePausingAddressesRevertInvalidNonce() public {
        vm.expectRevert(ITeeCommonErrors.InvalidNonce.selector);
        flareTeeManager.hasSignedTeePausingAddresses(extensionId, 0, realOwnerExtension1);
    }


    function testHasSignedTeePausingAddresses() public {
        Signature memory signature = _getSignature(0, pausingAddresses, privateKeys[0]);

        vm.startPrank(realOwnerExtension1);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, 1);
        flareTeeManager.setTeePausingAddresses(extensionId, pausingAddresses);
        vm.stopPrank();

        // signer: signers[0]
        flareTeeManager.signTeePausingAddresses(extensionId, 0, signature);

        assertTrue(flareTeeManager.hasSignedTeePausingAddresses(extensionId, 0, signers[0]));
        assertFalse(flareTeeManager.hasSignedTeePausingAddresses(extensionId, 0, signers[1]));
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


    function _getSignature(
        uint256 _nonce,
        address[] memory _pausingAddresses,
        uint256 _privateKey
    )
        private pure
        returns (Signature memory)
    {
        bytes32 hashOfPausingAddresses = keccak256(abi.encode("TEE_PAUSING_ADDRESSES", _nonce, _pausingAddresses));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(hashOfPausingAddresses);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, signedMessageHash);
        return Signature(v, r, s);
    }
}
