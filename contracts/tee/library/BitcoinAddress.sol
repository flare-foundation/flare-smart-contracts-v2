// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { Base58Check } from "./Base58Check.sol";

/**
 * @title BitcoinAddress
 * @notice Never-reverting, network-aware validator for Bitcoin payout addresses. Accepts the
 *         spendable address types only: legacy P2PKH and P2SH (Base58Check), SegWit v0 P2WPKH/P2WSH
 *         (Bech32), and SegWit v1 Taproot P2TR (Bech32m), on mainnet, testnet, and regtest.
 * @dev The accepted set is hardcoded (no settable config). Undefined witness versions (2..16) and
 *      non-standard program lengths are rejected — paying an undefined witness version risks loss
 *      (such outputs are currently anyone-can-spend). Bech32/Bech32m checksums follow BIP-173/BIP-350.
 *      SegWit addresses are accepted in either all-lowercase or all-uppercase (mixed case rejected),
 *      matching BIP-173 and the Flare FDC AddressValidity verifier; the FDC canonical `standardAddress`
 *      form is lowercase, so any consumer that needs a single form should lowercase bech32.
 */
library BitcoinAddress {

    enum Network {
        Mainnet,
        Testnet,
        Regtest
    }

    // Two concatenated 128-byte lookup tables kept in one constant so a single memory copy (and one
    // stack slot) backs both — the latter matters because the SegWit decoder's inline assembly is
    // otherwise one stack slot too deep under the non-viaIR (coverage) profile.
    //
    // [0..128)  Reverse Bech32 map (charset "qpzry9x8gf2tvdw0s3jn54khce6mua7l"): ASCII byte -> entry,
    //           or 0xff if not a Bech32 character. The entry packs the 5-bit value in bits 0..4 and
    //           the case in bits 6..7 (0x40 = lowercase letter, 0x80 = uppercase letter, 0 = digit),
    //           so one lookup yields both the symbol value (`& 0x1f`) and the case bit for the
    //           mixed-case check, with no per-char range tests. Bytes > 127 are rejected before indexing.
    // [128..256) Polymod generator lookup: for each 5-bit `top` (0..31), the XOR of the BIP-173
    //           generator constants selected by its set bits (32 packed big-endian uint32 entries),
    //           folding a step with one lookup + XOR instead of five conditional XORs.
    bytes internal constant BECH32_TABLES =
        hex"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
        hex"ffffffffffffffffffffffffffffffff0fff0a1115141a1e0705ffffffffffff"
        hex"ff9dff988d99898897ff92969f9b93ff818083908b9c8c8e868482ffffffffff"
        hex"ff5dff584d59494857ff52565f5b53ff414043504b5c4c4e464442ffffffffff"
        hex"000000003b6a57b226508e6d1d3ad9df1ea119fa25cb4e4838f19797039bc025"
        hex"3d4233dd0628646f1b12bdb02078ea0223e32a2718897d9505b3a44a3ed9f3f8"
        hex"2a1462b3117e35010c44ecde372ebb6c34b57b490fdf2cfb12e5f524298fa296"
        hex"1756516e2c3c06dc3106df030a6c88b109f74894329d1f262fa7c6f914cd914b";

    /**
     * @notice Returns true iff `_address` is a valid, spendable Bitcoin address for `_network`.
     * @param _address  The address string to validate.
     * @param _network  The expected network (mainnet/testnet/regtest).
     * @return          True iff `_address` is a well-formed, accepted Bitcoin address on `_network`.
     */
    function isValid(
        string memory _address,
        Network _network
    )
        internal view
        returns (bool)
    {
        bytes memory input = bytes(_address);
        if (_looksLikeSegwit(input)) {
            return _isValidSegwit(input, uint256(uint8(_network)));
        }
        return _isValidBase58(_address, _network);
    }

    /**
     * @notice Validates a legacy Base58Check address (P2PKH / P2SH) and checks its network.
     */
    function _isValidBase58(
        string memory _address,
        Network _network
    )
        private view
        returns (bool)
    {
        (bool ok, uint8 version, ) = Base58Check.decode(_address);
        if (!ok) {
            return false;
        }
        // Mainnet: 0x00 (P2PKH) / 0x05 (P2SH). Testnet & regtest share 0x6f (P2PKH) / 0xc4 (P2SH).
        if (version == 0x00 || version == 0x05) {
            return _network == Network.Mainnet;
        }
        if (version == 0x6f || version == 0xc4) {
            return _network == Network.Testnet || _network == Network.Regtest;
        }
        return false;
    }

    /**
     * @notice Validates a Bech32/Bech32m SegWit address, checking case, HRP/network, checksum,
     *         witness version, and program length against the hardcoded accepted set.
     * @dev Gas-optimized inline-assembly single pass: the input bytes are read directly (no per-byte
     *      bounds checks), each data symbol is decoded once via `BECH32_REVMAP`, folded into the
     *      Bech32 polymod (generator constants and HRP expansion inlined), and — for the program
     *      symbols — regrouped from 5-bit to 8-bit. `_expectedNet` is the {Network} enum as a uint
     *      (0 = Mainnet, 1 = Testnet, 2 = Regtest). Pure (no precompiles). Never reverts.
     */
    function _isValidSegwit(
        bytes memory _input,
        uint256 _expectedNet
    )
        private pure
        returns (bool _valid)
    {
        bytes memory tables = BECH32_TABLES;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // lowercase an ASCII byte (A-Z -> a-z)
            function lc(c) -> r {
                r := c
                if and(gt(c, 0x40), lt(c, 0x5b)) { r := add(c, 32) }
            }
            // one BIP-173 polymod step folding 5-bit `v` into running checksum `chk`; the five
            // generator XORs selected by the top 5 bits are precomputed in `glut` (entry = top*4).
            function pmod(chk, v, glut) -> out {
                let top := shr(25, chk)
                out := xor(xor(shl(5, and(chk, 0x1ffffff)), v), shr(224, mload(add(glut, mul(top, 4)))))
            }
            // HRP -> network (0/1/2, or 0xff if unrecognized) and separator index (2/4, or 0).
            // The separator is the unique '1' (0x31); for HRP bc/tb/bcrt it sits at index 2 or 4.
            function hrpInfo(dptr) -> net, sep {
                net := 0xff
                switch eq(byte(0, mload(add(dptr, 2))), 0x31)
                case 1 {
                    sep := 2
                    let a := lc(byte(0, mload(dptr)))
                    let b := lc(byte(0, mload(add(dptr, 1))))
                    if and(eq(a, 0x62), eq(b, 0x63)) { net := 0 } // "bc"
                    if and(eq(a, 0x74), eq(b, 0x62)) { net := 1 } // "tb"
                }
                default {
                    if eq(byte(0, mload(add(dptr, 4))), 0x31) {
                        sep := 4
                        let a := lc(byte(0, mload(dptr)))
                        let b := lc(byte(0, mload(add(dptr, 1))))
                        let c := lc(byte(0, mload(add(dptr, 2))))
                        let d := lc(byte(0, mload(add(dptr, 3))))
                        if and(and(eq(a, 0x62), eq(b, 0x63)), and(eq(c, 0x72), eq(d, 0x74))) {
                            net := 2 // "bcrt"
                        }
                    }
                }
            }
            // Single pass over hrpExpand(hrp) ++ data symbols, then the BIP-173/350 acceptance checks;
            // returns 1 iff the address is a valid, accepted SegWit address for the (already
            // network-matched) HRP. Folding the checks in here keeps the outer block's stack shallow
            // enough to compile without viaIR (coverage profile). BIP-173 allows an address to be
            // all-lowercase OR all-uppercase; only mixed case (cmask == 3) is rejected.
            function scanAll(dptr, tbl, glut, sep, m) -> valid {
                let chk := 1
                let cmask := 0
                // hrpExpand: each char's high 3 bits, then a 0 separator, then each char's low 5 bits.
                for { let i := 0 } lt(i, sep) { i := add(i, 1) } {
                    let raw := byte(0, mload(add(dptr, i)))
                    if and(gt(raw, 0x40), lt(raw, 0x5b)) { cmask := or(cmask, 2) }
                    if and(gt(raw, 0x60), lt(raw, 0x7b)) { cmask := or(cmask, 1) }
                    chk := pmod(chk, shr(5, lc(raw)), glut)
                }
                chk := pmod(chk, 0, glut)
                for { let i := 0 } lt(i, sep) { i := add(i, 1) } {
                    chk := pmod(chk, and(lc(byte(0, mload(add(dptr, i)))), 31), glut)
                }
                // data symbols: decode once, fold into polymod, regroup the program bits 5->8.
                let acc := 0
                let bits := 0
                let plen := 0
                let witver := 0
                for { let i := 0 } lt(i, m) { i := add(i, 1) } {
                    let raw := byte(0, mload(add(dptr, add(add(sep, 1), i))))
                    if gt(raw, 127) { leave } // valid stays 0
                    // one lookup -> 5-bit value (low 5 bits) + case (bit6 lower, bit7 upper)
                    let e := byte(0, mload(add(tbl, raw)))
                    if eq(e, 0xff) { leave }
                    cmask := or(cmask, shr(6, and(e, 0xc0)))
                    chk := pmod(chk, and(e, 0x1f), glut)
                    switch i
                    case 0 { witver := and(e, 0x1f) }
                    default {
                        // program symbols exclude the version (index 0) and the 6-symbol checksum
                        if lt(add(i, 6), m) {
                            acc := or(shl(5, acc), and(e, 0x1f))
                            bits := add(bits, 5)
                            if gt(bits, 7) {
                                bits := sub(bits, 8)
                                plen := add(plen, 1)
                            }
                            acc := and(acc, sub(shl(bits, 1), 1))
                        }
                    }
                }
                if eq(cmask, 3) { leave } // mixed case is invalid (BIP-173)
                if or(gt(bits, 4), gt(acc, 0)) { leave } // 5->8 padding must be < 5 bits, all zero
                // checksum constant + accepted program length, by witness version (reject 2..16):
                // P2WPKH/P2WSH (v0, Bech32) and P2TR (v1, Bech32m).
                switch witver
                case 0 { if and(eq(chk, 1), or(eq(plen, 20), eq(plen, 32))) { valid := 1 } }
                case 1 { if and(eq(chk, 0x2bc830a3), eq(plen, 32)) { valid := 1 } }
            }

            let dptr := add(_input, 0x20)
            let n := mload(_input)
            for {} 1 {} {
                // BIP-173 caps a Bech32 string at 90 chars; lower bound leaves room for HRP + '1' +
                // version + 6-symbol checksum.
                if or(lt(n, 8), gt(n, 90)) { break }
                let net, sep := hrpInfo(dptr)
                if iszero(eq(net, _expectedNet)) { break }
                // data length (witness version + program + 6-symbol checksum)
                let m := sub(sub(n, sep), 1)
                if lt(m, 7) { break }
                // tables: [0x20..0xa0) = Bech32 reverse map, [0xa0..0x120) = polymod generator LUT
                _valid := scanAll(dptr, add(tables, 0x20), add(tables, 0xa0), sep, m)
                break
            }
        }
    }

    /**
     * @notice Fast prefix check: does `_input` start with a recognized Bech32 HRP and separator
     *         ("bc1"/"tb1"/"bcrt1", case-insensitive)? Routes the dispatch in `isValid`.
     */
    function _looksLikeSegwit(
        bytes memory _input
    )
        private pure
        returns (bool)
    {
        uint256 n = _input.length;
        if (n >= 3 && _input[2] == "1") {
            bytes1 a = _toLower(_input[0]);
            bytes1 b = _toLower(_input[1]);
            if ((a == "b" && b == "c") || (a == "t" && b == "b")) {
                return true;
            }
        }
        if (
            n >= 5 && _input[4] == "1" &&
            _toLower(_input[0]) == "b" && _toLower(_input[1]) == "c" &&
            _toLower(_input[2]) == "r" && _toLower(_input[3]) == "t"
        ) {
            return true;
        }
        return false;
    }

    /**
     * @notice Lowercases an ASCII byte (A-Z -> a-z); leaves all other bytes unchanged.
     */
    function _toLower(
        bytes1 _c
    )
        private pure
        returns (bytes1)
    {
        uint8 c = uint8(_c);
        if (c >= 0x41 && c <= 0x5a) {
            return bytes1(c + 32);
        }
        return _c;
    }
}
