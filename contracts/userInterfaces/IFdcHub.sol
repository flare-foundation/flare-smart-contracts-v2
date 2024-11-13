// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./IFdcInflationConfigurations.sol";
import "./IFdcRequestFeeConfigurations.sol";


/**
 * FdcHub interface.
 */
interface IFdcHub  {

    // Event emitted when an attestation request is made.
    event AttestationRequest(bytes data, uint256 fee);

    // Event emitted when a requests offset is set.
    event RequestsOffsetSet(uint8 requestsOffsetSeconds);

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
     * The offset (in seconds) for the requests to be processed during the current voting round.
     */
    function requestsOffsetSeconds() external view returns (uint8);

    /**
     * The FDC inflation configurations contract.
     */
    function fdcInflationConfigurations() external view returns(IFdcInflationConfigurations);

    /**
     * The FDC request fee configurations contract.
     */
    function fdcRequestFeeConfigurations() external view returns (IFdcRequestFeeConfigurations);
}
