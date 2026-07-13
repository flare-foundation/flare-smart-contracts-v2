// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/**
 * @title Base58Check
 * @notice Shared, validation-only Base58Check decoder for chains that use the Bitcoin Base58
 *         alphabet (Bitcoin, Dogecoin). Decodes the 25-byte `version | hash160(20) | checksum(4)`
 *         payload, verifies the double-SHA256 checksum, and returns the version byte for the caller
 *         to map to a chain/network. Never reverts.
 * @dev Gas-optimized inline-assembly implementation (same shape as {XrplAddress}): the input bytes
 *      are read directly, accumulated into a single uint256 (the 25-byte payload is 200 bits), and
 *      the checksum is the first 4 bytes of a double SHA-256 computed via the `0x02` precompile —
 *      hence `view`, not `pure`. The encoding is required to be canonical (leading-'1' count plus
 *      magnitude bytes must equal the fixed 25-byte length).
 */
library Base58Check {

    // Reverse Bitcoin Base58 map ("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"):
    // ASCII byte -> digit 0..57, or 0xff if not a Base58 character. 128-byte ASCII table; bytes > 127
    // are rejected by the c > 127 guard before indexing.
    bytes internal constant REVMAP =
        hex"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
        hex"ffffffffffffffffffffffffffffffffff000102030405060708ffffffffffff"
        hex"ff090a0b0c0d0e0f10ff1112131415ff161718191a1b1c1d1e1f20ffffffffff"
        hex"ff2122232425262728292a2bff2c2d2e2f30313233343536373839ffffffffff";

    /**
     * @notice Decodes a Base58Check string, verifying its checksum.
     * @param _address  The Base58Check address string.
     * @return _ok       True iff `_address` is a well-formed 25-byte Base58Check payload with a valid
     *                    double-SHA256 checksum and canonical leading-zero encoding.
     * @return _version  The version byte (most significant byte of the payload); 0 when `_ok` is false.
     * @return _hash160  The 20-byte hash payload; zero when `_ok` is false.
     */
    function decode(
        string memory _address
    )
        internal view
        returns (
            bool _ok,
            uint8 _version,
            bytes20 _hash160
        )
    {
        bytes memory revmap = REVMAP;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let tbl := add(revmap, 0x20)
            let dptr := add(_address, 0x20)
            let n := mload(_address)
            for {} 1 {} {
                // A 25-byte payload encodes to 25..34 Base58 chars; the 35 upper bound also keeps the
                // accumulation overflow-safe (58**35 < 2**256).
                if or(lt(n, 25), gt(n, 35)) { break }
                let acc := 0
                let lz := 0          // leading '1' (digit 0) count
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
                // Canonical encoding: leading '1's + magnitude bytes must total the fixed 25-byte
                // payload length (this also bounds acc < 2**200, so the version byte sits in bits 192).
                let mb := 0
                for { let t := acc } gt(t, 0) {} { t := shr(8, t) mb := add(mb, 1) }
                if iszero(eq(add(lz, mb), 25)) { break }
                // Double SHA-256 over version+hash160 (the first 21 of the 25 bytes); compare the
                // 4-byte checksum (the low 4 bytes of acc). `acc` is right-aligned in the word at p, so
                // the payload occupies p+7..p+31 and version+hash160 is p+7..p+27 (21 bytes).
                let p := mload(0x40)
                mstore(p, acc)
                if iszero(staticcall(gas(), 2, add(p, 7), 21, add(p, 0x40), 32)) { break }
                if iszero(staticcall(gas(), 2, add(p, 0x40), 32, add(p, 0x60), 32)) { break }
                if iszero(eq(shr(224, mload(add(p, 0x60))), and(acc, 0xffffffff))) { break }
                _ok := 1
                _version := and(shr(192, acc), 0xff)
                _hash160 := shl(96, and(shr(32, acc), 0xffffffffffffffffffffffffffffffffffffffff))
                break
            }
        }
    }
}
