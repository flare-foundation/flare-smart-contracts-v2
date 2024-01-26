// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * Random provider interface.
 */
interface IRandomProvider {

    /**
     * Returns current random number.
     * @return _currentRandom Current random number.
     */
    function getCurrentRandom() external view returns(uint256 _currentRandom);

    /**
     * Returns current random number with quality.
     * @return _currentRandom Current random number.
     * @return _isSecureRandom Indicates if current random number is secure.
     */
    function getCurrentRandomWithQuality() external view returns(uint256 _currentRandom, bool _isSecureRandom);
}
