// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IFdc2Hub } from "../../userInterfaces/fdc2/IFdc2Hub.sol";
import { ITeeAvailabilityCheck } from "../../userInterfaces/fdc2/ITeeAvailabilityCheck.sol";
import { IPMWPaymentStatus } from "../../userInterfaces/fdc2/IPMWPaymentStatus.sol";
import { IPMWMultisigAccountConfigured } from "../../userInterfaces/fdc2/IPMWMultisigAccountConfigured.sol";


interface Fdc2Structs {

    function fdc2RequestHeaderStruct(IFdc2Hub.Fdc2RequestHeader calldata) external;
    function fdc2AttestationRequestStruct(IFdc2Hub.Fdc2AttestationRequest calldata) external;
    function fdc2ResponseHeaderStruct(IFdc2Hub.Fdc2ResponseHeader calldata) external;

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
