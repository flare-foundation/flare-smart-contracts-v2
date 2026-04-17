// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IVerificationFacet } from "../../userInterfaces/tee/IVerificationFacet.sol";
import { ISystemStateVerifierFacet } from "../../userInterfaces/tee/ISystemStateVerifierFacet.sol";


interface TeeVerificationStructs {

    function teeAttestationStruct(IVerificationFacet.TeeAttestation calldata) external;

    function teeSystemStateStruct(ISystemStateVerifierFacet.TeeSystemState calldata) external;
}
