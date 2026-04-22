// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { Fdc2Verification } from "../../../../contracts/fdc2/implementation/Fdc2Verification.sol";
import { Fdc2VerificationProxy } from "../../../../contracts/fdc2/proxy/Fdc2VerificationProxy.sol";
import { IFdc2Verification } from "../../../../contracts/userInterfaces/fdc2/IFdc2Verification.sol";
import { IMachineManagerFacet } from "../../../../contracts/userInterfaces/tee/IMachineManagerFacet.sol";
import { IRelay } from "../../../../contracts/userInterfaces/IRelay.sol";
import { Signature } from "../../../../contracts/userInterfaces/ISignature.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract Fdc2VerificationTest is Test {

    Fdc2Verification private fdc2Verification;
    Fdc2Verification private fdc2VerificationImpl;
    Fdc2VerificationProxy private fdc2VerificationProxy;

    address private governance;
    address private addressUpdater;
    address private relay;
    address private flareTeeManager;

    bytes private signingPolicySignatures;
    bytes32 private messageHash;
    address private teeId;
    address private newTeeId;
    uint256 private privateKey;
    uint256 private newPrivateKey;
    Signature private signature;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;


    function setUp() public {
        signingPolicySignatures = abi.encode("signingPolicySignatures");
        messageHash = keccak256("messageHash");
        (teeId, privateKey) = makeAddrAndKey("teeId");
        (newTeeId, newPrivateKey) = makeAddrAndKey("newTeeId");
        signature = _createSignature(privateKey);

        addressUpdater = makeAddr("addressUpdater");
        governance = makeAddr("governance");

        fdc2VerificationImpl = new Fdc2Verification();
        fdc2VerificationProxy = new Fdc2VerificationProxy(
            IGovernanceSettings(address(this)),
            governance,
            addressUpdater,
            address(fdc2VerificationImpl)
        );
        fdc2Verification = Fdc2Verification(address(fdc2VerificationProxy));

        contractNameHashes = new bytes32[](3);
        contractAddresses = new address[](3);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareTeeManager"));
        contractNameHashes[2] = keccak256(abi.encode("Relay"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("FlareTeeManager");
        contractAddresses[2] = makeAddr("Relay");

        vm.prank(addressUpdater);
        fdc2Verification.updateContractAddresses(contractNameHashes, contractAddresses);

        relay = address(fdc2Verification.relay());
        flareTeeManager = address(fdc2Verification.flareTeeManager());

        _mockGetTeeMachineStatus(IMachineManagerFacet.TeeStatus.PRODUCTION);
        _mockGetExtensionId(0);

        vm.mockCall(
            relay,
            abi.encodeWithSelector(
                IRelay.verifyCustomSignature.selector
            ),
            abi.encode(1)
        );
    }

    // verifyTeeSignature
    function testVerifyTeeSignatureRevertTeeMachineNotAvailable() public {
        _mockGetTeeMachineStatus(IMachineManagerFacet.TeeStatus.PAUSED);
        vm.expectRevert(IFdc2Verification.TeeMachineNotAvailable.selector);
        fdc2Verification.verifyTeeSignature(signature, messageHash);
    }


    function testVerifyTeeSignatureRevertInvalidTeeMachineExtensionId() public {
        _mockGetExtensionId(1);
        vm.expectRevert(IFdc2Verification.InvalidTeeMachineExtensionId.selector);
        fdc2Verification.verifyTeeSignature(signature, messageHash);
    }

    function testVerifyTeeSignature() public {
        address returnedTeeId =
            fdc2Verification.verifyTeeSignature(signature, messageHash);
        assertEq(returnedTeeId, teeId);
    }


    // verifyTeeSignatures
    function testVerifyTeeSignaturesRevertTeeMachineNotAvailable() public {
        Signature[] memory signatures = new Signature[](1);
        signatures[0] = signature;
        _mockGetTeeMachineStatus(IMachineManagerFacet.TeeStatus.PAUSED);
        vm.expectRevert(IFdc2Verification.TeeMachineNotAvailable.selector);
        fdc2Verification.verifyTeeSignatures(signatures, messageHash);
    }


    function testVerifyTeeSignaturesRevertDuplicatedTeeId() public {
        Signature[] memory signatures = new Signature[](2);
        signatures[0] = signature;
        signatures[1] = signatures[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                IFdc2Verification.DuplicatedTeeId.selector,
                teeId
            )
        );
        fdc2Verification.verifyTeeSignatures(signatures, messageHash);
    }


    function testVerifyTeeSignatures() public {
        Signature[] memory signatures = new Signature[](0);
        address[] memory teeIds =
            fdc2Verification.verifyTeeSignatures(signatures, messageHash);
        assertEq(teeIds.length, 0);

        signatures = new Signature[](2);
        signatures[0] = signature;
        signatures[1] = _createSignature(newPrivateKey);
        teeIds = fdc2Verification.verifyTeeSignatures(signatures, messageHash);
        assertEq(teeIds.length, 2);
        assertEq(teeIds[0], teeId);
        assertEq(teeIds[1], newTeeId);
    }


    // recoverCosigners
    function testRecoverCosignersRevertDuplicatedCosigner() public {
        Signature[] memory signatures = new Signature[](2);
        signatures[0] = signature;
        signatures[1] = signatures[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                IFdc2Verification.DuplicatedCosigner.selector,
                teeId
            )
        );
        fdc2Verification.recoverCosigners(signatures, messageHash);
    }


    function testRecoverCosigners() public {
        Signature[] memory signatures = new Signature[](0);
        address[] memory cosigners =
            fdc2Verification.recoverCosigners(signatures, messageHash);
        assertEq(cosigners.length, 0);

        signatures = new Signature[](2);
        signatures[0] = signature;
        signatures[1] = _createSignature(newPrivateKey);
        cosigners = fdc2Verification.recoverCosigners(signatures, messageHash);
        assertEq(cosigners.length, 2);
        assertEq(cosigners[0], teeId);
        assertEq(cosigners[1], newTeeId);
    }


    function _mockGetTeeMachineStatus(IMachineManagerFacet.TeeStatus _status) private {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IMachineManagerFacet.getTeeMachineStatus.selector),
            abi.encode(_status)
        );
    }

    function _mockGetExtensionId(uint256 _extensionId) private {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IMachineManagerFacet.getExtensionId.selector),
            abi.encode(_extensionId)
        );
    }

    function _createSignature(
        uint256 _privateKey
    )
        private view
        returns (Signature memory)
    {
        bytes32 signedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, signedMessageHash);
        return Signature(v, r, s);
    }
}