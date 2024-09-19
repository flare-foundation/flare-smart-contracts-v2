// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


/**
 * FdcInflationConfigurations interface.
 */
interface IFdcInflationConfigurations {

    /// The FDC configuration struct.

    struct FdcConfiguration {
        // attestation type
        bytes32 attestationType;
        // source
        bytes32 source;
        // inflation share for this configuration
        uint24 inflationShare;
        // minimal reward eligibility threshold in number of request
        uint8 minRequestsThreshold;
        // mode (additional settings interpreted on the client side off-chain)
        uint224 mode;
    }

    /**
     * Returns the FDC configuration at `_index`.
     * @param _index The index of the FDC configuration.
     */
    function getFdcConfiguration(uint256 _index) external view returns(FdcConfiguration memory);

    /**
     * Returns the FDC configurations.
     */
    function getFdcConfigurations() external view returns(FdcConfiguration[] memory);
}
