// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IReplication } from "../../userInterfaces/tee/IReplication.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";

/**
 * @title Replication
 * @notice Library for TEE machine replication management.
 * @dev Uses ERC-7201 namespaced storage.
 */
library Replication {

    /// @custom:storage-location erc7201:tee.Replication.State
    struct State {
        mapping(address oldTeeId => address newTeeId) replicatingTeeIds;
        uint256 pauseBeforeUpgradeMinDurationSeconds;
    }

    bytes32 internal constant STATE_POSITION = bytes32(erc7201("tee.Replication.State"));

    function setPauseBeforeUpgradeMinDurationSeconds(
        uint256 _duration
    )
        internal
    {
        require(1 minutes <= _duration && _duration <= 1 days, ITeeCommonErrors.InvalidDuration());
        getState().pauseBeforeUpgradeMinDurationSeconds = _duration;
        emit IReplication.PauseBeforeUpgradeMinDurationSecondsSet(_duration);
    }

    function getReplicatingTeeId(
        address _oldTeeId
    )
        internal view
        returns (address)
    {
        return getState().replicatingTeeIds[_oldTeeId];
    }

    function getState()
        internal pure
        returns (State storage _state)
    {
        bytes32 position = STATE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _state.slot := position
        }
    }
}
