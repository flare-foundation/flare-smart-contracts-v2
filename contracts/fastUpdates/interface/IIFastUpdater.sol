// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "flare-smart-contracts/contracts/genesis/interface/IFlareDaemonize.sol";
import { IFastUpdater } from "../../userInterfaces/IFastUpdater.sol";
import "../../protocol/interface/IIPublicKeyVerifier.sol";


/**
 * Fast updater internal interface.
 */
interface IIFastUpdater is IFastUpdater, IFlareDaemonize, IIPublicKeyVerifier {

    /**
     * Reset feeds (pull the latest values and set them as the current values).
     * @param _indices The indices of the feeds to reset.
     * @dev Only the FastUpdatesConfiguration or governance can call this method.
     */
    function resetFeeds(uint256[] memory _indices) external;

    /**
     * Remove feeds.
     * @param _indices The indices of the feeds to remove.
     * @dev Only the FastUpdatesConfiguration can call this method.
     */
    function removeFeeds(uint256[] memory _indices) external;

    /**
     * Returns the list of addresses that are allowed to call the fetchCurrentFeeds method for free.
     */
    function getFreeFetchAddresses() external view returns (address[] memory);
}
