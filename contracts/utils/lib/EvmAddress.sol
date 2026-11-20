// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/**
 * @title EvmAddress
 * @notice Pure, never-reverting validator for EVM addresses. Accepts only the single canonical form:
 *         the EIP-55 mixed-case checksummed `0x`-prefixed hex string (exactly as produced by
 *         converting an `address` to its checksummed string). Network-agnostic — an EVM address is
 *         identical across all EVM chains, so no network is taken.
 * @dev Gas-optimized inline-assembly implementation. The EIP-55 checksum is always enforced
 *      (all-lowercase / all-uppercase forms are rejected unless they happen to be canonical), so there
 *      is exactly one valid representation per address. It computes a single `keccak256` over the
 *      lowercase hex (the EIP-55 hash) and verifies each input letter's case against the hash nibbles
 *      — no address parsing into 20 bytes and no checksummed-string rebuild. `keccak256` is a pure
 *      opcode (not a precompile), so the function is `pure`. Never reverts.
 */
library EvmAddress {

    /**
     * @notice Returns true iff `_address` is the canonical EIP-55 checksummed (`0x`-prefixed) form.
     * @param _address  The address string to validate.
     * @return _valid   True iff `_address` equals the canonical checksummed representation.
     */
    function isValid(
        string memory _address
    )
        internal pure
        returns (bool _valid)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let dptr := add(_address, 0x20)
            let n := mload(_address)
            for {} 1 {} {
                // Single canonical form: "0x" + 40 hex characters.
                if iszero(eq(n, 42)) { break }
                if iszero(eq(byte(0, mload(dptr)), 0x30)) { break } // '0'
                if iszero(eq(byte(0, mload(add(dptr, 1))), 0x78)) { break } // 'x'
                let hexPtr := add(dptr, 2)
                // Pass 1: validate hex and build the lowercase ASCII form into scratch (EIP-55 hashes
                // the lowercase hex string).
                let p := mload(0x40)
                let bad := 0
                for { let i := 0 } lt(i, 40) { i := add(i, 1) } {
                    let c := byte(0, mload(add(hexPtr, i)))
                    let low := c
                    let okc := 0
                    if and(gt(c, 0x2f), lt(c, 0x3a)) { okc := 1 }                    // '0'..'9'
                    if and(gt(c, 0x60), lt(c, 0x67)) { okc := 1 }                    // 'a'..'f'
                    if and(gt(c, 0x40), lt(c, 0x47)) { okc := 1 low := add(c, 0x20) } // 'A'..'F' -> lower
                    if iszero(okc) { bad := 1 break }
                    mstore8(add(p, i), low)
                }
                if bad { break }
                let hash := keccak256(p, 40)
                // Pass 2: each hex letter must be uppercase iff its EIP-55 hash nibble is >= 8. Nibble i
                // (from the most significant) is bits [4*(63-i) .. +3] of the 256-bit hash.
                for { let i := 0 } lt(i, 40) { i := add(i, 1) } {
                    let c := byte(0, mload(add(hexPtr, i)))
                    let isUp := and(gt(c, 0x40), lt(c, 0x47)) // 'A'..'F'
                    let isLo := and(gt(c, 0x60), lt(c, 0x67)) // 'a'..'f'
                    if or(isUp, isLo) {
                        let mustUpper := gt(and(shr(mul(4, sub(63, i)), hash), 0xf), 7)
                        if and(mustUpper, isLo) { bad := 1 break }
                        if and(iszero(mustUpper), isUp) { bad := 1 break }
                    }
                }
                if bad { break }
                _valid := 1
                break
            }
        }
    }
}
