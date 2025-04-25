// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";

/**
 * TeeFeeCalculator interface.
 */
interface ITeeFeeCalculator {

    /// Event emitted when operation fee is set.
    event OperationFeeSet(
        bytes32 opType,
        bytes32 opCommand,
        uint256 fee
    );

    /**
     * Returns the operation's fee.
     * @param _opType The operation type.
     * @param _opCommand The operation command.
     * @return _operationFee The fee.
     */
    function getOperationFee(
        bytes32 _opType,
        bytes32 _opCommand
    )
        external view returns (uint256 _operationFee);

    /**
     * Calculates the fee for the operation and wallet id.
     * @param _opType The operation type.
     * @param _opCommand The operation command.
     * @param _walletId The wallet id.
     * @return _fee The calculated fee.
     */
    function calculateFeeByWalletId(
        bytes32 _opType,
        bytes32 _opCommand,
        bytes32 _walletId
    )
        external view returns (uint256 _fee);

    /**
     * Calculates the fee for the operation and list of tee ids that will receive instructions.
     * @param _opType The operation type.
     * @param _opCommand The operation command.
     * @param _teeIds The list of tee ids that will receive instructions.
     * @return _fee The calculated fee.
     */
    function calculateFeeByTeeIds(
        bytes32 _opType,
        bytes32 _opCommand,
        address[] memory _teeIds
    )
        external view returns (uint256 _fee);


}