// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * FtdcHub interface.
 */
interface IFtdcHub {

    struct FtdcProve {
        address[] teeIds;
        uint16 thresholdBIPS;
        address[] cosigners;
        uint64 cosignersThreshold;
        bytes attestationRequest;
    }

    event MinThresholdBIPSSet(uint16 minThresholdBIPS);
    event DefaultNumberOfTeesSet(uint8 defaultNumberOfTees);

    /**
     * Requests an attestation.
     * @param _thresholdBIPS The threshold in BIPS (optional).
     * @param _numberOfTees The number of TEEs (optional).
     * @param _teeIds The TEE ids (optional).
     * @param _cosigners The cosigners (optional).
     * @param _cosignersThreshold The cosigners threshold - must be 0 if cosigners are not provided.
     * @param _attestationRequest The attestation request.
     */
    function requestAttestation(
        uint16 _thresholdBIPS,
        uint256 _numberOfTees,
        address[] memory _teeIds,
        address[] memory _cosigners,
        uint64 _cosignersThreshold,
        bytes calldata _attestationRequest
    )
        external payable;
}
