// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/*
 * Opaque type synonyms to enforce arithemtic correctness.
 * All of these are internally uint256 to avert solc's restricted-bit-size internal handling.
 * Since the space is available, the fractional parts of all (except Price,
 * which is not controlled by us) are very wide.
 */

type Scale is uint256;      // 1x127
type Precision is uint256;  // 0x127; the fractional part of Scale, top bit always 0
type SampleSize is uint256; // 8x120; current gas usage and block gas limit force <32 update transactions per block
type Range is uint256;      // 8x120, with some space for >100% fluctuations
                            // (measured volatility per block is ~1e-3 at most)
type Fractional is uint256; // 0x128

type Fee is uint256;        // 128x0; same scale as currency units,restricted to bottom 128 bits
                            // (1e18 integer and fractional parts) to accommodate arithmetic

Scale constant oneS = Scale.wrap(1 << 127);
Fee constant oneF = Fee.wrap(1);
SampleSize constant zeroS = SampleSize.wrap(0);
Range constant zeroR = Range.wrap(0);
Fee constant zeroF = Fee.wrap(0);

function _check(uint256 x) pure returns(bool) {
    return x < 1<<128;
}

function check(Scale x) pure returns(bool) {
    return _check(Scale.unwrap(x));
}

function check(Precision x) pure returns(bool) {
    return _check(Precision.unwrap(x));
}

function check(SampleSize x) pure returns(bool) {
    return _check(SampleSize.unwrap(x));
}

function check(Range x) pure returns(bool) {
    return _check(Range.unwrap(x));
}

function check(Fractional x) pure returns(bool) {
    return _check(Fractional.unwrap(x));
}

function check(Fee x) pure returns(bool) {
    return _check(Fee.unwrap(x));
}

function add(SampleSize x, SampleSize y) pure returns (SampleSize z) {
    unchecked {
        z = SampleSize.wrap(SampleSize.unwrap(x) + SampleSize.unwrap(y));
    }
}

function add(Range x, Range y) pure returns (Range z) {
    unchecked {
        z = Range.wrap(Range.unwrap(x) + Range.unwrap(y));
    }
}

function add(Fee x, Fee y) pure returns (Fee z) {
    unchecked {
        z = Fee.wrap(Fee.unwrap(x) + Fee.unwrap(y));
    }
}

function sub(SampleSize x, SampleSize y) pure returns (SampleSize z) {
    unchecked {
        z = SampleSize.wrap(SampleSize.unwrap(x) - SampleSize.unwrap(y));
    }
}

function sub(Range x, Range y) pure returns (Range z) {
    unchecked {
        z = Range.wrap(Range.unwrap(x) - Range.unwrap(y));
    }
}

function sub(Fee x, Fee y) pure returns (Fee z) {
    unchecked {
        z = Fee.wrap(Fee.unwrap(x) - Fee.unwrap(y));
    }
}

function sum(SampleSize[] storage list) view returns (SampleSize z) {
    unchecked {
        z = zeroS;
        for (uint256 i = 0; i < list.length; ++i) {
            z = add(z, list[i]);
        }
    }
}

function sum(Range[] storage list) view returns (Range z) {
    unchecked {
        z = zeroR;
        for (uint256 i = 0; i < list.length; ++i) {
            z = add(z, list[i]);
        }
    }
}

function sum(Fee[] storage list) view returns (Fee z) {
    unchecked {
        for (uint256 i = 0; i < list.length; ++i) {
            z = add(z, list[i]);
        }
    }
}

function scaleWithPrecision(Precision p) pure returns (Scale s) {
    unchecked {
        return Scale.wrap(Scale.unwrap(oneS) + Precision.unwrap(p));
    }
}

function lessThan(Range x, Range y) pure returns (bool) {
    unchecked {
        return Range.unwrap(x) < Range.unwrap(y);
    }
}

function lessThan(Fee x, Fee y) pure returns (bool) {
    unchecked {
        return Fee.unwrap(x) < Fee.unwrap(y);
    }
}

function lessThan(Range x, SampleSize y) pure returns (bool) {
    unchecked {
        return Range.unwrap(x) < SampleSize.unwrap(y);
    }
}

function mul(Scale x, Scale y) pure returns(Scale z) {
    unchecked {
        uint256 xWide = Scale.unwrap(x);
        uint256 yWide = Scale.unwrap(y);
        uint256 zWide = (xWide * yWide) >> 127;
        z = Scale.wrap(zWide);
    }
}

function mul(Fee x, Range y) pure returns (Fee z) {
    unchecked {
        uint256 xWide = Fee.unwrap(x);
        uint256 yWide = Range.unwrap(y);
        uint256 zWide = (xWide * yWide) >> 120;
        z = Fee.wrap(zWide);
    }
}

function mul(Fractional x, Fee y) pure returns (Fee z) {
    unchecked {
        uint256 xWide = Fractional.unwrap(x);
        uint256 yWide = Fee.unwrap(y);
        uint256 zWide = (xWide * yWide) >> 128;
        z = Fee.wrap(zWide);
    }
}

function mul(Fractional x, SampleSize y) pure returns (SampleSize z) {
    unchecked {
        uint256 xWide = Fractional.unwrap(x);
        uint256 yWide = SampleSize.unwrap(y);
        uint256 zWide = (xWide * yWide) >> 128;
        z = SampleSize.wrap(zWide);
    }
}

function frac(Range x, Range y) pure returns (Fractional z) {
    unchecked {
       uint256 xWide = Range.unwrap(x) << 128;
        uint256 yWide = Range.unwrap(y);
        uint256 zWide = xWide / yWide;
        z = Fractional.wrap(zWide);
    }
}

function frac(Fee x, Fee y) pure returns (Fractional z) {
    unchecked {
        uint256 xWide = Fee.unwrap(x) << 128;
        uint256 yWide = Fee.unwrap(y);
        uint256 zWide = xWide / yWide;
        z = Fractional.wrap(zWide);
    }
}

function div(Range x, SampleSize y) pure returns (Precision z) {
    unchecked {
        uint256 xWide = Range.unwrap(x) << 127;
        uint256 yWide = SampleSize.unwrap(y);
        uint256 zWide = xWide / yWide;
        z = Precision.wrap(zWide);
    }
}

