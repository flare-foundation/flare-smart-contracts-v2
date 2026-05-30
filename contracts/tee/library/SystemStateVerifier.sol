// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ISystemStateVerifier } from "../../userInterfaces/tee/ISystemStateVerifier.sol";
import { MachineManager } from "./MachineManager.sol";

/**
 * @title SystemStateVerifier
 * @notice Library for verifying TEE machine system state.
 * @dev Single uniform strict-compare path against the chain's stored `initialTeeId`:
 *      - Empty payload (`_stateVersion == 0 && _state.length == 0`) is accepted only if the
 *        machine's stored `initialTeeId` is zero (binary signalled non-replication at first
 *        attestation, or hasn't attested yet).
 *      - Populated payload requires `state.status == ACTIVE && state.initialTeeId == stored`.
 *
 *      The "capture vs compare" distinction is in the callers (`toProduction`, `replicateFrom`):
 *      when the machine is `INITIALIZED` and the proof carries a populated payload, the facet
 *      pre-writes the expected `initialTeeId` before invoking the verifier. The verifier then
 *      simply confirms the chain's value matches the TEE-attested value. State mutations roll
 *      back on revert, so the pre-write pattern is safe.
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
        address storedInitialTeeId = MachineManager.getInitialTeeId(_teeId);
        if (_stateVersion == bytes32(0)) {
            return _state.length == 0 && storedInitialTeeId == address(0);
        }
        ISystemStateVerifier.TeeSystemState memory state =
            abi.decode(_state, (ISystemStateVerifier.TeeSystemState));
        return
            state.status == ISystemStateVerifier.TeeMachineStatus.ACTIVE &&
            state.initialTeeId == storedInitialTeeId;
    }
}
