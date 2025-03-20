// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";

/**
 * TeeDataConnector interface.
 */
interface ITeeDataConnector {

    struct FtdcProve {
        ITeeRegistry.TeeMachineWithAttestationData[] teeMachines;
        uint16 thresholdBIPS;
        bytes attestationRequest;
    }

    event MinThresholdBIPSSet(uint16 minThresholdBIPS);
    event DefaultNumberOfTeesSet(uint8 defaultNumberOfTees);

    function requestAttestation(
        uint16 _thresholdBIPS,
        uint256 _numberOfTees,
        address[] memory _teeIds,
        bytes calldata _attestationRequest
    )
        external payable;
}
