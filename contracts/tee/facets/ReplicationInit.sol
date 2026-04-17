// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Replication } from "../library/Replication.sol";

/**
 * @title ReplicationInit
 * @notice Init contract for adding ReplicationFacet via diamondCut.
 */
contract ReplicationInit {

    function init(
        uint256 _pauseBeforeUpgradeMinDurationSeconds
    )
        external
    {
        Replication.setPauseBeforeUpgradeMinDurationSeconds(_pauseBeforeUpgradeMinDurationSeconds);
    }
}
