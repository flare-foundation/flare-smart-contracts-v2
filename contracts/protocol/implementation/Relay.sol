// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Finalisation.sol";

// import "hardhat/console.sol";

contract Relay {
    struct StateData {
        uint8 randomNumberProtocolId;
        uint32 randomTimestamp;
    }
    uint256 public lastInitializedRewardEpoch;
    // rewardEpochId => signingPolicyHash
    mapping(uint256 => bytes32) public toSigningPolicyHash;
    // protocolId => votingRoundId => merkleRoot
    mapping(uint256 => mapping(uint256 => bytes32)) public merkleRoots;

    address public signingPolicySetter;

    StateData public stateData;

    constructor(
        address _signingPolicySetter,
        uint256 rewardEpochId,
        bytes32 signingPolicyHash
    ) {
        signingPolicySetter = _signingPolicySetter;
        lastInitializedRewardEpoch = rewardEpochId;
        toSigningPolicyHash[rewardEpochId] = signingPolicyHash;
    }

    /// Only signingPolicySetter address/contract can call this method.
    modifier onlySigningPolicySetter() {
        require(msg.sender == signingPolicySetter, "only sign policy setter");
        _;
    }

    // struct SigningPolicy {
    //     uint24 rId;                 // Reward epoch id.
    //     uint32 startVotingRoundId;  // First voting round id of validity.
    //                                 // Usually it is the first voting round of reward epoch rID.
    //                                 // It can be later,
    //                                 // if the confirmation of the signing policy on Flare blockchain gets delayed.
    //     uint16 threshold;           // Confirmation threshold (absolute value of noramalised weights).
    //     uint256 seed;               // Random seed.
    //     address[] voters;           // The list of eligible voters in the canonical order.
    //     uint16[] weights;           // The corresponding list of normalised signing weights of eligible voters.
    //                                 // Normalisation is done by compressing the weights from 32-byte values to 2 bytes,
    //                                 // while approximately keeping the weight relations.
    // }

    function setSigningPolicy(
        Finalisation.SigningPolicy calldata _signingPolicy
    ) public onlySigningPolicySetter returns (bytes32) {
        require(
            lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId,
            "not next reward epoch"
        );
        require(
            _signingPolicy.voters.length == _signingPolicy.weights.length,
            "size mismatch"
        );
        require(_signingPolicy.voters.length > 0, "must be non-trivial");
        require(
            _signingPolicy.voters.length == _signingPolicy.weights.length,
            "size mismatch"
        );
        // bytes32 currentHash;
        bytes memory toHash = bytes.concat(
            bytes2(uint16(_signingPolicy.voters.length)),
            bytes3(_signingPolicy.rewardEpochId),
            bytes4(_signingPolicy.startVotingRoundId),
            bytes2(_signingPolicy.threshold),
            bytes32(_signingPolicy.seed),
            bytes20(_signingPolicy.voters[0]),
            bytes1(uint8(_signingPolicy.weights[0] >> 8))
        );
        bytes32 currentHash = keccak256(toHash);
        uint256 weightIndex = 0;
        uint256 weightPos = 1;
        uint256 voterIndex = 1;
        uint256 voterPos = 0;
        uint256 count;
        uint256 bytesToTake;
        bytes32 nextSlot;
        uint256 pos;
        uint256 hashCount = 1;

        while (weightIndex < _signingPolicy.voters.length) {
            count = 0;
            nextSlot = bytes32(uint256(0));
            while (count < 32 && weightIndex < _signingPolicy.voters.length) {
                if (weightIndex < voterIndex) {
                    bytesToTake = 2 - weightPos;
                    pos = weightPos;
                    bytes32 weightData = bytes32(
                        uint256(uint16(_signingPolicy.weights[weightIndex])) <<
                            (30 * 8)
                    );
                    if (count + bytesToTake > 32) {
                        bytesToTake = 32 - count;
                        weightPos += bytesToTake;
                    } else {
                        weightPos = 0;
                        weightIndex++;
                    }
                    nextSlot =
                        nextSlot |
                        bytes32(((weightData << (8 * pos)) >> (8 * count)));
                } else {
                    bytesToTake = 20 - voterPos;
                    pos = voterPos;
                    bytes32 voterData = bytes32(
                        uint256(uint160(_signingPolicy.voters[voterIndex])) <<
                            (12 * 8)
                    );
                    if (count + bytesToTake > 32) {
                        bytesToTake = 32 - count;
                        voterPos += bytesToTake;
                    } else {
                        voterPos = 0;
                        voterIndex++;
                    }
                    nextSlot =
                        nextSlot |
                        bytes32(((voterData << (8 * pos)) >> (8 * count)));
                }
                count += bytesToTake;
            }
            if (count > 0) {
                currentHash = keccak256(bytes.concat(currentHash, nextSlot));
                hashCount++;
            }
        }
        toSigningPolicyHash[_signingPolicy.rewardEpochId] = currentHash;
        lastInitializedRewardEpoch = _signingPolicy.rewardEpochId;
        return currentHash;
    }

    // Signing policy byte encoding structure
    // 2 bytes - size
    // 3 bytes - rewardEpochId
    // 4 bytes - startingVotingRoundId
    // 2 bytes - threshold
    // 32 bytes - randomSeed
    // array of 'size':
    // - 20 bytes address
    // - 2 bytes weight
    // Total 43 + size * (20 + 2) bytes
    // metadataLength = 11 bytes (size, rewardEpochId, startingVotingRoundId, threshold)

    // Protocol message merkle root structure
    // 1 byte - protocolId
    // 4 bytes - votingRoundId
    // 1 byte - randomQualityScore
    // 32 bytes - merkleRoot
    // Total 38 bytes

    // Signature with index structure
    // 1 byte - v
    // 32 bytes - r
    // 32 bytes - s
    // 2 byte - index in signing policy
    // Total 67 bytes

    /**
     * ECDSA signature relay
     * Can be called in three modes.
     * (1) Initializing with signing policy. This can be done only once, usually after deployment.
     *     The calldata should include only:
     *        function signature (4 bytes) + signing policy (2209 bytes),
     *     total of exactly 2224 bytes.
     * (2) Relaying signing policy. The structure of the calldata is:
     *        function signature (4 bytes) + active signing policy (2209 bytes) + 0 (1 byte) + new signing policy (2209 bytes),
     *     total of exactly 4423 bytes.
     * (3) Relaying signed message. The structure of the calldata is:
     *        function signature (4 bytes) + signing policy (2209 bytes) + signed message (38 bytes) + ECDSA signatures with indices (66 bytes each),
     *     total of 2251 + 66 * N bytes, where N is the number of signatures.
     */
    //
    // (1) Initializing with signing policy. This can be done only once, usually after deployment. The calldata should include only signature and signing policy.
    function relay() external {
        uint256 tmpVar;
        assembly {
            // Helper function to revert with a message
            // Since string length cannot be determined in assembly easily, the matching length of the message string must be provided.
            function revertWithMessage(memPtr, message, msgLength) {
                mstore(
                    memPtr,
                    0x08c379a000000000000000000000000000000000000000000000000000000000
                )
                mstore(add(memPtr, 0x04), 0x20) // String offset
                mstore(add(memPtr, 0x24), msgLength) // Revert reason length
                mstore(add(memPtr, 0x44), message)
                revert(memPtr, 0x64) // Revert data length is 4 bytes for selector and 3 slots of 0x20 bytes
            }

            function revertWithValue(memPtr, val) {
                mstore(memPtr, val)
                revert(memPtr, 0x20)
            }

            // Helper function to calculate the matching reward epoch id from voting round id
            // Here the constants should be set properly
            function rewardEpochIdFromVotingRoundId(votingRoundId)
                -> rewardEpochId
            {
                let firstRewardEpochVotingRoundId := 1000 // CONST firstRewardEpochVotingRoundId = 1000
                let rewardEpochDurationInEpochs := 3360 // CONST rewardEpochDurationInEpochs = 3360   (3.5 days)
                rewardEpochId := div(
                    sub(votingRoundId, firstRewardEpochVotingRoundId),
                    rewardEpochDurationInEpochs
                )
            }

            // Helper function to calculate the signing policy hash while trying to minimize the usage of memory
            // Uses slots 0 and 32
            function calculateSigningPolicyHash(
                memPos,
                calldataPos,
                policyLength
            ) -> policyHash {
                // first byte
                calldatacopy(memPos, calldataPos, 32)
                let endPos := add(calldataPos, mul(div(policyLength, 32), 32))
                for {
                    let pos := add(calldataPos, 32)
                } lt(pos, endPos) {
                    pos := add(pos, 32)
                } {
                    calldatacopy(add(memPos, 32), pos, 32)
                    mstore(memPos, keccak256(memPos, 64))
                }

                // handle the remaining 12 bytes at the end
                mstore(add(memPos, 32), 0)
                calldatacopy(add(memPos, 32), endPos, mod(policyLength, 32)) // remaining bytes
                mstore(memPos, keccak256(memPos, 64))
                policyHash := mload(memPos)
            }

            // Constants
            let memPtr := mload(0x40) // free memory pointer
            // CONST thresholdIncrease = 120
            // CONST metadataLength = 11
            // CONST fullMetadataLength = 11 + 32 = 43
            // CONST messageLength = 38
            // CONST signatureLength = 67 = 1 v + 32 r + 32 s + 2 index

            // Variables
            let pos := 4 // Calldata position
            let signatureStart := 0 // First index of signatures in calldata

            ///////////// Extracting signing policy metadata /////////////
            if lt(calldatasize(), 15) {
                // 4 + 11 (CONST metadataLength) = 15
                revertWithMessage(memPtr, "Invalid sign policy metadata", 28)
            }

            calldatacopy(memPtr, pos, 11) // CONST metadataLength = 11
            let metadata := shr(168, mload(memPtr)) // >> 256 - 11*8 = 256 - 11*8 = 168
            // let numberOfVoters := shr(72, metadata) // 2 bytes - size (>> 9 * 8 = 72)
            // let
            let rewardEpochId := and(shr(48, metadata), 0xffffff) // 3 bytes - rewardEpochId (>> 6 * 8 = 48)
            // let startingVotingRoundId := and(shr(16, metadata), 0xffffffff) // 4 bytes - startingVotingRoundId (>> 2 * 8 = 16)
            let threshold := and(metadata, 0xffff) // 2 bytes - threshold
            // 11 (CONST metadataLength) + 32 (random seed) + (CONST numberOfVoters) * (20 + 2)
            // 43 + 22 * numberOfVoters
            let signingPolicyLength := add(43, mul(shr(72, metadata), 22))

            // The calldata must be of length at least 4 (function selector) + signingPolicyLength + 1 (protocolId)
            if lt(calldatasize(), add(signingPolicyLength, 5)) {
                revertWithMessage(memPtr, "Invalid sign policy length", 26)
            }

            ///////////// Verifying signing policy /////////////
            // signing policy hash
            let signingPolicyHash := calculateSigningPolicyHash(
                memPtr,
                4,
                signingPolicyLength
            )

            //  toSigningPolicyHash[rewardEpochId] = existingSigningPolicyHash
            mstore(memPtr, rewardEpochId) // key (rewardEpochId)
            mstore(add(memPtr, 32), toSigningPolicyHash.slot)
            let existingSigningPolicyHash := sload(keccak256(memPtr, 64))

            // From here on we have calldatasize() > 4 + signingPolicyLength

            ///////////// Verifying signing policy /////////////
            if iszero(eq(signingPolicyHash, existingSigningPolicyHash)) {
                revertWithMessage(memPtr, "Signing policy hash mismatch", 28)
            }
            // jump to protocol message Merkle root
            pos := add(signingPolicyLength, 4)

            // Extracting protocolId, votingRoundId and randomQualityScore
            // 1 bytes - protocolId
            // 4 bytes - votingRoundId
            // 1 bytes - randomQualityScore
            // 32 bytes - merkleRoot
            // message length: 38

            calldatacopy(memPtr, pos, 1)
            let protocolId := shr(248, mload(memPtr)) // 1 byte - protocolId (>> 256 - 8 = 248)

            let votingRoundId := 0
            // let randomQualityScore := 0
            ///////////// Preparation of message hash /////////////
            // protocolId > 0 means we are relaying (Mode 3)
            // The signed hash is the message hash and it gets prepared into slot 32
            if gt(protocolId, 0) {
                signatureStart := add(add(4, signingPolicyLength), 38) // CONST messageLength = 38
                if lt(calldatasize(), signatureStart) {
                    revertWithMessage(memPtr, "Too short message", 17)
                }
                calldatacopy(memPtr, pos, 38) // CONST messageLength = 38

                votingRoundId := and(shr(216, mload(memPtr)), 0xffffffff) // 4 bytes - votingRoundId (>> 256 - (1 + 4)*8 = 216)
                // randomQualityScore := shr(248, shl(40, mload(memPtr)))
                // the usual reward epoch id
                let messageRewardEpochId := rewardEpochIdFromVotingRoundId(
                    votingRoundId
                )
                let startingVotingRoundId := and(shr(16, metadata), 0xffffffff) // 4 bytes - startingVotingRoundId (>> 2 * 8 = 16)
                // in case the reward epoch id start gets delayed -> signing policy for earlier reward epoch must be provided
                if and(
                    eq(messageRewardEpochId, rewardEpochId),
                    lt(votingRoundId, startingVotingRoundId)
                ) {
                    revertWithMessage(memPtr, "Delayed sign policy", 19)
                }

                // Given a signing policy for reward epoch R one can sign either messages in reward epochs R and R+1 only
                if or(
                    gt(messageRewardEpochId, add(rewardEpochId, 1)),
                    lt(messageRewardEpochId, rewardEpochId)
                ) {
                    revertWithMessage(
                        memPtr,
                        "Wrong sign policy reward epoch",
                        30
                    )
                }

                // When signing with previous reward epoch's signing policy, use higher threshold
                if eq(sub(messageRewardEpochId, 1), rewardEpochId) {
                    threshold := div(mul(threshold, 120), 100) // CONST thresholdIncrease = 120   (20%)
                }

                // Prepera the message hash into slot 32
                mstore(add(memPtr, 32), keccak256(memPtr, 38)) // CONST messageLength = 38
            }
            // protocolId == 0 means we are relaying new signing policy (Mode 2)
            // The signed hash is the signing policy hash and it gets prepared into slot 32
            if eq(protocolId, 0) {
                if lt(calldatasize(), add(16, signingPolicyLength)) {
                    // 4 selector + signingPolicyLength + 1 protocolId + 11 CONST metadataLength = 16 + signingPolicyLength
                    revertWithMessage(memPtr, "No new sign policy size", 23)
                }

                // New metadata
                calldatacopy(memPtr, add(5, signingPolicyLength), 11) // 4 selector + 1 protocolId,  CONST metadataLength = 11
                let newMetadata := shr(168, mload(memPtr)) // ()>> 256 - 11*8 = 168)
                // let newNumberOfVoters := shr(72, newMetadata) // 2 bytes - size (>> 9 * 8 = 72)
                let newSigningPolicyLength := add(
                    43,
                    mul(shr(72, newMetadata), 22)
                )

                signatureStart := add(
                    5,
                    add(newSigningPolicyLength, signingPolicyLength)
                )
                if lt(calldatasize(), signatureStart) {
                    revertWithMessage(
                        memPtr,
                        "Wrong size for new sign policy",
                        30
                    )
                }

                let newSigningPolicyRewardEpochId := and(
                    shr(48, newMetadata),
                    0xffffff
                ) // 3 bytes - rewardEpochId (>> 6 * 8 = 48)
                let tmpLastInitializedRewardEpochId := sload(
                    lastInitializedRewardEpoch.slot
                )
                // let nextRewardEpochId := add(tmpLastInitializedRewardEpochId, 1)
                if iszero(
                    eq(
                        add(1, tmpLastInitializedRewardEpochId),
                        newSigningPolicyRewardEpochId
                    )
                ) {
                    revertWithMessage(memPtr, "Not next reward epoch", 21)
                }
                // let newSigningPolicyStart := add(5, signingPolicyLength) // 4 selector + signingPolicyLength + 1 protocolId
                let newSigningPolicyHash := calculateSigningPolicyHash(
                    memPtr,
                    add(5, signingPolicyLength),
                    newSigningPolicyLength
                )
                // Write to storage - if signature weight is not sufficient, this will be reverted
                sstore(
                    lastInitializedRewardEpoch.slot,
                    newSigningPolicyRewardEpochId
                )
                // toSigningPolicyHash[newSigningPolicyRewardEpochId] = newSigningPolicyHash
                mstore(memPtr, newSigningPolicyRewardEpochId)
                mstore(add(memPtr, 32), toSigningPolicyHash.slot)
                sstore(keccak256(memPtr, 64), newSigningPolicyHash)
                // Prepare the hash on slot 32 for signature verification
                mstore(add(memPtr, 32), newSigningPolicyHash)
            }

            // Assumptions here:
            // - memPtr (slot 0) contains either protocol message merkle root hash or new signing policy hash
            // - signatureStart points to the first signature in calldata
            // - We are sure that calldatasize() >= signatureStart

            // There need to be exactly multiple of 66 bytes for signatures
            if mod(sub(calldatasize(), signatureStart), 67) {
                // CONST signatureLength = 67
                revertWithMessage(memPtr, "Wrong signatures length", 23)
            }

            // Prefixed hash calculation
            // 4-bytes padded prefix into slot 0
            mstore(memPtr, "0000\x19Ethereum Signed Message:\n32")
            // Prefixed hash into slot 0, skipping 4-bytes of prefix
            mstore(memPtr, keccak256(add(memPtr, 4), 60))

            // Processing signatures. Memory map:
            // memPtr (slot 0) | prefixedHash
            // 32              | v  // first 31 bytes always 0
            // 64              | r, signer
            // 96              | s, expectedSigner
            // 128             | index, weight
            mstore(add(memPtr, 0x20), 0) // clear v - only the lowest byte will change

            for {
                let i := 0
                // accumulated weight of signatures
                let weight := 0
                // enforces increasing order of indices in signatures
                let nextUnusedIndex := 0
                // number of signatures
                let numberOfSignatures := div(
                    sub(calldatasize(), signatureStart),
                    67
                ) // CONST signatureLength = 67
            } lt(i, numberOfSignatures) {
                i := add(i, 1)
            } {
                // signature position
                pos := add(signatureStart, mul(i, 67)) // CONST signatureLength = 67
                // overriding only the last byte of 'v' and setting r, s
                calldatacopy(add(memPtr, 63), pos, 67) // CONST signatureLength = 67
                // Note that those things get set
                // - slot +32 - the rightmost byte of 'v' gets set
                // - slot +64    - r
                // - slot +96    - s
                // - slot +128   - index (only the top 2 bytes)
                let index := shr(240, mload(add(memPtr, 128))) // >> 256 - 2*8 = 240

                // Index sanity checks in regard to signing policy
                if gt(index, sub(shr(72, metadata), 1)) {
                    // CONST numberOfVoters = shr(72, metadata)
                    revertWithMessage(memPtr, "Index out of range", 18)
                }

                if lt(index, nextUnusedIndex) {
                    revertWithMessage(memPtr, "Index out of order", 18)
                }
                nextUnusedIndex := add(index, 1)

                // ecrecover call. Address goes to slot 64, it is 0 padded
                if iszero(
                    staticcall(not(0), 0x01, memPtr, 0x80, add(memPtr, 64), 32)
                ) {
                    revertWithMessage(memPtr, "ecrecover error", 15)
                }
                // extract expected signer address to slot no 96
                mstore(add(memPtr, 96), 0) // zeroing slot for expected address

                // position of address on 'index': 4 + 20 + index x 22 (expectedSigner)
                let addressPos := add(47, mul(index, 22)) // 47 == 4 selector + CONST fullMetadataLength = 43
                // 108 = 96 + 12  - skip 12 bytes of prefix
                calldatacopy(add(memPtr, 108), addressPos, 20)

                // Check if the recovered signer is the expected signer
                if iszero(eq(mload(add(memPtr, 64)), mload(add(memPtr, 96)))) {
                    revertWithMessage(memPtr, "Wrong signature", 15)
                }

                // extract weight, reuse field for r (slot 64)
                mstore(add(memPtr, 64), 0) // clear r field
                // skip 30 bytes: memPtr + 64 + 30 = memPtr + 94
                calldatacopy(add(memPtr, 94), add(addressPos, 20), 2)
                weight := add(weight, mload(add(memPtr, 64)))

                if gt(weight, threshold) {
                    // jump over fun selector, signing policy and 17 bytes of protocolId, votingRoundId and randomQualityScore
                    pos := add(add(4, signingPolicyLength), sub(38, 32)) // CONST messageLength = 38, last 32 bytes are merkleRoot
                    calldatacopy(memPtr, pos, 32)
                    let merkleRoot := mload(memPtr)
                    // writing into the map
                    mstore(memPtr, protocolId) // key 1 (protocolId)
                    mstore(add(memPtr, 32), merkleRoots.slot) // merkleRoot slot

                    mstore(add(memPtr, 32), keccak256(memPtr, 64)) // parent map location in slot for next hashing
                    mstore(memPtr, votingRoundId) // key 2 (votingRoundId)
                    sstore(keccak256(memPtr, 64), merkleRoot) // merkleRoot stored at merkleRoots[protocolId][votingRoundId]

                    // TODO: set randomNumberQualityScore
                    return(0, 0) // all done
                }
            }
        }
        revert("Not enough weight");
    }
}
