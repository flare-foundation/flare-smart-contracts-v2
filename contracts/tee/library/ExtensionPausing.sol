// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";

/**
 * @title ExtensionPausing
 * @notice Library for managing TEE pausing-address records: per-extension lists of addresses
 *         authorised under one or more pinned governance configurations.
 * @dev Uses ERC-7201 namespaced storage, separate from ExtensionGovernance.
 *      Each pausing-addresses record pins a list of governance hashes; each pinned hash gets
 *      its own approval (signers + signatures + per-hash thresholdMet flag). Approvals are
 *      independent: reaching one approval's threshold does not stop signature collection in
 *      the others.
 */
library ExtensionPausing {

    // Per-pinned-hash bookkeeping. `signatureCount` (uint64) + `thresholdMet` (bool) pack
    // into a single storage slot (9 bytes). Signatures themselves are NOT stored per-approval
    // — they live once on the record (see `signatures` below), regardless of how many
    // approvals a single signer's signature contributes to.
    struct TeePausingApproval {
        mapping(address signer => bool) hasSigned;
        uint64 signatureCount;
        // Per-hash one-shot flag; flips to true the first time this approval's signature count
        // reaches its hash-specific threshold. Stays true thereafter.
        bool thresholdMet;
    }

    struct TeePausingAddressesRecord {
        EnumerableSet.AddressSet pausingAddresses;
        // Precomputed at setTeePausingAddresses time; signers ECDSA-recover against this hash.
        bytes32 messageHash;
        // Pinned at creation; duplicates rejected up front.
        bytes32[] governanceHashes;
        // Canonical, deduplicated signatures. Each successful sign call appends exactly one
        // entry, regardless of how many pinned hashes the signer is valid under. Per-approval
        // attribution is recovered in views via ECDSA recovery + the `hasSigned` mapping.
        Signature[] signatures;
        mapping(bytes32 governanceHash => TeePausingApproval) approvals;
    }

    struct TeeExtensionPausingState {
        uint256 nextPausingAddressesNonce;
        mapping(uint256 nonce => TeePausingAddressesRecord) nonceToTeePausingAddresses;
    }

    /// @custom:storage-location erc7201:tee.ExtensionPausing.State
    struct State {
        mapping(uint256 extensionId => TeeExtensionPausingState) extensionStates;
    }

    // erc7201 builtin not recognized by slither's parser; the constant is initialized at declaration
    //slither-disable-next-line uninitialized-state
    bytes32 internal constant STATE_POSITION = bytes32(erc7201("tee.ExtensionPausing.State"));

    function getState()
        internal pure
        returns (State storage _state)
    {
        bytes32 position = STATE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _state.slot := position
        }
    }
}
