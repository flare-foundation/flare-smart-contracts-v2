// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeMachineRegistryFacet } from "../../userInterfaces/tee/ITeeMachineRegistryFacet.sol";


interface TeeMachineRegistryStructs {

    function teeMachineDataStruct(ITeeMachineRegistryFacet.TeeMachineData calldata) external;

    function teeMachineStruct(ITeeMachineRegistryFacet.TeeMachine calldata) external;

    function teeMachineWithAttestationDataStruct(
        ITeeMachineRegistryFacet.TeeMachineWithAttestationData calldata
    ) external;
}
