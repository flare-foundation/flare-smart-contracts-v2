// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import {IFastUpdateIncentiveManager} from "../../userInterfaces/IFastUpdateIncentiveManager.sol";


interface IIFastUpdateIncentiveManager is IFastUpdateIncentiveManager {
    /**
     * This function should be called once per block to advance the incentive manager's state.
     */
    function advance() external;
}
