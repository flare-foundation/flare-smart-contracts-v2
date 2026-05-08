// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { G1Point } from "../lib/Bn256.sol";
import {
    SortitionState,
    verifySortitionCredential,
    verifySortitionProof,
    verifySignature
} from "../lib/Sortition.sol";
import { SortitionCredential } from "../../userInterfaces/ISortition.sol";

contract SortitionMock {
    function verifySortitionCredentialTest(
        SortitionState calldata sortitionState,
        SortitionCredential calldata sortitionCredential
    ) public view returns (bool _check) {
        (_check, ) = verifySortitionCredential(sortitionState, sortitionCredential);
    }

    function verifySortitionProofTest(
        SortitionState calldata sortitionState,
        SortitionCredential calldata sortitionCredential
    ) public view returns (bool) {
        return verifySortitionProof(sortitionState, sortitionCredential);
    }

    function verifySignatureTest(
        G1Point memory pk,
        bytes32 message,
        uint256 signature,
        G1Point memory r
    ) public view returns (bool) {
        verifySignature(pk, message, signature, r);
        return true;
    }
}
