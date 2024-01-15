// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IFtsoFeedPublisher.sol";


interface FtsoMerkleStructs {

    function feedStruct(IFtsoFeedPublisher.Feed calldata _feed) external;

    function randomStruct(IFtsoFeedPublisher.Random calldata _random) external;
}
