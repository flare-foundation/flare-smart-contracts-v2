// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IOperationFees } from "../../userInterfaces/tee/IOperationFees.sol";

/**
 * @title OperationFees
 * @notice Library for calculating fees for TEE operations.
 * @dev Uses ERC-7201 namespaced storage. Contains only logic that is
 *      reused by other libraries/facets. Governance-only setters live
 *      in OperationFeesFacet directly.
 */
library OperationFees {

    /// @custom:storage-location erc7201:tee.OperationFees.State
    struct State {
        /// Default fee for operations.
        uint256 defaultFee;
        /// Fee per (opType, opCommand) pair.
        mapping(bytes32 opType => mapping(bytes32 opCommand => uint256 fee)) operationFee;
    }

    bytes32 internal constant STATE_POSITION = bytes32(erc7201("tee.OperationFees.State"));

    /// Writes the default fee into ERC-7201 storage and emits
    /// `IOperationFees.DefaultFeeSet`. Shared by `OperationFeesFacet.setDefaultFee`
    /// (governance-gated runtime setter) and `FlareTeeManagerInit.init` (deploy-time
    /// initialization). Auth is the caller's responsibility.
    function setDefaultFee(
        uint256 _defaultFee
    )
        internal
    {
        require(_defaultFee > 0, IOperationFees.DefaultFeeZero());
        getState().defaultFee = _defaultFee;
        emit IOperationFees.DefaultFeeSet(_defaultFee);
    }

    function getOperationFee(
        bytes32 _opType,
        bytes32 _opCommand
    )
        internal view
        returns (uint256 _fee)
    {
        State storage s = getState();
        _fee = s.operationFee[_opType][_opCommand];
        if (_fee == 0) {
            _fee = s.defaultFee;
        }
    }

    function calculateFeeByTeeIds(
        bytes32 _opType,
        bytes32 _opCommand,
        address[] memory _teeIds
    )
        internal view
        returns (uint256)
    {
        return getOperationFee(_opType, _opCommand) * _teeIds.length;
    }

    function getState()
        internal pure
        returns (State storage _state)
    {
        bytes32 position = STATE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _state.slot := position
        }
    }
}
