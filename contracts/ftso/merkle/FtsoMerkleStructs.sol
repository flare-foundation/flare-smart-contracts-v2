// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/IFtsoFeedPublisher.sol";


interface FtsoMerkleStructs {

    function feedStruct(IFtsoFeedPublisher.Feed calldata _feed) external;

    function feedWithProofStruct(IFtsoFeedPublisher.FeedWithProof calldata _proof) external;

    function randomStruct(IFtsoFeedPublisher.Random calldata _random) external;
}
