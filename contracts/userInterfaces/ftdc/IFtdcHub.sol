// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * FtdcHub interface.
 */
interface IFtdcHub {

    struct FtdcRequestHeader {
        bytes32 attestationType;
        bytes32 sourceId;
        uint16 thresholdBIPS;
        address[] cosigners;
        uint64 cosignersThreshold;
    }

    struct FtdcAttestationRequest {
        FtdcRequestHeader header;
        bytes requestBody;
    }

    struct FtdcResponseHeader {
        bytes32 attestationType;
        bytes32 sourceId;
        uint16 thresholdBIPS;
        address[] cosigners;
        uint64 cosignersThreshold;
        uint64 timestamp;
    }

    event MinThresholdBIPSSet(uint16 minThresholdBIPS);
    event DefaultNumberOfTeesSet(uint8 defaultNumberOfTees);


    // Error types for FtdcHub require statements
    error ThresholdInvalid();
    error NumberOfTeesAndTeeIdsInvalid();
    error CosignersThresholdInvalid();
    error MultipleResponsesPossible();
    error TeeMachineNotAvailable();
    error FeeTooLow();

    /**
     * Requests an attestation.
     * @param _thresholdBIPS The threshold in BIPS (optional).
     * @param _numberOfTees The number of TEEs (optional).
     * @param _teeIds The TEE ids (optional).
     * @param _cosigners The cosigners (optional).
     * @param _cosignersThreshold The cosigners threshold - must be 0 if cosigners are not provided.
     * @param _attestationType The attestation type.
     * @param _sourceId The source id.
     * @param _requestBody The request body.
     */
    function requestAttestation(
        uint16 _thresholdBIPS,
        uint256 _numberOfTees,
        address[] memory _teeIds,
        address[] memory _cosigners,
        uint64 _cosignersThreshold,
        bytes32 _attestationType,
        bytes32 _sourceId,
        bytes calldata _requestBody
    )
        external payable;
}
