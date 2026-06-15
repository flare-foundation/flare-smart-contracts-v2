// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { Replication } from "../library/Replication.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title ReplicationInit
 * @notice Init contract for adding ReplicationFacet via diamondCut.
 */
contract ReplicationInit is Initializable {

    constructor() {
        _disableInitializers();
    }

    function init(
        uint256 _pauseBeforeUpgradeMinDurationSeconds
    )
        external
        reinitializer(2)
    {
        Replication.setPauseBeforeUpgradeMinDurationSeconds(_pauseBeforeUpgradeMinDurationSeconds);
    }
}
