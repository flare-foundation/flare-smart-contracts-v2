// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


/**
 * FtdcRequestFeeConfigurations interface.
 */
interface IFtdcRequestFeeConfigurations  {

    // Event emitted when a type and source price is set.
    event TypeAndSourceFeeSet(bytes32 indexed attestationType, bytes32 indexed source, uint256 fee);
    // Event emitted when a type and source price is removed.
    event TypeAndSourceFeeRemoved(bytes32 indexed attestationType, bytes32 indexed source);

    error FeeMustBeGreaterThanZero();
    error FeeNotSet();
    error TypeAndSourceCombinationNotSupported();
    error LengthsMismatch();

    /**
     * Method to get the base fee for a type and source pair. It reverts if the pair is not supported.
     * @param _type The type of the attestation.
     * @param _source The source of the attestation.
     * @return The fee for the type and source pair.
     */
    function getTypeAndSourceFee(bytes32 _type, bytes32 _source) external view returns (uint256);

}
