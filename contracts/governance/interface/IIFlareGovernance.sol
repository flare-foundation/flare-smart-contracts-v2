// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IFlareGovernance } from "../../userInterfaces/IFlareGovernance.sol";

/**
 * @title IIFlareGovernance
 * @notice Internal interface extending IFlareGovernance with governance-only methods.
 * @dev Adds cancelGovernanceCall (governance only) and switchToProductionMode (initial governance only).
 */
interface IIFlareGovernance is IFlareGovernance {

    /**
     * Cancel a timelocked governance call before it has been executed.
     * @dev Only governance can call this method.
     * @param _encodedCall ABI encoded call data (signature and parameters).
     *      You should use `encodedCall` parameter from `GovernanceCallTimelocked` event.
     */
    function cancelGovernanceCall(
        bytes calldata _encodedCall
    )
        external;

    /**
     * Enter the production mode after all the initial governance settings have been set.
     * This enables timelocks and the governance is afterwards obtained by calling
     * `governanceSettings.getGovernanceAddress()`.
     */
    function switchToProductionMode()
        external;
}
