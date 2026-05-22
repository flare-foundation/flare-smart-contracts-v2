// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ExtensionManager } from "../tee/library/ExtensionManager.sol";

/**
 * @title MockTeeGovernanceHashSetter
 * @notice Test-only diamond facet that overwrites the governance hash bound to a given
 *         (extensionId, codeHash) pair. Used by `test/integration/EndToEnd.test.ts` to retrofit a
 *         non-zero governance hash onto TEE_CODE_HASH before exercising MachinePathManager —
 *         without touching the existing TEE availability-check / proof-verification flow which
 *         relies on the default zero binding.
 *
 * @dev NOT included in any production diamond cut. Added only by Hardhat integration tests via
 *      `diamondCut` after deployment.
 */
contract MockTeeGovernanceHashSetter {

    function mockSetTeeGovernanceHash(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _governanceHash
    )
        external
    {
        ExtensionManager.getState().extensions[_extensionId].codeHashToVersion[_codeHash].governanceHash =
            _governanceHash;
    }
}
