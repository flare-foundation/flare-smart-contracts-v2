// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeeDataConnector.sol";
import "../../userInterfaces/tee/ITeeAvailabilityCheck.sol";
import "../../userInterfaces/tee/ITeeKeyExistence.sol";


interface TeeDataConnectorStructs {

    function ftdcProveStruct(ITeeDataConnector.FtdcProve calldata) external;

    function availabilityCheckProofStruct(ITeeAvailabilityCheck.Proof calldata) external;

    function keyExistenceProofStruct(ITeeKeyExistence.Proof calldata) external;
}
