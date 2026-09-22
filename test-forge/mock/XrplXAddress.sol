// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/**
 * @title XrplXAddress
 * @notice Pure utility library for deriving an XRPL X-address (XLS-5d) from a classic account
 *         identifier (the 160-bit AccountID) and an optional 32-bit destination tag.
 * @dev    Not imported anywhere yet. The X-address payload is:
 *
 *           prefix(2) | accountId(20) | flag(1) | tag(8, little-endian) | checksum(4)   = 35 bytes
 *
 *         - prefix: 0x05 0x44 (mainnet, "X...") or 0x04 0x93 (testnet, "T...")
 *         - flag:   0x00 when no tag is present, 0x01 for a 32-bit tag
 *         - tag:    8 little-endian bytes; only the low 4 carry the 32-bit tag, the high 4 are zero
 *                   (64-bit tags / flag 0x02 are intentionally not supported — destination tags are 32-bit)
 *         - checksum: first 4 bytes of sha256(sha256(prefix|accountId|flag|tag))
 *
 *         The 35-byte payload is then Base58-encoded with the XRPL alphabet.
 *
 *         Hashing uses the EVM `sha256` precompile (no assembly). Base58 conversion is done with
 *         limb-based integer arithmetic in plain Solidity (two `mload`s aside): a classic payload
 *         (25 bytes) fits one uint256, an X-address payload (35 bytes) uses two base-2**248 limbs.
 *         Note that "no tag" (`_hasTag == false`) and "tag == 0" yield different X-addresses,
 *         matching the reference implementation.
 */
