// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IINodePossessionVerifier.sol";

/**
 * Node possession verification contract.
 */
contract NodePossessionVerifier is IINodePossessionVerifier {

    // OID = 1.2.840.113549.1.1.11
    bytes internal constant PKCS1_V15_SHA256 = hex"003031300d060960864801650304020105000420";
    uint256 internal constant PKCS1_V15_SHA256_LENGTH = 20; // PKCS1_V15_SHA256.length

    /**
     * @inheritdoc IINodePossessionVerifier
     */
    function verifyNodePossession(
        address _voter,
        bytes20 _nodeId,
        bytes memory _certificateRaw,
        bytes memory _signature
    )
        external view
    {
        bytes20 nodeIdFromPublicKey = ripemd160(abi.encodePacked(sha256(abi.encodePacked(_certificateRaw))));
        require(nodeIdFromPublicKey == _nodeId, "invalid node id");
        (bytes memory modulus, bytes memory exponent) = extractPublicKeyFromRawCert(_certificateRaw);
        bytes32 message = sha256(abi.encodePacked(_voter));
        require(verifyPKCS1v15SHA256(message, _signature, modulus, exponent), "invalid signature");
    }

    // https://www.rfc-editor.org/rfc/rfc8017.html
    /** Verifies a PKCS1v1.5 with SHA256 signature.
      * @param _messageSHA256 SHA256 hash of the message.
      * @param _signature RSA signature.
      * @param _modulus RSA modulus.
      * @param _exponent RSA public exponent.
      * @return True if the signature is valid, false otherwise.
      */
    function verifyPKCS1v15SHA256(
        bytes32 _messageSHA256,
        bytes memory _signature,
        bytes memory _modulus,
        bytes memory _exponent
    )
        public view returns(bool)
    {
        uint256 length = _modulus.length;
        if(length < 64) {
            return false; // invalid modulus length
        }

        if(_signature.length != length) {
            return false; // invalid signature length
        }

        //slither-disable-next-line encode-packed-collision
        (bool success, bytes memory result) = address(0x05).staticcall(
            abi.encodePacked(_signature.length, _exponent.length, _modulus.length, _signature, _exponent, _modulus)
        );
        if (!success) {
            return false; // bigModExp failed
        }
        assert(result.length == length);

        if (result[0] != 0x00 || result[1] != 0x01) {
            return false; // invalid start
        }

        uint256 paddingEnd = length - PKCS1_V15_SHA256_LENGTH -  32 ; // 32 is the length of the message sha256 hash
        for (uint256 i = 2; i < paddingEnd; i++) {
            if (result[i] != 0xff) {
                return false; // invalid padding
            }
        }

        for (uint256 i = 0; i < PKCS1_V15_SHA256_LENGTH; i++) {
            if (result[paddingEnd + i] != PKCS1_V15_SHA256[i]) {
                return false; // invalid sha256 version
            }
        }


        for (uint256 i = 0; i < 32; i++) {
            if (result[paddingEnd + PKCS1_V15_SHA256_LENGTH + i] != _messageSHA256[i]) {
                return false; // invalid message sha256 hash
            }
        }

        return true;
    }

    /**
     * Extracts the public key from a raw certificate.
     * Returns the modulus and exponent of the public key.
     * @param _certificateRaw The raw certificate.
     * @return _modulus The modulus of the public key.
     * @return _exponent The exponent of the public key.
     */
    function extractPublicKeyFromRawCert(bytes memory _certificateRaw)
        public view
        returns (bytes memory _modulus, bytes memory _exponent)
    {
        (uint256 length, bytes memory data, bool success) = this.readASN1Element(_certificateRaw, 0x30, true);
        require(success, "couldn't read certificate element");

        // read RawTBSCertificate element
	    (, data, success) = this.readASN1Element(data, 0x30, true);
        require(success, "couldn't read RawTBSCertificate element");

        // version
        (length, , success) = this.readASN1Element(data, 0xa0, false);
        require(success, "couldn't read version element");

        // serial number
        data = this.sliceStart(data, length);
        (length, , success) = this.readASN1Element(data, 0x02, false);
        require(success, "couldn't read serial number element");

        // signature algorithm identifier
        data = this.sliceStart(data, length);
        (length, , success) = this.readASN1Element(data, 0x30, false);
        require(success, "couldn't read signature algorithm identifier");

        // issuer
        data = this.sliceStart(data, length);
        (length, , success) = this.readASN1Element(data, 0x30, false);
        require(success, "couldn't read issuer element");

        // validity
        data = this.sliceStart(data, length);
        (length, , success) = this.readASN1Element(data, 0x30, false);
        require(success, "couldn't read validity element");

        // subject
        data = this.sliceStart(data, length);
        (length, , success) = this.readASN1Element(data, 0x30, false);
        require(success, "couldn't read subject element");

        // subject public key info
        data = this.sliceStart(data, length);
        (, data, success) = this.readASN1Element(data, 0x30, true);
        require(success, "couldn't read subject public key info element");

        // algorithm
        (length, , success) = this.readASN1Element(data, 0x30, false);
        require(success, "couldn't read algorithm element");

        // public key
        data = this.sliceStart(data, length);
        (, data, success) = this.readASN1Element(data, 0x03, true);
        require(success, "couldn't read public key element");

        // Get N and E from public key
        // Note to skip the first byte, which is the number of unused bits
        data = this.sliceStart(data, 1);
        (, data, success) = this.readASN1Element(data, 0x30, true);
        require(success, "couldn't read public key data");

        // N and E
        (length, _modulus, success) = this.readASN1Element(data, 0x02, true);
        require(success, "couldn't read N element");
        // skip the first byte, which is 0x00
        _modulus = this.sliceStart(_modulus, 1);

        // E
        data = this.sliceStart(data, length);
        (, _exponent, success) = this.readASN1Element(data, 0x02, true);
        require(success, "couldn't read E element");
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
        if(_data.length < 2) { // data too short
            return (0, "", false);
        }
        bytes1 tag = _data[0];
        bytes1 lengthByte = _data[1];
        if(_expectedTag != bytes1(0) && tag != _expectedTag) { // unexpected tag
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

    /**
     * Slices a byte array from a start index to the end.
     */
    function sliceStart(bytes calldata _data, uint256 _start) public pure returns(bytes memory slicedData) {
        require(_start <= _data.length, "start index out of bounds");
        return _data[_start:];
    }
}
