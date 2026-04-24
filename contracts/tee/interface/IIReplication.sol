// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IReplication } from "../../userInterfaces/tee/IReplication.sol";

/**
 * @title IIReplication
 * @notice Internal interface for the ReplicationFacet.
 * @dev Extends the public interface with governance-only methods.
 */
interface IIReplication is IReplication {

    /**
     * Sets the minimum duration (in paused status) before a TEE machine can be upgraded.
     * Emits PauseBeforeUpgradeMinDurationSecondsSet event.
     * @param _pauseBeforeUpgradeMinDurationSeconds The minimum duration in seconds.
     * @dev Only governance can call this method.
     */
    function setPauseBeforeUpgradeMinDurationSeconds(
        uint256 _pauseBeforeUpgradeMinDurationSeconds
    )
        external;
}
