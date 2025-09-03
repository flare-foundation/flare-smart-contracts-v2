// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IFtdcHub } from "../../userInterfaces/ftdc/IFtdcHub.sol";
import { ITeeAvailabilityCheck } from "../../userInterfaces/ftdc/ITeeAvailabilityCheck.sol";
import { IPMWPaymentStatus } from "../../userInterfaces/ftdc/IPMWPaymentStatus.sol";
import { IPMWMultisigAccountConfigured } from "../../userInterfaces/ftdc/IPMWMultisigAccountConfigured.sol";


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

    function pmwMultisigAccountConfiguredRequestBodyStruct(
        IPMWMultisigAccountConfigured.RequestBody calldata
    )
        external;
    function pmwMultisigAccountConfiguredResponseBodyStruct(
        IPMWMultisigAccountConfigured.ResponseBody calldata
    )
        external;
    function pmwMultisigAccountConfiguredProofStruct(
        IPMWMultisigAccountConfigured.Proof calldata
    )
        external;
}
