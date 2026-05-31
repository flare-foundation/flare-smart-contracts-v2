// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { SignedPayload } from "../lib/SignedPayload.sol";

/**
 * @title SignedPayloadStructs
 * @notice ABI-only re-export of the `SignedPayload.Payload` struct so off-chain tooling can
 *         look up its layout via the compiled artifact (same pattern as the TEE structs
 *         interfaces). Not deployed; not called.
 */
interface SignedPayloadStructs {
    function payloadStruct(SignedPayload.Payload calldata) external;
}
