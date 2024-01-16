
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;


interface IFtsoFeedPublisher {

    struct Feed {
        uint32 votingRoundId;
        bytes8 name;
        int32 value;
        uint16 turnoutBIPS;
        int8 decimals;
    }

    struct Random {
        uint32 votingRoundId;
        uint256 value;
        bool isSecure;
    }

    struct FeedWithProof {
        bytes32[] merkleProof;
        Feed body;
    }

    function publish(FeedWithProof[] calldata _proofs) external;
}
