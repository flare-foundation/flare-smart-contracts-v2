// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * Fdc2InflationConfigurations interface.
 */
interface IFdc2InflationConfigurations {

    /// The FDC2 configuration struct.
    struct Fdc2Configuration {
        // attestation type
        bytes32 attestationType;
        // source id
        bytes32 sourceId;
        // inflation share for this configuration
        uint24 inflationShare;
        // minimal reward eligibility threshold in number of requests
        uint8 minRequestsThreshold;
        // mode (additional settings interpreted on the client side off-chain)
        uint224 mode;
    }

    error InvalidIndex();
    error LengthsMismatch();

    /**
     * Returns the FDC2 configuration at `_index`.
     * @param _index The index of the FDC2 configuration.
     */
    function getFdc2Configuration(
        uint256 _index
    )
        external view
        returns (Fdc2Configuration memory);

    /**
     * Returns the FDC2 configurations.
     */
    function getFdc2Configurations()
        external view
        returns (Fdc2Configuration[] memory);
}
