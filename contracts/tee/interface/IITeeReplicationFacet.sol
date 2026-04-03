// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeReplicationFacet } from "../../userInterfaces/tee/ITeeReplicationFacet.sol";

/**
 * @title IITeeReplicationFacet
 * @notice Internal interface for the TeeReplicationFacet.
 * @dev Extends the public interface with governance-only methods.
 */
interface IITeeReplicationFacet is ITeeReplicationFacet {

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
