// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * FtsoManagerProxy internal interface.
 */
interface IIFtsoManagerProxy {

    function relay() external view returns (address);

    function fastUpdater() external view returns (address);

    function flareSystemsManager() external view returns (address);

    function fastUpdatesConfiguration() external view returns (address);

    function submission() external view returns (address);
}
