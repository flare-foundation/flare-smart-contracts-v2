// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";

/**
 * @title IOperationFees
 * @notice Public interface for the OperationFeesFacet.
 */
interface IOperationFees is ITeeCommonErrors {

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

    error DefaultFeeZero();

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

    /**
     * Calculates the fee for an operation on the given wallet, resolving the receiving tee ids
     * the same way `pay`/`reissue` do (deduplicated PRODUCTION tee ids). Reverts with
     * `ThresholdNotMet` if the wallet does not have enough available keys.
     * @param _walletId The wallet id.
     * @param _opType The operation type.
     * @param _opCommand The operation command.
     * @return _fee The calculated fee.
     */
    function calculateFeeByWalletId(
        bytes32 _walletId,
        bytes32 _opType,
        bytes32 _opCommand
    )
        external view
        returns (uint256 _fee);
}
