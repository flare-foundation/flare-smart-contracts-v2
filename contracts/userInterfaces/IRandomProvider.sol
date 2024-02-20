// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * Random provider interface.
 */
interface IRandomProvider {


    /**
     * Returns current random number. Method reverts if random number was not generated securely.
     * @return _randomNumber Current random number.
     */
    function getCurrentRandom() external view returns(uint256 _randomNumber);

    /**
     * Returns current random number and a flag indicating if it was securely generated.
     * It is up to the caller to decide whether to use the returned random number or not.
     * @return _randomNumber Current random number.
     * @return _isSecureRandom Indicates if current random number is secure.
     */
    function getCurrentRandomWithQuality() external view returns(uint256 _randomNumber, bool _isSecureRandom);

    /**
     * Returns current random number, a flag indicating if it was securely generated and its timestamp.
     * It is up to the caller to decide whether to use the returned random number or not.
     * @return _randomNumber Current random number.
     * @return _isSecureRandom Indicates if current random number is secure.
     * @return _randomTimestamp Random timestamp.
     */
    function getCurrentRandomWithQualityAndTimestamp()
        external view
        returns(uint256 _randomNumber, bool _isSecureRandom, uint256 _randomTimestamp);
}
