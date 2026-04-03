// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IITeeFeeCalculatorFacet } from "../interface/IITeeFeeCalculatorFacet.sol";
import { ITeeFeeCalculatorFacet } from "../../userInterfaces/tee/ITeeFeeCalculatorFacet.sol";
import { TeeFeeCalculator } from "../library/TeeFeeCalculator.sol";
import { GovernedFacet } from "./GovernedFacet.sol";

/**
 * @title TeeFeeCalculatorFacet
 * @notice Diamond facet for calculating and managing TEE operation fees.
 * @dev Thin wrapper around the TeeFeeCalculator library.
 *      Governance methods use `onlyGovernance` from GovernedBase (inherited
 *      via delegatecall into Diamond storage).
 */
contract TeeFeeCalculatorFacet is IITeeFeeCalculatorFacet, GovernedFacet {

    /**
     * @inheritdoc IITeeFeeCalculatorFacet
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
        TeeFeeCalculator.State storage s = TeeFeeCalculator.getState();
        for (uint256 i = 0; i < _opTypes.length; i++) {
            s.operationFee[_opTypes[i]][_opCommands[i]] = _fees[i];
        }
        emit OperationFeesSet(_opTypes, _opCommands, _fees);
    }

    /**
     * @inheritdoc IITeeFeeCalculatorFacet
     */
    function setDefaultFee(
        uint256 _defaultFee
    )
        external
        onlyGovernance
    {
        TeeFeeCalculator.getState().defaultFee = _defaultFee;
        emit DefaultFeeSet(_defaultFee);
    }

    /**
     * @inheritdoc ITeeFeeCalculatorFacet
     */
    function getDefaultFee()
        external view
        returns (uint256)
    {
        return TeeFeeCalculator.getDefaultFee();
    }

    /**
     * @inheritdoc ITeeFeeCalculatorFacet
     */
    function getOperationFee(
        bytes32 _opType,
        bytes32 _opCommand
    )
        external view
        returns (uint256)
    {
        return TeeFeeCalculator.getOperationFee(_opType, _opCommand);
    }

    /**
     * @inheritdoc ITeeFeeCalculatorFacet
     */
    function calculateFeeByTeeIds(
        bytes32 _opType,
        bytes32 _opCommand,
        address[] memory _teeIds
    )
        external view
        returns (uint256 _fee)
    {
        return TeeFeeCalculator.calculateFeeByTeeIds(_opType, _opCommand, _teeIds);
    }
}
