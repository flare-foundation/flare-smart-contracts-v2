// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TeeStateVerifier interface.
 */
interface ITeeStateVerifier {

    /**
     * Verifies the TEE machine state.
     * @param _teeId The TEE machine id.
     * @param _state The TEE machine state - ABI encoded struct.
     * @return _isValid True if the state is valid, false otherwise.
     */
    function verifyTeeMachineState(
        address _teeId,
        bytes calldata _state
    )
        external
        returns (bool _isValid);
}
