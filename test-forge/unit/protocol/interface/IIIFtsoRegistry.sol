// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "flare-smart-contracts/contracts/utils/interface/IIFtsoRegistry.sol";


/**
 * @title Wrapped Native token
 * Accept native token deposits and mint ERC20 WNAT (wrapped native) tokens 1-1.
 */
interface IIIFtsoRegistry is IIFtsoRegistry {
    /**
     * Deposit Native and mint wNat ERC20.
     */
    function governance() external returns (address);

    function initialiseRegistry(address) external;

    function updateContractAddresses(bytes32[] memory, address[] memory) external;

    function getAddressUpdater() external returns (address);
}
