// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title TeeFeeCalculator
 * @notice Library for calculating fees for TEE operations.
 * @dev Uses ERC-7201 namespaced storage. Contains only logic that is
 *      reused by other libraries/facets. Governance-only setters live
 *      in TeeFeeCalculatorFacet directly.
 */
library TeeFeeCalculator {

    /// @custom:storage-location erc7201:tee.TeeFeeCalculator.State
    struct State {
        /// Default fee for operations.
        uint256 defaultFee;
        /// Fee per (opType, opCommand) pair.
        mapping(bytes32 opType => mapping(bytes32 opCommand => uint256 fee)) operationFee;
    }

    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("tee.TeeFeeCalculator.State")) - 1)
    ) & ~bytes32(uint256(0xff));

    function getDefaultFee()
        internal view
        returns (uint256)
    {
        return getState().defaultFee;
    }

    function getOperationFee(
        bytes32 _opType,
        bytes32 _opCommand
    )
        internal view
        returns (uint256)
    {
        return getState().operationFee[_opType][_opCommand];
    }

    function calculateFeeByTeeIds(
        bytes32 _opType,
        bytes32 _opCommand,
        address[] memory _teeIds
    )
        internal view
        returns (uint256 _fee)
    {
        State storage s = getState();
        _fee = s.operationFee[_opType][_opCommand];
        if (_fee == 0) {
            _fee = s.defaultFee;
        }
        _fee *= _teeIds.length;
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
