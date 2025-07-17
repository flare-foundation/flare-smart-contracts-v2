// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

interface TeeStructs {

    struct TeeInstruction {
        bytes32 instructionId;
        address teeId;
        uint64 timestamp;
        uint24 rewardEpochId;
        bytes32 opType;
        bytes32 opCommand;
        bytes originalMessage;
        bytes additionalFixedMessage;
    }

    struct Attestation {
        bytes32 challenge;
        address teeId;
        uint24 initialSigningPolicyId;
        bytes32 initialSigningPolicyHash;
        uint24 lastSigningPolicyId;
        bytes32 lastSigningPolicyHash;
        bytes32 stateHash;
        uint64 teeTimestamp;
    }

    struct PMWState {
        uint256 status;
    }

    struct VoteSequenceInit {
        bytes32 instructionId;
        bytes32 instructionHash;
        uint24 rewardEpochId;
        address teeId;
    }

    struct VoteSequenceNext {
        bytes32 voteHash;
        uint64 sequence;
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes32 additionalVariableMessageHash;
        uint64 timestamp;
    }

    struct VoteReceipt {
        bytes32 voteHash;
        uint64 sequence;
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes32 additionalVariableMessageHash;
        uint64 timestamp;
    }

    function teeInstructionStruct(TeeInstruction calldata) external;
    function attestationStruct(Attestation calldata) external;
    function pmwStateStruct(PMWState calldata) external;
    function voteSequenceInitStruct(VoteSequenceInit calldata) external;
    function voteSequenceNextStruct(VoteSequenceNext calldata) external;
    function voteReceiptStruct(VoteReceipt calldata) external;
}
