// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/IFeeCalculator.sol";

interface IIFeeCalculator is IFeeCalculator {

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

}
