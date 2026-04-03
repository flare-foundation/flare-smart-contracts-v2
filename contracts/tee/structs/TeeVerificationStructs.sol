// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeVerificationFacet } from "../../userInterfaces/tee/ITeeVerificationFacet.sol";
import { ITeeSystemStateVerifierFacet } from "../../userInterfaces/tee/ITeeSystemStateVerifierFacet.sol";


interface TeeVerificationStructs {

    function teeAttestationStruct(ITeeVerificationFacet.TeeAttestation calldata) external;

    function teeSystemStateStruct(ITeeSystemStateVerifierFacet.TeeSystemState calldata) external;
}
