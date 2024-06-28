// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

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
