// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * Relay interface.
 */
interface IIRelayConfig {
    /**
     * Returns the minimal required fee in wei.
     * @param _sender Sender for which the required fee is calculated.
     * @return _minFeeInWei Required fee in wei.
     */
    function requiredFee(address _sender) external view returns (uint256 _minFeeInWei);

    /**
     * Returns the address to which all fees are passed
     */
    function feeCollectionAddress() external view returns (address payable _feeCollectionAddress);

    /**
     * Checks whether the sender can access the merkle root directly.
     */
    function canGetMerkleRoot(address _sender) external view returns (bool);

    /**
     * Checks whether the sender can access the signing policy directly.
     */
    function canGetSigningPolicy(address _sender) external view returns (bool);

    /**
     * Checks whether the sender can set the signing policy directly.
     */
    function canSetSigningPolicy(address _sender) external view returns (bool);

}
