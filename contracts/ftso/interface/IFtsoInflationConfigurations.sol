// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


interface IFtsoInflationConfigurations {

    /// The FTSO configuration struct.
    struct FtsoConfiguration {
        // concatenated feed names - i.e. base/quote symbol - multiple of 8 (one feedName is bytes8)
        bytes feedNames;
        // inflation share for this configuration group
        uint24 inflationShare;
        // rewards split mode (0 means equally, 1 means random,...)
        uint16 mode;
        // primary band reward share in PPM (parts per million)
        uint24 primaryBandRewardSharePPM;
        // secondary band width in PPM (parts per million) in relation to the median - multiple of 3 (uint24)
        bytes secondaryBandWidthPPMs;
    }

    /**
     * Returns the FTSO configurations.
     */
    function getFtsoConfigurations() external view returns(FtsoConfiguration[] memory);
}
