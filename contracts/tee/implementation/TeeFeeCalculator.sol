// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../utils/lib/AddressSet.sol";

/**
 * TeeFeeCalculator is used for determining the fee for TEE operation types and commands.
 */

contract TeeInstructions is ITeeInstructions, Governed, AddressUpdatable {
