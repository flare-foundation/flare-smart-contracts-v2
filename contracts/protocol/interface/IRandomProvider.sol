// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


interface IRandomProvider {

    function getCurrentRandom() external view returns(uint256 _currentRandom);

    function getCurrentRandomWithQuality() external view returns(uint256 _currentRandom, bool _goodRandom);
}
