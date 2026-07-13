// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { SortitionMock } from "../../../../contracts/fastUpdates/mock/SortitionMock.sol";
import { G1Point } from "../../../../contracts/userInterfaces/IBn256.sol";
import { SortitionCredential } from "../../../../contracts/userInterfaces/ISortition.sol";
import { SortitionState } from "../../../../contracts/fastUpdates/lib/Sortition.sol";

contract SortitionTest is Test {

    SortitionMock private sortition;

    function setUp() public {
        sortition = new SortitionMock();
    }

    function testVerifySignature() public {
        bytes memory result = _generateData("signature");
        (
            G1Point memory pk,
            bytes32 message,
            uint256 s,
            G1Point memory r
        ) = abi.decode(result, (G1Point, bytes32, uint256, G1Point));

        bool valid = sortition.verifySignatureTest(pk, message, s, r);
        assertTrue(valid);
    }

    function testVerifySortitionProof() public {
        bytes memory result = _generateData("proof");
        (
            SortitionState memory state,
            SortitionCredential memory credential
        ) = abi.decode(result, (SortitionState, SortitionCredential));

        bool valid = sortition.verifySortitionProofTest(state, credential);
        assertTrue(valid);
    }

    function testSortitionCredentialAcceptReject() public {
        bytes memory result = _generateData("credential");
        (
            SortitionState memory state,
            SortitionCredential memory credential
        ) = abi.decode(result, (SortitionState, SortitionCredential));

        // Should pass with the generated scoreCutoff
        bool valid = sortition.verifySortitionCredentialTest(state, credential);
        assertTrue(valid);

        // Should fail with scoreCutoff = 0
        state.scoreCutoff = 0;
        valid = sortition.verifySortitionCredentialTest(state, credential);
        assertFalse(valid);
    }

    function _generateData(
        string memory _mode
    )
        internal
        returns (bytes memory)
    {
        string[] memory command = new string[](3);
        command[0] = "node";
        command[1] = "test-forge/scripts/generate_sortition_data.js";
        command[2] = _mode;
        return vm.ffi(command);
    }
}
