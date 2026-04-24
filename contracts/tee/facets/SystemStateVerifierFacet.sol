// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ISystemStateVerifier } from "../../userInterfaces/tee/ISystemStateVerifier.sol";
import { SystemStateVerifier } from "../library/SystemStateVerifier.sol";

/**
 * @title SystemStateVerifierFacet
 * @notice Facet exposing TEE system state verification.
 */
contract SystemStateVerifierFacet is ISystemStateVerifier {

    /**
     * @inheritdoc ISystemStateVerifier
     */
    function verifyTeeSystemState(
        address _teeId,
        bytes32 _stateVersion,
        bytes calldata _state
    )
        external view
        returns (bool _isValid)
    {
        return SystemStateVerifier.verifyTeeSystemState(_teeId, _stateVersion, _state);
    }
}
