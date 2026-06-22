// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IAddressValidator } from "../../userInterfaces/tee/IAddressValidator.sol";


interface AddressValidatorStructs {

    function sourceConfigStruct(IAddressValidator.SourceConfig calldata) external;
}
