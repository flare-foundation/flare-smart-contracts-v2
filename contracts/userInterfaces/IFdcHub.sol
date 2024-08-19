// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./IFdcInflationConfigurations.sol";


/**
 * FdcHub interface.
 */
interface IFdcHub  {
    // Event emitted when an attestation request is made.
    event AttestationRequest(bytes data, uint256 fee);

    // Event emitted when a requests offset is set.
    event RequestsOffsetSet(uint8 requestsOffsetSeconds);

    // Event emitted when a type and source price is set.
    event TypeAndSourceFeeSet(bytes32 indexed attestationType, bytes32 indexed source, uint256 fee);

    // Event emitted when a type and source price is removed.
    event TypeAndSourceFeeRemoved(bytes32 indexed attestationType, bytes32 indexed source);

    /// Event emitted when inflation rewards are offered.
    event InflationRewardsOffered(
        // reward epoch id
        uint24 indexed rewardEpochId,
        // fdc configurations
        IFdcInflationConfigurations.FdcConfiguration[] fdcConfigurations,
        // amount (in wei) of reward in native coin
        uint256 amount
    );

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

    /**
     * The offset (in seconds) for the requests to be processed during the current voting round.
     */
    function requestsOffsetSeconds() external view returns (uint8);
}
