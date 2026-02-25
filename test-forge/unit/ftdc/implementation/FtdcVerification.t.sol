// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FtdcVerification } from "../../../../contracts/ftdc/implementation/FtdcVerification.sol";
import { FtdcVerificationProxy } from "../../../../contracts/ftdc/proxy/FtdcVerificationProxy.sol";
import { IFtdcVerification } from "../../../../contracts/userInterfaces/ftdc/IFtdcVerification.sol";
import { ITeeMachineRegistry } from "../../../../contracts/userInterfaces/tee/ITeeMachineRegistry.sol";
import { IRelay } from "../../../../contracts/userInterfaces/IRelay.sol";
import { Signature } from "../../../../contracts/userInterfaces/ISignature.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract FtdcVerificationTest is Test {

    FtdcVerification private ftdcVerification;
    FtdcVerification private ftdcVerificationImpl;
    FtdcVerificationProxy private ftdcVerificationProxy;

    address private governance;
    address private addressUpdater;
    address private relay;
    address private teeMachineRegistry;

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

        ftdcVerificationImpl = new FtdcVerification();
        ftdcVerificationProxy = new FtdcVerificationProxy(
            IGovernanceSettings(address(this)),
            governance,
            addressUpdater,
            address(ftdcVerificationImpl)
        );
        ftdcVerification = FtdcVerification(address(ftdcVerificationProxy));

        contractNameHashes = new bytes32[](3);
        contractAddresses = new address[](3);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeMachineRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("Relay"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("TeeMachineRegistry");
        contractAddresses[2] = makeAddr("Relay");

        vm.prank(addressUpdater);
        ftdcVerification.updateContractAddresses(contractNameHashes, contractAddresses);

        relay = address(ftdcVerification.relay());
        teeMachineRegistry = address(ftdcVerification.teeMachineRegistry());

        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.PRODUCTION);
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
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.PAUSED);
        vm.expectRevert(IFtdcVerification.TeeMachineNotAvailable.selector);
        ftdcVerification.verifyTeeSignature(signature, messageHash);
    }


    function testVerifyTeeSignatureRevertInvalidTeeMachineExtensionId() public {
        _mockGetExtensionId(1);
        vm.expectRevert(IFtdcVerification.InvalidTeeMachineExtensionId.selector);
        ftdcVerification.verifyTeeSignature(signature, messageHash);
    }

    function testVerifyTeeSignature() public {
        address returnedTeeId =
            ftdcVerification.verifyTeeSignature(signature, messageHash);
        assertEq(returnedTeeId, teeId);
    }


    // verifyTeeSignatures
    function testVerifyTeeSignaturesRevertTeeMachineNotAvailable() public {
        Signature[] memory signatures = new Signature[](1);
        signatures[0] = signature;
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.PAUSED);
        vm.expectRevert(IFtdcVerification.TeeMachineNotAvailable.selector);
        ftdcVerification.verifyTeeSignatures(signatures, messageHash);
    }


    function testVerifyTeeSignaturesRevertDuplicatedTeeId() public {
        Signature[] memory signatures = new Signature[](2);
        signatures[0] = signature;
        signatures[1] = signatures[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                IFtdcVerification.DuplicatedTeeId.selector,
                teeId
            )
        );
        ftdcVerification.verifyTeeSignatures(signatures, messageHash);
    }


    function testVerifyTeeSignatures() public {
        Signature[] memory signatures = new Signature[](0);
        address[] memory teeIds =
            ftdcVerification.verifyTeeSignatures(signatures, messageHash);
        assertEq(teeIds.length, 0);

        signatures = new Signature[](2);
        signatures[0] = signature;
        signatures[1] = _createSignature(newPrivateKey);
        teeIds = ftdcVerification.verifyTeeSignatures(signatures, messageHash);
        assertEq(teeIds.length, 2);
        assertEq(teeIds[0], teeId);
        assertEq(teeIds[1], newTeeId);
    }


    // verifyCosignerSignatures
    function testVerifyCosignerSignaturesRevertDuplicatedCosigner() public {
        Signature[] memory signatures = new Signature[](2);
        signatures[0] = signature;
        signatures[1] = signatures[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                IFtdcVerification.DuplicatedCosigner.selector,
                teeId
            )
        );
        ftdcVerification.verifyCosignerSignatures(signatures, messageHash);
    }


    function testVerifyCosignerSignatures() public {
        Signature[] memory signatures = new Signature[](0);
        address[] memory cosigners =
            ftdcVerification.verifyCosignerSignatures(signatures, messageHash);
        assertEq(cosigners.length, 0);

        signatures = new Signature[](2);
        signatures[0] = signature;
        signatures[1] = _createSignature(newPrivateKey);
        cosigners = ftdcVerification.verifyCosignerSignatures(signatures, messageHash);
        assertEq(cosigners.length, 2);
        assertEq(cosigners[0], teeId);
        assertEq(cosigners[1], newTeeId);
    }


    function _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus _status) private {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(ITeeMachineRegistry.getTeeMachineStatus.selector),
            abi.encode(_status)
        );
    }

    function _mockGetExtensionId(uint256 _extensionId) private {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(ITeeMachineRegistry.getExtensionId.selector),
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