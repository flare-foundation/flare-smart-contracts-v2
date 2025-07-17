// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeeVerification.sol";
import "../interface/IITeeStateVerifier.sol";


interface TeeVerificationStructs {

    function teeAttestationStruct(ITeeVerification.TeeAttestation calldata) external;

    function teeMachineStateStruct(IITeeStateVerifier.TeeMachineState calldata) external;
}
