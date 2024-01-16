// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IFtsoInflationConfigurations.sol";
import "../../governance/implementation/Governed.sol";


contract FtsoInflationConfigurations is Governed, IFtsoInflationConfigurations {

    uint256 internal constant PPM_MAX = 1e6;

    FtsoConfiguration[] internal ftsoConfigurations;

    constructor(
        IGovernanceSettings _governanceSettings,
        address _governance
    )
        Governed(_governanceSettings, _governance)
    { }

    function addFtsoConfiguration(FtsoConfiguration calldata _config) external onlyGovernance {
        _checkFtsoConfiguration(_config);
        ftsoConfigurations.push(_config);
    }

    function replaceFtsoConfiguration(uint256 _index, FtsoConfiguration calldata _config) external onlyGovernance {
        require(ftsoConfigurations.length > _index, "invalid index");
        _checkFtsoConfiguration(_config);
        ftsoConfigurations[_index] = _config;
    }

    function removeFtsoConfiguration(uint256 _index) external onlyGovernance {
        uint256 length = ftsoConfigurations.length;
        require(length > _index, "invalid index");

        ftsoConfigurations[_index] = ftsoConfigurations[length - 1]; // length > 0
        ftsoConfigurations.pop();
    }

    function getFtsoConfiguration(uint256 _index) external view returns(FtsoConfiguration memory) {
        return ftsoConfigurations[_index];
    }

    function getFtsoConfigurations() external view override returns(FtsoConfiguration[] memory) {
        return ftsoConfigurations;
    }

    function _checkFtsoConfiguration(FtsoConfiguration calldata _configuration) internal pure {
        require(_configuration.primaryBandRewardSharePPM <= PPM_MAX, "invalid primaryBandRewardSharePPM value");
        //slither-disable-next-line weak-prng
        require(_configuration.feedNames.length % 8 == 0, "invalid feedNames length");
        //slither-disable-next-line weak-prng
        require(_configuration.secondaryBandWidthPPMs.length % 3 == 0, "invalid secondaryBandWidthPPMs length");

        uint256 length = _configuration.feedNames.length / 8;
        require(_configuration.secondaryBandWidthPPMs.length / 3 == length, "array lengths do not match");

        for (uint256 i = 0; i < length; i++) {
            require(uint24(bytes3(_configuration.secondaryBandWidthPPMs[i * 3 : (i + 1) * 3])) <= PPM_MAX,
                "invalid secondaryBandWidthPPMs value");
        }
    }
}