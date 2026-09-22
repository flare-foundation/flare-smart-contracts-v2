
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Signature } from "../../contracts/userInterfaces/ISignature.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { Vm } from "forge-std/Vm.sol";

library SignatureHelper {

    function createSignature(
        Vm _vm,
        bytes32 messageHash,
        uint256 _privateKey
    )
        internal pure
        returns (Signature memory)
    {
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = _vm.sign(_privateKey, signedMessageHash);
        return Signature(v, r, s);
    }
}