library XrplXAddress {

    // result of validateAddress: the detected format, or Invalid if validation failed
    enum AddressFormat {
        Invalid,
        Classic,
        XAddress
    }

    // forward map: Base58 digit (0..57) -> XRPL alphabet character
    bytes internal constant ALPHABET = "rpshnaf39wBUDNEGHJKLM4PQRST7VWXYZ2bcdeCg65jkm8oFqi1tuvAxyz";
    // reverse map: character code (0..255) -> Base58 digit + 1 (0 means "not a Base58 character"),
    // precomputed from ALPHABET so it never has to be rebuilt at runtime
    bytes internal constant REVMAP =
        hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        hex"00332208162a291c2e0900000000000000370b270d0f30101100121314150e001718191a1b0c1d1e1f20210000000000"
        hex"000623242526072804322b2c002d052f023101033435360a38393a000000000000000000000000000000000000000000"
        hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
        hex"00000000000000000000000000000000";

    error InvalidClassicAddress();
    error InvalidBase58Character();
    error InvalidXAddress();
    error UnsupportedTagFlag();

    /**
     * @notice Derives the X-address from a classic address string and an optional destination tag.
     * @param _classicAddress   Classic XRPL address (e.g. "rGWrZyQqhTp9Xu7G5Pkayo7bXjH4k4QYpf").
     * @param _tag              32-bit destination tag; ignored when `_hasTag` is false.
     * @param _hasTag           Whether a destination tag is present.
     * @param _testNetwork      True for testnet ("T...") prefix, false for mainnet ("X...").
     * @return                  The Base58 X-address string.
     */
    function encodeFromClassicAddress(
        string memory _classicAddress,
        uint32 _tag,
        bool _hasTag,
        bool _testNetwork
    )
        internal pure
        returns (string memory)
    {
        return encode(decodeClassicAddress(_classicAddress), _tag, _hasTag, _testNetwork);
    }

    /**
     * @notice Derives the X-address from a 20-byte AccountID and an optional destination tag.
     * @param _accountId        The 160-bit AccountID (the hash embedded in a classic r-address).
     * @param _tag              32-bit destination tag; ignored when `_hasTag` is false.
     * @param _hasTag           Whether a destination tag is present.
     * @param _testNetwork      True for testnet ("T...") prefix, false for mainnet ("X...").
     * @return                  The Base58 X-address string.
     */
    function encode(
        bytes20 _accountId,
        uint32 _tag,
        bool _hasTag,
        bool _testNetwork
    )
        internal pure
        returns (string memory)
    {
        // 31-byte body: prefix(2) | accountId(20) | flag(1) | tag(8, little-endian)
        bytes memory body = new bytes(31);
        if (_testNetwork) {
            body[0] = 0x04;
            body[1] = 0x93;
        } else {
            body[0] = 0x05;
            body[1] = 0x44;
        }
        for (uint256 i = 0; i < 20; i++) {
            body[2 + i] = _accountId[i];
        }
        uint32 tag = _hasTag ? _tag : 0;
        body[22] = bytes1(_hasTag ? uint8(1) : uint8(0));
        body[23] = bytes1(uint8(tag));
        body[24] = bytes1(uint8(tag >> 8));
        body[25] = bytes1(uint8(tag >> 16));
        body[26] = bytes1(uint8(tag >> 24));
        // body[27..30] remain zero (high 32 bits of the 64-bit tag field)

        bytes32 checksum = sha256(abi.encodePacked(sha256(body)));

        bytes memory full = new bytes(35);
        for (uint256 i = 0; i < 31; i++) {
            full[i] = body[i];
        }
        full[31] = checksum[0];
        full[32] = checksum[1];
        full[33] = checksum[2];
        full[34] = checksum[3];

        return _base58Encode35(full);
    }

    /**
     * @notice Decodes a classic XRPL address string into its 20-byte AccountID, verifying the checksum.
     * @param _classicAddress   Classic XRPL address string.
     * @return                  The 20-byte AccountID.
     */
    function decodeClassicAddress(
        string memory _classicAddress
    )
        internal pure
        returns (bytes20)
    {
        bytes memory input = bytes(_classicAddress);
        // The decoded payload is version(1) | accountId(20) | checksum(4) = 25 bytes (200 bits),
        // so the whole value fits in a single uint256. Accumulate the Base58 digits directly using
        // the constant reverse map (REVMAP[c] = digit + 1; 0 means "not a Base58 character").
        // Checked arithmetic rejects any over-long input by reverting on overflow.
        bytes memory revmap = REVMAP; // copy the constant into memory once, then index cheaply
        uint256 value = 0;
        for (uint256 i = 0; i < input.length; i++) {
            uint256 digit = uint8(revmap[uint8(input[i])]);
            require(digit != 0, InvalidBase58Character());
            value = value * 58 + (digit - 1);
        }
        // The version byte (most significant of the 25) must be 0x00, i.e. value < 2**192.
        // This also canonicalises leading zero bytes: the 25-byte layout is reconstructed from
        // the integer, so accountIds starting with 0x00 need no special handling.
        require(value >> 192 == 0, InvalidClassicAddress());

        bytes20 accountId = bytes20(uint160(value >> 32));
        // checksum is over the 21-byte body [0x00 | accountId]; compare against the low 4 bytes
        bytes32 checksum = sha256(abi.encodePacked(sha256(abi.encodePacked(bytes1(0x00), accountId))));
        require(uint32(value) == uint32(bytes4(checksum)), InvalidClassicAddress());
        return accountId;
    }

    /**
     * @notice Decodes an X-address into its AccountID, destination tag and network.
     * @param _xAddress     The Base58 X-address string ("X..." mainnet or "T..." testnet).
     * @return _accountId   The 20-byte AccountID.
     * @return _tag         The 32-bit destination tag (0 when `_hasTag` is false).
     * @return _hasTag      Whether a destination tag is present.
     * @return _testNetwork True if the address carries the testnet prefix.
     */
    function decodeXAddress(
        string memory _xAddress
    )
        internal pure
        returns (
            bytes20 _accountId,
            uint32 _tag,
            bool _hasTag,
            bool _testNetwork
        )
    {
        bytes memory input = bytes(_xAddress);
        // The X-address payload is 35 bytes (280 bits) -> does not fit one uint256, so accumulate
        // into two base-2**248 limbs: `hi` = top 4 bytes, `lo` = bottom 31 bytes, using the constant
        // reverse map. Checked arithmetic on `hi` rejects over-long inputs by reverting on overflow.
        bytes memory revmap = REVMAP; // copy the constant into memory once, then index cheaply
        uint256 mask = (uint256(1) << 248) - 1;
        uint256 hi = 0;
        uint256 lo = 0;
        for (uint256 i = 0; i < input.length; i++) {
            uint256 digit = uint8(revmap[uint8(input[i])]);
            require(digit != 0, InvalidBase58Character());
            uint256 acc = lo * 58 + (digit - 1); // lo < 2**248 -> lo*58 < 2**254, fits
            lo = acc & mask;
            hi = hi * 58 + (acc >> 248); // carry out of the low limb
        }
        require(hi >> 32 == 0, InvalidXAddress()); // payload must be exactly 35 bytes

        // prefix -> network (bytes[0..1] are the top 2 bytes of `hi`)
        uint256 prefix = hi >> 16;
        if (prefix == 0x0544) {
            _testNetwork = false;
        } else if (prefix == 0x0493) {
            _testNetwork = true;
        } else {
            revert InvalidXAddress();
        }

        // `body` = the first 31 bytes [prefix(2) | accountId(20) | flag(1) | tag(8)] as a 248-bit
        // big-endian integer: top 4 bytes from `hi`, next 27 bytes from `lo` (dropping `lo`'s low
        // 4 bytes, which are the checksum). Hashing `bytes31(body)` avoids any byte-buffer copy.
        uint256 body = (hi << 216) | (lo >> 32);
        bytes32 checksum = sha256(abi.encodePacked(sha256(abi.encodePacked(bytes31(uint248(body))))));
        require(uint32(bytes4(checksum)) == uint32(lo), InvalidXAddress()); // stored checksum = low 4 bytes

        // extract fields from `body` by bit position (byte k occupies bits (30 - k) * 8 .. +7)
        _accountId = bytes20(uint160((body >> 72) & ((uint256(1) << 160) - 1))); // bytes[2..21]
        uint256 flag = (body >> 64) & 0xff; // byte[22]
        if (flag == 0) {
            require(uint64(body) == 0, InvalidXAddress()); // all 8 tag bytes [23..30] must be zero
            _hasTag = false;
            _tag = 0;
        } else if (flag == 1) {
            require(uint32(body) == 0, InvalidXAddress()); // high 4 tag bytes [27..30] must be zero
            // 32-bit tag is little-endian in bytes[23..26]
            _tag = uint32(
                ((body >> 56) & 0xff) |
                (((body >> 48) & 0xff) << 8) |
                (((body >> 40) & 0xff) << 16) |
                (((body >> 32) & 0xff) << 24)
            );
            _hasTag = true;
        } else {
            // flag 2 (64-bit tag) is not supported — destination tags are 32-bit
            revert UnsupportedTagFlag();
        }
    }

    /**
     * @notice Encodes a 20-byte AccountID into its classic XRPL address string ("r...").
     * @param _accountId   The 20-byte AccountID.
     * @return             The classic Base58 address string.
     */
    function accountIdToClassicAddress(
        bytes20 _accountId
    )
        internal pure
        returns (string memory)
    {
        bytes memory alphabet = ALPHABET; // copy the constant into memory once, then index cheaply
        // payload = version(0x00) | accountId(20) | checksum(4) = 25 bytes, value < 2**192 -> fits uint256
        bytes32 checksum = sha256(abi.encodePacked(sha256(abi.encodePacked(bytes1(0x00), _accountId))));
        uint256 value = (uint256(uint160(_accountId)) << 32) | uint32(bytes4(checksum));

        // count leading zero bytes of the 25-byte payload (>= 1 for the 0x00 version byte);
        // each leading zero byte becomes a leading 'r' (alphabet[0]) in Base58
        uint256 zeros = 0;
        while (zeros < 25 && (value >> (8 * (24 - zeros))) & 0xff == 0) {
            zeros++;
        }

        // 25 bytes -> at most 35 Base58 digits; fill the magnitude digits from the back
        bytes memory buffer = new bytes(35);
        uint256 pos = 35;
        uint256 v = value;
        while (v != 0) {
            unchecked {
                pos--;
                buffer[pos] = alphabet[v % 58];
                v /= 58;
            }
        }

        bytes memory result = new bytes(zeros + (35 - pos));
        for (uint256 i = 0; i < zeros; i++) {
            result[i] = alphabet[0];
        }
        uint256 idx = zeros;
        for (uint256 i = pos; i < 35; i++) {
            result[idx++] = buffer[i];
        }
        return string(result);
    }

    /**
     * @notice Decodes an X-address directly into its classic address string, tag and network.
     * @param _xAddress         The Base58 X-address string ("X..." mainnet or "T..." testnet).
     * @return _classicAddress  The classic Base58 address string ("r...").
     * @return _tag             The 32-bit destination tag (0 when `_hasTag` is false).
     * @return _hasTag          Whether a destination tag is present.
     * @return _testNetwork     True if the address carries the testnet prefix.
     */
    function decodeXAddressToClassic(
        string memory _xAddress
    )
        internal pure
        returns (
            string memory _classicAddress,
            uint32 _tag,
            bool _hasTag,
            bool _testNetwork
        )
    {
        bytes20 accountId;
        (accountId, _tag, _hasTag, _testNetwork) = decodeXAddress(_xAddress);
        _classicAddress = accountIdToClassicAddress(accountId);
    }

    /**
     * @notice Returns true iff `_classicAddress` is a well-formed classic address with a valid checksum.
     * @dev Never reverts — returns false on any malformed input.
     */
    function isValidClassicAddress(
        string memory _classicAddress
    )
        internal pure
        returns (bool)
    {
        bytes memory input = bytes(_classicAddress);
        // length bound keeps the unchecked accumulation overflow-safe (58**40 < 2**256)
        if (input.length == 0 || input.length > 40) {
            return false;
        }
        bytes memory revmap = REVMAP; // copy the constant into memory once, then index cheaply
        uint256 value = 0;
        for (uint256 i = 0; i < input.length; i++) {
            uint256 digit = uint8(revmap[uint8(input[i])]);
            if (digit == 0) {
                return false;
            }
            unchecked {
                value = value * 58 + (digit - 1);
            }
        }
        if (value >> 192 != 0) {
            return false;
        }
        bytes20 accountId = bytes20(uint160(value >> 32));
        bytes32 checksum = sha256(abi.encodePacked(sha256(abi.encodePacked(bytes1(0x00), accountId))));
        return uint32(value) == uint32(bytes4(checksum));
    }

    /**
     * @notice Returns true iff `_xAddress` is a well-formed X-address with a valid checksum.
     * @dev Never reverts — returns false on any malformed input. Does not parse the tag.
     */
    function isValidXAddress(
        string memory _xAddress
    )
        internal pure
        returns (bool)
    {
        bytes memory input = bytes(_xAddress);
        // length bound keeps the unchecked accumulation overflow-safe
        if (input.length == 0 || input.length > 50) {
            return false;
        }
        bytes memory revmap = REVMAP; // copy the constant into memory once, then index cheaply
        uint256 mask = (uint256(1) << 248) - 1;
        uint256 hi = 0;
        uint256 lo = 0;
        for (uint256 i = 0; i < input.length; i++) {
            uint256 digit = uint8(revmap[uint8(input[i])]);
            if (digit == 0) {
                return false;
            }
            unchecked {
                uint256 acc = lo * 58 + (digit - 1);
                lo = acc & mask;
                hi = hi * 58 + (acc >> 248);
            }
        }
        if (hi >> 32 != 0) {
            return false;
        }
        uint256 prefix = hi >> 16;
        if (prefix != 0x0544 && prefix != 0x0493) {
            return false;
        }
        // body = first 31 bytes as a 248-bit big-endian integer (top 4 from `hi`, next 27 from `lo`)
        uint256 body = (hi << 216) | (lo >> 32);
        bytes32 checksum = sha256(abi.encodePacked(sha256(abi.encodePacked(bytes31(uint248(body))))));
        return uint32(bytes4(checksum)) == uint32(lo); // stored checksum = low 4 bytes of `lo`
    }

    /**
     * @notice Detects whether `_address` is a classic or X-address and validates its checksum.
     * @dev Dispatches on the leading character — classic addresses start with 'r', X-addresses with
     *      'X' (mainnet) or 'T' (testnet) — then runs the matching validator. Never reverts.
     * @param _address  The address string to classify and validate.
     * @return          `Classic` or `XAddress` when the checksum is valid for the detected format,
     *                  otherwise `Invalid`.
     */
    function validateAddress(
        string memory _address
    )
        internal pure
        returns (AddressFormat)
    {
        bytes memory input = bytes(_address);
        if (input.length == 0) {
            return AddressFormat.Invalid;
        }
        uint8 first = uint8(input[0]);
        if (first == 0x72) {
            // 'r' -> classic
            return isValidClassicAddress(_address) ? AddressFormat.Classic : AddressFormat.Invalid;
        }
        if (first == 0x58 || first == 0x54) {
            // 'X' (mainnet) or 'T' (testnet) -> X-address
            return isValidXAddress(_address) ? AddressFormat.XAddress : AddressFormat.Invalid;
        }
        return AddressFormat.Invalid;
    }

    /**
     * @notice Base58-encodes the fixed 35-byte X-address payload using the XRPL alphabet.
     * @dev Limb-based long division. The 35-byte (280-bit) value is held as two limbs in base
     *      2**248: `limb0` = top 4 bytes, `limb1` = bottom 31 bytes. Since 58 * 2**248 < 2**256,
     *      every `remainder * 2**248 + limb` intermediate fits in a single uint256, so each digit
     *      is extracted with native DIV/MOD — no 512-bit division. This replaces the O(n^2)
     *      byte-array long division with ~47 cheap iterations.
     *
     *      The X-address prefix (0x05 / 0x04) guarantees a non-zero most-significant byte, so there
     *      are never leading zero bytes and the general leading-'r' handling is unnecessary here.
     */
    function _base58Encode35(
        bytes memory _data
    )
        private pure
        returns (string memory)
    {
        bytes memory alphabet = ALPHABET; // copy the constant into memory once, then index cheaply
        uint256 base = uint256(1) << 248;
        uint256 mask = base - 1;
        uint256 limb0; // top 4 bytes (bytes[0..3]) -> < 2**32
        uint256 limb1; // bottom 31 bytes (bytes[4..34]) -> < 2**248
        // reading a 32-byte word out of a `bytes` array is not expressible in plain Solidity
        // solhint-disable-next-line no-inline-assembly
        assembly {
            limb0 := shr(224, mload(add(_data, 32))) // bytes[0..3], right-aligned
            limb1 := and(mload(add(_data, 35)), mask) // bytes[3..34] masked to bottom 31 bytes
        }

        // 35 bytes -> at most 48 Base58 digits; fill from the back
        bytes memory buffer = new bytes(48);
        uint256 pos = 48;
        while (limb0 != 0 || limb1 != 0) {
            unchecked {
                // long division by 58, most-significant limb first, carrying the remainder down
                uint256 acc = limb0; // incoming remainder is 0 for the high limb
                limb0 = acc / 58;
                uint256 rem = acc % 58;
                acc = rem * base + limb1;
                limb1 = acc / 58;
                rem = acc % 58;
                pos--;
                buffer[pos] = alphabet[rem];
            }
        }

        bytes memory result = new bytes(48 - pos);
        for (uint256 i = pos; i < 48; i++) {
            result[i - pos] = buffer[i];
        }
        return string(result);
    }
}
