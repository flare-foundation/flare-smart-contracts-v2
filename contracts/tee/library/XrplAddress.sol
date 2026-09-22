// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/**
 * @title XrplAddress
 * @notice Pure-validation, never-reverting validator for XRPL addresses — classic ("r...") and
 *         X-addresses ("X..." mainnet / "T..." testnet) — verifying the Base58 form and the
 *         double-SHA256 checksum.
 * @dev Gas-optimized inline-assembly implementation. Validation only: this is the audited subset of
 *      the XRPL address logic. Encoding and decoding (X-address derivation, classic<->accountId
 *      conversion) live in the test-only codec mock and are intentionally not part of the
 *      production/audited surface.
 *
 *      Classic addresses decode to 25 bytes (which fit one uint256); X-addresses decode to 35 bytes
 *      and use two-limb (hi, lo) arithmetic. All checksums are the first 4 bytes of a double
 *      SHA-256 (precompile 0x02), so the validators are `view`, not `pure`. The embedded X-address
 *      tag is 32-bit (flag 0 or 1); the reserved 64-bit form (flag 2) is rejected, matching
 *      ripple-address-codec. XRPL classic addresses carry no network, so callers that need a network
 *      distinction must rely on the X-address prefix.
 */
library XrplAddress {

    // Reverse base58 map (XRPL alphabet "rpshnaf39wBUDNEGHJKLM4PQRST7VWXYZ2bcdeCg65jkm8oFqi1tuvAxyz"):
    // ASCII byte -> value 0..57, or 0xff if not a base58 char. 128-byte ASCII table; bytes > 127 are
    // rejected by the c > 127 guard before indexing.
    bytes internal constant REVMAP =
        hex"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
        hex"ffffffffffffffffffffffffffffffffff3221071529281b2d08ffffffffffff"
        hex"ff360a260c0e2f0f10ff111213140dff161718191a0b1c1d1e1f20ffffffffff"
        hex"ff0522232425062703312a2bff2c042e0130000233343509373839ffffffffff";

    uint256 private constant MASK64 = 0xffffffffffffffff;

    /**
     * @notice Returns true iff `_address` is a valid XRPL address for the requested network.
     * @dev X-addresses carry the network in their prefix ('X' = mainnet, 'T' = testnet), so an
     *      X-address is accepted only when its prefix matches `_testnet`. Classic 'r' addresses carry
     *      no network and are accepted for either. Never reverts.
     * @param _address  The address string to validate.
     * @param _testnet  True to require testnet, false to require mainnet (X-addresses only).
     * @return          True iff `_address` is valid and, for X-addresses, on the requested network.
     */
    function isValid(
        string memory _address,
        bool _testnet
    )
        internal view
        returns (bool)
    {
        bytes memory input = bytes(_address);
        if (input.length == 0) {
            return false;
        }
        uint8 first = uint8(input[0]);
        if (first == 0x72) {
            // 'r' classic -> no network info, accept for either network
            return _isValidClassicAddress(_address);
        }
        if (first == 0x58) {
            // 'X' mainnet X-address
            return !_testnet && _isValidXAddress(_address);
        }
        if (first == 0x54) {
            // 'T' testnet X-address
            return _testnet && _isValidXAddress(_address);
        }
        return false;
    }

    /**
     * @notice Returns true iff `_classicAddress` is a well-formed classic address with a valid checksum.
     * @dev Never reverts — returns false on any malformed input. The decoded payload must be canonical
     *      (leading-zero count plus magnitude bytes equal to the fixed 25-byte length).
     */
    function _isValidClassicAddress(
        string memory _classicAddress
    )
        private view
        returns (bool _valid)
    {
        bytes memory revmap = REVMAP;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let tbl := add(revmap, 0x20)
            let dptr := add(_classicAddress, 0x20)
            let n := mload(_classicAddress)
            for {} 1 {} {
                if or(lt(n, 25), gt(n, 35)) { break }
                let acc := 0
                let lz := 0
                let counting := 1
                let bad := 0
                for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                    let c := byte(0, mload(add(dptr, i)))
                    if gt(c, 127) { bad := 1 break }
                    let v := byte(0, mload(add(tbl, c)))
                    if eq(v, 0xff) { bad := 1 break }
                    if counting { switch v case 0 { lz := add(lz, 1) } default { counting := 0 } }
                    acc := add(mul(acc, 58), v)
                }
                if bad { break }
                let mb := 0
                for { let t := acc } gt(t, 0) {} { t := shr(8, t) mb := add(mb, 1) }
                if iszero(eq(add(lz, mb), 25)) { break }
                if shr(192, acc) { break }
                let p := mload(0x40)
                mstore(p, acc)
                if iszero(staticcall(gas(), 2, add(p, 7), 21, add(p, 0x40), 32)) { break }
                if iszero(staticcall(gas(), 2, add(p, 0x40), 32, add(p, 0x60), 32)) { break }
                if eq(shr(224, mload(add(p, 0x60))), and(acc, 0xffffffff)) { _valid := 1 }
                break
            }
        }
    }

    /**
     * @notice Returns true iff `_xAddress` is a well-formed X-address with a valid checksum.
     * @dev Never reverts — returns false on any malformed input. Validates the tag flag: flag 0
     *      requires all 8 tag bytes zero, flag 1 requires the high 4 tag bytes zero, and the reserved
     *      64-bit form (flag >= 2) is rejected.
     */
    function _isValidXAddress(
        string memory _xAddress
    )
        private view
        returns (bool _valid)
    {
        bytes memory revmap = REVMAP;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let tbl := add(revmap, 0x20)
            let dptr := add(_xAddress, 0x20)
            let n := mload(_xAddress)
            for {} 1 {} {
                if or(lt(n, 46), gt(n, 48)) { break }
                let lo := 0
                let hi := 0
                let bad := 0
                let lead := 0
                for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                    let c := byte(0, mload(add(dptr, i)))
                    if gt(c, 127) { bad := 1 break }
                    let v := byte(0, mload(add(tbl, c)))
                    if eq(v, 0xff) { bad := 1 break }
                    if and(iszero(i), iszero(v)) { lead := 1 }
                    let mm := mulmod(lo, 58, not(0))
                    let prod := mul(lo, 58)
                    let newLo := add(prod, v)
                    hi := add(add(mul(hi, 58), sub(sub(mm, prod), lt(mm, prod))), lt(newLo, prod))
                    lo := newLo
                }
                if bad { break }
                if lead { break }
                let pfx := shr(8, hi)
                if iszero(or(eq(pfx, 0x0544), eq(pfx, 0x0493))) { break }
                let flag := and(shr(96, lo), 0xff)
                if gt(flag, 1) { break }
                let tagField := and(shr(32, lo), MASK64)
                if and(iszero(flag), gt(tagField, 0)) { break }
                if and(eq(flag, 1), gt(and(tagField, 0xffffffff), 0)) { break }
                let p := mload(0x40)
                mstore(p, shl(232, hi))
                mstore(add(p, 3), lo)
                if iszero(staticcall(gas(), 2, p, 31, add(p, 0x40), 32)) { break }
                if iszero(staticcall(gas(), 2, add(p, 0x40), 32, add(p, 0x60), 32)) { break }
                if eq(shr(224, mload(add(p, 0x60))), and(lo, 0xffffffff)) { _valid := 1 }
                break
            }
        }
    }
}
