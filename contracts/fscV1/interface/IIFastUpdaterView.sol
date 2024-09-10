// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../fastUpdates/lib/Bn256.sol";
import { SortitionCredential } from "../../fastUpdates/lib/Sortition.sol";

/**
 * Fast updater interface, used for fetching current feeds without a fee.
 */
interface IIFastUpdaterView {

    /**
     * Public access to the stored data of each feed, allowing controlled batch access to the lengthy complete data.
     * Feeds should be sorted for better performance.
     * @param _indices Index numbers of the feeds for which data should be returned, corresponding to `feedIds` in
     * the `FastUpdatesConfiguration` contract.
     * @return _feeds The list of data for the requested feeds, in the same order as the feed indices were given
     * (which may not be their sorted order).
     * @return _decimals The list of decimal places for the requested feeds, in the same order as the feed indices were
     * given (which may not be their sorted order).
     * @return _timestamp The timestamp of the last update.
     */
    function fetchCurrentFeeds(
        uint256[] calldata _indices
    )
        external view
        returns (
            uint256[] memory _feeds,
            int8[] memory _decimals,
            uint64 _timestamp
        );

}