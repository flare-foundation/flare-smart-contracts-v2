// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


interface IFtsoInflationConfigurations {

    /// The FTSO configuration struct.
    struct FtsoConfiguration {
        // concatenated feed names - i.e. base/quote symbol - multiple of 8 (one feedName is bytes8)
        bytes feedNames;
        // inflation share for this configuration group
        uint24 inflationShare;
        // minimal reward eligibility threshold in BIPS (basis points)
        uint16 minimalThresholdBIPS;
        // primary band reward share in PPM (parts per million)
        uint24 primaryBandRewardSharePPM;
        // secondary band width in PPM (parts per million) in relation to the median - multiple of 3 (uint24)
        bytes secondaryBandWidthPPMs;
        // rewards split mode (0 means equally, 1 means random,...)
        uint16 mode;
    }

    /**
     * Returns the FTSO configurations.
     */
    function getFtsoConfigurations() external view returns(FtsoConfiguration[] memory);
}
