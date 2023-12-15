// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library MerkleRoot {
    /// Calculates the Merkle root given fixed order of leaves
    function calculateMerkleRoot(
        bytes32[] memory leaves
    ) public pure returns (bytes32) {
        require(leaves.length > 0, "Must have at least one leaf");
        if (leaves.length == 1) {
            return leaves[0];
        }
        uint256 logN = 0;
        uint256 n = leaves.length;
        while (n > 1) {
            logN++;
            n /= 2;
        }
        bytes32[] memory hashStack = new bytes32[](logN + 1);
        uint256[] memory levelStack = new uint256[](logN + 1);
        // index in initial array for the first element of the deepest level
        uint256 leftStart = (1 << logN) - (n % (1 << logN));
        uint256 stackTop = 0;

        // deepest level has index 0. The hash array is on at most 2 last levels.
        // If there is only one level, then n = 2^k, and leftStart = n, and the while in the second loop will not be executed.
        for (uint256 initialLevel = 0; initialLevel < 2; initialLevel++) {
            uint256 arrayLength;
            uint arrayPtr;

            if (initialLevel == 0) {
                arrayPtr = leftStart;
                arrayLength = leaves.length;
                for (uint256 i = 0; i < 2; i++) {
                    hashStack[stackTop] = leaves[arrayPtr];
                    levelStack[stackTop] = initialLevel;
                    stackTop++;
                    arrayPtr++;
                }
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
                    // swap
                    if (hashStack[stackTop - 1] < hashStack[stackTop - 2]) {
                        bytes32 tmp = hashStack[stackTop - 1];
                        hashStack[stackTop - 1] = hashStack[stackTop - 2];
                        hashStack[stackTop - 2] = tmp;
                    }
                    // use assembly to do keccak and save memory allocation
                    hashStack[stackTop - 2] = keccak256(
                        bytes.concat(
                            hashStack[stackTop - 2],
                            hashStack[stackTop - 1]
                        )
                    );
                    levelStack[stackTop - 2] = levelStack[stackTop - 1] + 1;
                    stackTop--;
                    continue;
                }
                // only if it is nothing to merge, add one more leaf to the stack
                if (arrayPtr < arrayLength) {
                    hashStack[stackTop] = leaves[arrayPtr];
                    levelStack[stackTop] = initialLevel;
                    stackTop++;
                    arrayPtr++;
                    continue;
                }

                revert("This should never happen");
            }
        }
        // This should never happen
        require(stackTop == 1, "Stack depth should be 1");
        return hashStack[0];
    }
}
