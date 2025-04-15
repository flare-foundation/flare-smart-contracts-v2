// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../tee/ITeeRegistry.sol";

/**
 * FtdcHub interface.
 */
interface IFtdcHub {

    struct FtdcProve {
        ITeeRegistry.TeeMachineWithAttestationData[] teeMachines;
        uint16 thresholdBIPS;
        bytes attestationRequest;
    }

    event MinThresholdBIPSSet(uint16 minThresholdBIPS);
    event DefaultNumberOfTeesSet(uint8 defaultNumberOfTees);

    /**
     * Requests an attestation.
     * @param _thresholdBIPS The threshold in BIPS.
     * @param _numberOfTees The number of TEEs.
     * @param _teeIds The TEE ids.
     * @param _attestationRequest The attestation request.
     */
    function requestAttestation(
        uint16 _thresholdBIPS,
        uint256 _numberOfTees,
        address[] memory _teeIds,
        bytes calldata _attestationRequest
    )
        external payable;
}
