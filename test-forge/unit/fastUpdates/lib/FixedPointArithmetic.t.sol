// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { FixedPointArithmeticMock } from "../../../../contracts/fastUpdates/mock/FixedPointArithmeticMock.sol";
import {
    Scale, Precision, SampleSize, Range, Fractional, Fee
} from "../../../../contracts/userInterfaces/IFixedPointArithmetic.sol";

contract FixedPointArithmeticTest is Test {

    FixedPointArithmeticMock private fpa;

    function setUp() public {
        fpa = new FixedPointArithmeticMock();
    }

    // ── Addition / subtraction ─────────────────────────────────────────────

    function testAddSubSampleSize(uint256 x, uint256 y) public view {
        x = bound(x, 0, 2 ** 16 - 2);
        y = bound(y, 0, 2 ** 16 - 2 - x);
        if (x < y) (x, y) = (y, x);

        (SampleSize z1, SampleSize z2) = fpa.addSampleSizeTest(
            SampleSize.wrap(x), SampleSize.wrap(y)
        );

        assertEq(SampleSize.unwrap(z1), x + y);
        assertEq(SampleSize.unwrap(z2), x - y);
    }

    function testAddSubRange(uint256 x, uint256 y) public view {
        x = bound(x, 0, 2 ** 16 - 2);
        y = bound(y, 0, 2 ** 16 - 2 - x);
        if (x < y) (x, y) = (y, x);

        (Range z1, Range z2) = fpa.addRangeTest(
            Range.wrap(x), Range.wrap(y)
        );

        assertEq(Range.unwrap(z1), x + y);
        assertEq(Range.unwrap(z2), x - y);
    }

    function testAddSubFee(uint256 x, uint256 y) public view {
        x = bound(x, 0, 2 ** 240 - 2);
        y = bound(y, 0, 2 ** 240 - 2 - x);
        if (x < y) (x, y) = (y, x);

        (Fee z1, Fee z2) = fpa.addFeeTest(
            Fee.wrap(x), Fee.wrap(y)
        );

        assertEq(Fee.unwrap(z1), x + y);
        assertEq(Fee.unwrap(z2), x - y);
    }

    // ── Multiplication ─────────────────────────────────────────────────────

    function testMulScale(uint256 xMant, uint256 yMant) public view {
        xMant = bound(xMant, 1, (1 << 47) + (1 << 45) - 1);
        yMant = bound(yMant, 1, (1 << 47) + (1 << 45) - 1);
        uint256 x = xMant << 80;
        uint256 y = yMant << 80;

        Scale z = fpa.mulScaleTest(Scale.wrap(x), Scale.wrap(y));

        assertEq(Scale.unwrap(z), (x * y) >> 127);
    }

    function testMulFeeRange(uint256 xMant, uint256 yMant) public view {
        xMant = bound(xMant, 0, (1 << 39) - 1);
        yMant = bound(yMant, 0, (1 << 47) - 1);
        uint256 x = xMant << 80;
        uint256 y = yMant << 80;

        Fee z = fpa.mulFeeRangeTest(Fee.wrap(x), Range.wrap(y));

        assertEq(Fee.unwrap(z), (x * y) >> 120);
    }

    function testMulFractionalFee(uint256 xMant, uint256 yVal) public view {
        xMant = bound(xMant, 0, (1 << 47) - 1);
        yVal = bound(yVal, 0, (1 << 32) - 1);
        uint256 x = xMant << 80;

        Fee z = fpa.mulFractionalFeeTest(Fractional.wrap(x), Fee.wrap(yVal));

        assertEq(Fee.unwrap(z), (x * yVal) >> 128);
    }

    function testMulFractionalSampleSize(uint256 xMant, uint256 yMant) public view {
        xMant = bound(xMant, 0, (1 << 47) - 1);
        yMant = bound(yMant, 0, (1 << 47) - 1);
        uint256 x = xMant << 80;
        uint256 y = yMant << 80;

        SampleSize z = fpa.mulFractionalSampleSizeTest(
            Fractional.wrap(x), SampleSize.wrap(y)
        );

        assertEq(SampleSize.unwrap(z), (x * y) >> 128);
    }

    // ── Division ───────────────────────────────────────────────────────────

    function testDivRange(uint256 xMant, uint256 yMant) public view {
        yMant = bound(yMant, 1, (1 << 47) - 1);
        xMant = bound(xMant, 0, yMant - 1);
        uint256 x = xMant << 80;
        uint256 y = yMant << 80;

        Fractional z = fpa.divRangeTest(Range.wrap(x), Range.wrap(y));

        assertEq(Fractional.unwrap(z), (x << 128) / y);
    }

    function testDivFee(uint256 xMant, uint256 yMant) public view {
        yMant = bound(yMant, 1, (1 << 47) - 1);
        xMant = bound(xMant, 0, yMant - 1);
        uint256 x = xMant << 80;
        uint256 y = yMant << 80;

        Fractional z = fpa.divFeeTest(Fee.wrap(x), Fee.wrap(y));

        assertEq(Fractional.unwrap(z), (x << 128) / y);
    }

    function testDivRangeSampleSize(uint256 xMant, uint256 yMant) public view {
        yMant = bound(yMant, 1, (1 << 47) - 1);
        xMant = bound(xMant, 0, yMant - 1);
        uint256 x = xMant << 80;
        uint256 y = yMant << 80;

        Precision z = fpa.divRangeSampleSizeTest(Range.wrap(x), SampleSize.wrap(y));

        assertEq(Precision.unwrap(z), (x << 127) / y);
    }

    // ── Comparison / conversion ────────────────────────────────────────────

    function testScaleWithPrecision(uint256 xMant) public view {
        xMant = bound(xMant, 0, (1 << 46) - 1);
        uint256 x = xMant << 80;

        Scale z = fpa.scaleWithPrecisionTest(Precision.wrap(x));

        assertEq(Scale.unwrap(z), x + (1 << 127));
    }

    function testLessThanRange(uint256 x, uint256 y) public view {
        x = bound(x, 0, type(uint16).max);
        y = bound(y, 0, type(uint16).max);

        bool result = fpa.lessThanRangeTest(Range.wrap(x), Range.wrap(y));

        assertEq(result, x < y);
    }

    function testLessThanFee(uint256 x, uint256 y) public view {
        x = bound(x, 0, type(uint32).max);
        y = bound(y, 0, type(uint32).max);

        bool result = fpa.lessThanFeeTest(Fee.wrap(x), Fee.wrap(y));

        assertEq(result, x < y);
    }

    function testLessThanRangeSampleSize(uint256 x, uint256 y) public view {
        x = bound(x, 0, type(uint16).max);
        y = bound(y, 0, type(uint16).max);

        bool result = fpa.lessThanRangeSampleSizeTest(
            Range.wrap(x), SampleSize.wrap(y)
        );

        assertEq(result, x < y);
    }
}
