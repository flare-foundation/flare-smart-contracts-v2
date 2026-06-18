// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { MachineManager } from "./MachineManager.sol";

/**
 * @title SystemStateVerifier
 * @notice Library for verifying the TEE machine system-state payload.
 * @dev The system-state payload must be empty: a TEE binary signs an empty payload
 *      (`_stateVersion == 0 && _state.length == 0`) and the machine's stored `initialTeeId`
 *      must be zero. Non-empty payloads are no longer admissible; `initialTeeId` is retained
 *      on-chain as a dormant field.
 */
library SystemStateVerifier {

    function verifyTeeSystemState(
        address _teeId,
        bytes32 _stateVersion,
        bytes calldata _state
    )
        internal view
        returns (bool)
    {
        return _stateVersion == bytes32(0) &&
            _state.length == 0 &&
            MachineManager.getInitialTeeId(_teeId) == address(0);
    }
}
