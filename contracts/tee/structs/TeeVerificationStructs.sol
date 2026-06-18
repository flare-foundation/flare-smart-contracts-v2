// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IVerification } from "../../userInterfaces/tee/IVerification.sol";


interface TeeVerificationStructs {

    function teeAttestationStruct(IVerification.TeeAttestation calldata) external;
}
