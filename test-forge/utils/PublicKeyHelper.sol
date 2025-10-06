// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PublicKey } from "../../contracts/userInterfaces/IPublicKey.sol";
import { PublicKeyUtils } from "../../contracts/utils/lib/PublicKeyUtils.sol";
import { Vm } from "forge-std/Vm.sol";

library PublicKeyHelper {

    function getRandomPublicKey(Vm _vm) internal returns (PublicKey memory) {
        // call external script to get random public key coordinates
        string[] memory command1 = new string[](4);
        string[] memory command2 = new string[](5);
        command1[0] = "cast";
        command1[1] = "wallet";
        command1[2] = "new";
        command1[3] = "--json";
        bytes memory result = _vm.ffi(command1);
        string memory privateKey = _vm.parseJsonString(string(result), "[0].private_key");
        command2[0] = "cast";
        command2[1] = "wallet";
        command2[2] = "public-key";
        command2[3] = "--raw-private-key";
        command2[4] = privateKey;
        result = _vm.ffi(command2);

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

    function getAddress(PublicKey memory _pk) internal pure returns (address) {
        return PublicKeyUtils.getAddress(_pk);
    }
}