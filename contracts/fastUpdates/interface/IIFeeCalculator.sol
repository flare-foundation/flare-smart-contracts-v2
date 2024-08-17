// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/IFeeCalculator.sol";

interface IIFeeCalculator is IFeeCalculator {

    /// Event emitted when setting fee for a feed.
    event FeeSet(bytes21 indexed feedId, uint256 fee);
    /// Event emitted when setting default fee for a category.
    event CategoryDefaultFeeSet(uint8 indexed category, uint256 fee);
    // Event emitted when removing fee for a feed.
    event FeeRemoved(bytes21 indexed feedId);

    /**
     * Sets default fees for categories.
     * If default for a category is not set, it is 0.
     * @param _categories List of categories.
     * @param _fees List of fees.
     * @dev Only governance can call this method.
     */
    function setCategoriesDefaultFees(
        uint8[] memory _categories,
        uint256[] memory _fees
    ) external;

    /**
     * Sets fees for feeds.
     * It overrides the default category feeds.
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
     * When fee is removed, the default fee for its category is used.
     * @param _feedIds List of feed ids.
     * @dev Only governance can call this method.
     */
    function removeFeedsFees(bytes21[] memory _feedIds) external;

}
