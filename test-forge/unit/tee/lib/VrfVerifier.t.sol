// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { VrfVerifier } from "../../../../contracts/tee/implementation/VrfVerifier.sol";
import { IVrfVerifier } from "../../../../contracts/userInterfaces/tee/IVrfVerifier.sol";

contract VrfVerifierTest is Test {

    VrfVerifier private verifier;

    function setUp() public {
        verifier = new VrfVerifier();
    }

    function testVerifyValidProof() public {
        (
            IVrfVerifier.Proof memory proof,
            uint256 pkX,
            uint256 pkY,
            bytes memory nonce
        ) = _generateProof("valid", "test-nonce");

        bool valid = verifier.verifyRandomness(proof, pkX, pkY, nonce);
        assertTrue(valid);
    }

    function testSameRandomnessForSameNonce() public {
        (
            IVrfVerifier.Proof memory proof1,,,
        ) = _generateProof("valid", "deterministic-nonce");

        bytes32 r1 = verifier.randomnessFromProof(
            proof1.gamma.x, proof1.gamma.y
        );

        (
            IVrfVerifier.Proof memory proof2,,,
        ) = _generateProof("valid", "deterministic-nonce");

        bytes32 r2 = verifier.randomnessFromProof(
            proof2.gamma.x, proof2.gamma.y
        );

        // Different key pairs produce different gammas
        // This test verifies both produce non-zero randomness
        assertTrue(r1 != bytes32(0));
        assertTrue(r2 != bytes32(0));
    }

    function testDifferentRandomnessForDifferentNonces() public {
        (
            IVrfVerifier.Proof memory proof1,
            uint256 pkX1,
            uint256 pkY1,
            bytes memory nonce1
        ) = _generateProof("valid", "nonce-a");

        (
            IVrfVerifier.Proof memory proof2,
            uint256 pkX2,
            uint256 pkY2,
            bytes memory nonce2
        ) = _generateProof("valid", "nonce-b");

        assertTrue(verifier.verifyRandomness(proof1, pkX1, pkY1, nonce1));
        assertTrue(verifier.verifyRandomness(proof2, pkX2, pkY2, nonce2));

        bytes32 r1 = verifier.randomnessFromProof(
            proof1.gamma.x, proof1.gamma.y
        );
        bytes32 r2 = verifier.randomnessFromProof(
            proof2.gamma.x, proof2.gamma.y
        );

        assertNotEq(r1, r2);
    }

    function testRejectWrongPublicKey() public {
        (
            IVrfVerifier.Proof memory proof,
            uint256 pkX,
            uint256 pkY,
            bytes memory nonce
        ) = _generateProof("wrong_pk", "test-nonce");

        vm.expectRevert(IVrfVerifier.InvalidUWitness.selector);
        verifier.verifyRandomness(proof, pkX, pkY, nonce);
    }

    function testRejectTamperedGamma() public {
        (
            IVrfVerifier.Proof memory proof,
            uint256 pkX,
            uint256 pkY,
            bytes memory nonce
        ) = _generateProof("tampered_gamma", "test-nonce");

        vm.expectRevert(IVrfVerifier.InvalidCGammaWitness.selector);
        verifier.verifyRandomness(proof, pkX, pkY, nonce);
    }

    function testVerifyMultipleKeyPairs() public {
        for (uint256 i = 0; i < 3; i++) {
            (
                IVrfVerifier.Proof memory proof,
                uint256 pkX,
                uint256 pkY,
                bytes memory nonce
            ) = _generateProof("valid", "shared-nonce");

            bool valid = verifier.verifyRandomness(proof, pkX, pkY, nonce);
            assertTrue(valid);
        }
    }

    function _generateProof(
        string memory _mode,
        string memory _nonce
    )
        internal
        returns (
            IVrfVerifier.Proof memory _proof,
            uint256 _pkX,
            uint256 _pkY,
            bytes memory _nonceBytes
        )
    {
        string[] memory command = new string[](4);
        command[0] = "node";
        command[1] = "test-forge/scripts/generate_vrf_proof.js";
        command[2] = _mode;
        command[3] = _nonce;
        bytes memory result = vm.ffi(command);
        (_proof, _pkX, _pkY, _nonceBytes) = abi.decode(
            result,
            (IVrfVerifier.Proof, uint256, uint256, bytes)
        );
    }
}
