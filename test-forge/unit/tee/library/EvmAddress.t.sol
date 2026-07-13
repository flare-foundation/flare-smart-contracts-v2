// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {EvmAddress} from "../../../../contracts/tee/library/EvmAddress.sol";

contract EvmAddressHarness {
    function isValid(
        string memory _address
    )
        external pure
        returns (bool)
    {
        return EvmAddress.isValid(_address);
    }
}

contract EvmAddressTest is Test {
    // Canonical EIP-55 checksummed vectors.
    string internal constant CHK_A = "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed";
    string internal constant CHK_B = "0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359";
    string internal constant CHK_C = "0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB";
    string internal constant CHK_D = "0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb";

    EvmAddressHarness internal harness;

    function setUp() public {
        harness = new EvmAddressHarness();
    }

    function testValidChecksummed() public view {
        assertTrue(harness.isValid(CHK_A));
        assertTrue(harness.isValid(CHK_B));
        assertTrue(harness.isValid(CHK_C));
        assertTrue(harness.isValid(CHK_D));
    }

    function testNonCanonicalCaseRejected() public view {
        // Only the canonical EIP-55 form is valid; all-lower and all-upper are rejected (the
        // canonical form of CHK_A is mixed-case).
        assertFalse(harness.isValid("0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed")); // all lower
        assertFalse(harness.isValid("0x5AAEB6053F3E94C9B9A09F33669435E7EF1BEAED")); // all upper
        // missing "0x" prefix is not the canonical form either
        assertFalse(harness.isValid("5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"));
    }

    function testMixedCaseBadChecksumRejected() public view {
        // CHK_A with one letter's case flipped breaks the EIP-55 checksum.
        assertFalse(harness.isValid("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BEAed"));
    }

    function testMalformedRejected() public view {
        assertFalse(harness.isValid("")); // empty
        assertFalse(harness.isValid("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAe")); // 39 hex chars
        assertFalse(harness.isValid("0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAeZ")); // non-hex 'Z'
        assertFalse(harness.isValid("0x")); // no body
    }
}
