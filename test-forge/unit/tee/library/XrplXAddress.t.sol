// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {XrplXAddress} from "../../../../contracts/tee/library/XrplXAddress.sol";

// Harness so the (internal) library functions get a real external entry point for size/gas measurement.
contract XrplXAddressHarness {
    function encode(
        bytes20 _accountId,
        uint32 _tag,
        bool _hasTag,
        bool _testNetwork
    )
        external pure
        returns (string memory)
    {
        return XrplXAddress.encode(_accountId, _tag, _hasTag, _testNetwork);
    }

    function encodeFromClassicAddress(
        string memory _classicAddress,
        uint32 _tag,
        bool _hasTag,
        bool _testNetwork
    )
        external pure
        returns (string memory)
    {
        return XrplXAddress.encodeFromClassicAddress(_classicAddress, _tag, _hasTag, _testNetwork);
    }

    function decodeClassicAddress(
        string memory _classicAddress
    )
        external pure
        returns (bytes20)
    {
        return XrplXAddress.decodeClassicAddress(_classicAddress);
    }

    function decodeXAddress(
        string memory _xAddress
    )
        external pure
        returns (
            bytes20 _accountId,
            uint32 _tag,
            bool _hasTag,
            bool _testNetwork
        )
    {
        return XrplXAddress.decodeXAddress(_xAddress);
    }

    function accountIdToClassicAddress(
        bytes20 _accountId
    )
        external pure
        returns (string memory)
    {
        return XrplXAddress.accountIdToClassicAddress(_accountId);
    }

    function decodeXAddressToClassic(
        string memory _xAddress
    )
        external pure
        returns (
            string memory _classicAddress,
            uint32 _tag,
            bool _hasTag,
            bool _testNetwork
        )
    {
        return XrplXAddress.decodeXAddressToClassic(_xAddress);
    }

    function isValidClassicAddress(
        string memory _classicAddress
    )
        external pure
        returns (bool)
    {
        return XrplXAddress.isValidClassicAddress(_classicAddress);
    }

    function isValidXAddress(
        string memory _xAddress
    )
        external pure
        returns (bool)
    {
        return XrplXAddress.isValidXAddress(_xAddress);
    }

    function validateAddress(
        string memory _address
    )
        external pure
        returns (XrplXAddress.AddressFormat)
    {
        return XrplXAddress.validateAddress(_address);
    }
}

