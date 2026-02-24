// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * @custom:name IWeb2Json
 * @custom:supported WEB2
 * @author Flare
 * @notice An attestation request that fetches JSON data from the given URL,
 * applies a jq filter to transform the returned result, and returns the structured data as ABI encoded data.
 * @custom:verification  Data is fetched from an URL `url`. The received data is then processed with jq as
 * the `postProcessJq` states. The structure of the final JSON is written in the `abiSignature`.
 *
 * The response contains an abi encoding of the final data.
 * @custom:lut `0xffffffffffffffff`
 * @custom:lut-limit `0xffffffffffffffff`
 */
interface IWeb2Json {
    /**
     * @notice Toplevel request
     * @param attestationType ID of the attestation type.
     * @param sourceId ID of the data source.
     * @param messageIntegrityCode `MessageIntegrityCode` that is derived from the expected response.
     * @param requestBody Data defining the request. Type (struct) and interpretation is determined
     * by the `attestationType`.
     */
    struct Request {
        bytes32 attestationType;
        bytes32 sourceId;
        bytes32 messageIntegrityCode;
        RequestBody requestBody;
    }

    /**
     * @notice Toplevel response
     * @param attestationType Extracted from the request.
     * @param sourceId Extracted from the request.
     * @param votingRound The ID of the State Connector round in which the request was considered.
     * @param lowestUsedTimestamp The lowest timestamp used to generate the response.
     * @param requestBody Extracted from the request.
     * @param responseBody Data defining the response. The verification rules for the construction
     * of the response body and the type are defined per specific `attestationType`.
     */
    struct Response {
        bytes32 attestationType;
        bytes32 sourceId;
        uint64 votingRound;
        uint64 lowestUsedTimestamp;
        RequestBody requestBody;
        ResponseBody responseBody;
    }

    /**
     * @notice Toplevel proof
     * @param merkleProof Merkle proof corresponding to the attestation response.
     * @param data Attestation response.
     */
    struct Proof {
        bytes32[] merkleProof;
        Response data;
    }

    /**
     * @notice Request body for Web2Json attestation type
     * @param url URL of the data source
     * @param httpMethod HTTP method to be used to fetch from URL source.
     * Supported methods: GET, POST, PUT, PATCH, DELETE.
     * @param headers Headers to be included to fetch from URL source. Use `{}` if no headers are needed.
     * @param queryParams Query parameters to be included to fetch from URL source.
     * Use `{}` if no query parameters are needed.
     * @param body Request body to be included to fetch from URL source. Use '{}' if no request body is required.
     * @param postProcessJq jq filter used to post-process the JSON response from the URL.
     * @param abiSignature ABI signature of the struct used to encode the data after jq post-processing.
     */
    struct RequestBody {
        string url;
        string httpMethod;
        string headers;
        string queryParams;
        string body;
        string postProcessJq;
        string abiSignature;
    }

    /**
     * @notice Response body for Web2Json attestation type
     * @param abiEncodedData Raw binary data encoded to match the function parameters in ABI.
     */
    struct ResponseBody {
        bytes abiEncodedData;
    }
}
