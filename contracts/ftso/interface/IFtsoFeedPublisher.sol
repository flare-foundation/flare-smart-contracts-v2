
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * IFtsoFeedPublisher interface.
 */
interface IFtsoFeedPublisher {

    /// The FTSO feed struct.
    struct Feed {
        uint32 votingRoundId;
        bytes8 name;
        int32 value;
        uint16 turnoutBIPS;
        int8 decimals;
    }

    /// The FTSO random struct.
    struct Random {
        uint32 votingRoundId;
        uint256 value;
        bool isSecure;
    }

    /// The FTSO feed with proof struct.
    struct FeedWithProof {
        bytes32[] merkleProof;
        Feed body;
    }

    /**
     * Publishes feeds.
     * @param _proofs The FTSO feeds with proofs to publish.
     */
    function publish(FeedWithProof[] calldata _proofs) external;
}
