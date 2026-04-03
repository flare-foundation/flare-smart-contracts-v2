// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeReplication } from "../library/TeeReplication.sol";

/**
 * @title TeeReplicationInit
 * @notice Init contract for adding TeeReplicationFacet via diamondCut.
 */
contract TeeReplicationInit {

    function init(
        uint256 _pauseBeforeUpgradeMinDurationSeconds
    )
        external
    {
        TeeReplication.setPauseBeforeUpgradeMinDurationSeconds(_pauseBeforeUpgradeMinDurationSeconds);
    }
}
