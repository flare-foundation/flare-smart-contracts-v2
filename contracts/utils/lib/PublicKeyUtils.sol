// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {PublicKey} from "../../userInterfaces/IPublicKey.sol";

library PublicKeyUtils {

    uint256 constant private P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

    function isPublicKeyValid(PublicKey memory _pk) internal pure returns (bool) {
        uint256 x = uint256(_pk.x);
        uint256 y = uint256(_pk.y);
        return x < P && x > 0 && y < P && y > 0 && mulmod(y, y, P) == addmod(mulmod(mulmod(x, x, P), x, P), 7, P);
    }

    function getAddress(PublicKey memory _pk) internal pure returns (address) {
        uint256[2] memory publicKeyPair = [uint256(_pk.x), uint256(_pk.y)];
        bytes32 hash = keccak256(abi.encodePacked(publicKeyPair));
        return address(uint160(uint256(hash)));
    }
}
