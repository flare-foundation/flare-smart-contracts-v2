// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IMachineManagerFacet } from "../../userInterfaces/tee/IMachineManagerFacet.sol";


interface TeeMachineStructs {

    function teeMachineDataStruct(IMachineManagerFacet.TeeMachineData calldata) external;

    function teeMachineStruct(IMachineManagerFacet.TeeMachine calldata) external;

    function teeMachineWithAttestationDataStruct(
        IMachineManagerFacet.TeeMachineWithAttestationData calldata
    ) external;
}
