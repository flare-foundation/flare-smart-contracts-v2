// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeSystemStateVerifierFacet } from "../../userInterfaces/tee/ITeeSystemStateVerifierFacet.sol";
import { TeeSystemStateVerifier } from "../library/TeeSystemStateVerifier.sol";

/**
 * @title TeeSystemStateVerifierFacet
 * @notice Facet exposing TEE system state verification.
 */
contract TeeSystemStateVerifierFacet is ITeeSystemStateVerifierFacet {

    /**
     * @inheritdoc ITeeSystemStateVerifierFacet
     */
    function verifyTeeSystemState(
        address _teeId,
        bytes32 _stateVersion,
        bytes calldata _state
    )
        external view
        returns (bool _isValid)
    {
        return TeeSystemStateVerifier.verifyTeeSystemState(_teeId, _stateVersion, _state);
    }
}
