// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title SignedPayload
 * @notice Canonical hashing of off-chain ECDSA signature preimages used across the protocol.
 * @dev Each signed message is described by a 3-field struct:
 *
 *      struct Payload {
 *          bytes32 prefix;     // per-operation domain tag, e.g. bytes32("TEE_MACHINE_REGISTER")
 *          uint256 chainId;    // block.chainid — prevents cross-chain replay
 *          bytes32 dataHash;   // keccak256(abi.encode(...operation-specific fields...))
 *      }
 *
 *      The `prefix` provides cross-operation domain separation; the `chainId` field prevents
 *      cross-chain replay; the `dataHash` carries the operation's bound state. Off-chain
 *      signers sign `eth_sign(messageHash)` — `ethSignedHash` returns exactly that value for
 *      use with `ECDSA.recover`.
 */
library SignedPayload {

    struct Payload {
        bytes32 prefix;
        uint256 chainId;
        bytes32 dataHash;
    }

    /**
     * Returns the canonical message hash a signer is expected to wrap with `eth_sign` —
     * `keccak256(abi.encode(Payload(prefix, chainId, dataHash)))`. Used both as the value
     * stored on-chain for multi-sig collection (re-wrapped with `toEthSignedMessageHash` at
     * each signature-verification call) and as the input to `ethSignedHash` below.
     */
    function messageHash(
        bytes32 _prefix,
        bytes32 _dataHash
    )
        internal view
        returns (bytes32)
    {
        return keccak256(abi.encode(Payload(_prefix, block.chainid, _dataHash)));
    }

    /**
     * Returns the eth-signed-message hash that `ECDSA.recover` is called with. Equivalent to
     * `MessageHashUtils.toEthSignedMessageHash(messageHash(_prefix, _dataHash))`.
     */
    function ethSignedHash(
        bytes32 _prefix,
        bytes32 _dataHash
    )
        internal view
        returns (bytes32)
    {
        return MessageHashUtils.toEthSignedMessageHash(messageHash(_prefix, _dataHash));
    }
}