contract XrplXAddressTest is Test {
    // ground truth from ripple-address-codec@5.0.1
    bytes20 internal constant ACCT_A = bytes20(0xaA066C988c712815Cc37af71472B7cbbbd4E2A0A);
    string internal constant CLASSIC_A = "rGWrZyQqhTp9Xu7G5Pkayo7bXjH4k4QYpf";
    bytes20 internal constant ACCT_PEPPER = bytes20(0xF40b468d5aC0DbA36E2941877AC2E9bBD48262A1);
    string internal constant CLASSIC_PEPPER = "rPEPPER7kfTD9w2To4CQk6UCfuHM9c6GDY";

    XrplXAddressHarness internal harness;

    function setUp() public {
        harness = new XrplXAddressHarness();
    }

    function testEncodeNoTag() public view {
        assertEq(
            harness.encode(ACCT_A, 0, false, false),
            "XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx1mHp98tDMoQXb"
        );
    }

    function testEncodeTagZeroDiffersFromNoTag() public view {
        // tag == 0 (present) must differ from "no tag"
        assertEq(
            harness.encode(ACCT_A, 0, true, false),
            "XVLhHMPHU98es4dbozjVtdWzVrDjtV8AqEL4xcZj5whKbmc"
        );
    }

    function testEncodeTag13() public view {
        assertEq(
            harness.encode(ACCT_A, 13, true, false),
            "XVLhHMPHU98es4dbozjVtdWzVrDjtVoUhWS5SgMMoLoBzqQ"
        );
    }

    function testEncodeMaxTag() public view {
        assertEq(
            harness.encode(ACCT_A, 4294967295, true, false),
            "XVLhHMPHU98es4dbozjVtdWzVrDjtV18pX8yuPT7y4xaEHi"
        );
    }

    function testEncodePepperTag12345() public view {
        assertEq(
            harness.encode(ACCT_PEPPER, 12345, true, false),
            "XV5sbjUmgPpvXv4ixFWZ5ptAYZ6PD28Sq49uo34VyjnmK5H"
        );
    }

    function testEncodeTestNetwork() public view {
        assertEq(
            harness.encode(ACCT_A, 13, true, true),
            "TVE26TYGhfLC7tQDno7G8dGtxSkYQnTNrgQwkM2tPvGzJRR"
        );
    }

    function testDecodeClassicAddress() public view {
        assertEq(harness.decodeClassicAddress(CLASSIC_A), ACCT_A);
        assertEq(harness.decodeClassicAddress(CLASSIC_PEPPER), ACCT_PEPPER);
    }

    function testEncodeFromClassicAddress() public view {
        assertEq(
            harness.encodeFromClassicAddress(CLASSIC_A, 13, true, false),
            "XVLhHMPHU98es4dbozjVtdWzVrDjtVoUhWS5SgMMoLoBzqQ"
        );
    }

    function testDecodeRevertsOnBadChecksum() public {
        // last char tampered
        vm.expectRevert(XrplXAddress.InvalidClassicAddress.selector);
        harness.decodeClassicAddress("rGWrZyQqhTp9Xu7G5Pkayo7bXjH4k4QYpg");
    }

    function testDecodeRevertsOnBadCharacter() public {
        // '0' is not in the Base58 alphabet
        vm.expectRevert(XrplXAddress.InvalidBase58Character.selector);
        harness.decodeClassicAddress("rGWrZyQqhTp9Xu7G5Pkayo7bXjH4k4QYp0");
    }

    // --- X-address -> (accountId, tag, network) ---

    function _assertDecode(
        string memory _x,
        bytes20 _expectedAcct,
        uint32 _expectedTag,
        bool _expectedHasTag,
        bool _expectedTest
    ) internal view {
        (bytes20 acct, uint32 tag, bool hasTag, bool test) = harness.decodeXAddress(_x);
        assertEq(acct, _expectedAcct);
        assertEq(tag, _expectedTag);
        assertEq(hasTag, _expectedHasTag);
        assertEq(test, _expectedTest);
    }

    function testDecodeXAddressNoTag() public view {
        _assertDecode("XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx1mHp98tDMoQXb", ACCT_A, 0, false, false);
    }

    function testDecodeXAddressTagZero() public view {
        // tag 0 present must decode to hasTag=true, tag=0 (distinct from "no tag")
        _assertDecode("XVLhHMPHU98es4dbozjVtdWzVrDjtV8AqEL4xcZj5whKbmc", ACCT_A, 0, true, false);
    }

    function testDecodeXAddressTag13() public view {
        _assertDecode("XVLhHMPHU98es4dbozjVtdWzVrDjtVoUhWS5SgMMoLoBzqQ", ACCT_A, 13, true, false);
    }

    function testDecodeXAddressMaxTag() public view {
        _assertDecode("XVLhHMPHU98es4dbozjVtdWzVrDjtV18pX8yuPT7y4xaEHi", ACCT_A, 4294967295, true, false);
    }

    function testDecodeXAddressPepper() public view {
        _assertDecode("XV5sbjUmgPpvXv4ixFWZ5ptAYZ6PD28Sq49uo34VyjnmK5H", ACCT_PEPPER, 12345, true, false);
    }

    function testDecodeXAddressTestNetwork() public view {
        _assertDecode("TVE26TYGhfLC7tQDno7G8dGtxSkYQnTNrgQwkM2tPvGzJRR", ACCT_A, 13, true, true);
    }

    function testDecodeXAddressRevertsOnBadChecksum() public {
        // last char tampered
        vm.expectRevert(XrplXAddress.InvalidXAddress.selector);
        harness.decodeXAddress("XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx1mHp98tDMoQXc");
    }

    function testEncodeDecodeRoundTrip() public view {
        string memory x = harness.encode(ACCT_PEPPER, 777, true, false);
        (bytes20 acct, uint32 tag, bool hasTag, bool test) = harness.decodeXAddress(x);
        assertEq(acct, ACCT_PEPPER);
        assertEq(tag, 777);
        assertTrue(hasTag);
        assertTrue(!test);
    }

    // --- accountId -> classic address ---

    function testAccountIdToClassicAddress() public view {
        assertEq(harness.accountIdToClassicAddress(ACCT_A), CLASSIC_A);
        assertEq(harness.accountIdToClassicAddress(ACCT_PEPPER), CLASSIC_PEPPER);
    }

    // --- X-address -> classic address + tag (single call) ---

    function testDecodeXAddressToClassic() public view {
        (string memory classic, uint32 tag, bool hasTag, bool test) =
            harness.decodeXAddressToClassic("XV5sbjUmgPpvXv4ixFWZ5ptAYZ6PD28Sq49uo34VyjnmK5H");
        assertEq(classic, CLASSIC_PEPPER);
        assertEq(tag, 12345);
        assertTrue(hasTag);
        assertTrue(!test);
    }

    function testDecodeXAddressToClassicTestNetNoTag() public view {
        (string memory classic, uint32 tag, bool hasTag, bool test) =
            harness.decodeXAddressToClassic("TVE26TYGhfLC7tQDno7G8dGtxSkYQnTNrgQwkM2tPvGzJRR");
        assertEq(classic, CLASSIC_A);
        assertEq(tag, 13);
        assertTrue(hasTag);
        assertTrue(test);
    }

    // --- validity-only checks (no revert) ---

    function testIsValidClassicAddress() public view {
        assertTrue(harness.isValidClassicAddress(CLASSIC_A));
        assertTrue(harness.isValidClassicAddress(CLASSIC_PEPPER));
        assertTrue(!harness.isValidClassicAddress("rGWrZyQqhTp9Xu7G5Pkayo7bXjH4k4QYpg")); // bad checksum
        assertTrue(!harness.isValidClassicAddress("rGWrZyQqhTp9Xu7G5Pkayo7bXjH4k4QYp0")); // bad char
        assertTrue(!harness.isValidClassicAddress("")); // empty
    }

    function testIsValidXAddress() public view {
        assertTrue(harness.isValidXAddress("XVLhHMPHU98es4dbozjVtdWzVrDjtVoUhWS5SgMMoLoBzqQ"));
        assertTrue(harness.isValidXAddress("TVE26TYGhfLC7tQDno7G8dGtxSkYQnTNrgQwkM2tPvGzJRR")); // testnet
        assertTrue(!harness.isValidXAddress("XVLhHMPHU98es4dbozjVtdWzVrDjtVoUhWS5SgMMoLoBzqR")); // bad checksum
        assertTrue(!harness.isValidXAddress(CLASSIC_A)); // classic address is not a valid X-address
    }

    // --- format-agnostic validation ---

    function _assertFormat(string memory _addr, XrplXAddress.AddressFormat _expected) internal view {
        assertEq(uint8(harness.validateAddress(_addr)), uint8(_expected));
    }

    function testValidateAddressDetectsFormat() public view {
        _assertFormat(CLASSIC_A, XrplXAddress.AddressFormat.Classic);
        _assertFormat(CLASSIC_PEPPER, XrplXAddress.AddressFormat.Classic);
        _assertFormat("XVLhHMPHU98es4dbozjVtdWzVrDjtVoUhWS5SgMMoLoBzqQ", XrplXAddress.AddressFormat.XAddress);
        _assertFormat("TVE26TYGhfLC7tQDno7G8dGtxSkYQnTNrgQwkM2tPvGzJRR", XrplXAddress.AddressFormat.XAddress);
    }

    function testValidateAddressRejectsInvalid() public view {
        // bad classic checksum
        _assertFormat("rGWrZyQqhTp9Xu7G5Pkayo7bXjH4k4QYpg", XrplXAddress.AddressFormat.Invalid);
        // bad X checksum
        _assertFormat("XVLhHMPHU98es4dbozjVtdWzVrDjtVoUhWS5SgMMoLoBzqR", XrplXAddress.AddressFormat.Invalid);
        _assertFormat("", XrplXAddress.AddressFormat.Invalid); // empty
        _assertFormat("1GWrZyQqhTp9Xu7G5Pkayo7bXjH4k4QYpf", XrplXAddress.AddressFormat.Invalid); // unknown prefix
    }
}
