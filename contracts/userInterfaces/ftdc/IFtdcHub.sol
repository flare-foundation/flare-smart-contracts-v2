// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * FtdcHub interface.
 */
interface IFtdcHub {

    /**
     * FTDC attestation request header structure.
     * @param attestationType The attestation type.
     * @param sourceId The source id.
     * @param thresholdBIPS The threshold in BIPS (optional, 0 uses signing policy threshold).
     * @param proofOwner The proof owner address (optional).
     */
    struct FtdcRequestHeader {
        bytes32 attestationType;
        bytes32 sourceId;
        uint16 thresholdBIPS;
        address proofOwner;
    }

    /**
     * FTDC attestation request structure.
     * @param header The request header (attestation type, source id, thresholdBIPS and proof owner).
     * @param requestBody The request body.
     */
    struct FtdcAttestationRequest {
        FtdcRequestHeader header;
        bytes requestBody;
    }

    struct FtdcResponseHeader {
        bytes32 attestationType;
        bytes32 sourceId;
        uint16 thresholdBIPS;
        address proofOwner;
        address[] cosigners;
        uint64 cosignersThreshold;
        uint64 timestamp;
    }

    event MinThresholdBIPSSet(uint16 minThresholdBIPS);
    event DefaultNumberOfTeesSet(uint8 defaultNumberOfTees);
    event AttestationRequested(
        bytes32 indexed instructionId,
        bytes32 indexed attestationType,
        bytes32 indexed sourceId,
        address proofOwner,
        address claimBackAddress,
        uint256 fee
    );

    error ThresholdInvalid();
    error NumberOfTeesAndTeeIdsInvalid();
    error CosignersThresholdInvalid();
    error MultipleResponsesPossible();
    error DuplicatedTeeId(address teeId);
    error TeeMachineNotAvailable();
    error OnlySystemExtensionId(address teeId);
    error FeeTooLow();
    error MinThresholdInvalid();
    error DefaultNumberOfTeesZero();

    /**
     * Requests an attestation.
     * Emits AttestationRequested event.
     * @param _attestationRequest The attestation request (header and body).
     * @param _numberOfTees The number of TEEs (optional).
     * @param _teeIds The TEE ids (optional).
     * @param _cosigners The cosigners (optional).
     * @param _cosignersThreshold The cosigners threshold - must be 0 if cosigners are not provided.
     * @param _claimBackAddress An address that can claim back the fee if the instructions are not executed (optional).
     */
    function requestAttestation(
        FtdcAttestationRequest calldata _attestationRequest,
        uint256 _numberOfTees,
        address[] memory _teeIds,
        address[] memory _cosigners,
        uint64 _cosignersThreshold,
        address _claimBackAddress
    )
        external payable;
}
