// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";
import "../ISignature.sol";

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
     * @param requestBody Extracted from the request.
     * @param responseBody Data defining the response. The verification rules for the construction of the
     * response body and the type are defined per specific `attestationType`.
     */
    struct Response {
        bytes32 attestationType;
        bytes32 sourceId;
        uint16 thresholdBIPS;
        uint64 timestamp;
        RequestBody requestBody;
        ResponseBody responseBody;
    }

    /**
     * @notice Toplevel proof
     * @param relayMessage Relay message used for verification on the relay contract - signatures of data providers.
     * @param teeSignatures Signatures of the TEEs.
     * @param data Attestation response.
     */
    struct Proof {
        bytes relayMessage;
        Signature[] teeSignatures;
        Response data;
    }

    /**
     * @notice Request body for ITeeKeyExistence attestation type
     * @param teeId TEE id.
     * @param walletId Wallet id.
     * @param keyId Key id.
     * @param opType Operation type of a wallet.
     */
    struct RequestBody {
        address teeId;
        bytes32 walletId;
        uint256 keyId;
        bytes32 opType;
    }

    /**
     * @notice Response body for ITeeKeyExistence attestation type
     * @param publicKey Public key of the address.
     * @param addressStr Address for the public key.
     */
    struct ResponseBody {
        bytes publicKey;
        string addressStr;
    }
}
