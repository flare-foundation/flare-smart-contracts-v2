// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/IFastUpdaterView.sol";
import "../../userInterfaces/IFastUpdatesConfiguration.sol";
import "../../userInterfaces/IRelay.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";

/**
 * FtsoManagerProxy internal interface.
 */
interface IIFtsoManagerProxy {

    function relay() external view returns (IRelay);

    function fastUpdater() external view returns (IFastUpdaterView);

    function flareSystemsManager() external view returns (IFlareSystemsManager);

    function fastUpdatesConfiguration() external view returns (IFastUpdatesConfiguration);
}
