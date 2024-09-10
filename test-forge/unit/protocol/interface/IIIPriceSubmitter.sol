// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "flare-smart-contracts/contracts/genesis/interface/IIPriceSubmitter.sol";

/**
 * @title Price submitter internal interface for testing.
 */
interface IIIPriceSubmitter is IIPriceSubmitter {

    function initialiseFixedAddress() external;

    function updateContractAddresses(bytes32[] memory, address[] memory) external;

    function setAddressUpdater(address) external;
}
