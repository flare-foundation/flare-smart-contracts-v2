// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../protocol/lib/MerkleRoot.sol";
 
contract MerkleTreeMock {

    using MerkleRoot for bytes32[];

    function merkleRootWithSpecificProof(
        bytes32[] memory leaves,
        int256 index
    ) external pure returns (bytes32, bytes32[] memory) {
        return leaves.calculateMerkleRootWithSpecificProof(index);
    }
}
