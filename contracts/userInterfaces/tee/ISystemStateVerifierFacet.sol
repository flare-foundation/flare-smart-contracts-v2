// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * @title ISystemStateVerifierFacet
 * @notice Public interface for the SystemStateVerifierFacet.
 */
interface ISystemStateVerifierFacet {

    enum TeeMachineStatus { ACTIVE, PAUSED, PAUSED_FOR_UPGRADE }

    struct TeeSystemState {
        TeeMachineStatus status;
        address initialTeeId;
        bytes32 teeGovernanceHash;
    }

    /**
     * Verifies the TEE machine system state.
     * @param _teeId The TEE machine id.
     * @param _stateVersion The version of the TEE machine state.
     * @param _state The TEE machine state - ABI encoded struct.
     * @return _isValid True if the state is valid, false otherwise.
     */
    function verifyTeeSystemState(
        address _teeId,
        bytes32 _stateVersion,
        bytes calldata _state
    )
        external
        returns (bool _isValid);
}
