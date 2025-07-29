// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

interface ITeeWalletProjectOpTypeConstants {

    /**
     * Returns the operation type.
     * @return _opType The operation type.
     */
    function getOpType() external view returns (bytes32);

    /**
     * Returns the required operation type constants.
     * @param _projectId The project id.
     * @return The ABI encoded operation type constants.
     * NOTE: Should revert if the required operation type constants are not set.
     */
    function getOpTypeConstants(bytes32 _projectId) external view returns(bytes memory);
}
