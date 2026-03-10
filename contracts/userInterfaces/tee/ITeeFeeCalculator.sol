// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TeeFeeCalculator interface.
 */
interface ITeeFeeCalculator {

    /// Event emitted when default fee is set.
    event DefaultFeeSet(
        uint256 defaultFee
    );

    /// Event emitted when operation fees are set.
    event OperationFeesSet(
        bytes32[] opTypes,
        bytes32[] opCommands,
        uint256[] fees
    );

    error LengthsMismatch();

    /**
     * Returns the default fee.
     * @return The default fee.
     */
    function getDefaultFee()
        external view
        returns (uint256);

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
        external view
        returns (uint256 _operationFee);

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
        external view
        returns (uint256 _fee);


}