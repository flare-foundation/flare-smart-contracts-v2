// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { TeeGovernance } from "../../../../contracts/tee/implementation/TeeGovernance.sol";
import { TeeGovernanceProxy } from "../../../../contracts/tee/proxy/TeeGovernanceProxy.sol";
import { ITeeGovernance } from "../../../../contracts/userInterfaces/tee/ITeeGovernance.sol";
import { ITeeExtensionRegistry } from "../../../../contracts/userInterfaces/tee/ITeeExtensionRegistry.sol";
import { Signature } from "../../../../contracts/userInterfaces/ISignature.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract TeeGovernanceTest is Test {

    TeeGovernance private teeGovernance;
    TeeGovernance private teeGovernanceImpl;
    TeeGovernanceProxy private teeGovernanceProxy;

    address private realOwnerExtension1;
    address private realOwnerExtension2;

    address private initialGovernance;
    address private addressUpdater;
    address private registryAddress;

    uint256 private extensionId;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address[] private pausingAddresses;
    address[] private signers;
    uint256[] private privateKeys;


    function setUp() public {
        extensionId = 1;
        realOwnerExtension1 = makeAddr("realOwnerExtension1");
        realOwnerExtension2 = makeAddr("realOwnerExtension2");

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("addressUpdater");
        teeGovernanceImpl = new TeeGovernance();

        teeGovernanceProxy = new TeeGovernanceProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            address(teeGovernanceImpl)
        );
        teeGovernance = TeeGovernance(address(teeGovernanceProxy));

        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("TeeExtensionRegistry");

        vm.prank(addressUpdater);
        teeGovernance.updateContractAddresses(contractNameHashes, contractAddresses);

        registryAddress = address(teeGovernance.teeExtensionRegistry());

        vm.mockCall(
            registryAddress,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.getExtensionOwner.selector,
                extensionId
            ),
            abi.encode(realOwnerExtension1)
        );

        vm.mockCall(
            registryAddress,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.getExtensionOwner.selector,
                extensionId + 1
            ),
            abi.encode(realOwnerExtension2)
        );

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
        vm.expectRevert(ITeeGovernance.OnlyExtensionOwner.selector);
        teeGovernance.setNewTeeGovernance(
            extensionId,
            signers,
            1
        );
    }


    function testSetNewTeeGovernanceRevertNoSigners() public {
        vm.prank(realOwnerExtension1);
        vm.expectRevert(ITeeGovernance.NoSigners.selector);
        teeGovernance.setNewTeeGovernance(extensionId, new address[](0), 1);
    }


    function testSetNewTeeGovernanceRevertInvalidThreshold() public {
        vm.startPrank(realOwnerExtension1);
        vm.expectRevert(ITeeGovernance.InvalidThreshold.selector);
        teeGovernance.setNewTeeGovernance(extensionId, signers, 0);
        vm.expectRevert(ITeeGovernance.InvalidThreshold.selector);
        teeGovernance.setNewTeeGovernance(extensionId, signers, 3);
        vm.stopPrank();
    }


    function testSetNewTeeGovernanceRevertSignerAlreadyExists() public {
        signers[1] = signers[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeGovernance.SignerAlreadyExists.selector,
                signers[0]
            )
        );
        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, signers, 1);
    }


    function testSetNewTeeGovernance() public {
        bytes32 governanceHash1 = keccak256(abi.encode(signers, 1));
        vm.startPrank(realOwnerExtension1);
        vm.expectEmit();
        emit ITeeGovernance.NewTeeGovernanceSet(extensionId, governanceHash1, signers, 1);
        teeGovernance.setNewTeeGovernance(extensionId, signers, 1);

        bytes32 governanceHash2 = keccak256(abi.encode(signers, 2));
        teeGovernance.setNewTeeGovernance(extensionId, signers, 2);
        assertEq(teeGovernance.getLatestTeeGovernanceHash(extensionId), governanceHash2);
        teeGovernance.setNewTeeGovernance(extensionId, signers, 1);
        assertEq(teeGovernance.getLatestTeeGovernanceHash(extensionId), governanceHash1);
        vm.stopPrank();
    }


    // setTeePausingAddresses
    function testSetTeePausingAddressesRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeGovernance.OnlyExtensionOwner.selector);
        teeGovernance.setTeePausingAddresses(extensionId, pausingAddresses);
    }


    function testSetTeePausingAddressesRevertPausingAddressAlreadyExists() public {
        pausingAddresses[1] = pausingAddresses[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeGovernance.PausingAddressAlreadyExists.selector,
                pausingAddresses[0]
            )
        );
        vm.prank(realOwnerExtension1);
        teeGovernance.setTeePausingAddresses(extensionId, pausingAddresses);
    }


    function testSetTeePausingAddresses() public {
        address[] memory emptyPausingAddresses = new address[](0);

        vm.startPrank(realOwnerExtension1);
        // empty
        vm.expectEmit();
        emit ITeeGovernance.NewPausingAddressesSet(extensionId, 0, emptyPausingAddresses);
        teeGovernance.setTeePausingAddresses(extensionId, emptyPausingAddresses);

        // new list
        vm.expectEmit();
        emit ITeeGovernance.NewPausingAddressesSet(extensionId, 1, pausingAddresses);
        teeGovernance.setTeePausingAddresses(extensionId, pausingAddresses);

        vm.stopPrank();
    }


    // signTeePausingAddresses
    function testSignTeePausingAddressesRevertInvalidNonce() public {
        Signature memory signature = _getSignature(0, signers, privateKeys[0]);
        vm.expectRevert(ITeeGovernance.InvalidNonce.selector);
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);
    }


    function testSignTeePausingAddressesRevertNotASigner() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setTeePausingAddresses(extensionId, pausingAddresses);

        Signature memory signature = _getSignature(0, pausingAddresses, privateKeys[0]);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeGovernance.NotASigner.selector,
                signers[0]
            )
        );
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);
    }


    function testSignTeePausingAddressesAlreadySigned() public {
        Signature memory signature = _getSignature(0, pausingAddresses, privateKeys[0]);
        vm.startPrank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, signers, 1);
        teeGovernance.setTeePausingAddresses(extensionId, pausingAddresses);
        vm.stopPrank();

        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeGovernance.AlreadySigned.selector,
                signers[0]
            )
        );
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);
    }


    function testSignTeePausingAddresses() public {
        Signature memory signature = _getSignature(0, pausingAddresses, privateKeys[0]);

        vm.startPrank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, signers, 1);
        teeGovernance.setTeePausingAddresses(extensionId, pausingAddresses);
        vm.stopPrank();

        vm.expectEmit();
        emit ITeeGovernance.NewPausingAddressesSigned(extensionId, 0, signers[0], signature);
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);
        vm.stopPrank();
    }


    // getLatestTeeGovernanceHash
    function testGetLatestTeeGovernanceHash() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, signers, 1);

        bytes32 governanceHash = keccak256(abi.encode(signers, 1)); // create governanceHash
        assertEq(teeGovernance.getLatestTeeGovernanceHash(extensionId), governanceHash);
    }


    // getTeeGovernanceThreshold
    function testGetTeeGovernanceThreshold() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, signers, 1);

        uint64 returnedThreshold =
            teeGovernance.getTeeGovernanceThreshold(
                extensionId, teeGovernance.getLatestTeeGovernanceHash(extensionId)
            );
        assertEq(returnedThreshold, 1);
    }


    // isTeeGovernanceSigner
    function testIsTeeGovernanceSigner() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, signers, 2);

        bytes32 governanceHash = teeGovernance.getLatestTeeGovernanceHash(extensionId);
        assertFalse(teeGovernance.isTeeGovernanceSigner(extensionId, governanceHash, realOwnerExtension1));
        assertTrue(teeGovernance.isTeeGovernanceSigner(extensionId, governanceHash, signers[0]));
        assertTrue(teeGovernance.isTeeGovernanceSigner(extensionId, governanceHash, signers[1]));
    }


    // getTeeGovernance
    function testGetTeeGovernanceRevertInvalidGovernanceHash() public {
        vm.expectRevert(ITeeGovernance.InvalidGovernanceHash.selector);
        teeGovernance.getTeeGovernance(extensionId + 1, bytes32(0));
    }


    function testGetTeeGovernance() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, signers, 1);

        bytes32 governanceHash = teeGovernance.getLatestTeeGovernanceHash(extensionId);
        (address[] memory returnedSigners, uint64 returnedThreshold) =
            teeGovernance.getTeeGovernance(extensionId, governanceHash);

        assertEq(returnedSigners[0], signers[0]);
        assertEq(returnedSigners[1], signers[1]);
        assertEq(returnedThreshold, 1);
    }


    // getLatestTeeGovernance
    function testGetLatestTeeGovernanceRevertGovernanceNotSet() public {
        vm.expectRevert(ITeeGovernance.GovernanceNotSet.selector);
        teeGovernance.getLatestTeeGovernance(extensionId);
    }


    function testGetLatestTeeGovernance() public {
        vm.startPrank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, signers, 1);
        teeGovernance.setNewTeeGovernance(extensionId, signers, 2);
        vm.stopPrank();

        address[] memory returnedSigners;
        uint64 returnedThreshold;
        (returnedSigners, returnedThreshold) = teeGovernance.getLatestTeeGovernance(extensionId);

        assertEq(returnedSigners[0],signers[0]);
        assertEq(returnedSigners[1], signers[1]);
        assertEq(returnedThreshold, 2);
    }


    // isGovernanceHashValid
    function testIsGovernanceHashValid() public {
        bytes32 governanceHash = keccak256(abi.encode(signers, 1));
        // no governance set
        assertFalse(teeGovernance.isGovernanceHashValid(extensionId, governanceHash));

        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, signers, 1);

        vm.prank(realOwnerExtension2);
        teeGovernance.setNewTeeGovernance(extensionId + 1, signers, 2);

        assertFalse(teeGovernance.isGovernanceHashValid(extensionId + 1, governanceHash));
        assertTrue(teeGovernance.isGovernanceHashValid(extensionId, governanceHash));

        assertFalse(teeGovernance.isGovernanceHashValid(extensionId, bytes32(0x0)));
        assertTrue(
            teeGovernance.isGovernanceHashValid(
                extensionId, teeGovernance.getLatestTeeGovernanceHash(extensionId)
            )
        );
    }


    // getTeePausingAddresses
    function testGetTeePausingAddressesRevertInvalidNonce() public {
        vm.expectRevert(ITeeGovernance.InvalidNonce.selector);
        teeGovernance.getTeePausingAddresses(extensionId, 5);
    }


    function testGetTeePausingAddresses() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setTeePausingAddresses(extensionId, pausingAddresses);

        Signature[] memory returnedSignatures;
        address[] memory returnedPausingAddresses;

        (returnedPausingAddresses, returnedSignatures) = teeGovernance.getTeePausingAddresses(extensionId, 0);
        assertEq(returnedPausingAddresses[0], pausingAddresses[0]);
        assertEq(returnedPausingAddresses[1], pausingAddresses[1]);
        assertEq(returnedSignatures.length, 0);

        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, signers, 1);

        Signature[] memory signatures = new Signature[](2);
        signatures[0] = _getSignature(0, pausingAddresses, privateKeys[0]);
        signatures[1] = _getSignature(0, pausingAddresses, privateKeys[1]);

        teeGovernance.signTeePausingAddresses(extensionId, 0, signatures[0]);
        teeGovernance.signTeePausingAddresses(extensionId, 0, signatures[1]);

        (returnedPausingAddresses, returnedSignatures) = teeGovernance.getTeePausingAddresses(extensionId, 0);
        assertEq(returnedPausingAddresses[0], pausingAddresses[0]);
        assertEq(returnedPausingAddresses[1], pausingAddresses[1]);
        assertEq(returnedSignatures.length, 2);
    }


    // getLatestTeePausingAddresses
    function testGetLatestTeePausingAddressesRevertPausingAddressesNotSet() public {
        vm.expectRevert(ITeeGovernance.PausingAddressesNotSet.selector);
        teeGovernance.getLatestTeePausingAddresses(extensionId);
    }


    function testGetLatestTeePausingAddresses() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setTeePausingAddresses(extensionId, pausingAddresses);

        uint256 returnedNonce;
        address[] memory returnedPausingAddresses;
        Signature[] memory returnedSignatures;
        (returnedNonce, returnedPausingAddresses, returnedSignatures) =
            teeGovernance.getLatestTeePausingAddresses(extensionId);

        assertEq(returnedNonce, 0);
        assertEq(returnedPausingAddresses[0], pausingAddresses[0]);
        assertEq(returnedPausingAddresses[1], pausingAddresses[1]);
        assertEq(returnedSignatures.length, 0);

        address[] memory signer = new address[](1);
        uint256 privateKey;
        (signer[0], privateKey) = makeAddrAndKey("signer");

        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, signer, 1);

        Signature memory signature = _getSignature(0, pausingAddresses, privateKey);
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);

        (returnedNonce, returnedPausingAddresses, returnedSignatures) =
            teeGovernance.getLatestTeePausingAddresses(extensionId);
        assertEq(returnedNonce, 0);
        assertEq(returnedPausingAddresses[0], pausingAddresses[0]);
        assertEq(returnedPausingAddresses[1], pausingAddresses[1]);
        assertEq(returnedSignatures.length, 1);
        assertTrue(_areSignaturesEq(returnedSignatures[0], signature));

    }


    // isTeePausingAddressesSigner
    function testIsTeePausingAddressesSigner() public {
        assertFalse(teeGovernance.isTeePausingAddressesSigner(extensionId, realOwnerExtension1));

        vm.startPrank(realOwnerExtension1);
        teeGovernance.setTeePausingAddresses(extensionId, pausingAddresses);
        assertFalse(teeGovernance.isTeePausingAddressesSigner(extensionId, realOwnerExtension1));

        teeGovernance.setNewTeeGovernance(extensionId, signers, 1);
        vm.stopPrank();

        assertTrue(teeGovernance.isTeePausingAddressesSigner(extensionId, signers[0]));
        assertTrue(teeGovernance.isTeePausingAddressesSigner(extensionId, signers[1]));
    }


    // hasSignedTeePausingAddresses
    function testHasSignedTeePausingAddressesRevertInvalidNonce() public {
        vm.expectRevert(ITeeGovernance.InvalidNonce.selector);
        teeGovernance.hasSignedTeePausingAddresses(extensionId, 0, realOwnerExtension1);
    }


    function testHasSignedTeePausingAddresses() public {
        Signature memory signature = _getSignature(0, pausingAddresses, privateKeys[0]);

        vm.startPrank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, signers, 1);
        teeGovernance.setTeePausingAddresses(extensionId, pausingAddresses);
        vm.stopPrank();

        // signer: signers[0]
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);

        assertTrue(teeGovernance.hasSignedTeePausingAddresses(extensionId, 0, signers[0]));
        assertFalse(teeGovernance.hasSignedTeePausingAddresses(extensionId, 0, signers[1]));
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