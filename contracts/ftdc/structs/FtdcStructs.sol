// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/ftdc/IFtdcHub.sol";
import "../../userInterfaces/ftdc/ITeeAvailabilityCheck.sol";
import "../../userInterfaces/ftdc/IPMWPaymentStatus.sol";


interface FtdcStructs {

    function ftdcRequestHeaderStruct(IFtdcHub.FtdcRequestHeader calldata) external;
    function ftdcAttestationRequestStruct(IFtdcHub.FtdcAttestationRequest calldata) external;
    function ftdcResponseHeaderStruct(IFtdcHub.FtdcResponseHeader calldata) external;

    function availabilityCheckTeeStateStruct(ITeeAvailabilityCheck.TeeState calldata) external;
    function availabilityCheckRequestBodyStruct(ITeeAvailabilityCheck.RequestBody calldata) external;
    function availabilityCheckResponseBodyStruct(ITeeAvailabilityCheck.ResponseBody calldata) external;
    function availabilityCheckProofStruct(ITeeAvailabilityCheck.Proof calldata) external;

    function pmwPaymentStatusRequestBodyStruct(IPMWPaymentStatus.RequestBody calldata) external;
    function pmwPaymentStatusResponseBodyStruct(IPMWPaymentStatus.ResponseBody calldata) external;
    function pmwPaymentStatusProofStruct(IPMWPaymentStatus.Proof calldata) external;
}
