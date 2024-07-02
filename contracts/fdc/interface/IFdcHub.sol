// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

// TODO: FDC hub is temporary name (Xavi / Alen)

/**
 * IFdcHub interface.
 */
interface IFdcHub  {
    // Event emitted when an attestation request is made.
    event AttestationRequest(bytes data, uint256 fee);
    // TODO: @Luka Iztok woudl prefer to also emit round id 

    // Event emitted when a type and source price is set.
    event TypeAndSourceFeeSet(bytes32 indexed _type, bytes32 indexed source, uint256 fee);
    // Event emitted when a type and source price is removed.
    event TypeAndSourceFeeRemoved(bytes32 indexed _type, bytes32 indexed source);

    /**
     * Method to request an attestation.
     * @param _data ABI encoded attestation request
     */
    function requestAttestation(bytes calldata _data) external payable;

    /**
     * Method to get the base fee for an attestation request. if 0 is returned, the request is not supported.
     * @param _data ABI encoded attestation request
     */
    function getRequestFee(bytes calldata _data) external view returns (uint256);
}
