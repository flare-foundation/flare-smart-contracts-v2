// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IMachineEmergencyPause } from "../../userInterfaces/tee/IMachineEmergencyPause.sol";

/**
 * @title IIMachineEmergencyPause
 * @notice Internal interface for the MachineEmergencyPauseFacet.
 * @dev Extends the public interface with the governance-only grace-period setter.
 *      The matching event (`EmergencyUnpauseGracePeriodSet`) and error
 *      (`GracePeriodTooLong`) stay on `IMachineEmergencyPause` (the public interface)
 *      per the codebase-wide rule that all events / errors live on the public surface.
 *      Aggregated by `IIFlareTeeManager`.
 */
interface IIMachineEmergencyPause is IMachineEmergencyPause {

    /**
     * Sets the global grace period (in seconds) applied after every emergency unpause.
     * Emits EmergencyUnpauseGracePeriodSet event.
     * @param _seconds New grace duration in seconds. Must be in
     *        [MIN_GRACE_PERIOD_SECONDS (30 min), MAX_GRACE_PERIOD_SECONDS (24 h)].
     * Can only be called by Flare governance (timelocked).
     */
    function setEmergencyUnpauseGracePeriodSeconds(
        uint256 _seconds
    )
        external;
}
