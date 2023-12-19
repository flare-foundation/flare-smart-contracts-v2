// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Finalisation.sol";

// import "hardhat/console.sol";

contract Relay {

    // IMPORTANT: if you change this, you have to adapt the assembly writing into this in the relay() function
    struct StateData {
        uint8 randomNumberProtocolId;
        uint32 firstVotingRoundStartSec;
        uint8 votingRoundDurationSec;
        uint32 firstRewardEpochStartVotingRoundId;
        uint16 rewardEpochDurationInVotingEpochs;
        uint16 thresholdIncreaseBIPS;
        uint32 randomVotingRoundId;
        bool randomNumberQualityScore;
    }

    uint256 public constant THRESHOLD_BIPS = 10000;
    uint256 public constant SELECTOR_BYTES = 4;

    // Signing policy byte encoding structure
    // 2 bytes - numberOfVoters
    // 3 bytes - rewardEpochId
    // 4 bytes - startingVotingRoundId
    // 2 bytes - threshold
    // 32 bytes - public key Merkle root
    // 32 bytes - randomSeed
    // array of 'size':
    // - 20 bytes address
    // - 2 bytes weight
    // Total 75 + size * (20 + 2) bytes
    // metadataLength = 11 bytes (size, rewardEpochId, startingVotingRoundId, threshold)

    /* solhint-disable const-name-snakecase */
    uint256 public constant NUMBER_OF_VOTERS_BYTES = 2;
    uint256 public constant NUMBER_OF_VOTERS_MASK = 0xffff;
    uint256 public constant METADATA_BYTES = 11;
    uint256 public constant MD_MASK_threshold = 0xffff;
    uint256 public constant MD_BOFF_threshold = 0;
    uint256 public constant MD_MASK_startingVotingRoundId = 0xffffffff;
    uint256 public constant MD_BOFF_startingVotingRoundId = 16;
    uint256 public constant MD_MASK_rewardEpochId = 0xffffff;
    uint256 public constant MD_BOFF_rewardEpochId = 48;
    uint256 public constant MD_MASK_numberOfVoters = 0xffff;
    uint256 public constant MD_BOFF_numberOfVoters = 72;
    /* solhint-enable const-name-snakecase */

    uint256 public constant PUBLIC_KEY_MERKLE_ROOT_BYTES = 32;
    uint256 public constant RANDOM_SEED_BYTES = 32;
    uint256 public constant ADDRESS_BYTES = 20;
    uint256 public constant WEIGHT_BYTES = 2;
    uint256 public constant ADDRESS_AND_WEIGHT_BYTES = 22; // ADDRESS_BYTES + WEIGHT_BYTES;
    //METADATA_BYTES + PUBLIC_KEY_MERKLE_ROOT_BYTES + RANDOM_SEED_BYTES;
    uint256 public constant SIGNING_POLICY_PREFIX_BYTES = 75;

    // Protocol message merkle root structure
    // 1 byte - protocolId
    // 4 bytes - votingRoundId
    // 1 byte - randomQualityScore
    // 32 bytes - merkleRoot
    // Total 38 bytes
    // if loaded into a memory slot, these are right shifts and masks
    /* solhint-disable const-name-snakecase */
    uint256 public constant MESSAGE_BYTES = 38;
    uint256 public constant PROTOCOL_ID_BYTES = 1;
    uint256 public constant MESSAGE_NO_MR_BYTES = 6;
    uint256 public constant MSG_NMR_MASK_randomQualityScore = 0xff;
    uint256 public constant MSG_NMR_BOFF_randomQualityScore = 0;
    uint256 public constant MSG_NMR_MASK_votingRoundId = 0xffffffff;
    uint256 public constant MSG_NMR_BOFF_votingRoundId = 8;
    uint256 public constant MSG_NMR_MASK_protocolId = 0xff;
    uint256 public constant MSG_NMR_BOFF_protocolId = 40;
    /* solhint-enable const-name-snakecase */

    /* solhint-disable const-name-snakecase */
    uint256 public constant SD_MASK_randomNumberProtocolId = 0xff;
    uint256 public constant SD_BOFF_randomNumberProtocolId = 0;
    uint256 public constant SD_MASK_firstVotingRoundStartSec = 0xffffffff;
    uint256 public constant SD_BOFF_firstVotingRoundStartSec = 8;
    uint256 public constant SD_MASK_votingRoundDurationSec = 0xff;
    uint256 public constant SD_BOFF_votingRoundDurationSec = 40;
    uint256 public constant SD_MASK_firstRewardEpochVotingRoundId = 0xffffffff;
    uint256 public constant SD_BOFF_firstRewardEpochVotingRoundId = 48;
    uint256 public constant SD_MASK_rewardEpochDurationInVotingEpochs = 0xffff;
    uint256 public constant SD_BOFF_rewardEpochDurationInVotingEpochs = 80;
    uint256 public constant SD_MASK_thresholdIncrease = 0xffff;
    uint256 public constant SD_BOFF_thresholdIncrease = 96;
    uint256 public constant SD_MASK_randomVotingRoundId = 0xffffffff;
    uint256 public constant SD_BOFF_randomVotingRoundId = 112;
    uint256 public constant SD_MASK_randomNumberQualityScore = 0xff;
    uint256 public constant SD_BOFF_randomNumberQualityScore = 144;
    /* solhint-enable const-name-snakecase */

    // Signature with index structure
    // 1 byte - v
    // 32 bytes - r
    // 32 bytes - s
    // 2 byte - index in signing policy
    // Total 67 bytes

    uint256 public constant NUMBER_OF_SIGNATURES_BYTES = 2;
    uint256 public constant NUMBER_OF_SIGNATURES_RIGHT_SHIFT_BITS = 240; // 8 * (32 - NUMBER_OF_SIGNATURES_BYTES)
    uint256 public constant NUMBER_OF_SIGNATURES_MASK = 0xffff;
    uint256 public constant SIGNATURE_WITH_INDEX_BYTES = 67; // 1 v + 32 r + 32 s + 2 index
    uint256 public constant SIGNATURE_V_BYTES = 1;
    uint256 public constant SIGNATURE_INDEX_RIGHT_SHIFT_BITS = 240; // 256 - 2*8 = 240

    // Memory slots
    /* solhint-disable const-name-snakecase */
    uint256 public constant M_0 = 0;
    uint256 public constant M_1 = 32;
    uint256 public constant M_2 = 64;
    uint256 public constant M_2_signingPolicyHashTmp = 64;
    uint256 public constant M_3 = 96;
    uint256 public constant M_3_existingSigningPolicyHashTmp = 96;
    uint256 public constant M_4 = 128;
    uint256 public constant M_5_stateData = 160;
    uint256 public constant M_6_signingPolicyLength = 192;
    uint256 public constant ADDRESS_OFFSET = 12;
    /* solhint-enable const-name-snakecase */

    uint256 public lastInitializedRewardEpoch;
    // rewardEpochId => signingPolicyHash
    mapping(uint256 => bytes32) public toSigningPolicyHash;
    // protocolId => votingRoundId => merkleRoot
    mapping(uint256 => mapping(uint256 => bytes32)) public merkleRoots;

    address public signingPolicySetter;

    StateData public stateData;

    /// Only signingPolicySetter address/contract can call this method.
    modifier onlySigningPolicySetter() {
        require(msg.sender == signingPolicySetter, "only sign policy setter");
        _;
    }

    constructor(
        address _signingPolicySetter,
        uint256 _rewardEpochId,
        bytes32 _signingPolicyHash,
        uint8 _randomNumberProtocolId, // TODO - we may want to be able to change this through governance
        uint32 _firstVotingRoundStartSec,
        uint8 _votingRoundDurationSec,
        uint32 _firstRewardEpochStartVotingRoundId,
        uint16 _rewardEpochDurationInVotingEpochs,
        uint16 _thresholdIncreaseBIPS
    ) {
        require(_thresholdIncreaseBIPS >= THRESHOLD_BIPS, "threshold increase too small");
        signingPolicySetter = _signingPolicySetter;
        lastInitializedRewardEpoch = _rewardEpochId;
        toSigningPolicyHash[_rewardEpochId] = _signingPolicyHash;
        stateData.randomNumberProtocolId = _randomNumberProtocolId;
        stateData.firstVotingRoundStartSec = _firstVotingRoundStartSec;
        stateData.votingRoundDurationSec = _votingRoundDurationSec;
        stateData.firstRewardEpochStartVotingRoundId = _firstRewardEpochStartVotingRoundId;
        stateData.rewardEpochDurationInVotingEpochs = _rewardEpochDurationInVotingEpochs;
        stateData.thresholdIncreaseBIPS = _thresholdIncreaseBIPS;
    }

    function setSigningPolicy(
        // using memory instead of calldata as called from another contract where signing policy is already in memory
        Finalisation.SigningPolicy memory _signingPolicy
    ) external onlySigningPolicySetter returns (bytes32) {
        require(
            lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId,
            "not next reward epoch"
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
            bytes32(uint256(0)), // TODO: for this Merkle root should be calculated
            bytes21(uint168(_signingPolicy.seed >> (8 * 11)))
        );

        bytes32 currentHash = keccak256(toHash);
        toHash = bytes.concat(
            currentHash,
            bytes11(bytes32(_signingPolicy.seed << (8 * 21))),
            bytes20(_signingPolicy.voters[0]),
            bytes1(uint8(_signingPolicy.weights[0] >> 8))
        );

        currentHash = keccak256(toHash);

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

    /**
     * ECDSA signature relay
     * Can be called in two modes.
     * (2) Relaying signing policy. The structure of the calldata is:
     *        function signature (4 bytes) + active signing policy (2209 bytes) + 0 (1 byte) + new signing policy (2209 bytes),
     *     total of exactly 4423 bytes.
     * (2) Relaying signed message. The structure of the calldata is:
     *        function signature (4 bytes) + signing policy (2209 bytes) + signed message (38 bytes) + ECDSA signatures with indices (66 bytes each),
     *     total of 2251 + 66 * N bytes, where N is the number of signatures.
     */
    //
    // (1) Initializing with signing policy. This can be done only once, usually after deployment. The calldata should include only signature and signing policy.
    function relay() external {
        // solhint-disable-next-line no-inline-assembly
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

            function assignStruct(structObj, valOffset, valMask, newVal)
                -> newStructObj
            {
                newStructObj := or(
                    and(
                        // zeroing the field
                        structObj,
                        not(
                            // zeroing mask
                            shl(valOffset, valMask)
                        )
                    ),
                    shl(valOffset, newVal)
                )
            }

            function structValue(structObj, valOffset, valMask) -> val {
                val := and(shr(valOffset, structObj), valMask)
            }

            // Helper function to calculate the matching reward epoch id from voting round id
            // Here the constants should be set properly
            function rewardEpochIdFromVotingRoundId(stateDataObj, votingRoundId)
                -> rewardEpochId
            {
                rewardEpochId := div(
                    sub(
                        votingRoundId,
                        structValue(
                            stateDataObj,
                            SD_BOFF_firstRewardEpochVotingRoundId,
                            SD_MASK_firstRewardEpochVotingRoundId
                        )
                    ),
                    structValue(
                        stateDataObj,
                        SD_BOFF_rewardEpochDurationInVotingEpochs,
                        SD_MASK_rewardEpochDurationInVotingEpochs
                    )
                )
            }

            // Helper function to calculate the end time of the voting roujnd
            // Here the constants should be set properly
            function votingRoundEndTime(stateDataObj, votingRoundId)
                -> timeStamp
            {
                timeStamp := add(
                    structValue(
                        stateDataObj,
                        SD_BOFF_firstVotingRoundStartSec,
                        SD_MASK_firstVotingRoundStartSec
                    ),
                    mul(
                        add(votingRoundId, 1),
                        structValue(
                            stateDataObj,
                            SD_BOFF_votingRoundDurationSec,
                            SD_MASK_votingRoundDurationSec
                        )
                    )
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
                // all but last 32-byte word
                let endPos := add(calldataPos, mul(div(policyLength, 32), 32))
                for {
                    let pos := add(calldataPos, 32)
                } lt(pos, endPos) {
                    pos := add(pos, 32)
                } {
                    calldatacopy(add(memPos, M_1), pos, 32)
                    mstore(memPos, keccak256(memPos, 64))
                }

                // handle the remaining bytes
                mstore(add(memPos, M_1), 0)
                calldatacopy(add(memPos, M_1), endPos, mod(policyLength, 32)) // remaining bytes
                mstore(memPos, keccak256(memPos, 64))
                policyHash := mload(memPos)
            }

            // Helper function to assign value to right alligned byte encoded struct like object

            // Constants
            let memPtr := mload(0x40) // free memory pointer
            // NOTE: the struct is packed in reverse order of bytes

            // stateData loaded into memory to slot M_5_stateData
            mstore(add(memPtr, M_5_stateData), sload(stateData.slot))

            // Variables
            let pos := 4 // Calldata position
            let signatureStart := 0 // First index of signatures in calldata

            ///////////// Extracting signing policy metadata /////////////
            if lt(calldatasize(), add(SELECTOR_BYTES, METADATA_BYTES)) {
                revertWithMessage(memPtr, "Invalid sign policy metadata", 28)
            }

            calldatacopy(memPtr, pos, METADATA_BYTES)
            // shift to right of bytes32
            let metadata := shr(sub(256, mul(8, METADATA_BYTES)), mload(memPtr))
            let numberOfVoters := structValue(
                metadata,
                MD_BOFF_numberOfVoters,
                MD_MASK_numberOfVoters
            )
            let rewardEpochId := structValue(
                metadata,
                MD_BOFF_rewardEpochId,
                MD_MASK_rewardEpochId
            )
            let threshold := structValue(
                metadata,
                MD_BOFF_threshold,
                MD_MASK_threshold
            )

            let signingPolicyLength := add(
                SIGNING_POLICY_PREFIX_BYTES,
                mul(numberOfVoters, ADDRESS_AND_WEIGHT_BYTES)
            )
            // storing signingPolicyLength to slot M_6_signingPolicyLength for access when stack is too deep
            mstore(add(memPtr, M_6_signingPolicyLength), signingPolicyLength)

            // The calldata must be of length at least 4 function selector + signingPolicyLength + 1 protocolId
            if lt(
                calldatasize(),
                add(SELECTOR_BYTES, add(signingPolicyLength, PROTOCOL_ID_BYTES))
            ) {
                revertWithMessage(memPtr, "Invalid sign policy length", 26)
            }

            ///////////// Verifying signing policy /////////////
            // signing policy hash temporarily stored to slot M_2
            mstore(
                add(memPtr, M_2_signingPolicyHashTmp),
                calculateSigningPolicyHash(
                    memPtr,
                    SELECTOR_BYTES,
                    signingPolicyLength
                )
            )

            //  toSigningPolicyHash[rewardEpochId] -> existingSigningPolicyHash
            mstore(memPtr, rewardEpochId) // key (rewardEpochId)
            mstore(add(memPtr, M_1), toSigningPolicyHash.slot)

            // store existing signing policy hash to slot M_3 temporarily
            mstore(
                add(memPtr, M_3_existingSigningPolicyHashTmp),
                sload(keccak256(memPtr, 64))
            )

            // From here on we have calldatasize() > 4 + signingPolicyLength

            ///////////// Verifying signing policy /////////////
            if iszero(
                eq(
                    mload(add(memPtr, M_2_signingPolicyHashTmp)),
                    mload(add(memPtr, M_3_existingSigningPolicyHashTmp))
                )
            ) {
                revertWithMessage(memPtr, "Signing policy hash mismatch", 28)
            }
            // jump to protocol message Merkle root
            pos := add(SELECTOR_BYTES, signingPolicyLength)

            // Extracting protocolId, votingRoundId and randomQualityScore
            // 1 bytes - protocolId
            // 4 bytes - votingRoundId
            // 1 bytes - randomQualityScore
            // 32 bytes - merkleRoot
            // message length: 38

            calldatacopy(memPtr, pos, PROTOCOL_ID_BYTES)

            let protocolId := shr(
                sub(256, mul(8, PROTOCOL_ID_BYTES)), // move to the rightmost position
                mload(memPtr)
            )

            let votingRoundId := 0

            ///////////// Preparation of message hash /////////////
            // protocolId > 0 means we are relaying (Mode 2)
            // The signed hash is the message hash and it gets prepared into slot 32
            if gt(protocolId, 0) {
                signatureStart := add(
                    SELECTOR_BYTES,
                    add(signingPolicyLength, MESSAGE_BYTES)
                )
                if lt(calldatasize(), signatureStart) {
                    revertWithMessage(memPtr, "Too short message", 17)
                }
                calldatacopy(memPtr, pos, MESSAGE_BYTES)

                votingRoundId := structValue(
                    shr(sub(256, mul(8, MESSAGE_NO_MR_BYTES)), mload(memPtr)),
                    MSG_NMR_BOFF_votingRoundId,
                    MSG_NMR_MASK_votingRoundId
                )
                // the usual reward epoch id
                let messageRewardEpochId := rewardEpochIdFromVotingRoundId(
                    mload(add(memPtr, M_5_stateData)),
                    votingRoundId
                )

                let startingVotingRoundId := structValue(
                    metadata,
                    MD_BOFF_startingVotingRoundId,
                    MD_MASK_startingVotingRoundId
                )
                // in case the reward epoch id start gets delayed -> signing policy for earlier
                // reward epoch must be provided
                if and(
                    eq(messageRewardEpochId, rewardEpochId),
                    lt(votingRoundId, startingVotingRoundId)
                ) {
                    revertWithMessage(memPtr, "Delayed sign policy", 19)
                }

                // Given a signing policy for reward epoch R one can sign either messages
                // in reward epochs R and R+1 only
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
                    threshold := div(
                        mul(
                            threshold,
                            structValue(
                                mload(add(memPtr, M_5_stateData)),
                                SD_BOFF_thresholdIncrease,
                                SD_MASK_thresholdIncrease
                            )
                        ),
                        THRESHOLD_BIPS
                    )
                }

                // Prepera the message hash into slot 32
                mstore(add(memPtr, M_1), keccak256(memPtr, MESSAGE_BYTES))
            }
            // protocolId == 0 means we are relaying new signing policy (Mode 1)
            // The signed hash is the signing policy hash and it gets prepared into slot 32

            if eq(protocolId, 0) {
                if lt(
                    calldatasize(),
                    add(
                        SELECTOR_BYTES,
                        add(
                            signingPolicyLength,
                            add(PROTOCOL_ID_BYTES, METADATA_BYTES)
                        )
                    )
                ) {
                    revertWithMessage(memPtr, "No new sign policy size", 23)
                }

                // New metadata
                calldatacopy(
                    memPtr,
                    add(
                        SELECTOR_BYTES,
                        add(PROTOCOL_ID_BYTES, signingPolicyLength)
                    ),
                    METADATA_BYTES
                )

                let newMetadata := shr(
                    sub(256, mul(8, METADATA_BYTES)),
                    mload(memPtr)
                )
                let newNumberOfVoters := structValue(
                    newMetadata,
                    MD_BOFF_numberOfVoters,
                    MD_MASK_numberOfVoters
                )

                let newSigningPolicyLength := add(
                    SIGNING_POLICY_PREFIX_BYTES,
                    mul(newNumberOfVoters, ADDRESS_AND_WEIGHT_BYTES)
                )

                signatureStart := add(
                    SELECTOR_BYTES,
                    add(
                        signingPolicyLength,
                        add(PROTOCOL_ID_BYTES, newSigningPolicyLength)
                    )
                )

                if lt(calldatasize(), signatureStart) {
                    revertWithMessage(
                        memPtr,
                        "Wrong size for new sign policy",
                        30
                    )
                }
                let newSigningPolicyRewardEpochId := structValue(
                    newMetadata,
                    MD_BOFF_rewardEpochId,
                    MD_MASK_rewardEpochId
                )

                let tmpLastInitializedRewardEpochId := sload(
                    lastInitializedRewardEpoch.slot
                )
                // Should be next reward epoch id
                if iszero(
                    eq(
                        add(1, tmpLastInitializedRewardEpochId),
                        newSigningPolicyRewardEpochId
                    )
                ) {
                    revertWithMessage(memPtr, "Not next reward epoch", 21)
                }

                let newSigningPolicyHash := calculateSigningPolicyHash(
                    memPtr,
                    add(
                        SELECTOR_BYTES,
                        add(signingPolicyLength, PROTOCOL_ID_BYTES)
                    ),
                    newSigningPolicyLength
                )
                // Write to storage - if signature weight is not sufficient, this will be reverted
                sstore(
                    lastInitializedRewardEpoch.slot,
                    newSigningPolicyRewardEpochId
                )
                // toSigningPolicyHash[newSigningPolicyRewardEpochId] = newSigningPolicyHash
                mstore(memPtr, newSigningPolicyRewardEpochId)
                mstore(add(memPtr, M_1), toSigningPolicyHash.slot)
                sstore(keccak256(memPtr, 64), newSigningPolicyHash)
                // Prepare the hash on slot 32 for signature verification
                mstore(add(memPtr, M_1), newSigningPolicyHash)
            }

            // Assumptions here:
            // - memPtr (slot 0) contains either protocol message merkle root hash or new signing policy hash
            // - signatureStart points to the first signature in calldata
            // - We are sure that calldatasize() >= signatureStart

            // Use M_2 temporarily to extract number of signatures
            // Note that M_1 is used for the hash
            if lt(
                calldatasize(),
                add(signatureStart, NUMBER_OF_SIGNATURES_BYTES)
            ) {
                revertWithMessage(memPtr, "No signature count", 18)
            }

            calldatacopy(
                add(memPtr, M_2),
                signatureStart,
                NUMBER_OF_SIGNATURES_BYTES
            )
            let numberOfSignatures := and(
                shr(
                    NUMBER_OF_SIGNATURES_RIGHT_SHIFT_BITS,
                    mload(add(memPtr, M_2))
                ),
                NUMBER_OF_SIGNATURES_MASK
            )
            signatureStart := add(signatureStart, NUMBER_OF_SIGNATURES_BYTES)
            if lt(
                calldatasize(),
                add(
                    signatureStart,
                    mul(numberOfSignatures, SIGNATURE_WITH_INDEX_BYTES)
                )
            ) {
                revertWithMessage(memPtr, "Not enough signatures", 21)
            }

            // Prefixed hash calculation
            // 4-bytes padded prefix into slot 0
            mstore(memPtr, "0000\x19Ethereum Signed Message:\n32")
            // Prefixed hash into slot 0, skipping 4-bytes of 0-prefix
            mstore(memPtr, keccak256(add(memPtr, 4), 60))

            // Processing signatures. Memory map:
            // memPtr (slot 0)  | prefixedHash
            // M_1              | v
            // M_2              | r, signer
            // M_3              | s, expectedSigner
            // M_4              | index, weight
            mstore(add(memPtr, M_1), 0) // clear v - only the lowest byte will change
            for {
                let i := 0
                // accumulated weight of signatures
                let weight := 0
                // enforces increasing order of indices in signatures
                let nextUnusedIndex := 0
            } lt(i, numberOfSignatures) {
                i := add(i, 1)
            } {
                // signature position
                pos := add(signatureStart, mul(i, SIGNATURE_WITH_INDEX_BYTES))

                // clear v - only the last byte will change
                mstore(add(memPtr, M_1), 0)

                calldatacopy(
                    add(memPtr, add(M_1, sub(32, SIGNATURE_V_BYTES))),
                    pos,
                    SIGNATURE_WITH_INDEX_BYTES
                ) // 63 ... last byte of slot +32
                // Note that those things get set
                // - slot M_1 - the rightmost byte of 'v' gets set
                // - slot M_2    - r
                // - slot M_3    - s
                // - slot M_4   - index (only the top 2 bytes)
                let index := shr(
                    SIGNATURE_INDEX_RIGHT_SHIFT_BITS,
                    mload(add(memPtr, M_4))
                )

                // Index sanity checks in regard to signing policy
                if gt(index, sub(numberOfVoters, 1)) {
                    revertWithMessage(memPtr, "Index out of range", 18)
                }

                if lt(index, nextUnusedIndex) {
                    revertWithMessage(memPtr, "Index out of order", 18)
                }
                nextUnusedIndex := add(index, 1)

                // ecrecover call. Address goes to slot 64, it is 0 padded
                if iszero(
                    staticcall(not(0), 0x01, memPtr, 0x80, add(memPtr, M_2), 32)
                ) {
                    revertWithMessage(memPtr, "ecrecover error", 15)
                }
                // extract expected signer address to slot no 96
                mstore(add(memPtr, M_3), 0) // zeroing slot for expected address

                // position of address on 'index': 4 + 20 + index x 22 (expectedSigner)
                let addressPos := add(
                    add(SELECTOR_BYTES, SIGNING_POLICY_PREFIX_BYTES),
                    mul(index, ADDRESS_AND_WEIGHT_BYTES)
                )

                calldatacopy(
                    add(memPtr, add(M_3, ADDRESS_OFFSET)),
                    addressPos,
                    ADDRESS_BYTES
                )

                // Check if the recovered signer is the expected signer
                if iszero(
                    eq(mload(add(memPtr, M_2)), mload(add(memPtr, M_3)))
                ) {
                    revertWithMessage(memPtr, "Wrong signature", 15)
                }

                // extract weight, reuse field for r (slot 64)
                mstore(add(memPtr, M_2), 0) // clear r field

                calldatacopy(
                    add(memPtr, add(M_2, sub(32, WEIGHT_BYTES))), // weight copied to the right of slot M2
                    add(addressPos, ADDRESS_BYTES),
                    WEIGHT_BYTES
                )
                weight := add(weight, mload(add(memPtr, M_2)))

                if gt(weight, threshold) {
                    // redefinition of memPtr to avoid stack too deep
                    let memPtrDup := memPtr
                    // jump over fun selector, signing policy and 17 bytes of protocolId,
                    // votingRoundId and randomQualityScore
                    pos := add(
                        add(SELECTOR_BYTES, signingPolicyLength),
                        sub(MESSAGE_BYTES, 32)
                    ) // last 32 bytes are merkleRoot
                    calldatacopy(memPtrDup, pos, 32)
                    let merkleRoot := mload(memPtrDup)
                    // writing into the map
                    mstore(memPtrDup, protocolId) // key 1 (protocolId)
                    mstore(add(memPtrDup, M_1), merkleRoots.slot) // merkleRoot slot

                    mstore(add(memPtrDup, M_1), keccak256(memPtrDup, 64)) // parent map location in slot for next hashing
                    mstore(memPtrDup, votingRoundId) // key 2 (votingRoundId)
                    sstore(keccak256(memPtrDup, 64), merkleRoot) // merkleRoot stored at merkleRoots[protocolId][votingRoundId]

                    // stateData.randomVotingRoundId = votingRoundId
                    let stateDataTemp := mload(add(memPtrDup, M_5_stateData))
                    stateDataTemp := assignStruct(
                        stateDataTemp,
                        SD_BOFF_randomVotingRoundId,
                        SD_MASK_randomVotingRoundId,
                        votingRoundId
                    )

                    // stateData.randomNumberQualityScore = message.randomQualityScore
                    calldatacopy(
                        memPtrDup,
                        add(SELECTOR_BYTES, signingPolicyLength),
                        MESSAGE_NO_MR_BYTES
                    )
                    mstore(
                        memPtrDup,
                        shr(
                            sub(256, mul(8, MESSAGE_NO_MR_BYTES)),
                            mload(memPtrDup)
                        )
                    ) // move message no mr right

                    stateDataTemp := assignStruct(
                        stateDataTemp,
                        SD_BOFF_randomNumberQualityScore,
                        SD_MASK_randomNumberQualityScore,
                        structValue(
                            mload(memPtrDup),
                            MSG_NMR_BOFF_randomQualityScore,
                            MSG_NMR_MASK_randomQualityScore
                        )
                    )

                    sstore(stateData.slot, stateDataTemp)

                    return(0, 0) // all done
                }
            }
        }
        revert("Not enough weight");
    }

    function getRandomNumber()
        external
        view
        returns (
            uint256 _randomNumber,
            bool _randomNumberQualityScore,
            uint32 _randomTimestamp
        )
    {
        _randomNumber = uint256(
            merkleRoots[stateData.randomNumberProtocolId][
                stateData.randomVotingRoundId
            ]
        );
        _randomNumberQualityScore = stateData.randomNumberQualityScore;
        _randomTimestamp =
            stateData.firstVotingRoundStartSec +
            (stateData.randomVotingRoundId + 1) *
            stateData.votingRoundDurationSec;
    }
}
