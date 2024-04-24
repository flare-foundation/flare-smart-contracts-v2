// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../lib/FixedPointArithmetic.sol" as FPA;


contract FixedPointArithmeticMock {
    // Addition/subtraction tests

    function addSampleSizeTest(FPA.SampleSize x, FPA.SampleSize y)
        public pure
        returns(FPA.SampleSize z1, FPA.SampleSize z2)
    {
        z1 = FPA.add(x, y);
        z2 = FPA.sub(x, y);
    }
    function addRangeTest(FPA.Range x, FPA.Range y) public pure returns(FPA.Range z1, FPA.Range z2) {
        z1 = FPA.add(x, y);
        z2 = FPA.sub(x, y);
    }
    function addFeeTest(FPA.Fee x, FPA.Fee y) public pure returns(FPA.Fee z1, FPA.Fee z2) {
        z1 = FPA.add(x, y);
        z2 = FPA.sub(x, y);
    }

    // Multiplication/division tests

    function mulScaleTest(FPA.Scale x, FPA.Scale y) public pure returns (FPA.Scale z) {
        z = FPA.mul(x, y);
    }
    function mulFeeRangeTest(FPA.Fee x, FPA.Range y) public pure returns (FPA.Fee z) {
        z = FPA.mul(x, y);
    }
    function mulFractionalFeeTest(FPA.Fractional x, FPA.Fee y) public pure returns (FPA.Fee z) {
        z = FPA.mul(x, y);
    }
    function mulFractionalSampleSizeTest(FPA.Fractional x, FPA.SampleSize y) public pure returns (FPA.SampleSize z) {
        z = FPA.mul(x, y);
    }
    function divRangeTest(FPA.Range x, FPA.Range y) public pure returns (FPA.Fractional z) {
        z = FPA.frac(x, y);
    }
    function divFeeTest(FPA.Fee x, FPA.Fee y) public pure returns (FPA.Fractional z) {
        z = FPA.frac(x, y);
    }
    function divRangeSampleSizeTest(FPA.Range x, FPA.SampleSize y) public pure returns (FPA.Precision z) {
        z = FPA.div(x, y);
    }

    // Comparison and conversion tests

    function scaleWithPrecisionTest(FPA.Precision x) public pure returns (FPA.Scale y) {
        y = FPA.scaleWithPrecision(x);
    }
    function lessThanRangeTest(FPA.Range x, FPA.Range y) public pure returns (bool) {
        return FPA.lessThan(x, y);
    }
    function lessThanFeeTest(FPA.Fee x, FPA.Fee y) public pure returns (bool) {
        return FPA.lessThan(x, y);
    }
    function lessThanRangeSampleSizeTest(FPA.Range x, FPA.SampleSize y) public pure returns (bool) {
        return FPA.lessThan(x, y);
    }
}
