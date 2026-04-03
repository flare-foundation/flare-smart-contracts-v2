// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeSystemStateVerifierFacet } from "../../userInterfaces/tee/ITeeSystemStateVerifierFacet.sol";
import { ITeeMachineRegistryFacet } from "../../userInterfaces/tee/ITeeMachineRegistryFacet.sol";
import { TeeMachineRegistry } from "./TeeMachineRegistry.sol";
import { TeeExtensionRegistry } from "./TeeExtensionRegistry.sol";

/**
 * @title TeeSystemStateVerifier
 * @notice Library for verifying TEE machine system state.
 * @dev Stateless library — uses TeeMachineRegistry and TeeExtensionRegistry for data.
 */
library TeeSystemStateVerifier {

    function verifyTeeSystemState(
        address _teeId,
        bytes32 _stateVersion,
        bytes calldata _state
    )
        internal view
        returns (bool)
    {
        ITeeMachineRegistryFacet.TeeMachineWithAttestationData memory teeMachine =
            TeeMachineRegistry.getTeeMachineWithAttestationData(_teeId);
        uint256 extensionId = TeeMachineRegistry.getExtensionId(_teeId);
        bytes32 teeGovernanceHash = TeeExtensionRegistry.getTeeGovernanceHash(extensionId, teeMachine.codeHash);
        if (_stateVersion == bytes32(0)) {
            return _state.length == 0 && teeGovernanceHash == bytes32(0);
        }
        ITeeSystemStateVerifierFacet.TeeSystemState memory state =
            abi.decode(_state, (ITeeSystemStateVerifierFacet.TeeSystemState));
        return
            state.status == ITeeSystemStateVerifierFacet.TeeMachineStatus.ACTIVE &&
            state.initialTeeId == teeMachine.initialTeeId &&
            state.teeGovernanceHash == teeGovernanceHash;
    }
}
