// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";

/**
 * TeeInstructions interface.
 */
interface ITeeInstructions {



    event TeeInstruction(
        bytes32 indexed indexHash,
        ITeeRegistry.TeeMachine[] teeMachines,
        uint256 rewardEpochId,
        bytes32 opType,
        bytes message
    );
}