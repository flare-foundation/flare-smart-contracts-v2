// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../userInterfaces/IFtsoFeedIdConverter.sol";


/**
 * FtsoFeedIdConverter contract.
 *
 * This contract is used for converting the feed id to type and name and vice versa.
 */
contract FtsoFeedIdConverter is IFtsoFeedIdConverter {

    /**
     * @inheritdoc IFtsoFeedIdConverter
     */
    function getFeedId(uint8 _type, string memory _name) external pure returns(bytes21) {
        bytes memory nameBytes = bytes(_name);
        require(nameBytes.length <= 20, "name too long");
        return bytes21(bytes.concat(bytes1(_type), nameBytes));
    }

    /**
     * @inheritdoc IFtsoFeedIdConverter
     */
    function getFeedTypeAndName(bytes21 _feedId) external pure returns(uint8 _type, string memory _name) {
        _type = uint8(_feedId[0]);
        uint256 length = 20;
        while (length > 0) {
            if (_feedId[length] != 0x00) {
                break;
            }
            length--;
        }
        bytes memory nameBytes = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            nameBytes[i] = _feedId[i + 1];
        }
        _name = string(nameBytes);
    }
}
