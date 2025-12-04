// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IINodePossessionVerifier } from "../interface/IINodePossessionVerifier.sol";
import { P256 } from "@openzeppelin/contracts/utils/cryptography/P256.sol";
import { RSA } from "@openzeppelin/contracts/utils/cryptography/RSA.sol";
import { Bytes } from "@openzeppelin/contracts/utils/Bytes.sol";

/**
 * Node possession verification contract.
 */
contract NodePossessionVerifier is IINodePossessionVerifier {

    bytes internal constant ECDSA_ALGORITHM_ID = hex"06072a8648ce3d020106082a8648ce3d030107";
    bytes internal constant RSA_ALGORITHM_ID = hex"06092a864886f70d0101010500";
    // N value of the P-256 curve
    uint256 internal constant N = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;

    /**
     * @inheritdoc IINodePossessionVerifier
     */
    function verifyNodePossession(
        address _voter,
        bytes20 _nodeId,
        bytes calldata _certificateRaw,
        bytes calldata _signature
    )
        external view
    {
        bytes20 nodeIdFromPublicKey = ripemd160(abi.encodePacked(sha256(abi.encodePacked(_certificateRaw))));
        require(nodeIdFromPublicKey == _nodeId, "invalid node id");
        bytes32 message = sha256(abi.encodePacked(bytes32(0), _voter));
        (bytes memory part1, bytes memory part2, bool isECDSA) = extractPublicKeyFromRawCertificate(_certificateRaw);
        if (isECDSA) {
            (bytes32 r, bytes32 s) = extractSignature(_signature);
            uint256 sUint = uint256(s);
            if (sUint > N / 2) {
                sUint = N - sUint;
            }
            require(P256.verify(message, r, bytes32(sUint), bytes32(part1), bytes32(part2)), "invalid signature");
        } else {
            require(RSA.pkcs1Sha256(message, _signature, part2, part1), "invalid signature");
        }
    }

    /**
     * Extracts the public key from a raw certificate.
     * Returns the modulus and exponent of the public key.
     * @param _certificateRaw The raw certificate.
     * @return _part1 The modulus (N) of the public key (for RSA) or X part of the public key (for ECDSA).
     * @return _part2 The exponent (E) of the public key (for RSA) or Y part of the public key (for ECDSA).
     * @return _isECDSA True if the public key is ECDSA, false if RSA.
     */
    function extractPublicKeyFromRawCertificate(bytes calldata _certificateRaw)
        public view
        returns (bytes memory _part1, bytes memory _part2, bool _isECDSA)
    {
        (uint256 length, bytes memory data, bool success) = readASN1Element(_certificateRaw, 0x30, true);
        require(success, "couldn't read certificate element");

        // read RawTBSCertificate element
	    (, data, success) = this.readASN1Element(data, 0x30, true);
        require(success, "couldn't read RawTBSCertificate element");

        // version
        (length, , success) = this.readASN1Element(data, 0xa0, false);
        require(success, "couldn't read version element");

        // serial number
        data = Bytes.slice(data, length);
        (length, , success) = this.readASN1Element(data, 0x02, false);
        require(success, "couldn't read serial number element");

        // signature algorithm identifier
        data = Bytes.slice(data, length);
        (length, , success) = this.readASN1Element(data, 0x30, false);
        require(success, "couldn't read signature algorithm identifier");

        // issuer
        data = Bytes.slice(data, length);
        (length, , success) = this.readASN1Element(data, 0x30, false);
        require(success, "couldn't read issuer element");

        // validity
        data = Bytes.slice(data, length);
        (length, , success) = this.readASN1Element(data, 0x30, false);
        require(success, "couldn't read validity element");

        // subject
        data = Bytes.slice(data, length);
        (length, , success) = this.readASN1Element(data, 0x30, false);
        require(success, "couldn't read subject element");

        // subject public key info
        data = Bytes.slice(data, length);
        (, data, success) = this.readASN1Element(data, 0x30, true);
        require(success, "couldn't read subject public key info element");

        // algorithm
        bytes memory algorithm;
        (length, algorithm, success) = this.readASN1Element(data, 0x30, true);
        require(success, "couldn't read algorithm element");

        if (keccak256(algorithm) == keccak256(ECDSA_ALGORITHM_ID)) { // ECDSA
            // public key
            data = Bytes.slice(data, length);
            (, data, success) = this.readASN1Element(data, 0x03, true);
            require(success, "couldn't read public key element");

            // skip the first byte, which is 0x00
            data = Bytes.slice(data, 1);

            require(data.length == 65 && data[0] == bytes1(0x04), "unsupported public key format");
            _part1 = Bytes.slice(data, 1, 33); // X
            _part2 = Bytes.slice(data, 33, 65); // Y
            _isECDSA = true;
        } else if (keccak256(algorithm) == keccak256(RSA_ALGORITHM_ID)) { // RSA
            // public key
            data = Bytes.slice(data, length);
            (, data, success) = this.readASN1Element(data, 0x03, true);
            require(success, "couldn't read public key element");

            // get N and E from public key
            // skip the first byte, which is the number of unused bits
            data = Bytes.slice(data, 1);
            (, data, success) = this.readASN1Element(data, 0x30, true);
            require(success, "couldn't read public key data");

            // N and E
            (length, _part1, success) = this.readASN1Element(data, 0x02, true);
            require(success, "couldn't read N element");
            if (_part1.length > 1 && _part1[0] == bytes1(0x00)) {
                // skip the first byte, which is 0x00
                _part1 = Bytes.slice(_part1, 1);
            }

            // E
            data = Bytes.slice(data, length);
            (, _part2, success) = this.readASN1Element(data, 0x02, true);
            require(success, "couldn't read E element");
            if (_part2.length > 1 && _part2[0] == bytes1(0x00)) {
                // skip the first byte, which is 0x00
                _part2 = Bytes.slice(_part2, 1);
            }
        } else {
            revert("algorithm not supported");
        }
    }

    /**
     * Extracts r and s values from an ECDSA signature in ASN.1 DER format.
     * @param _signature The ECDSA signature in ASN.1 DER format.
     * @return _r The r value of the signature.
     * @return _s The s value of the signature.
     */
    function extractSignature(bytes calldata _signature)
        public view
        returns(bytes32 _r, bytes32 _s)
    {
        bytes memory rs;
        (uint256 length, bytes memory data, bool success) = readASN1Element(_signature, 0x30, true);
        require(success, "couldn't read signature");
        require(length == _signature.length, "invalid signature length");
        (length, rs, success) = this.readASN1Element(data, 0x02, true);
        require(success, "couldn't read r");
        if (rs.length < 33) {
            _r = bytes32(rs);
        } else if (rs.length == 33 && rs[0] == bytes1(0x00)) {
            // skip the first byte, which is 0x00
            _r = bytes32(Bytes.slice(rs, 1));
        } else {
            revert("invalid r");
        }
        data = Bytes.slice(data, length);
        (length , rs, success) = this.readASN1Element(data, 0x02, true);
        require(success, "couldn't read s");
        require(length == data.length, "invalid data length");
        if (rs.length < 33) {
            _s = bytes32(rs);
        } else if (rs.length == 33 && rs[0] == bytes1(0x00)) {
            // skip the first byte, which is 0x00
            _s = bytes32(Bytes.slice(rs, 1));
        } else {
            revert("invalid s");
        }
    }

    /**
     * Reads ASN1 element from data and check if it has expected tag.
     * If expected tag is 0, then any tag is accepted.
     * Returns the length of the bytes read and the element itself if `_extractData` is true.
     * @param _data The data to read from.
     * @param _expectedTag The expected tag of the element.
     * @param _extractData If true, the element is returned.
     * @return _length The length of the bytes read (header length + element length).
     * @return _extractedData The extracted element without the header.
     */
    function readASN1Element(bytes calldata _data, bytes1 _expectedTag, bool _extractData)
        public pure
        returns(uint256 _length, bytes memory _extractedData, bool _success)
    {
        if (_data.length < 2) { // data too short
            return (0, "", false);
        }
        bytes1 tag = _data[0];
        bytes1 lengthByte = _data[1];
        if (_expectedTag != bytes1(0) && tag != _expectedTag) { // unexpected tag
            return (0, "", false);
        }

        uint32 headerLength = 2;
        if (lengthByte & 0x80 == 0) {
            // If bit 8 of lengthByte is 0, then length is the number of bytes
            _length = uint8(lengthByte);
        } else {
            // If bit 8 of length is 1, then the next 7 bits are the number of bytes
            // that represent the length
            uint8 numBytes = uint8(lengthByte & 0x7f);
            if (numBytes > 4) {
                return (0, "", false); // length too long
            }
            if (_data.length < 2 + numBytes) {
                return (0, "", false); // data too short for length bytes
            }
            _length = 0;
            for (uint256 i = 0; i < numBytes; i++) {
                _length <<= 8;
                _length += uint8(_data[2 + i]);
            }
            headerLength += numBytes;
        }

        // update length to include header
        _length += headerLength;

        if (_data.length < _length) {
            return (0, "", false); // data too short for content
        }

        if (_extractData) {
            _extractedData = _data[headerLength : _length];
        }
        _success = true;
    }
}
