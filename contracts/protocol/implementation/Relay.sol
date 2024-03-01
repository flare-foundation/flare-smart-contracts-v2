// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IIRelay.sol";

contract Relay is IIRelay {
    /**
     * State variables for the relay contract
     * IMPORTANT: if you change this, you have to adapt the assembly code interacting with
     * the struct with relay() function
     */
    struct StateData {
        /// The protocol id of the random number protocol
        uint8 randomNumberProtocolId;
        /// The timestamp of the first voting round start
        uint32 firstVotingRoundStartTs;
        /// The duration of a voting epoch in seconds
        uint8 votingEpochDurationSeconds;
        /// The voting round id of the first reward epoch
        uint32 firstRewardEpochStartVotingRoundId;
        /// The duration of a reward epoch in voting epochs
        uint16 rewardEpochDurationInVotingEpochs;
        /// The threshold increase in BIPS for signing with old signing policy
        uint16 thresholdIncreaseBIPS;

        /// Publication of current random number
        /// The voting round id of the random number generation
        uint32 randomVotingRoundId;
        /// If true, the random number is generated secure
        bool isSecureRandom;

        /// The last reward epoch id for which the signing policy has been initialized
        uint32 lastInitializedRewardEpoch;

        /// If true, signing policy relay is disabled
        bool noSigningPolicyRelay;
    }

    // Auxilary struct for memory variables
    struct Counters {
        uint256 weightIndex;
        uint256 weightPos;
        uint256 voterIndex;
        uint256 voterPos;
        uint256 count;
        uint256 bytesToTake;
        bytes32 nextSlot;
        uint256 pos;
        uint256 signingPolicyPos;
    }

    uint256 private constant THRESHOLD_BIPS = 10000;
    uint256 private constant SELECTOR_BYTES = 4;
    uint256 private constant MAX_VOTERS = 300;
    uint256 private constant MIN_THRESHOLD_BIPS = 5000;
    uint256 private constant MAX_THRESHOLD_BIPS = 6600;

    // Signing policy byte encoding structure
    // 2 bytes - numberOfVoters
    // 3 bytes - rewardEpochId
    // 4 bytes - startingVotingRoundId
    // 2 bytes - threshold
    // 32 bytes - randomSeed
    // array of 'size':
    // - 20 bytes address
    // - 2 bytes weight
    // Total 43 + size * (20 + 2) bytes
    // metadataLength = 11 bytes (size, rewardEpochId, startingVotingRoundId, threshold)

    /* solhint-disable const-name-snakecase */
    uint256 private constant METADATA_BYTES = 11;
    uint256 private constant MD_MASK_threshold = 0xffff;
    uint256 private constant MD_BOFF_threshold = 0;
    uint256 private constant MD_MASK_startingVotingRoundId = 0xffffffff;
    uint256 private constant MD_BOFF_startingVotingRoundId = 16;
    uint256 private constant MD_MASK_rewardEpochId = 0xffffff;
    uint256 private constant MD_BOFF_rewardEpochId = 48;
    uint256 private constant MD_MASK_numberOfVoters = 0xffff;
    uint256 private constant MD_BOFF_numberOfVoters = 72;
    /* solhint-enable const-name-snakecase */

    uint256 private constant RANDOM_SEED_BYTES = 32;
    uint256 private constant ADDRESS_BYTES = 20;
    uint256 private constant WEIGHT_BYTES = 2;
    uint256 private constant WEIGHT_MASK = 0xffff;
    uint256 private constant ADDRESS_AND_WEIGHT_BYTES = 22; // ADDRESS_BYTES + WEIGHT_BYTES;
    //METADATA_BYTES + RANDOM_SEED_BYTES;
    uint256 private constant SIGNING_POLICY_PREFIX_BYTES = 43;

    // Protocol message merkle root structure
    // 1 byte - protocolId
    // 4 bytes - votingRoundId
    // 1 byte - isSecureRandom
    // 32 bytes - merkleRoot
    // Total 38 bytes
    // if loaded into a memory slot, these are right shifts and masks
    /* solhint-disable const-name-snakecase */
    uint256 private constant MESSAGE_BYTES = 38;
    uint256 private constant PROTOCOL_ID_BYTES = 1;
    uint256 private constant MESSAGE_NO_MR_BYTES = 6;
    uint256 private constant MSG_NMR_MASK_isSecureRandom = 0xff;
    uint256 private constant MSG_NMR_BOFF_isSecureRandom = 0;
    uint256 private constant MSG_NMR_MASK_votingRoundId = 0xffffffff;
    uint256 private constant MSG_NMR_BOFF_votingRoundId = 8;
    uint256 private constant MSG_NMR_MASK_protocolId = 0xff;
    uint256 private constant MSG_NMR_BOFF_protocolId = 40;
    /* solhint-enable const-name-snakecase */

    /* solhint-disable const-name-snakecase */
    uint256 private constant SD_MASK_randomNumberProtocolId = 0xff;
    uint256 private constant SD_BOFF_randomNumberProtocolId = 0;
    uint256 private constant SD_MASK_firstVotingRoundStartTs = 0xffffffff;
    uint256 private constant SD_BOFF_firstVotingRoundStartTs = 8;
    uint256 private constant SD_MASK_votingEpochDurationSeconds = 0xff;
    uint256 private constant SD_BOFF_votingEpochDurationSeconds = 40;
    uint256 private constant SD_MASK_firstRewardEpochStartVotingRoundId = 0xffffffff;
    uint256 private constant SD_BOFF_firstRewardEpochStartVotingRoundId = 48;
    uint256 private constant SD_MASK_rewardEpochDurationInVotingEpochs = 0xffff;
    uint256 private constant SD_BOFF_rewardEpochDurationInVotingEpochs = 80;
    uint256 private constant SD_MASK_thresholdIncreaseBIPS = 0xffff;
    uint256 private constant SD_BOFF_thresholdIncreaseBIPS = 96;
    uint256 private constant SD_MASK_randomVotingRoundId = 0xffffffff;
    uint256 private constant SD_BOFF_randomVotingRoundId = 112;
    uint256 private constant SD_MASK_isSecureRandom = 0xff;
    uint256 private constant SD_BOFF_isSecureRandom = 144;
    uint256 private constant SD_MASK_lastInitializedRewardEpoch = 0xffffffff;
    uint256 private constant SD_BOFF_lastInitializedRewardEpoch = 152;
    uint256 private constant SD_MASK_noSigningPolicyRelay = 0xff;
    uint256 private constant SD_BOFF_noSigningPolicyRelay = 184;
    /* solhint-enable const-name-snakecase */

    // Signature with index structure
    // 1 byte - v
    // 32 bytes - r
    // 32 bytes - s
    // 2 byte - index in signing policy
    // Total 67 bytes

    uint256 private constant NUMBER_OF_SIGNATURES_BYTES = 2;
    uint256 private constant NUMBER_OF_SIGNATURES_RIGHT_SHIFT_BITS = 240; // 8 * (32 - NUMBER_OF_SIGNATURES_BYTES)
    uint256 private constant NUMBER_OF_SIGNATURES_MASK = 0xffff;
    uint256 private constant SIGNATURE_WITH_INDEX_BYTES = 67; // 1 v + 32 r + 32 s + 2 index
    uint256 private constant SIGNATURE_V_BYTES = 1;
    uint256 private constant SIGNATURE_INDEX_RIGHT_SHIFT_BITS = 240; // 256 - 2*8 = 240

    // Memory slots
    /* solhint-disable const-name-snakecase */
    uint256 private constant M_0 = 0;
    uint256 private constant M_1 = 32;
    uint256 private constant M_2 = 64;
    uint256 private constant M_2_signingPolicyHashTmp = 64;
    uint256 private constant M_3 = 96;
    uint256 private constant M_3_existingSigningPolicyHashTmp = 96;
    uint256 private constant M_4 = 128;
    uint256 private constant M_5_stateData = 160;
    uint256 private constant M_5_isSecureRandom = 160;
    uint256 private constant M_6_merkleRoot = 192;

    uint256 private constant ADDRESS_OFFSET = 12;
    /* solhint-enable const-name-snakecase */

    // rewardEpochId => signingPolicyHash
    mapping(uint256 rewardEpochId => bytes32) public toSigningPolicyHash;
    // protocolId => votingRoundId => merkleRoot
    //slither-disable-next-line uninitialized-state
    mapping(uint256 protocolId => mapping(uint256 votingRoundId => bytes32)) public merkleRoots;
    // rewardEpochId => startingVotingRoundId
    mapping(uint256 rewardEpochId => uint256) public startingVotingRoundIds;

    address public signingPolicySetter;

    StateData public stateData;

    /// Only signingPolicySetter address/contract can call this method.
    modifier onlySigningPolicySetter() {
        require(msg.sender == signingPolicySetter, "only sign policy setter");
        _;
    }

    constructor(
        address _signingPolicySetter,
        uint32 _initialRewardEpochId,
        uint32 _startingVotingRoundIdForInitialRewardEpochId,
        bytes32 _initialSigningPolicyHash,
        uint8 _randomNumberProtocolId,
        uint32 _firstVotingRoundStartTs,
        uint8 _votingEpochDurationSeconds,
        uint32 _firstRewardEpochStartVotingRoundId,
        uint16 _rewardEpochDurationInVotingEpochs,
        uint16 _thresholdIncreaseBIPS
    ) {
        require(_thresholdIncreaseBIPS >= THRESHOLD_BIPS, "threshold increase too small");
        require(_firstRewardEpochStartVotingRoundId + _initialRewardEpochId * _rewardEpochDurationInVotingEpochs <=
            _startingVotingRoundIdForInitialRewardEpochId, "invalid initial starting voting round id");
        signingPolicySetter = _signingPolicySetter;
        stateData.lastInitializedRewardEpoch = _initialRewardEpochId;
        startingVotingRoundIds[_initialRewardEpochId] = _startingVotingRoundIdForInitialRewardEpochId;
        toSigningPolicyHash[_initialRewardEpochId] = _initialSigningPolicyHash;
        stateData.randomNumberProtocolId = _randomNumberProtocolId;
        stateData.firstVotingRoundStartTs = _firstVotingRoundStartTs;
        stateData.votingEpochDurationSeconds = _votingEpochDurationSeconds;
        stateData.firstRewardEpochStartVotingRoundId = _firstRewardEpochStartVotingRoundId;
        stateData.rewardEpochDurationInVotingEpochs = _rewardEpochDurationInVotingEpochs;
        stateData.thresholdIncreaseBIPS = _thresholdIncreaseBIPS;
        if(signingPolicySetter != address(0)) {
            stateData.noSigningPolicyRelay = true;
        }
    }

    /**
     * @inheritdoc IIRelay
     */
    function setSigningPolicy(
        // using memory instead of calldata as called from another contract where signing policy is already in memory
        SigningPolicy memory _signingPolicy
    ) external onlySigningPolicySetter returns (bytes32) {
        require(
            stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId,
            "not next reward epoch"
        );
        require(_signingPolicy.voters.length > 0, "must be non-trivial");
        require(_signingPolicy.voters.length <= MAX_VOTERS, "too many voters");
        require(
            _signingPolicy.voters.length == _signingPolicy.weights.length,
            "size mismatch"
        );
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < _signingPolicy.weights.length; i++) {
            totalWeight += _signingPolicy.weights[i];
        }
        require(totalWeight < 2**16, "total weight too big");
        require(
            uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) >= totalWeight * MIN_THRESHOLD_BIPS, 
            "too small threshold"
        );
        require(
            uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) <= totalWeight * MAX_THRESHOLD_BIPS, 
            "too big threshold"
        );

        bytes memory signingPolicyBytes = new bytes(
            SIGNING_POLICY_PREFIX_BYTES +
                _signingPolicy.voters.length *
                ADDRESS_AND_WEIGHT_BYTES
        );

        Counters memory m;

        // bytes32 currentHash;
        bytes memory toHash = bytes.concat(
            bytes2(uint16(_signingPolicy.voters.length)),
            bytes3(_signingPolicy.rewardEpochId),
            bytes4(_signingPolicy.startVotingRoundId),
            bytes2(_signingPolicy.threshold),
            bytes32(uint256(_signingPolicy.seed)),
            bytes20(_signingPolicy.voters[0]),
            bytes1(uint8(_signingPolicy.weights[0] >> 8))
        );

        for (; m.signingPolicyPos < 64; m.signingPolicyPos++) {
            signingPolicyBytes[m.signingPolicyPos] = toHash[m.signingPolicyPos];
        }

        bytes32 currentHash = keccak256(toHash);

        m.weightIndex = 0;
        m.weightPos = 1;
        m.voterIndex = 1;
        m.voterPos = 0;

        while (m.weightIndex < _signingPolicy.voters.length) {
            m.count = 0;
            m.nextSlot = bytes32(uint256(0));
            m.bytesToTake = 0;
            while (
                m.count < 32 && m.weightIndex < _signingPolicy.voters.length
            ) {
                if (m.weightIndex < m.voterIndex) {
                    m.bytesToTake = 2 - m.weightPos;
                    m.pos = m.weightPos;
                    bytes32 weightData = bytes32(
                        uint256(
                            uint16(_signingPolicy.weights[m.weightIndex])
                        ) << (30 * 8)
                    );
                    if (m.count + m.bytesToTake > 32) {
                        m.bytesToTake = 32 - m.count;
                        m.weightPos += m.bytesToTake;
                    } else {
                        m.weightPos = 0;
                        m.weightIndex++;
                    }
                    m.nextSlot |= bytes32(
                        ((weightData << (8 * m.pos)) >> (8 * m.count))
                    );
                } else {
                    m.bytesToTake = 20 - m.voterPos;
                    m.pos = m.voterPos;
                    bytes32 voterData = bytes32(
                        uint256(uint160(_signingPolicy.voters[m.voterIndex])) <<
                            (12 * 8)
                    );
                    if (m.count + m.bytesToTake > 32) {
                        m.bytesToTake = 32 - m.count;
                        m.voterPos += m.bytesToTake;
                    } else {
                        m.voterPos = 0;
                        m.voterIndex++;
                    }
                    m.nextSlot |= bytes32(
                        ((voterData << (8 * m.pos)) >> (8 * m.count))
                    );
                }
                m.count += m.bytesToTake;
            }
            if (m.count > 0) {
                currentHash = keccak256(bytes.concat(currentHash, m.nextSlot));
                for (uint256 i = 0; i < m.count; i++) {
                    signingPolicyBytes[m.signingPolicyPos] = m.nextSlot[i];
                    m.signingPolicyPos++;
                }
            }
        }
        toSigningPolicyHash[_signingPolicy.rewardEpochId] = currentHash;
        stateData.lastInitializedRewardEpoch = _signingPolicy.rewardEpochId;
        startingVotingRoundIds[_signingPolicy.rewardEpochId] = _signingPolicy
            .startVotingRoundId;
        emit SigningPolicyInitialized(
            _signingPolicy.rewardEpochId,
            _signingPolicy.startVotingRoundId,
            _signingPolicy.threshold,
            _signingPolicy.seed,
            _signingPolicy.voters,
            _signingPolicy.weights,
            signingPolicyBytes,
            uint64(block.timestamp)
        );

        return currentHash;
    }

    /**
     * @inheritdoc IRelay
     */
    function relay() external {

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

            // Helper function to assign value to right aligned byte encoded struct like object
            function structValue(_structObj, _valOffset, _valMask) -> _val {
                _val := and(shr(_valOffset, _structObj), _valMask)
            }

            // Helper function to calculate the expected reward epoch id from voting round id
            // Here the constants should be set properly
            function rewardEpochIdFromVotingRoundId(
                _stateDataObj,
                _votingRoundId
            ) -> _rewardEpochId {
                let firstRewardEpochStartVotingRoundId := structValue(
                    _stateDataObj,
                    SD_BOFF_firstRewardEpochStartVotingRoundId,
                    SD_MASK_firstRewardEpochStartVotingRoundId
                )
                if lt(_votingRoundId, firstRewardEpochStartVotingRoundId) {
                    revertWithMessage(mload(0x40), "Invalid voting round id", 23)
                }
                _rewardEpochId := div(
                    sub(
                        _votingRoundId,
                        firstRewardEpochStartVotingRoundId
                    ),
                    structValue(
                        _stateDataObj,
                        SD_BOFF_rewardEpochDurationInVotingEpochs,
                        SD_MASK_rewardEpochDurationInVotingEpochs
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
                if iszero(mod(_policyLength, 32)) {
                    // no additinal bytes
                    _policyHash := mload(_memPos)
                }
                if gt(mod(_policyLength, 32), 0) {
                    // handle the remaining bytes
                    mstore(add(_memPos, M_1), 0)
                    calldatacopy(add(_memPos, M_1), endPos, mod(_policyLength, 32)) // remaining bytes
                    mstore(_memPos, keccak256(_memPos, 64))
                    _policyHash := mload(_memPos)
                }
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

            function checkThresholdConsistency(
                _memPtr,
                _metadata,
                _signingPolicyStart
            ) {
                let totalWeight := 0
                for {
                    let i := 0                    
                    let offset := add(
                        add(_signingPolicyStart, SIGNING_POLICY_PREFIX_BYTES),
                        ADDRESS_BYTES
                    )
                    let numberOfVoters := structValue(
                        _metadata,
                        MD_BOFF_numberOfVoters,
                        MD_MASK_numberOfVoters
                    )
                } lt(i, numberOfVoters) {
                    i := add(i, 1)
                } {
                    // clear the memory slot
                    mstore(_memPtr, 0)
                    // copy the weight to the rightmost WEIGHT_BYTES
                    calldatacopy(
                        add(_memPtr, sub(32, WEIGHT_BYTES)),
                        add(
                            offset,
                            mul(i, ADDRESS_AND_WEIGHT_BYTES)
                        ),
                        WEIGHT_BYTES
                    )
                    // add to the total weight
                    totalWeight := add(
                        totalWeight,
                        mload(_memPtr)
                    )
                }
                if gt(totalWeight, sub(shl(16, 1),1)) {   // totalWeight > 2 ** 16 - 1
                    revertWithMessage(_memPtr, "total weight too big", 20)
                }
                let threshold := structValue(
                    _metadata,
                    MD_BOFF_threshold,
                    MD_MASK_threshold
                )
                if lt(mul(threshold, THRESHOLD_BIPS), mul(totalWeight, MIN_THRESHOLD_BIPS)) {
                    revertWithMessage(_memPtr, "too small threshold", 19)
                }
                if gt(mul(threshold, THRESHOLD_BIPS), mul(totalWeight, MAX_THRESHOLD_BIPS)) {
                    revertWithMessage(_memPtr, "too big threshold", 17)
                }
            }

            // free memory pointer
            let memPtr := mload(0x40)
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

            // Extracting protocolId, votingRoundId and isSecureRandom
            // 1 bytes - protocolId
            // 4 bytes - votingRoundId
            // 1 bytes - isSecureRandom
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
                // Check if merkleRoots[protocolId][votingRoundId] is set
                // NOTE: M1 is already consumed. Hence using M_3 and M_4
                mstore(add(memPtrGP0, M_3), protocolId) // key 1 (protocolId)
                mstore(add(memPtrGP0, M_4), merkleRoots.slot) // merkleRoot slot
                mstore(add(memPtrGP0, M_4), keccak256(add(memPtrGP0, M_3), 64))
                mstore(add(memPtrGP0, M_3), votingRoundId) // key 2 (votingRoundId)

                if gt(sload(keccak256(add(memPtrGP0, M_3), 64)), 0) {
                    revertWithMessage(memPtrGP0, "Already relayed", 15)
                }

                // the expected reward epoch id
                let messageRewardEpochId := rewardEpochIdFromVotingRoundId(
                    mload(add(memPtrGP0, M_5_stateData)),
                    votingRoundId
                )

                // Given a signing policy for reward epoch R one can sign either messages
                // in reward epochs R or later
                if lt(messageRewardEpochId, rewardEpochId) {
                    revertWithMessage(memPtrGP0, "Wrong sign policy reward epoch", 30)
                }

                let startingVotingRoundId := structValue(
                    metadata,
                    MD_BOFF_startingVotingRoundId,
                    MD_MASK_startingVotingRoundId
                )
                // in case the reward epoch id start gets delayed -> signing policy for earlier
                // reward epoch must be provided
                if lt(votingRoundId, startingVotingRoundId) {
                    revertWithMessage(memPtrGP0, "Delayed sign policy", 19)
                }

                if gt(messageRewardEpochId, rewardEpochId) {
                    let lastInitializedRewardEpoch :=
                        structValue(
                            mload(add(memPtrGP0, M_5_stateData)),
                            SD_BOFF_lastInitializedRewardEpoch,
                            SD_MASK_lastInitializedRewardEpoch
                        )
                    if gt(lastInitializedRewardEpoch, rewardEpochId) {
                        mstore(add(memPtrGP0, M_3), add(rewardEpochId, 1)) // key (rewardEpochId + 1)
                        mstore(add(memPtrGP0, M_4), startingVotingRoundIds.slot) // startingVotingRoundIds slot
                        let nextStartingVotingRoundId := sload(keccak256(add(memPtrGP0, M_3), 64))
                        // if votingRoundId >= nextStartingVotingRoundId, revert
                        if gt(add(votingRoundId, 1), nextStartingVotingRoundId) {
                            revertWithMessage(memPtrGP0, "Must use new sign policy", 24)
                        }
                    }
                    if eq(lastInitializedRewardEpoch, rewardEpochId) {
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

                    // At this point we have situation:
                    // - messageRewardEpochId is not initialized -> increased threshold
                    // - messageRewardEpochId is initialized -> votingRoundId < nextStartingVotingRoundId
                    // consequently the threshold can stay the same
                }
                // all revert conditions are checked

                // Prepare the message hash into slot M_1
                mstore(add(memPtrGP0, M_1), keccak256(memPtrGP0, MESSAGE_BYTES))
            }

            // protocolId == 0 means we are relaying new signing policy (Mode 1)
            // The signed hash is the signing policy hash and it gets prepared into slot 32

            if eq(protocolId, 0) {
                // Check if signing policy relay is enabled

                if gt(
                    structValue(
                        mload(add(mload(0x40), M_5_stateData)),
                        SD_BOFF_noSigningPolicyRelay,
                        SD_MASK_noSigningPolicyRelay
                    ),
                    0
                ) {
                    revertWithMessage(mload(0x40), "Sign policy relay disabled", 26)
                }

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
                    revertWithMessage(mload(0x40), "No new sign policy size", 23)
                }

                // New metadata
                calldatacopy(
                    mload(0x40),
                    add(
                        SELECTOR_BYTES,
                        add(PROTOCOL_ID_BYTES, signingPolicyLength)
                    ),
                    METADATA_BYTES
                )

                let newMetadata := shr(
                    sub(256, mul(8, METADATA_BYTES)),
                    mload(mload(0x40))
                )
                let newNumberOfVoters := structValue(
                    newMetadata,
                    MD_BOFF_numberOfVoters,
                    MD_MASK_numberOfVoters
                )
                // must be at least one voter
                if eq(newNumberOfVoters, 0) {
                    revertWithMessage(mload(0x40), "must be non-trivial", 19)
                }
                // must be at most MAX_VOTERS
                if gt(newNumberOfVoters, MAX_VOTERS) {
                    revertWithMessage(mload(0x40), "too many voters", 15)
                }

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
                    revertWithMessage(mload(0x40), "Wrong size for new sign policy", 30)
                }

                let newSigningPolicyRewardEpochId := structValue(
                    newMetadata,
                    MD_BOFF_rewardEpochId,
                    MD_MASK_rewardEpochId
                )

                let tmpLastInitializedRewardEpochId := structValue(
                    mload(add(mload(0x40), M_5_stateData)),
                    SD_BOFF_lastInitializedRewardEpoch,
                    SD_MASK_lastInitializedRewardEpoch
                )

                // should the old signing policy reward epoch id be the last intialized one
                if iszero(
                    eq(
                        tmpLastInitializedRewardEpochId,
                        rewardEpochId
                    )
                ) {
                    revertWithMessage(mload(0x40), "Not with last intialized", 24)
                }

                // Should be next reward epoch id
                if iszero(
                    eq(
                        add(1, tmpLastInitializedRewardEpochId),
                        newSigningPolicyRewardEpochId
                    )
                ) {
                    revertWithMessage(mload(0x40), "Not next reward epoch", 21)
                }

                // Check the threshold consistency
                checkThresholdConsistency(
                    mload(0x40), 
                    newMetadata, 
                    add(
                        SELECTOR_BYTES,
                        add(PROTOCOL_ID_BYTES, signingPolicyLength)
                    )                    
                )

                let newSigningPolicyHash := calculateSigningPolicyHash(
                    mload(0x40),
                    add(
                        SELECTOR_BYTES,
                        add(signingPolicyLength, PROTOCOL_ID_BYTES)
                    ),
                    newSigningPolicyLength
                )
                // Update temporary stateData. If the weight of signatures if
                // over threshold, then this will be written to storage
                mstore(
                    add(mload(0x40), M_5_stateData),
                    assignStruct(
                        mload(add(mload(0x40), M_5_stateData)),
                        SD_BOFF_lastInitializedRewardEpoch,
                        SD_MASK_lastInitializedRewardEpoch,
                        newSigningPolicyRewardEpochId
                    )
                )

                // startingVotingRoundId[newSigningPolicyRewardEpochId] = newMetadata.startingVotingRoundId
                mstore(mload(0x40), newSigningPolicyRewardEpochId)
                mstore(add(mload(0x40), M_1), startingVotingRoundIds.slot)
                sstore(
                    keccak256(mload(0x40), 64),
                    structValue(
                        newMetadata,
                        MD_BOFF_startingVotingRoundId,
                        MD_MASK_startingVotingRoundId
                    )
                )

                // toSigningPolicyHash[newSigningPolicyRewardEpochId] = newSigningPolicyHash
                mstore(mload(0x40), newSigningPolicyRewardEpochId)
                mstore(add(mload(0x40), M_1), toSigningPolicyHash.slot)
                sstore(keccak256(mload(0x40), 64), newSigningPolicyHash)
                // Prepare the hash on slot 32 for signature verification
                mstore(add(mload(0x40), M_1), newSigningPolicyHash)
                // IMPORTANT: assumes that if threshold is not sufficient, the transaction will be reverted

                // emit event
                // use temporarily M_3 to store event signature
                mstore(add(mload(0x40), M_3), "SigningPolicyRelayed(uint256)")
                log2(mload(0x40), 0, keccak256(add(mload(0x40), M_3), 29), newSigningPolicyRewardEpochId)
            }

            // Assumptions here:
            // - memPtr (slot M_1) contains either protocol message merkle root hash or new signing policy hash
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
            // M_3              | s, expectedSigner + weight
            // M_4              | index

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
                if gt(add(index, 1), numberOfVoters) {
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
                    if eq(protocolId, 0) {
                        // Store updated stateData (lastInitializedRewardEpoch)
                        sstore(
                            stateData.slot,
                            mload(add(memPtrFor, M_5_stateData))
                        )
                    }

                    if gt(protocolId, 0) {
                        let votingRoundId := extractVotingRoundIdFromMessage(
                            memPtrFor,
                            signingPolicyLength
                        )
                        // M_6_merkleRoot <- Merkle root
                        calldatacopy(
                            add(memPtrFor, M_6_merkleRoot),
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
                            mload(add(memPtrFor, M_6_merkleRoot))
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

                            // stateData.isSecureRandom = message.isSecureRandom
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
                                    SD_BOFF_isSecureRandom,
                                    SD_MASK_isSecureRandom,
                                    structValue(
                                        mload(memPtrFor),
                                        MSG_NMR_BOFF_isSecureRandom,
                                        MSG_NMR_MASK_isSecureRandom
                                    )
                                )
                            )

                            sstore(
                                stateData.slot,
                                mload(add(memPtrFor, M_5_stateData))
                            )

                            // M_5_stateData is not used anymore. Using M_5_isSecureRandom for
                            // isSecureRandom, together with M_6_merkleRoot for data of an event
                            mstore(
                                add(memPtrFor, M_5_isSecureRandom),
                                structValue(
                                    mload(add(memPtrFor, M_5_isSecureRandom)),
                                    SD_BOFF_isSecureRandom,
                                    SD_MASK_isSecureRandom
                                )
                            )
                            // Use M_3 and M4 to store event signature
                            mstore(add(memPtrFor, M_3), "ProtocolMessageRelayed(uint8,uin")
                            mstore(add(memPtrFor, M_4), "t32,bool,bytes32)")
                            log3(
                                add(memPtrFor, M_5_isSecureRandom), 64, keccak256(add(memPtrFor, M_3), 49),
                                protocolId, votingRoundId
                            )
                        } // if protocolId == stateData.randomNumberProtocolId
                    } // if protocolId > 0
                    // in case protocolId == 0, the new signing policy is already stored
                    // and event emitted
                    // set _result to 1 to indicate successful relay/finalization
                    return(0,0)
                }
            } // for

            // NO CODE SHOULD BE ADDED HERE
        } // assembly
        revert("Not enough weight");
    }

    /**
     * @inheritdoc IRelay
     */
    function getRandomNumber()
        external
        view
        returns (
            uint256 _randomNumber,
            bool _isSecureRandom,
            uint256 _randomTimestamp
        )
    {
        _randomNumber = uint256(
            merkleRoots[stateData.randomNumberProtocolId][
                stateData.randomVotingRoundId
            ]
        );
        _isSecureRandom = stateData.isSecureRandom;
        _randomTimestamp =
            stateData.firstVotingRoundStartTs +
            uint256(stateData.randomVotingRoundId + 1) *
            stateData.votingEpochDurationSeconds;
    }

    /**
     * @inheritdoc IRelay
     */
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

    /**
     * @inheritdoc IRelay
     */
    function getConfirmedMerkleRoot(uint256 _protocolId, uint256 _votingRoundId)
        external
        view
        returns (bytes32)
    {
        if (_protocolId == 0) {
            return toSigningPolicyHash[_votingRoundId];
        }
        return merkleRoots[_protocolId][_votingRoundId];
    }

    /**
     * @inheritdoc IRelay
     */
    function lastInitializedRewardEpochData() external view returns (
        uint32 _lastInitializedRewardEpoch,
        uint32 _startingVotingRoundIdForLastInitializedRewardEpoch
    ) {
        _lastInitializedRewardEpoch = stateData.lastInitializedRewardEpoch;
        _startingVotingRoundIdForLastInitializedRewardEpoch =
            uint32(startingVotingRoundIds[_lastInitializedRewardEpoch]);
    }
}
