// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * @custom:name IXRPPaymentNonexistence
 * @custom:id 0x09
 * @custom:supported XRP, testXRP
 * @author Flare
 * @notice Assertion that an agreed-upon XRP payment has not been made by a certain deadline.
 * A confirmed request shows that a transaction meeting certain criteria (address, amount, reference) did not appear
 * in the specified block range.
 *
 *
 * This type of attestation can be used to e.g. provide grounds to liquidate funds locked by a smart contract on
 * Flare when a payment is missed.
 *
 * @custom:verification If `firstOverflowBlock` cannot be determined or does not have a sufficient
 * [number of confirmations](/specs/attestations/configs.md#finalityconfirmation), the attestation
 * request is rejected.
 *
 * If `firstOverflowBlockNumber` is higher or equal to `minimalBlockNumber`, the request is rejected.
 * The search range are blocks between heights including `minimalBlockNumber` and excluding `firstOverflowBlockNumber`.
 * If the verifier does not have a view of all blocks from `minimalBlockNumber` to `firstOverflowBlockNumber`,
 *  the attestation request is rejected.
 *
 * The request is confirmed if no transaction meeting the specified criteria is found in the search range.
 *
 * Criteria for the transaction:
 * - The transaction is of type payment.
 * - The destination address hash matches the hash of the destination address of the transaction.
 * - If `checkFirstMemoData` is true, the hash of the MemoData field of the first Memo in the transaction matches
 * `firstMemoDataHash`.
 * - If `checkDestinationTag` is true, the destination tag of the transaction matches `destinationTag`.
 * At least one of the fields `checkFirstMemoData` and `checkDestinationTag` must be true for the request to be valid.
 * - One of the following is true:
 *   - Transaction status is `SUCCESS` and the amount received by the specified destination address is greater
 *  than the specified `value`.
 *   - Transaction status is `RECEIVER_FAILURE` and the specified destination address would receive an amount
 * greater than the specified `value` had the transaction been successful.
 *
 *
 * Timestamp is `close_time` converted to UNIX time.
 *
 * @custom:lut `minimalBlockTimestamp`
 * @custom:lutlimit `0x127500`
 */
interface IXRPPaymentNonexistence {
  /**
   * @notice Top level request
   * @param attestationType ID of the attestation type.
   * @param sourceId ID of the data source.
   * @param messageIntegrityCode `MessageIntegrityCode` that is derived from the expected response as defined.
   * @param requestBody Data defining the request. Type (struct) and interpretation is determined by the
   * `attestationType`.
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
   * @param responseBody Data defining the response. The verification rules for the construction of the response
   * body and the type are defined per specific `attestationType`.
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
   * @notice Top level proof
   * @param merkleProof Merkle proof corresponding to the attestation response.
   * @param data Attestation response.
   */
  struct Proof {
    bytes32[] merkleProof;
    Response data;
  }

  /**
   * @notice Request body for XRPPaymentNonexistence attestation type
   * @param minimalBlockNumber The start block of the search range.
   * @param deadlineBlockNumber The blockNumber to be included in the search range.
   * @param deadlineTimestamp The timestamp to be included in the search range.
   * @param destinationAddressHash The standard address hash of the address to which the payment had to be done.
   * @param amount The requested amount in minimal units that had to be paid.
   * @param checkFirstMemoData Whether to consider the firstMemoDataHash field in the search. Notice:
   * At least one `checkFirstMemoData` (this field) or `checkDestinationTag` must be true.
   * @param firstMemoDataHash Hash of the MemoData field of the first Memo in the transaction.
   * @param checkDestinationTag Whether to consider the destinationTag field in the search. Notice:
   * At least one `checkFirstMemoData` or `checkDestinationTag` (this field) must be true.
   * @param destinationTag Destination tag of the transaction.
   * @custom:below If both `firstMemoDataHash` and `destinationTag` are zero, they are not considered in the
   * search and are ignored, effectively looking for any transaction with at least the specified amount sent to
   * the specified address.
   * @param proofOwner Address authorized to use the proof, where applicable.
   */
  struct RequestBody {
    uint64 minimalBlockNumber;
    uint64 deadlineBlockNumber;
    uint64 deadlineTimestamp;
    bytes32 destinationAddressHash;
    uint256 amount;
    bool checkFirstMemoData;
    bytes32 firstMemoDataHash;
    bool checkDestinationTag;
    uint256 destinationTag;
    address proofOwner;
  }

  /**
   * @notice Response body for XRPPaymentNonexistence attestation type.
   * @param minimalBlockTimestamp The timestamp of the minimalBlock.
   * @param firstOverflowBlockNumber The height of the firstOverflowBlock.
   * @param firstOverflowBlockTimestamp The timestamp of the firstOverflowBlock.
   * @custom:below `firstOverflowBlock` is the first block that has block number higher than `deadlineBlockNumber`
   * and timestamp later than `deadlineTimestamp`.
   * The specified search range are blocks between heights including `minimalBlockNumber` and excluding
   * `firstOverflowBlockNumber`.
   */
  struct ResponseBody {
    uint64 minimalBlockTimestamp;
    uint64 firstOverflowBlockNumber;
    uint64 firstOverflowBlockTimestamp;
  }
}
