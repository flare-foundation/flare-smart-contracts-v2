// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../tee/ITeeRegistry.sol";
import "../ISignature.sol";
import "../IPublicKey.sol";

bytes32 constant TEE_KEY_EXISTENCE_ATTESTATION_TYPE = bytes32("TeeKeyExistence");

interface ITeeKeyExistence {

    /**
     * @notice Toplevel request
     * @param attestationType ID of the attestation type.
     * @param sourceId Id of the data source.
     * @param requestBody Data defining the request. Type and interpretation is determined by the `attestationType`.
     */
    struct Request {
        bytes32 attestationType;
        bytes32 sourceId;
        RequestBody requestBody;
    }

    /**
     * @notice Toplevel response
     * @param attestationType Extracted from the request.
     * @param sourceId Extracted from the request.
     * @param thresholdBIPS Extracted from the request (event).
     * @param timestamp Extracted from the request (block timestamp).
     * @param cosigners Extracted from the request (event).
     * @param cosignersThreshold Extracted from the request (event).
     * @param requestBody Extracted from the request.
     * @param responseBody Data defining the response. The verification rules for the construction of the
     * response body and the type are defined per specific `attestationType`.
     */
    struct Response {
        bytes32 attestationType;
        bytes32 sourceId;
        uint16 thresholdBIPS;
        uint64 timestamp;
        address[] cosigners;
        uint64 cosignersThreshold;
        RequestBody requestBody;
        ResponseBody responseBody;
    }

    /**
     * @notice Toplevel proof
     * @param relayMessage Relay message used for verification on the relay contract - signatures of data providers.
     * @param teeSignatures Signatures of the TEEs.
     * @param cosignerSignatures Signatures of the cosigners.
     * @param data Attestation response.
     */
    struct Proof {
        bytes relayMessage;
        Signature[] teeSignatures;
        Signature[] cosignerSignatures;
        Response data;
    }

    /**
     * @notice Request body for ITeeKeyExistence attestation type
     * @param teeId TEE id.
     * @param walletId Wallet id.
     * @param keyId Key id.
     */
    struct RequestBody {
        address teeId;
        bytes32 walletId;
        uint64 keyId;
    }

    /**
     * @notice Response body for ITeeKeyExistence attestation type
     * @param opType Operation type of a wallet.
     * @param publicKey Public key of the address.
     * @param restored True if the key was restored, false if generated on the TEE machine.
     * @param addressStr Address for the public key.
     * @param adminsPublicKeys Public keys of the admins.
     * @param adminsThreshold Admins threshold.
     * @param cosigners Cosigners of the wallet.
     * @param cosignersThreshold Cosigners threshold.
     * @param opTypeConstants Operation type constants.
     * @param pausingAddresses Addresses that can pause the wallet.
     * @param opTypeSettings Operation type settings.
     */
    struct ResponseBody {
        bytes32 opType;
        bytes publicKey;
        bool restored;
        string addressStr;
        PublicKey[] adminsPublicKeys;
        uint64 adminsThreshold;
        address[] cosigners;
        uint64 cosignersThreshold;
        bytes opTypeConstants;
        address[] pausingAddresses;
        bytes opTypeSettings;
    }
}
