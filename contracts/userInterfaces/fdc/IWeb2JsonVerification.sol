// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IWeb2Json } from "./IWeb2Json.sol";

interface IWeb2JsonVerification {

    function verifyWeb2Json(IWeb2Json.Proof calldata _proof)
        external view returns (bool _proved);
}
