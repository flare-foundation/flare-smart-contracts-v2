// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

interface IIFeeCalculator {

    event FeeSet(bytes21 indexed feedId, uint256 fee);
    event DefaultFeeSet(uint8 indexed category, uint256 fee);
    event FeeRemoved(bytes21 indexed feedId);

    function setCategoriesDefaultFees(
        uint8[] memory _categories,
        uint256[] memory _fees
    ) external;

    function setFeedsFees(
        bytes21[] memory _feedIds,
        uint256[] memory _fees
    ) external;

    function removeFeedsFees(bytes21[] memory _feedIds) external;

    function calculateFee(uint256[] memory _indices) external view returns (uint256 _fee);

    function getFeedFee(bytes21 _feedId) external view returns (uint256 _fee);
}
