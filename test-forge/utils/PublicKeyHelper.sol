// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PublicKey } from "../../contracts/userInterfaces/IPublicKey.sol";
import { PublicKeyUtils } from "../../contracts/utils/lib/PublicKeyUtils.sol";
import { Vm } from "forge-std/Vm.sol";

library PublicKeyHelper {

    function getRandomPrivateKey(Vm _vm) internal returns (uint256) {
        // call external script to get random private key
        string[] memory command = new string[](4);
        command[0] = "cast";
        command[1] = "wallet";
        command[2] = "new";
        command[3] = "--json";
        bytes memory result = _vm.ffi(command);
        string memory privateKey = _vm.parseJsonString(string(result), "[0].private_key");
        return uint256(bytes32(bytes(privateKey)));
    }

    function getPublicKey(Vm _vm, uint256 _privateKey) internal returns (PublicKey memory) {
        // call external script to get public key coordinates from private key
        string[] memory command = new string[](5);
        command[0] = "cast";
        command[1] = "wallet";
        command[2] = "public-key";
        command[3] = "--raw-private-key";
        command[4] = _vm.toString(_privateKey);
        bytes memory result = _vm.ffi(command);

        // check if result is 64 bytes
        require(result.length == 64, "invalid output length");

        // extract x and y as bytes32
        bytes32 x;
        bytes32 y;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            x := mload(add(result, 32)) // first 32 bytes (hex-decoded)
            y := mload(add(result, 64)) // second 32 bytes
        }

        PublicKey memory pk = PublicKey(x, y);
        // test that the coordinates are valid
        require(PublicKeyUtils.isPublicKeyValid(pk), "invalid public key");

        return pk;
    }

    function getRandomPublicKey(Vm _vm) internal returns (PublicKey memory) {
        uint256 privateKey = getRandomPrivateKey(_vm);
        return getPublicKey(_vm, privateKey);
    }

    function getAddress(PublicKey memory _pk) internal pure returns (address) {
        return PublicKeyUtils.getAddress(_pk);
    }
}