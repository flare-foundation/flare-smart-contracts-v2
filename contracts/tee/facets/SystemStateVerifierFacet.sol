// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ISystemStateVerifierFacet } from "../../userInterfaces/tee/ISystemStateVerifierFacet.sol";
import { SystemStateVerifier } from "../library/SystemStateVerifier.sol";

/**
 * @title SystemStateVerifierFacet
 * @notice Facet exposing TEE system state verification.
 */
contract SystemStateVerifierFacet is ISystemStateVerifierFacet {

    /**
     * @inheritdoc ISystemStateVerifierFacet
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
