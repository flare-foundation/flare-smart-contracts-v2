// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeeVerification.sol";


interface TeeVerificationStructs {

    function teeAttestationStruct(ITeeVerification.TeeAttestation calldata) external;
}
