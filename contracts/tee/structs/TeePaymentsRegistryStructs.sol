// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeePaymentsRegistry } from "../../userInterfaces/tee/ITeePaymentsRegistry.sol";


interface TeePaymentsRegistryStructs {

    function sourceRegistrationStruct(ITeePaymentsRegistry.SourceRegistration calldata) external;

    function sourceConfigStruct(ITeePaymentsRegistry.SourceConfig calldata) external;
}
