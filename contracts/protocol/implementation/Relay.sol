// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// import "hardhat/console.sol";

contract Relay {
    // IMPORTANT: if you change this, you have to adapt the assembly writing into this in the relay() function
    struct StateData {
        uint8 randomNumberProtocolId;
        uint32 firstVotingRoundStartTs;
        uint8 votingEpochDurationSeconds;
        uint32 firstRewardEpochStartVotingRoundId;
        uint16 rewardEpochDurationInVotingEpochs;
        uint16 thresholdIncreaseBIPS;
        uint32 randomVotingRoundId;
        bool randomNumberQualityScore;
    }

    struct SigningPolicy {
        uint24 rewardEpochId;       // Reward epoch id.
        uint32 startVotingRoundId;  // First voting round id of validity.
                                    // Usually it is the first voting round of reward epoch rID.
                                    // It can be later,
                                    // if the confirmation of the signing policy on Flare blockchain gets delayed.
        uint16 threshold;           // Confirmation threshold (absolute value of noramalised weights).
        uint256 seed;               // Random seed.
        address[] voters;           // The list of eligible voters in the canonical order.
        uint16[] weights;           // The corresponding list of normalised signing weights of eligible voters.
                                    // Normalisation is done by compressing the weights from 32-byte values to 2 bytes,
                                    // while approximately keeping the weight relations.
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
    uint256 public constant WEIGHT_MASK = 0xffff;
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
    uint256 public constant SD_MASK_firstVotingRoundStartTs = 0xffffffff;
    uint256 public constant SD_BOFF_firstVotingRoundStartTs = 8;
    uint256 public constant SD_MASK_votingEpochDurationSeconds = 0xff;
    uint256 public constant SD_BOFF_votingEpochDurationSeconds = 40;
    uint256 public constant SD_MASK_firstRewardEpochStartVotingRoundId =
        0xffffffff;
    uint256 public constant SD_BOFF_firstRewardEpochStartVotingRoundId = 48;
    uint256 public constant SD_MASK_rewardEpochDurationInVotingEpochs = 0xffff;
    uint256 public constant SD_BOFF_rewardEpochDurationInVotingEpochs = 80;
    uint256 public constant SD_MASK_thresholdIncreaseBIPS = 0xffff;
    uint256 public constant SD_BOFF_thresholdIncreaseBIPS = 96;
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
        uint256 _initialRewardEpochId,
        bytes32 _initialSigningPolicyHash,
        uint8 _randomNumberProtocolId, // TODO - we may want to be able to change this through governance
        uint32 _firstVotingRoundStartTs,
        uint8 _votingEpochDurationSeconds,
        uint32 _firstRewardEpochStartVotingRoundId,
        uint16 _rewardEpochDurationInVotingEpochs,
        uint16 _thresholdIncreaseBIPS
    ) {
        require(
            _thresholdIncreaseBIPS >= THRESHOLD_BIPS,
            "threshold increase too small"
        );
        signingPolicySetter = _signingPolicySetter;
        lastInitializedRewardEpoch = _initialRewardEpochId;
        toSigningPolicyHash[_initialRewardEpochId] = _initialSigningPolicyHash;
        stateData.randomNumberProtocolId = _randomNumberProtocolId;
        stateData.firstVotingRoundStartTs = _firstVotingRoundStartTs;
        stateData.votingEpochDurationSeconds = _votingEpochDurationSeconds;
        stateData
            .firstRewardEpochStartVotingRoundId = _firstRewardEpochStartVotingRoundId;
        stateData
            .rewardEpochDurationInVotingEpochs = _rewardEpochDurationInVotingEpochs;
        stateData.thresholdIncreaseBIPS = _thresholdIncreaseBIPS;
    }

    function setSigningPolicy(
        // using memory instead of calldata as called from another contract where signing policy is already in memory
        SigningPolicy memory _signingPolicy
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
     * Finalization function for new signing policies and protocol messages.
     * It can be used as finalization contract on Flare chain or as relay contract on other EVM chain.
     * Can be called in two modes. It expects calldata that is parsed in a custom manner. 
     * Hence the transaction calls should assemble relevant calldata in the 'data' field. 
     * Depending on the data provided, the contract operations in essentially two modes:
     * (1) Relaying signing policy. The structure of the calldata is:
     *        function signature (4 bytes) + active signing policy (2209 bytes) 
     *             + 0 (1 byte) + new signing policy (2209 bytes),
     *     total of exactly 4423 bytes.
     * (2) Relaying signed message. The structure of the calldata is:
     *        function signature (4 bytes) + signing policy (2209 bytes) 
     *           + signed message (38 bytes) + ECDSA signatures with indices (66 bytes each),
     *     total of 2251 + 66 * N bytes, where N is the number of signatures.
     */
    function relay() external returns (uint256 _result) {
        // 0 - not relayed
        // 1 - relayed
        // 2 - relayed and priority checked
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Helper function to revert with a message
            // Since string length cannot be determined in assembly easily, the matching length 
            // of the message string must be provided.
            function revertWithMessage(_memPtr, _message, _msgLength) {
                mstore(
                    _memPtr,
                    0x08c379a000000000000000000000000000000000000000000000000000000000
                )
                mstore(add(_memPtr, 0x04), 0x20) // String offset
                mstore(add(_memPtr, 0x24), _msgLength) // Revert reason length
                mstore(add(_memPtr, 0x44), _message)
                revert(_memPtr, 0x64) // Revert data length is 4 bytes for selector and 3 slots of 0x20 bytes
            }

            function revertWithValue(_memPtr, _val) {
                mstore(_memPtr, _val)
                revert(_memPtr, 0x20)
            }

            function assignStruct(_structObj, _valOffset, _valMask, newVal)
                -> _newStructObj
            {
                _newStructObj := or(
                    and(
                        // zeroing the field
                        _structObj,
                        not(
                            // zeroing mask
                            shl(_valOffset, _valMask)
                        )
                    ),
                    shl(_valOffset, newVal)
                )
            }

            function structValue(_structObj, _valOffset, _valMask) -> _val {
                _val := and(shr(_valOffset, _structObj), _valMask)
            }

            // Helper function to calculate the matching reward epoch id from voting round id
            // Here the constants should be set properly
            function rewardEpochIdFromVotingRoundId(
                _stateDataObj,
                _votingRoundId
            ) -> _rewardEpochId {
                _rewardEpochId := div(
                    sub(
                        _votingRoundId,
                        structValue(
                            _stateDataObj,
                            SD_BOFF_firstRewardEpochStartVotingRoundId,
                            SD_MASK_firstRewardEpochStartVotingRoundId
                        )
                    ),
                    structValue(
                        _stateDataObj,
                        SD_BOFF_rewardEpochDurationInVotingEpochs,
                        SD_MASK_rewardEpochDurationInVotingEpochs
                    )
                )
            }

            // Helper function to calculate the end time of the voting roujnd
            // Here the constants should be set properly
            function votingRoundEndTime(_stateDataObj, _votingRoundId)
                -> _timestamp
            {
                _timestamp := add(
                    structValue(
                        _stateDataObj,
                        SD_BOFF_firstVotingRoundStartTs,
                        SD_MASK_firstVotingRoundStartTs
                    ),
                    mul(
                        add(_votingRoundId, 1),
                        structValue(
                            _stateDataObj,
                            SD_BOFF_votingEpochDurationSeconds,
                            SD_MASK_votingEpochDurationSeconds
                        )
                    )
                )
            }

            // Helper function to calculate the signing policy hash while trying to minimize the usage of memory
            // Uses slots 0 and 32
            function calculateSigningPolicyHash(
                _memPos,
                _calldataPos,
                _policyLength
            ) -> _policyHash {
                // first byte
                calldatacopy(_memPos, _calldataPos, 32)
                // all but last 32-byte word
                let endPos := add(_calldataPos, mul(div(_policyLength, 32), 32))
                for {
                    let pos := add(_calldataPos, 32)
                } lt(pos, endPos) {
                    pos := add(pos, 32)
                } {
                    calldatacopy(add(_memPos, M_1), pos, 32)
                    mstore(_memPos, keccak256(_memPos, 64))
                }

                // handle the remaining bytes
                mstore(add(_memPos, M_1), 0)
                calldatacopy(add(_memPos, M_1), endPos, mod(_policyLength, 32)) // remaining bytes
                mstore(_memPos, keccak256(_memPos, 64))
                _policyHash := mload(_memPos)
            }

            function extractVotingRoundIdFromMessage(
                _memPtr,
                _signingPolicyLength
            ) -> _votingRoundId {
                calldatacopy(
                    _memPtr,
                    add(SELECTOR_BYTES, _signingPolicyLength),
                    MESSAGE_NO_MR_BYTES
                )

                _votingRoundId := structValue(
                    shr(sub(256, mul(8, MESSAGE_NO_MR_BYTES)), mload(_memPtr)),
                    MSG_NMR_BOFF_votingRoundId,
                    MSG_NMR_MASK_votingRoundId
                )
            }

            // Helper function to assign value to right alligned byte encoded struct like object

            // Constants
            let memPtr := mload(0x40) // free memory pointer
            // NOTE: the struct is packed in reverse order of bytes

            // stateData loaded into memory to slot M_5_stateData
            mstore(add(memPtr, M_5_stateData), sload(stateData.slot))

            ///////////// Extracting signing policy metadata /////////////
            if lt(calldatasize(), add(SELECTOR_BYTES, METADATA_BYTES)) {
                revertWithMessage(memPtr, "Invalid sign policy metadata", 28)
            }

            calldatacopy(memPtr, SELECTOR_BYTES, METADATA_BYTES)
            // shift to right of bytes32
            let metadata := shr(sub(256, mul(8, METADATA_BYTES)), mload(memPtr))
            let rewardEpochId := structValue(
                metadata,
                MD_BOFF_rewardEpochId,
                MD_MASK_rewardEpochId
            )

            let signingPolicyLength := add(
                SIGNING_POLICY_PREFIX_BYTES,
                mul(
                    structValue(
                        metadata,
                        MD_BOFF_numberOfVoters,
                        MD_MASK_numberOfVoters
                    ),
                    ADDRESS_AND_WEIGHT_BYTES
                )
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

            // Extracting protocolId, votingRoundId and randomQualityScore
            // 1 bytes - protocolId
            // 4 bytes - votingRoundId
            // 1 bytes - randomQualityScore
            // 32 bytes - merkleRoot
            // message length: 38

            calldatacopy(
                memPtr,
                add(SELECTOR_BYTES, signingPolicyLength),
                PROTOCOL_ID_BYTES
            )

            let protocolId := shr(
                sub(256, mul(8, PROTOCOL_ID_BYTES)), // move to the rightmost position
                mload(memPtr)
            )

            let signatureStart := 0 // First index of signatures in calldata
            let threshold := structValue(
                metadata,
                MD_BOFF_threshold,
                MD_MASK_threshold
            )

            ///////////// Preparation of message hash /////////////
            // protocolId > 0 means we are relaying (Mode 2)
            // The signed hash is the message hash and it gets prepared into slot 32
            if gt(protocolId, 0) {
                let memPtrGP0 := mload(0x40)
                signatureStart := add(
                    SELECTOR_BYTES,
                    add(signingPolicyLength, MESSAGE_BYTES)
                )
                if lt(calldatasize(), signatureStart) {
                    revertWithMessage(memPtrGP0, "Too short message", 17)
                }

                calldatacopy(
                    memPtrGP0,
                    add(SELECTOR_BYTES, signingPolicyLength),
                    MESSAGE_BYTES
                )

                let votingRoundId := structValue(
                    shr(
                        sub(256, mul(8, MESSAGE_NO_MR_BYTES)),
                        mload(memPtrGP0)
                    ),
                    MSG_NMR_BOFF_votingRoundId,
                    MSG_NMR_MASK_votingRoundId
                )

                // the usual reward epoch id
                let messageRewardEpochId := rewardEpochIdFromVotingRoundId(
                    mload(add(memPtrGP0, M_5_stateData)),
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
                    revertWithMessage(memPtrGP0, "Delayed sign policy", 19)
                }

                // Given a signing policy for reward epoch R one can sign either messages
                // in reward epochs R and R+1 only
                if or(
                    gt(messageRewardEpochId, add(rewardEpochId, 1)),
                    lt(messageRewardEpochId, rewardEpochId)
                ) {
                    revertWithMessage(
                        memPtrGP0,
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
                                mload(add(memPtrGP0, M_5_stateData)),
                                SD_BOFF_thresholdIncreaseBIPS,
                                SD_MASK_thresholdIncreaseBIPS
                            )
                        ),
                        THRESHOLD_BIPS
                    )
                }

                // Prepera the message hash into slot 32
                mstore(add(memPtrGP0, M_1), keccak256(memPtrGP0, MESSAGE_BYTES))
            }

            // protocolId == 0 means we are relaying new signing policy (Mode 1)
            // The signed hash is the signing policy hash and it gets prepared into slot 32

            if eq(protocolId, 0) {
                let memPtrP0 := mload(0x40)

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
                    revertWithMessage(memPtrP0, "No new sign policy size", 23)
                }

                // New metadata
                calldatacopy(
                    memPtrP0,
                    add(
                        SELECTOR_BYTES,
                        add(PROTOCOL_ID_BYTES, signingPolicyLength)
                    ),
                    METADATA_BYTES
                )

                let newMetadata := shr(
                    sub(256, mul(8, METADATA_BYTES)),
                    mload(memPtrP0)
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
                        memPtrP0,
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
                    revertWithMessage(memPtrP0, "Not next reward epoch", 21)
                }

                let newSigningPolicyHash := calculateSigningPolicyHash(
                    memPtrP0,
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
                mstore(memPtrP0, newSigningPolicyRewardEpochId)
                mstore(add(memPtrP0, M_1), toSigningPolicyHash.slot)
                sstore(keccak256(memPtrP0, 64), newSigningPolicyHash)
                // Prepare the hash on slot 32 for signature verification
                mstore(add(memPtrP0, M_1), newSigningPolicyHash)
                // IMPORTANT: assumes that if threshold is not sufficient, the transaction will be reverted
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
                let numberOfVoters := structValue(
                    metadata,
                    MD_BOFF_numberOfVoters,
                    MD_MASK_numberOfVoters
                )
                let i := 0
                // accumulated weight of signatures
                let weight := 0
                // enforces increasing order of indices in signatures
                let nextUnusedIndex := 0
                let memPtrFor := mload(0x40)
            } lt(i, numberOfSignatures) {
                i := add(i, 1)
            } {
                // clear v - only the last byte will change
                mstore(add(memPtrFor, M_1), 0)

                calldatacopy(
                    add(memPtrFor, add(M_1, sub(32, SIGNATURE_V_BYTES))),
                    add(signatureStart, mul(i, SIGNATURE_WITH_INDEX_BYTES)), // signature position
                    SIGNATURE_WITH_INDEX_BYTES
                ) // 63 ... last byte of slot +32
                // Note that those things get set
                // - slot M_1 - the rightmost byte of 'v' gets set
                // - slot M_2    - r
                // - slot M_3    - s
                // - slot M_4   - index (only the top 2 bytes)
                let index := shr(
                    SIGNATURE_INDEX_RIGHT_SHIFT_BITS,
                    mload(add(memPtrFor, M_4))
                )

                // Index sanity checks in regard to signing policy
                if gt(index, sub(numberOfVoters, 1)) {
                    revertWithMessage(memPtrFor, "Index out of range", 18)
                }

                if lt(index, nextUnusedIndex) {
                    revertWithMessage(memPtrFor, "Index out of order", 18)
                }
                nextUnusedIndex := add(index, 1)

                // ecrecover call. Address goes to slot 64, it is 0 padded
                if iszero(
                    staticcall(
                        not(0),
                        0x01,
                        memPtrFor,
                        0x80,
                        add(memPtrFor, M_2),
                        32
                    )
                ) {
                    revertWithMessage(memPtrFor, "ecrecover error", 15)
                }
                // extract expected signer address to slot no 96
                mstore(add(memPtrFor, M_3), 0) // zeroing slot for expected address

                calldatacopy(
                    add(memPtrFor, sub(add(M_3, ADDRESS_OFFSET), WEIGHT_BYTES)),
                    add(
                        add(SELECTOR_BYTES, SIGNING_POLICY_PREFIX_BYTES),
                        mul(index, ADDRESS_AND_WEIGHT_BYTES)
                    ),
                    ADDRESS_AND_WEIGHT_BYTES
                )

                // Check if the recovered signer is the expected signer
                if iszero(
                    eq(
                        mload(add(memPtrFor, M_2)),
                        shr(mul(8, WEIGHT_BYTES), mload(add(memPtrFor, M_3))) // keep the address only
                    )
                ) {
                    revertWithMessage(memPtrFor, "Wrong signature", 15)
                }

                weight := add(
                    weight,
                    and(mload(add(memPtrFor, M_3)), WEIGHT_MASK)
                )

                if gt(weight, threshold) {                    
                    // If relaying messages, store the Merkle root
                    if gt(protocolId, 0) {
                        let votingRoundId := extractVotingRoundIdFromMessage(
                            memPtrFor,
                            signingPolicyLength
                        )
                        // M_3 <- Merkle root
                        calldatacopy(
                            add(memPtrFor, M_3),
                            add(
                                add(SELECTOR_BYTES, signingPolicyLength),
                                sub(MESSAGE_BYTES, 32) // last 32 bytes are merkleRoot
                            ),
                            32
                        )

                        // writing into the map
                        mstore(memPtrFor, protocolId) // key 1 (protocolId)
                        mstore(add(memPtrFor, M_1), merkleRoots.slot) // merkleRoot slot

                        // parent map location in slot for next hashing
                        mstore(add(memPtrFor, M_1), keccak256(memPtrFor, 64))
                        mstore(memPtrFor, votingRoundId) // key 2 (votingRoundId)
                        // merkleRoot stored at merkleRoots[protocolId][votingRoundId]
                        sstore(
                            keccak256(memPtrFor, 64),
                            mload(add(memPtrFor, M_3))
                        ) // set Merkle Root

                        // if protocolId == stateData.randomNumberProtocolId
                        if eq(
                            protocolId,
                            structValue(
                                mload(add(memPtrFor, M_5_stateData)),
                                SD_BOFF_randomNumberProtocolId,
                                SD_MASK_randomNumberProtocolId
                            )
                        ) {
                            
                            // stateData.randomVotingRoundId = votingRoundId
                            mstore(
                                add(memPtrFor, M_5_stateData),
                                assignStruct(
                                    mload(add(memPtrFor, M_5_stateData)),
                                    SD_BOFF_randomVotingRoundId,
                                    SD_MASK_randomVotingRoundId,
                                    votingRoundId
                                )
                            )

                            // stateData.randomNumberQualityScore = message.randomQualityScore
                            calldatacopy(
                                memPtrFor,
                                add(SELECTOR_BYTES, signingPolicyLength),
                                MESSAGE_NO_MR_BYTES
                            )
                            mstore(
                                memPtrFor,
                                shr(
                                    sub(256, mul(8, MESSAGE_NO_MR_BYTES)),
                                    mload(memPtrFor)
                                )
                            )

                            mstore(
                                add(memPtrFor, M_5_stateData),
                                assignStruct(
                                    mload(add(memPtrFor, M_5_stateData)),
                                    SD_BOFF_randomNumberQualityScore,
                                    SD_MASK_randomNumberQualityScore,
                                    structValue(
                                        mload(memPtrFor),
                                        MSG_NMR_BOFF_randomQualityScore,
                                        MSG_NMR_MASK_randomQualityScore
                                    )
                                )
                            )

                            sstore(
                                stateData.slot,
                                mload(add(memPtrFor, M_5_stateData))
                            )
                        } // if protocolId == stateData.randomNumberProtocolId
                    } // if protocolId > 0
                    // set _result to 1 to indicate successful relay/finalization
                    _result := 1
                    break
                }
            } // for

            // NO CODE SHOULD BE ADDED HERE
        } // assembly
        if (_result == 0) {
            revert("Not enough weight");
        }
        // _result is 1
        // TODO: check if cryptographic sortition proof is valid. If so, return 2
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
            stateData.firstVotingRoundStartTs +
            (stateData.randomVotingRoundId + 1) *
            stateData.votingEpochDurationSeconds;
    }

    function getVotingRoundId(
        uint256 _timestamp
    ) external view returns (uint256) {
        require(
            _timestamp >= stateData.firstVotingRoundStartTs,
            "before the start"
        );
        return
            (_timestamp - stateData.firstVotingRoundStartTs) /
            stateData.votingEpochDurationSeconds;
    }
}
