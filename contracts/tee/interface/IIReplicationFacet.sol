// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IReplicationFacet } from "../../userInterfaces/tee/IReplicationFacet.sol";

/**
 * @title IIReplicationFacet
 * @notice Internal interface for the ReplicationFacet.
 * @dev Extends the public interface with governance-only methods.
 */
interface IIReplicationFacet is IReplicationFacet {

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
