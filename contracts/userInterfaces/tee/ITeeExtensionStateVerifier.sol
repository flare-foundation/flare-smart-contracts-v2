// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TeeExtensionStateVerifier interface.
 */
interface ITeeExtensionStateVerifier {

    /**
     * Verifies the TEE machine state.
     * @param _teeId The TEE machine id.
     * @param _stateVersion The version of the TEE machine state.
     * @param _state The TEE machine state - ABI encoded struct.
     * @return _isValid True if the state is valid, false otherwise.
     */
    function verifyTeeState(
        address _teeId,
        bytes32 _stateVersion,
        bytes calldata _state
    )
        external view
        returns (bool _isValid);
}
