// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


/**
 * FdcRequestFeeConfigurations interface.
 */
interface IFdcRequestFeeConfigurations  {

    // Event emitted when a type and source price is set.
    event TypeAndSourceFeeSet(bytes32 indexed attestationType, bytes32 indexed source, uint256 fee);

    // Event emitted when a type and source price is removed.
    event TypeAndSourceFeeRemoved(bytes32 indexed attestationType, bytes32 indexed source);

    /**
     * Method to get the base fee for an attestation request. It reverts if the request is not supported.
     * @param _data ABI encoded attestation request
     */
    function getRequestFee(bytes calldata _data) external view returns (uint256);

}
