// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

// TODO: FDC hub is temporary name (Xavi / Alen)

/**
 * IFdcHub interface.
 */
interface IFdcHub  {
    event AttestationRequest(bytes data, uint256 fee);

    /**
     * Method to request an attestation.
     * @param _data ABI encoded attestation request
     */
    function requestAttestation(bytes calldata _data) external payable;

    /**
     * Method to get the base fee for an attestation request.
     * @param _data ABI encoded attestation request
     */
    function getBaseFee(bytes calldata _data) external view returns (uint256);
}
