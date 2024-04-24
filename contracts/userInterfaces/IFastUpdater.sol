// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../fastUpdates/lib/Bn256.sol";
import { SortitionCredential } from "../fastUpdates/lib/Sortition.sol";

/**
 * Fast updater interface.
 */
interface IFastUpdater {

    /// Signature structure
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /// Fast update structure
    struct FastUpdates {
        uint256 sortitionBlock;
        SortitionCredential sortitionCredential;
        bytes deltas;
        Signature signature;
    }

    /// Event emitted when a new set of updates is submitted.
    event FastUpdateFeedsSubmitted(address indexed signingPolicyAddress);

    /// Event emitted when a feed is added or reset.
    event FastUpdateFeedReset(
        uint256 indexed votingRoundId,
        uint256 indexed index,
        bytes21 indexed id,
        uint256 value,
        int8 decimals);

    /// Event emitted when a feed is removed.
    event FastUpdateFeedRemoved(
        uint256 indexed index);

    /// Event emitted at the start of a new voting epoch - current feeds' values and decimals.
    event FastUpdateFeeds(uint256 indexed votingEpochId, uint256[] feeds, int8[] decimals);

    /**
     * The entry point for providers to submit an update transaction.
     * @param _updates Data of an update transaction, which in addition to the actual list of updates,
     * includes the sortition credential proving the provider's eligibility to make updates in the also-included
     * sortition round, as well as a signature allowing a single registered provider to submit from multiple
     * EVM accounts.
     */
    function submitUpdates(FastUpdates calldata _updates) external;

    /**
     * Public access to the stored data of all feeds.
     * @return _feedIds The list of feed ids.
     * @return _feeds The list of feeds.
     * @return _decimals The list of decimal places for feeds.
     */
    function fetchAllCurrentFeeds()
        external view
        returns (
            bytes21[] memory _feedIds,
            uint256[] memory _feeds,
            int8[] memory _decimals
        );

    /**
     * Public access to the stored data of each feed, allowing controlled batch access to the lengthy complete data.
     * Feeds should be sorted for better performance.
     * @param _indices Index numbers of the feeds for which data should be returned, corresponding to `feedIds` in
     * the `FastUpdatesConfiguration` contract.
     * @return _feeds The list of data for the requested feeds, in the same order as the feed indices were given
     * (which may not be their sorted order).
     * @return _decimals The list of decimal places for the requested feeds, in the same order as the feed indices were
     * given (which may not be their sorted order).
     */
    function fetchCurrentFeeds(
        uint256[] calldata _indices
    )
        external view
        returns (
            uint256[] memory _feeds,
            int8[] memory _decimals
        );

    /**
     * Informational getter concerning the eligibility criterion for being chosen by sortition.
     * @return _cutoff The upper endpoint of the acceptable range of "scores" that providers generate for sortition.
     * A score below the cutoff indicates eligibility to submit updates in the present sortition round.
     */
    function currentScoreCutoff() external view returns (uint256 _cutoff);

    /**
     * Informational getter concerning a provider's likelihood of being chosen by sortition.
     * @param _signingPolicyAddress The signing policy address of the specified provider. This is different from the
     * sender of an update transaction, due to the signature included in the `FastUpdates` type.
     * @return _weight The specified provider's weight for sortition purposes. This is derived from the provider's
     * delegation weight for the FTSO, but rescaled against a fixed number of "virtual providers", indicating how many
     * potential updates a single provider may make in a sortition round.
     */
    function currentSortitionWeight(address _signingPolicyAddress) external view returns (uint256 _weight);
}
