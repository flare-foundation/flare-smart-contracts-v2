// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IIOperationFees } from "../interface/IIOperationFees.sol";
import { IOperationFees } from "../../userInterfaces/tee/IOperationFees.sol";
import { OperationFees } from "../library/OperationFees.sol";
import { FlareGovernedAccess } from "../../governance/implementation/FlareGovernedAccess.sol";

/**
 * @title OperationFeesFacet
 * @notice Diamond facet for calculating and managing TEE operation fees.
 * @dev Thin wrapper around the OperationFees library.
 *      Governance methods use `onlyGovernance` from FlareGovernedAccess (inherited
 *      via delegatecall into Diamond storage).
 */
contract OperationFeesFacet is IIOperationFees, FlareGovernedAccess {

    /**
     * @inheritdoc IIOperationFees
     */
    function setOperationFees(
        bytes32[] calldata _opTypes,
        bytes32[] calldata _opCommands,
        uint256[] calldata _fees
    )
        external
        onlyGovernance
    {
        require(
            _opTypes.length == _opCommands.length && _opTypes.length == _fees.length,
            LengthsMismatch()
        );
        OperationFees.State storage s = OperationFees.getState();
        for (uint256 i = 0; i < _opTypes.length; i++) {
            s.operationFee[_opTypes[i]][_opCommands[i]] = _fees[i];
        }
        emit OperationFeesSet(_opTypes, _opCommands, _fees);
    }

    /**
     * @inheritdoc IIOperationFees
     */
    function setDefaultFee(
        uint256 _defaultFee
    )
        external
        onlyGovernance
    {
        OperationFees.setDefaultFee(_defaultFee);
    }

    /**
     * @inheritdoc IOperationFees
     */
    function getDefaultFee()
        external view
        returns (uint256)
    {
        return OperationFees.getDefaultFee();
    }

    /**
     * @inheritdoc IOperationFees
     */
    function getOperationFee(
        bytes32 _opType,
        bytes32 _opCommand
    )
        external view
        returns (uint256)
    {
        return OperationFees.getOperationFee(_opType, _opCommand);
    }

    /**
     * @inheritdoc IOperationFees
     */
    function calculateFeeByTeeIds(
        bytes32 _opType,
        bytes32 _opCommand,
        address[] memory _teeIds
    )
        external view
        returns (uint256 _fee)
    {
        return OperationFees.calculateFeeByTeeIds(_opType, _opCommand, _teeIds);
    }
}
