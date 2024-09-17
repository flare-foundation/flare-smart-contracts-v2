// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Scale, Precision, SampleSize, Range, Fractional, Fee} from  "../../userInterfaces/IFixedPointArithmetic.sol";


Scale constant oneS = Scale.wrap(1 << 127);
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

