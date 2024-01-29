
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/IFtsoFeedPublisher.sol";


/**
 * IIFtsoFeedPublisher interface.
 */
interface IIFtsoFeedPublisher is IFtsoFeedPublisher {

    /**
     * Publishes feeds.
     * @param _feeds The feeds to publish.
     * @dev This method can only be called by the feeds publisher contract.
     */
    function publishFeeds(Feed[] memory _feeds) external;
}
