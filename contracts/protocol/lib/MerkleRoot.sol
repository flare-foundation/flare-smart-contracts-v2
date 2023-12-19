// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// import "hardhat/console.sol";

library MerkleRoot {
    // Additional variables to avoid stack too deep error
    struct State {
        uint256 n;
        uint256 logN;
    }

    /// Calculates the Merkle root given fixed leaves
    /// @param leaves The leaves to calculate the Merkle root for
    /// @param index The index of the leaf to calculate the Merkle proof for.
    /// If negative, no Merkle proof is calculated
    /// @notice It uses Flare Merkle tree implementation
    /// see: https://gitlab.com/flarenetwork/state-connector-protocol/-/blob/main/specs/scProtocol/merkle-tree.md
    /// The algorithm is optimized to calculate Merkle root with minimal amount of allocated additional memory.
    /// For n leafs, it only uses O(log(n)) additional memory.
    /// The full Merkle tree with n leaves is represented as an array of length 2*n-1.
    /// The last n elements of the array are the leaves. The data structure uses the
    /// complete left aligned binary tree in an array, a well known representation for binary heaps.
    /// Instead of actually constructing the tree the following recursive algorithm is used:
    /// merklerRoot(tree) = sortedHash(merkleRoot(leftSubTree(tree)), merkleRoot(rightSubTree(tree)))
    /// The algorithm is essentially an iterative version of the recursive algorithm using a stack.
    /// To calculate Merkle proof for a leaf, the algorithm keeps the track of sibiling hashes on the stack and
    /// adds them to the Merkle proof when the leaf is hashed with its sibiling.
    function calculateMerkleRootWithSpecificProof(
        bytes32[] memory leaves,
        int256 index
    ) internal pure returns (bytes32 root, bytes32[] memory proof) {
        require(leaves.length > 0, "Must have at least one leaf");
        if (leaves.length == 1) {
            return (leaves[0], new bytes32[](0));
        }
        require(index < 0 || uint256(index) < leaves.length, "Index too big");
        // Additional variables to avoid stack too deep error
        State memory state;
        state.logN = 0;
        state.n = leaves.length;

        // calculating floor(log2(n))
        while (state.n > 1) {
            state.logN++;
            state.n /= 2;
        }
        // reinitialize n
        state.n = leaves.length;

        // -1 indicates no merkle proof needed
        int256 nextMerkleProofHashIndex = index >= 0 &&
            index < int256(leaves.length)
            ? int256(0)
            : int256(-1);

        // Stack allocation
        bytes32[] memory hashStack = new bytes32[](state.logN + 1);
        uint256[] memory levelStack = new uint256[](state.logN + 1);

        // For Flare Merkle tree one can prove by induction the folowing.
        // If n = 2^k, the leaves are all on the same level (level 0).
        // Otherwise the leaves are on two levels, the deepest level (level 0) and
        // the second deepest level (level 1). The leaves with indices in array [0, leftStart - 1]]
        // are on the level 1, while the leaves with indices in array [leftStart, n - 1]
        // are on the level 0. The following is true:
        // leftStart = 2^k - n % 2^k, where k = floor(log2(n))
        uint256 leftStart = (1 << state.logN) - (state.n % (1 << state.logN));
        uint256 stackTop = 0;
        // Merkle proof array allocation
        uint256 merkleProofLength = nextMerkleProofHashIndex >= 0
            ? (index >= int256(leftStart) ? state.logN + 1 : state.logN)
            : 0;
        proof = nextMerkleProofHashIndex >= 0
            ? new bytes32[](merkleProofLength)
            : new bytes32[](0);

        // -1 indicates that a sibiling is not on the stack yet
        // Once a sibiling gets hashed on the top of the stack, the hash is added
        // to Merkle proof and pushed to the top of the stack.
        // At that point the index gets set from -1 to that value.
        // Algorithm ensures that after the first hashing this value does not change.
        // The value hence changed at most twice: once when the leaf is put onto the
        // stack and then on first hashing.
        int256 nextMerkleHashSibilingStackIndex = -1;

        // deepest level has index 0. The hash array is on at most
        // 2 last levels. If there is only one level, then n = 2^k,
        // and leftStart = n, and the while in the second loop will not be executed.
        // The recursion algorithm would first consume leaves on indices [leftStart, n - 1] on level 0
        // and then leaves [0, leftStart - 1] on level 1.
        // The outer for loop accounts for those two steps.
        // The inner while loop tries to merge two hashes if they are on the same level (levels are inverted depth).
        // If the top two entries are not mergable, then the next element from concatenated array
        // [leftStart ... n - 1, 0 ... leftStart - 1] is pushed to the stack.
        // For loop accounts for concatenation.
        for (uint256 initialLevel = 0; initialLevel < 2; initialLevel++) {
            uint256 arrayLength;
            uint arrayPtr;
            if (initialLevel == 0) {
                arrayPtr = leftStart;
                arrayLength = leaves.length;
            } else {
                arrayPtr = 0;
                arrayLength = leftStart;
            }
            while (
                arrayPtr < arrayLength ||
                (stackTop > 1 &&
                    levelStack[stackTop - 1] == levelStack[stackTop - 2])
            ) {
                // prioritize merging top of stack if the same level
                if (
                    stackTop > 1 &&
                    levelStack[stackTop - 1] == levelStack[stackTop - 2]
                ) {
                    // check if the sibiling is to be added to the Merkle proof
                    if (nextMerkleProofHashIndex >= 0) {
                        if (
                            nextMerkleHashSibilingStackIndex ==
                            int256(stackTop - 1)
                        ) {
                            proof[
                                uint256(nextMerkleProofHashIndex)
                            ] = hashStack[stackTop - 2];
                            nextMerkleProofHashIndex++;
                            nextMerkleHashSibilingStackIndex = int256(
                                stackTop - 2
                            );
                        } else if (
                            nextMerkleHashSibilingStackIndex ==
                            int256(stackTop - 2)
                        ) {
                            proof[
                                uint256(nextMerkleProofHashIndex)
                            ] = hashStack[stackTop - 1];
                            nextMerkleProofHashIndex++;
                            nextMerkleHashSibilingStackIndex = int256(
                                stackTop - 2
                            );
                        }
                    }

                    // swap the top of the stack - needed for correct hashing order
                    if (hashStack[stackTop - 1] < hashStack[stackTop - 2]) {
                        (hashStack[stackTop - 1], hashStack[stackTop - 2]) =
                            (hashStack[stackTop - 2], hashStack[stackTop - 1]);
                    }

                    assembly {
                        // First slot of hashStack is reserved for stackTop length
                        // hashStack[stackTop - 2] is therefore at position hashStack + 32 * (stackTop - 1)
                        let ptr := add(hashStack, mul(sub(stackTop, 1), 32))
                        mstore(ptr, keccak256(ptr, 64))
                    }
                    // Solidity version of the assembly above, only that it reserves additional memory
                    // hashStack[stackTop - 2] = keccak256(
                    //     bytes.concat(
                    //         hashStack[stackTop - 2],
                    //         hashStack[stackTop - 1]
                    //     )
                    // );
                    levelStack[stackTop - 2]++;
                    stackTop--;
                    continue;
                }
                // only if it is nothing to merge, add one more leaf to the stack
                if (arrayPtr < arrayLength) {
                    hashStack[stackTop] = leaves[arrayPtr];
                    levelStack[stackTop] = initialLevel;
                    if (
                        nextMerkleProofHashIndex >= 0 &&
                        arrayPtr == uint256(index)
                    ) {
                        nextMerkleHashSibilingStackIndex = int256(stackTop);
                    }
                    stackTop++;
                    arrayPtr++;
                    continue;
                }
                revert("This should never happen");
            }
        }
        // This should never happen
        require(stackTop == 1, "Stack depth should be 1");
        return (hashStack[0], proof);
    }
}
