// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "flare-smart-contracts/contracts/utils/interface/IIFtsoRegistry.sol";

/**
 * @title FtsoRegistry internal interface for testing.
 */
interface IIIFtsoRegistry is IIFtsoRegistry {
    function initialiseRegistry(address) external;

    function updateContractAddresses(bytes32[] memory, address[] memory) external;
}
