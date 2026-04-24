// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IMachineManager } from "../../userInterfaces/tee/IMachineManager.sol";


interface TeeMachineStructs {

    function teeMachineDataStruct(IMachineManager.TeeMachineData calldata) external;

    function teeMachineStruct(IMachineManager.TeeMachine calldata) external;

    function teeMachineWithAttestationDataStruct(
        IMachineManager.TeeMachineWithAttestationData calldata
    ) external;
}
