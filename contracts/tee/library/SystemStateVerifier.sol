// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ISystemStateVerifierFacet } from "../../userInterfaces/tee/ISystemStateVerifierFacet.sol";
import { IMachineManagerFacet } from "../../userInterfaces/tee/IMachineManagerFacet.sol";
import { MachineManager } from "./MachineManager.sol";
import { ExtensionManager } from "./ExtensionManager.sol";

/**
 * @title SystemStateVerifier
 * @notice Library for verifying TEE machine system state.
 * @dev Stateless library — uses MachineManager and ExtensionManager for data.
 */
library SystemStateVerifier {

    function verifyTeeSystemState(
        address _teeId,
        bytes32 _stateVersion,
        bytes calldata _state
    )
        internal view
        returns (bool)
    {
        IMachineManagerFacet.TeeMachineWithAttestationData memory teeMachine =
            MachineManager.getTeeMachineWithAttestationData(_teeId);
        uint256 extensionId = MachineManager.getExtensionId(_teeId);
        bytes32 teeGovernanceHash = ExtensionManager.getTeeGovernanceHash(extensionId, teeMachine.codeHash);
        if (_stateVersion == bytes32(0)) {
            return _state.length == 0 && teeGovernanceHash == bytes32(0);
        }
        ISystemStateVerifierFacet.TeeSystemState memory state =
            abi.decode(_state, (ISystemStateVerifierFacet.TeeSystemState));
        return
            state.status == ISystemStateVerifierFacet.TeeMachineStatus.ACTIVE &&
            state.initialTeeId == teeMachine.initialTeeId &&
            state.teeGovernanceHash == teeGovernanceHash;
    }
}
