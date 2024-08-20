// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/IFeeCalculator.sol";

interface IIFeeCalculator is IFeeCalculator {

    /// Event emitted when setting a fee for a feed.
    event FeedFeeSet(bytes21 indexed feedId, uint256 fee);
    /// Event emitted when setting a fee for a category.
    event CategoryFeeSet(uint8 indexed category, uint256 fee);
    // Event emitted when removing a fee for a feed.
    event FeedFeeRemoved(bytes21 indexed feedId);
    // Event emitted when removing a fee for a category.
    event CategoryFeeRemoved(uint8 indexed category);
    // Event emitted when setting a default fee.
    event DefaultFeeSet(uint256 fee);

    /**
     * Sets a default fee.
     * @param _fee The default fee.
     * @dev Only governance can call this method.
     * @dev Must be greater than 0.
     */
    function setDefaultFee(uint256 _fee) external;

    /**
     * Sets fees for categories.
     * It overrides the default fee.
     * @param _categories List of categories.
     * @param _fees List of fees.
     * @dev Only governance can call this method.
     */
    function setCategoriesFees(
        uint8[] memory _categories,
        uint256[] memory _fees
    ) external;

    /**
     * Sets fees for feeds.
     * It overrides feed's category fee.
     * @param _feedIds List of feed ids.
     * @param _fees List of fees.
     * @dev Only governance can call this method.
     */
    function setFeedsFees(
        bytes21[] memory _feedIds,
        uint256[] memory _fees
    ) external;

    /**
     * Removes fees for feeds.
     * When a feed fee is removed, its category fee or, if it's not set, a default fee is used.
     * @param _feedIds List of feed ids.
     * @dev Only governance can call this method.
     */
    function removeFeedsFees(bytes21[] memory _feedIds) external;

    /**
     * Removes fees for categories.
     * When a category fee is removed, a default fee is used.
     * @param _categories List of categories.
     * @dev Only governance can call this method.
     */
    function removeCategoriesFees(uint8[] memory _categories) external;

    /**
     * Returns a fee for a feed.
     * @param _feedId Feed id for which to return a fee.
     */
    function getFeedFee(bytes21 _feedId) external view returns (uint256 _fee);

    /**
     * Returns a fee for a category.
     * @param _category Category for which to return a fee.
     */
    function getCategoryFee(uint8 _category) external view returns (uint256 _fee);

    /**
     * Returns a default fee.
     */
    function defaultFee() external view returns (uint256 _fee);

    /**
     * Calculates a fee that needs to be paid to fetch feeds' data.
     * Used when fetching feeds' data.
     * @param _indices Indices of the feeds, corresponding to feed ids in
     * the FastUpdatesConfiguration contract.
    */
    function calculateFeeByIndices(uint256[] memory _indices) external view returns (uint256 _fee);
}
