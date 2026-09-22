// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {XrplAddress} from "../../../../contracts/tee/library/XrplAddress.sol";
import {XrplXAddress} from "../../../mock/XrplXAddress.sol";

// Harness so the (internal) library function gets a real external entry point for the tests.
contract XrplAddressHarness {
    function isValid(
        string memory _address,
        bool _testnet
    )
        external view
        returns (bool)
    {
        return XrplAddress.isValid(_address, _testnet);
    }
}

/// @notice Tests for the inline-assembly XrplAddress validator, routed through the public
///         `isValid(address, testnet)` surface. Golden vectors are taken from the audited Go
///         reference (go-flare-common/pkg/xrpl/address, cross-checked against ripple-address-codec /
///         XLS-6); structural rejection cases are mirrored from the xrplAddr library tests.
contract XrplAddressTest is Test {
    bytes20 internal constant ACCT_A = bytes20(0xaA066C988c712815Cc37af71472B7cbbbd4E2A0A);
    string internal constant CLASSIC_A = "rGWrZyQqhTp9Xu7G5Pkayo7bXjH4k4QYpf";
    string internal constant X_A_NOTAG = "XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx1mHp98tDMoQXb";
    string internal constant XADDR_TEST = "TVE26TYGhfLC7tQDno7G8dGtxSkYQn49b3qD26PK7FcGSKE";

    bytes internal constant ALPHABET = "rpshnaf39wBUDNEGHJKLM4PQRST7VWXYZ2bcdeCg65jkm8oFqi1tuvAxyz";

    string[12] internal validClassic = [
        "rhbQ2PoSsmzh5XnmWnutCa6dmAC2qj1z1S",
        "rUpy3eEg8rqjqfUoLeBnZkscbKbFsKXC3v",
        "rMuZNV2kjCKs8v8rd8QFizAaPdvCDYTPc7",
        "rf27pmNLFaXFwQfZPbTKe2Z665e1V76oC5",
        "rN5N6fJbc8xyViPDeQFMQMpYfVHuxSGV2G",
        "rJQesZZEQzW9J3Eb1X1Snc7E6YGk7kTMoK",
        "r9cvJhquqeExszdWZSw2rrFP98fsVFLdPe",
        "rJrRMgiRgrU6hDF4pgu5DXQdWyPbY35ErN",
        "rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh",
        "rU6K7V3Po4snVhBBaU29sesqs2qTQJWDw1",
        "rLUEXYuLiQptky37CqLcm9USQpPiz5rkpD",
        "rGWrZyQqhTp9Xu7G5Pkayo7bXjH4k4QYpf"
    ];

    // Known-valid mainnet ("X...") X-addresses for the same account, across tag flags.
    string[5] internal validXMain = [
        "XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx1mHp98tDMoQXb", // no tag
        "XVLhHMPHU98es4dbozjVtdWzVrDjtV8AqEL4xcZj5whKbmc", // tag 0
        "XVLhHMPHU98es4dbozjVtdWzVrDjtVijiy6dVhdE4mRdMDU", // tag 13371337
        "XVLhHMPHU98es4dbozjVtdWzVrDjtV18pX8yuPT7y4xaEHi", // tag max
        "XVPcpSm47b1CZkf5AkKM9a84dQHe3mTCLZc5ZAoh11sd5nY" // other account, tag 42
    ];

    XrplAddressHarness internal harness;

    function setUp() public {
        harness = new XrplAddressHarness();
    }

    // ------------------------------------------------------------------ classic (network-agnostic)

    function testClassicAcceptedForEitherNetwork() public view {
        // classic 'r' addresses carry no network -> accepted regardless of `_testnet`
        assertTrue(harness.isValid(CLASSIC_A, false));
        assertTrue(harness.isValid(CLASSIC_A, true));
    }

    function testValidClassicVectorsAccepted() public view {
        for (uint256 i = 0; i < validClassic.length; i++) {
            assertTrue(harness.isValid(validClassic[i], false), validClassic[i]);
            assertTrue(harness.isValid(validClassic[i], true), validClassic[i]);
        }
    }

    function testMalformedClassicRejected() public view {
        assertFalse(harness.isValid("", false)); // empty
        assertFalse(harness.isValid("rhbQ2PoSsmzh5XnmWnutCa6dmAC2qj1z1l", false)); // bad alphabet char 'l'
        assertFalse(harness.isValid("rHb9CJAWyB4rj91VRWn96DkukG4bwdtyT0", false)); // bad alphabet char '0'
        assertFalse(harness.isValid("rGWrZyQqhTp9Xu7G5Pkayo7bXjH4k4QYpg", false)); // bad checksum
        assertFalse(harness.isValid("rhbQ2PoSsmzh5XnmWnutCa6dmAC2qj1z1h", false)); // bad checksum 2
        assertFalse(harness.isValid("rU6K7V3Po4snVhBBaU29sesqs2qTQJWDw2", false)); // bad checksum 3
        assertFalse(harness.isValid("rKTyuZsNuQbL", false)); // too short
        assertFalse(harness.isValid("hhbQ2PoSsmzh5XnmWnutCa6dmAC2qj1z1S", false)); // unknown leading char
    }

    // -------------------------------------------------------------------- X-address + network rules

    function testXAddressNetworkEnforced() public view {
        // X-mainnet ('X') accepted only when mainnet requested
        assertTrue(harness.isValid(X_A_NOTAG, false));
        assertFalse(harness.isValid(X_A_NOTAG, true));
        // X-testnet ('T') accepted only when testnet requested
        assertTrue(harness.isValid(XADDR_TEST, true));
        assertFalse(harness.isValid(XADDR_TEST, false));
    }

    function testValidXMainVectorsAccepted() public view {
        for (uint256 i = 0; i < validXMain.length; i++) {
            assertTrue(harness.isValid(validXMain[i], false), validXMain[i]); // valid on mainnet
            assertFalse(harness.isValid(validXMain[i], true), validXMain[i]); // rejected on testnet
        }
    }

    function testValidTestnetAccepted() public view {
        assertTrue(harness.isValid(XADDR_TEST, true));
        assertFalse(harness.isValid(XADDR_TEST, false));
    }

    function testMalformedXRejected() public view {
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx1mHp98"); // truncated
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx1mHp98tDMoQXc"); // bad checksum
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx1mHp98tDMoQX0"); // bad alphabet char
    }

    /// @dev X-addresses with a valid checksum but a reserved/illegal tag flag must be rejected.
    function testReservedFlagXRejected() public view {
        // flag 0 (no tag) with a tag byte set
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV53jSo8mAyvfybtDtz");
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV5feDExwfMngHkavE9");
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdxApGmSFzLRdmrq");
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx18rqCzSi1mvc2");
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx1mHBiTuhTFFSt");
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx1mHpBz4998sdm");
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx1mHp9oPf6LhVX");
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx1mHp98tJBzqpp");
        // flag 1 (32-bit tag) with a HIGH tag byte set
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV8AqEL4x8GQjraTqWQ");
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV8AqEL4xcbAUr43a8X");
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV8AqEL4xcZkUzDugMz");
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV8AqEL4xcZj5HM1jaS");
        // reserved / higher flags
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV18pX8zeUygYrCgrPh"); // flag 2 (main)
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtVxcDFEcKoPdMvzPFe3"); // flag 3 (main)
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtixrEKteMKRq2cTWip9"); // flag 255 (main)
        _reject("TVE26TYGhfLC7tQDno7G8dGtxSkYQnXoy6kSAtDD3cACeAS"); // flag 2 (test)
    }

    /// @dev base58-clean inputs whose decoded length is not 35 must be rejected.
    function testLengthBoundaryRejected() public view {
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx1mHp98tDMoQX"); // 46-char truncation
        _reject("XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx1mHp98tDMoQXbr"); // 48-char overlong
        _reject("rpshnaf39wBUDNEGHJKLM4PQRST7VWXYZ2bcdeCg65jkm8"); // 46-char arbitrary base58
        _reject("rpshnaf39wBUDNEGHJKLM4PQRST7VWXYZ2bcdeCg65jkm8oF"); // 48-char arbitrary base58
    }

    function testLeadingPaddingRejected() public view {
        // an extra leading 'r' makes the string a non-canonical 'r' (classic) input -> rejected
        _reject(string.concat("r", X_A_NOTAG));
        _reject(string.concat("rr", X_A_NOTAG));
        _reject(string.concat("r", CLASSIC_A));
    }

    // ------------------------------------------------------------- base58 alphabet exhaustiveness

    function testEveryNonAlphabetAsciiRejects() public view {
        bytes memory cBase = bytes(CLASSIC_A);
        bytes memory xBase = bytes(X_A_NOTAG);
        for (uint256 c = 0; c < 128; c++) {
            if (_inAlphabet(uint8(c))) {
                continue;
            }
            // mutate an interior byte (prefix stays, so dispatch is unchanged)
            assertFalse(harness.isValid(_withByteAt(cBase, 5, uint8(c)), false), "classic non-alpha");
            assertFalse(harness.isValid(_withByteAt(xBase, 10, uint8(c)), false), "x non-alpha");
        }
    }

    function testHighBytesRejected() public view {
        bytes memory cBase = bytes(CLASSIC_A);
        bytes memory xBase = bytes(X_A_NOTAG);
        for (uint256 c = 128; c < 256; c++) {
            assertFalse(harness.isValid(_withByteAt(cBase, 5, uint8(c)), false), "classic high byte");
            assertFalse(harness.isValid(_withByteAt(xBase, 10, uint8(c)), false), "x high byte");
        }
    }

    // --------------------------------------------------- cross-check against the test-only codec

    /// Anything the codec mock encodes must validate, on the matching network, for both classic and
    /// X-address forms — and be rejected on the wrong network for X-addresses.
    function testCrossCheckAgainstCodec() public view {
        assertEq(XrplXAddress.accountIdToClassicAddress(ACCT_A), CLASSIC_A);
        assertTrue(harness.isValid(XrplXAddress.accountIdToClassicAddress(ACCT_A), false));
        assertTrue(harness.isValid(XrplXAddress.accountIdToClassicAddress(ACCT_A), true));

        string memory xMain = XrplXAddress.encode(ACCT_A, 13, true, false);
        assertTrue(harness.isValid(xMain, false));
        assertFalse(harness.isValid(xMain, true)); // mainnet X-address rejected on testnet

        string memory xTest = XrplXAddress.encode(ACCT_A, 99, true, true);
        assertTrue(harness.isValid(xTest, true));
        assertFalse(harness.isValid(xTest, false)); // testnet X-address rejected on mainnet

        // tagless mainnet encoding round-trips to the frozen no-tag vector
        assertEq(XrplXAddress.encode(ACCT_A, 0, false, false), X_A_NOTAG);
        assertTrue(harness.isValid(X_A_NOTAG, false));
    }

    // -------------------------------------------------------------------------------------- fuzz

    /// @dev `isValid` must return a bool for ANY input and never revert.
    function testFuzzIsValidNeverReverts(bytes32 _seed, uint8 _len) public view {
        uint256 n = uint256(_len) % 64;
        bytes memory b = new bytes(n);
        for (uint256 i = 0; i < n; i++) {
            b[i] = bytes1(uint8(uint256(keccak256(abi.encodePacked(_seed, i)))));
        }
        string memory s = string(b);
        harness.isValid(s, false);
        harness.isValid(s, true);
    }

    function testFuzzValidClassicAcceptedEitherNetwork(uint8 _idx) public view {
        string memory classic = validClassic[_idx % validClassic.length];
        assertTrue(harness.isValid(classic, false));
        assertTrue(harness.isValid(classic, true));
    }

    // ----------------------------------------------------------------------------------- helpers

    /// @dev A malformed/illegal address must be rejected regardless of the requested network.
    function _reject(string memory _s) internal view {
        assertFalse(harness.isValid(_s, false), "must reject (mainnet)");
        assertFalse(harness.isValid(_s, true), "must reject (testnet)");
    }

    function _inAlphabet(uint8 _c) internal pure returns (bool) {
        bytes memory a = ALPHABET;
        for (uint256 i = 0; i < a.length; i++) {
            if (uint8(a[i]) == _c) {
                return true;
            }
        }
        return false;
    }

    function _withByteAt(
        bytes memory _base,
        uint256 _pos,
        uint8 _b
    )
        internal pure
        returns (string memory)
    {
        bytes memory copy = new bytes(_base.length);
        for (uint256 i = 0; i < _base.length; i++) {
            copy[i] = _base[i];
        }
        copy[_pos] = bytes1(_b);
        return string(copy);
    }
}
