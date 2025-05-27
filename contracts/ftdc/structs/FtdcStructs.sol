// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/ftdc/IFtdcHub.sol";
import "../../userInterfaces/ftdc/ITeeAvailabilityCheck.sol";
import "../../userInterfaces/ftdc/IPMWPaymentStatus.sol";


interface TeeDataConnectorStructs {

    function ftdcProveStruct(IFtdcHub.FtdcProve calldata) external;

    function availabilityCheckRequestStruct(ITeeAvailabilityCheck.Request calldata) external;
    function availabilityCheckResponseStruct(ITeeAvailabilityCheck.Response calldata) external;
    function availabilityCheckProofStruct(ITeeAvailabilityCheck.Proof calldata) external;

    function pmwPaymentStatusRequestStruct(IPMWPaymentStatus.Request calldata) external;
    function pmwPaymentStatusResponseStruct(IPMWPaymentStatus.Response calldata) external;
    function pmwPaymentStatusProofStruct(IPMWPaymentStatus.Proof calldata) external;
}
