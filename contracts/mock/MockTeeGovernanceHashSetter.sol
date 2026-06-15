// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { MachineManager } from "../tee/library/MachineManager.sol";

/**
 * @title MockTeeGovernanceHashSetter
 * @notice Test-only diamond facet that overwrites the governance hash bound to a given TEE machine.
 *         Used by `test/integration/EndToEnd.test.ts` to retrofit a non-zero governance hash onto
 *         already-registered TEE machines before exercising MachinePathManager — without
 *         re-running the full registration flow.
 *
 * @dev NOT included in any production diamond cut. Added only by Hardhat integration tests via
 *      `diamondCut` after deployment.
 */
contract MockTeeGovernanceHashSetter {

    function mockSetTeeMachineGovernanceHash(
        address _teeId,
        bytes32 _governanceHash
    )
        external
    {
        MachineManager.getState().teeMachineStates[_teeId].governanceHash = _governanceHash;
    }
}
