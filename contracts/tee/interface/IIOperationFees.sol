// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IOperationFees } from "../../userInterfaces/tee/IOperationFees.sol";

/**
 * @title IIOperationFees
 * @notice Internal interface for the OperationFeesFacet.
 * @dev Extends the public interface with governance-only methods.
 */
interface IIOperationFees is IOperationFees {

    /**
     * Sets fees for operations.
     * @param _opTypes List of operation types.
     * @param _opCommands List of operation commands.
     * @param _fees List of fees.
     * @dev Only governance can call this method.
     */
    function setOperationFees(
        bytes32[] calldata _opTypes,
        bytes32[] calldata _opCommands,
        uint256[] calldata _fees
    )
        external;

    /**
     * Sets the default fee.
     * @param _defaultFee The new default fee.
     * @dev Only governance can call this method.
     */
    function setDefaultFee(
        uint256 _defaultFee
    )
        external;
}
