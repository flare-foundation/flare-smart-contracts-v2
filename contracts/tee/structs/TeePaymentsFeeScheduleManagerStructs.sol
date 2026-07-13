// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeePaymentsFeeScheduleManager } from "../../userInterfaces/tee/ITeePaymentsFeeScheduleManager.sol";


interface TeePaymentsFeeScheduleManagerStructs {

    function feeScheduleStruct(ITeePaymentsFeeScheduleManager.FeeSchedule calldata) external;

    function feeScheduleConfigInputStruct(ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput calldata) external;

    function feeScheduleConfigStruct(ITeePaymentsFeeScheduleManager.FeeScheduleConfig calldata) external;
}
