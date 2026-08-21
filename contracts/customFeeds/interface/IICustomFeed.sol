
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * IICustomFeed interface.
 */
interface IICustomFeed {

    /**
     * Returns the current feed.
     * @return _value The value of the feed; may be negative for feeds with a signed source.
     * NOTE: The return type changed from uint256 to int256. This does not change the function selector
     * or ABI encoding. Existing implementations remain compatible for values not greater than
     * `type(int256).max`.
     * @return _decimals The decimals of the feed.
     * @return _timestamp The timestamp of the feed.
     */
    function getCurrentFeed() external payable returns (int256 _value, int8 _decimals, uint64 _timestamp);


    /**
     * Returns the feed id.
     * @return _feedId The feed id.
     */
    function feedId() external view returns (bytes21 _feedId);

    /**
     * Calculates the fee for fetching the feed.
     * @return _fee The fee for fetching the feed.
     */
    function calculateFee() external view returns (uint256 _fee);
}
