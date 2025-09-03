// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeVerification } from "../../userInterfaces/tee/ITeeVerification.sol";
import { IITeeSystemStateVerifier } from "../interface/IITeeSystemStateVerifier.sol";


interface TeeVerificationStructs {

    function teeAttestationStruct(ITeeVerification.TeeAttestation calldata) external;

    function teeSystemStateStruct(IITeeSystemStateVerifier.TeeSystemState calldata) external;
}
