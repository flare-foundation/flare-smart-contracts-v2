// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

abstract contract CircularListManager {
    uint256 public circularLength;

    constructor(uint256 _cl) {
        _setCircularLength(_cl);
    }

    function _setCircularLength(uint256 _cl) internal {
        require(_cl > 0, "CircularListManager: circular length must be greater than 0");
        circularLength = _cl;
    }

    function _ix(uint256 i) internal view returns (uint256) {
        return (i + block.number) % circularLength;
    }

    function _blockIx(uint256 _blockNum, string memory _failMsg) internal view returns (uint256) {
        require(_blockNum <= block.number && block.number < _blockNum + circularLength, _failMsg);
        uint256 blocksAgo = block.number - _blockNum;
        return _backIx(blocksAgo);
    }

    function _backIx(uint256 _i) internal view returns (uint256) {
        assert(_i < circularLength);
        return _ix(circularLength - _i);
    }

    function _prevIx() internal view returns (uint256) {
        return _backIx(1);
    }

    function _thisIx() internal view returns (uint256) {
        return _ix(0);
    }

    function _nextIx() internal view returns (uint256) {
        return _ix(1);
    }
}