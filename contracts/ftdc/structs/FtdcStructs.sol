// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/ftdc/IFtdcHub.sol";
import "../../userInterfaces/ftdc/ITeeAvailabilityCheck.sol";


interface TeeDataConnectorStructs {

    function ftdcProveStruct(IFtdcHub.FtdcProve calldata) external;

    function availabilityCheckRequestStruct(ITeeAvailabilityCheck.Request calldata) external;
    function availabilityCheckResponseStruct(ITeeAvailabilityCheck.Response calldata) external;
    function availabilityCheckProofStruct(ITeeAvailabilityCheck.Proof calldata) external;
}
