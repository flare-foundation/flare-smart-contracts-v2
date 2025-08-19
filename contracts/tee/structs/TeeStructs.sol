// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/IPublicKey.sol";
import "../../userInterfaces/ftdc/ITeeAvailabilityCheck.sol";

interface TeeStructs {

    struct Instruction {
        bytes32 instructionId;
        address teeId;
        uint64 timestamp;
        uint32 rewardEpochId;
        bytes32 opType;
        bytes32 opCommand;
        address[] cosigners;
        uint64 cosignersThreshold;
        bytes originalMessage;
        bytes additionalFixedMessage;
    }

    struct Attestation {
        bytes32 challenge;
        PublicKey publicKey;
        uint32 initialSigningPolicyId;
        bytes32 initialSigningPolicyHash;
        uint32 lastSigningPolicyId;
        bytes32 lastSigningPolicyHash;
        ITeeAvailabilityCheck.TeeState state;
        uint64 teeTimestamp;
    }

    struct VoteSequenceInit {
        bytes32 instructionId;
        bytes32 instructionHash;
        uint32 rewardEpochId;
        address teeId;
    }

    struct VoteSequenceNext {
        bytes32 voteHash;
        uint64 sequence;
        bytes signature;
        bytes32 additionalVariableMessageHash;
        uint64 timestamp;
    }

    struct VoteReceipt {
        bytes32 instructionHash;
        uint64 sequence;
        bytes signature;
        bytes32 additionalVariableMessageHash;
        uint64 timestamp;
        bytes32 voteHash;
    }

    function instructionStruct(Instruction calldata) external;
    function attestationStruct(Attestation calldata) external;
    function voteSequenceInitStruct(VoteSequenceInit calldata) external;
    function voteSequenceNextStruct(VoteSequenceNext calldata) external;
    function voteReceiptStruct(VoteReceipt calldata) external;
}
