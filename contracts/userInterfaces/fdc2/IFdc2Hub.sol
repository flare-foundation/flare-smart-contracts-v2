// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

bytes32 constant FDC2_OP_TYPE = bytes32("F_FDC2");

// Domain prefix bound into every FDC2 attestation-proof signed payload (TEE availability
// check, PMW multisig configured, PMW payment status, ...). See `SignedPayload`. The
// per-attestation differentiation (which attestation type, which source) lives inside the
// signed `Fdc2ResponseHeader` itself via `attestationType` and `sourceId`.
bytes32 constant FDC2 = bytes32("FDC2");

/**
 * Fdc2Hub interface.
 */
interface IFdc2Hub {

    /**
     * FDC2 attestation request header structure.
     * @param attestationType The attestation type.
     * @param sourceId The source id.
     * @param thresholdBIPS The threshold in BIPS (optional, 0 uses signing policy threshold).
     *  Nonzero values must be in `[minThresholdBIPS, 10000)` - 10000 itself is rejected, since the
     *  off-chain TEE verifier does not accept it and the request fee is non-refundable.
     *  Compared with strict inequality, so e.g. 5000 (50%) requires strictly more than 50% of the weight.
     * @param proofOwner The proof owner address (optional).
     */
    struct Fdc2RequestHeader {
        bytes32 attestationType;
        bytes32 sourceId;
        uint16 thresholdBIPS;
        address proofOwner;
    }

    /**
     * FDC2 attestation request structure.
     * @param header The request header (attestation type, source id, thresholdBIPS and proof owner).
     * @param requestBody The request body.
     */
    struct Fdc2AttestationRequest {
        Fdc2RequestHeader header;
        bytes requestBody;
    }

    struct Fdc2ResponseHeader {
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
     * @dev Requests are accepted for machines in PRODUCTION status as well as INITIALIZED status: this is needed
     *  for the initial verification, where data provider signatures are checked instead of TEE signatures.
     *  Proof validation via `verifyTeeSignature`, however, requires the machines to be in PRODUCTION status.
     */
    function requestAttestation(
        Fdc2AttestationRequest calldata _attestationRequest,
        uint256 _numberOfTees,
        address[] memory _teeIds,
        address[] memory _cosigners,
        uint64 _cosignersThreshold,
        address _claimBackAddress
    )
        external payable;
}
