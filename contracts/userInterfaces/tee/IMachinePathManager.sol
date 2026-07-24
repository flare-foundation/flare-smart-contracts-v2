// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { Signature } from "../ISignature.sol";

// Domain prefix for the per-extension machine-path-list signed payload. See `SignedPayload`.
bytes32 constant TEE_MACHINE_PATH_LIST = bytes32("TEE_MACHINE_PATH_LIST");

/**
 * @title IMachinePathManager
 * @notice Public interface for the MachinePathManagerFacet.
 *
 * @dev Per-extension governance-signed allow-list of (sourceTeeIds[], destinationTeeIds[]) paths,
 *      addressing TEE machines directly by `address teeId`. The primitive is intentionally generic
 *      so it can gate other authorized TEE-to-TEE flows beyond key backup/restore.
 *
 *      Addressing: lists are per-extension, identified by their 1-indexed nonce. The list with nonce
 *      `N` lives at array index `N - 1`. Only the latest-nonce signed list per extension is active;
 *      older signed lists are deprecated automatically when a newer-nonce one becomes signed.
 *
 *      Governance: a list tracks the union of all governance hashes derived from every teeId added
 *      (in either role across any path). The list is signed when every involved governance has
 *      reached its threshold. A signer that belongs to multiple involved governances contributes to
 *      each of their counts simultaneously; the raw signature is stored once.
 */
interface IMachinePathManager {

    struct MachinePath {
        address[] sourceTeeIds;
        address[] destinationTeeIds;
    }

    /// A msg.sender approval recorded by `approveMachinePathList` (signer = the calling Safe).
    /// `blockNumber` lets relay clients locate the Safe `execTransaction` transaction and extract
    /// the owner signatures and transaction parameters without scanning the chain. `safeNonce` is
    /// the Safe nonce the owners signed (the Safe's nonce is part of the EIP-712 SafeTxHash but is
    /// read from Safe storage rather than passed to `execTransaction`, so it is captured here —
    /// the one SafeTxHash ingredient not recoverable from the transaction calldata).
    /// Packed into a single storage slot (20 + 8 + 4 = 32 bytes; 2^32 Safe transactions is
    /// unreachable).
    struct Approval {
        address signer;
        uint64 blockNumber;
        uint32 safeNonce;
    }

    event MachinePathListStarted(
        uint256 indexed extensionId,
        uint256 indexed nonce
    );

    event MachinePathsAdded(
        uint256 indexed extensionId,
        uint256 indexed nonce,
        MachinePath[] paths
    );

    event MachinePathListFinalized(
        uint256 indexed extensionId,
        uint256 indexed nonce,
        bytes32[] involvedGovernanceHashes
    );

    event MachinePathListSignatureAdded(
        uint256 indexed extensionId,
        uint256 indexed nonce,
        address indexed signer,
        bytes32[] countedGovernanceHashes
    );

    /// `safeNonce` is the signed Safe nonce (see `Approval.safeNonce`) — together with the log's
    /// block number this makes the event a complete artifact pointer for relay clients.
    event MachinePathListApproved(
        uint256 indexed extensionId,
        uint256 indexed nonce,
        address indexed safe,
        uint32 safeNonce,
        bytes32[] satisfiedGovernanceHashes
    );

    event MachinePathListSigned(
        uint256 indexed extensionId,
        uint256 indexed nonce
    );

    // `InvalidNonce` is inherited from `ITeeCommonErrors` (via the aggregate interface) and raised by
    // the library when the (extensionId, nonce) pair does not resolve to a stored list.
    error ListAlreadyFinalized();
    error ListNotFinalized();
    error NoActiveMachinePathList();
    error InvalidMachinePath();
    error NoPaths();
    error NoSourceTeeIds();
    error NoDestinationTeeIds();
    error SourceTeeIdAlreadyExists();
    error DestinationTeeIdAlreadyExists();
    error SignerAlreadySigned();
    error UnrecognizedSigner();
    error GovernanceHashZero(address teeId);
    error MessageHashMismatch();
    error SafeGovernanceStale();

    /**
     * Creates a new (empty) machine-path list for the given extension and returns its nonce.
     * The returned nonce is `getMachinePathListsCount(extensionId)` immediately after the call
     * (1-indexed within the extension; strictly increasing).
     * Emits MachinePathListStarted.
     * Can only be called by the extension owner or the extension operator.
     * @param _extensionId The extension id.
     * @return _nonce The freshly-allocated list nonce.
     */
    function createNewMachinePathList(
        uint256 _extensionId
    )
        external
        returns (uint256 _nonce);

    /**
     * Appends paths to a not-yet-finalized list. For each teeId in each path, the function derives
     * the teeId's governance hash from its codeHash and adds it to the list's involved-governance set.
     * teeIds may freely mix governances within either role inside a single path.
     * Emits MachinePathsAdded.
     * Can only be called by the extension owner or the extension operator.
     * @param _extensionId The extension id.
     * @param _nonce The list nonce.
     * @param _paths The paths to add.
     */
    function addMachinePaths(
        uint256 _extensionId,
        uint256 _nonce,
        MachinePath[] calldata _paths
    )
        external;

    /**
     * Finalizes the list and computes its messageHash. After this call the list is ready for
     * signing but no further paths may be added.
     * Emits MachinePathListFinalized.
     * Can only be called by the extension owner or the extension operator.
     * @param _extensionId The extension id.
     * @param _nonce The list nonce.
     */
    function finalizeMachinePathList(
        uint256 _extensionId,
        uint256 _nonce
    )
        external;

    /**
     * Submits a signature for a finalized list. The signature is counted toward every involved
     * governance the signer is a member of. The list becomes "signed" (and promoted to active iff
     * its nonce exceeds the current active) once every involved governance is satisfied — its
     * signature count reached its threshold, or its Safe approved via `approveMachinePathList`.
     * Signatures may still be submitted after the list is signed (evidence collection for
     * off-chain verifiers, e.g. snapshot owners bridging an old governance hash); activation and
     * active-nonce promotion happen only on the first transition, so MachinePathListSigned is
     * emitted at most once per list.
     * Emits MachinePathListSignatureAdded; emits MachinePathListSigned when activation occurs.
     * Anyone may relay a signature.
     * @param _extensionId The extension id.
     * @param _nonce The list nonce.
     * @param _signature The EIP-191 (`personal_sign`) signature over the list's messageHash.
     */
    function signMachinePathList(
        uint256 _extensionId,
        uint256 _nonce,
        Signature calldata _signature
    )
        external;

    /**
     * msg.sender counterpart of `signMachinePathList` for Safe-backed governances (see
     * `IExtensionGovernance.setNewTeeGovernanceSafe`). The calling Safe cannot produce an ECDSA
     * signature, so its caller identity is the approval: every involved governance whose
     * registered Safe address equals `msg.sender` AND whose owner/threshold snapshot is still
     * satisfiable by the Safe's live quorum (live threshold not below the snapshot threshold, and
     * at least snapshot-threshold-many snapshot signers still live owners) is marked
     * Safe-approved — a satisfaction path independent of the ECDSA signature counts, which this
     * function never touches (`getMachinePathListSignatureCount` always reflects real signatures
     * only). A Safe-approved governance counts as satisfied for activation, since the Safe
     * executes only after threshold-many owner confirmations.
     * Unsatisfiable snapshots are skipped; if every matching snapshot is unsatisfiable the call
     * reverts `SafeGovernanceStale` (bridge via direct snapshot-owner signatures through
     * `signMachinePathList`, or re-register governance and machines). Callers matching no involved
     * governance revert `UnrecognizedSigner`. Repeat approvals — including after the list is
     * signed — are permitted and idempotent on the flags (no per-signer dedup: a contract can
     * never produce the ECDSA signature the dedup exists for); each call appends another
     * `Approval` entry, giving relays a fresh artifact pointer (e.g. after an owner rotation).
     * Activation and active-nonce promotion happen only on the first transition, so
     * MachinePathListSigned is emitted at most once per list.
     *
     * `_messageHash` must equal the list's stored messageHash (`MessageHashMismatch` otherwise).
     * Embedding it in the transaction calldata makes the Safe owners' signatures over the Safe
     * transaction hash bind the full path-list content: off-chain verifiers (TEE nodes) recompute
     * the expected messageHash from the received paths, check the Safe transaction's `to` (this
     * contract), `operation` (CALL) and calldata (this selector, extensionId, nonce, messageHash),
     * recompute the EIP-712 SafeTxHash under the Safe's domain (safe address + chainId) and recover
     * at least threshold-many distinct snapshot owners from the packed signatures (rejecting
     * approved-hash `v=1` and contract-signature `v=0` entries). Execute the Safe transaction from
     * a non-owner account so all threshold signatures are real ECDSA signatures. The recorded
     * `Approval.blockNumber` (see `getMachinePathListApprovals`) locates the transaction, and
     * `Approval.safeNonce` supplies the signed Safe nonce — the one SafeTxHash ingredient not
     * present in the `execTransaction` calldata (captured here as `safe.nonce() - 1`, since the
     * Safe increments its nonce before making the inner call). Batched execution (e.g. MultiSend,
     * which runs as a delegatecall to the MultiSend contract) is NOT supported: the approval must
     * be its own direct Safe transaction, or offline verifiers reject the artifact (`to` /
     * `operation` mismatch). On-chain the call would still count (msg.sender is the Safe either
     * way), so submitters must take care — a batched approval is valid on-chain but useless as a
     * node artifact.
     *
     * When old and new snapshots of the same Safe are involved in one list, the extension owner
     * must coordinate the confirming owners so that they satisfy each involved snapshot's threshold
     * within that snapshot's owner set — the chain enforces satisfiability, not the actual choice
     * of confirmers; nodes bound to a snapshot the confirmers do not satisfy will reject the
     * artifact (fail-closed; bridge via direct snapshot-owner signatures, a fresh list nonce, or
     * machine re-registration).
     * Emits MachinePathListApproved; emits MachinePathListSigned when activation occurs.
     * @param _extensionId The extension id.
     * @param _nonce The list nonce.
     * @param _messageHash Must match `getMachinePathListMessageHash(_extensionId, _nonce)`.
     */
    function approveMachinePathList(
        uint256 _extensionId,
        uint256 _nonce,
        bytes32 _messageHash
    )
        external;

    /**
     * Non-reverting probe. Returns true iff the extension has a currently-active signed list AND
     * that list contains a path whose sourceTeeIds includes `_sourceTeeId` and whose destinationTeeIds
     * includes `_destinationTeeId`.
     * @param _extensionId The extension id.
     * @param _sourceTeeId The source TEE id.
     * @param _destinationTeeId The destination TEE id.
     * @return True if the pair is allowed by the active list, false otherwise.
     */
    function isMachinePathValid(
        uint256 _extensionId,
        address _sourceTeeId,
        address _destinationTeeId
    )
        external view
        returns (bool);

    /**
     * Returns the nonce of the active list for the given extension.
     * Reverts with `NoActiveMachinePathList` if no list has been signed for the extension yet.
     * @param _extensionId The extension id.
     * @return _nonce The active list nonce.
     */
    function getActiveMachinePathListNonce(
        uint256 _extensionId
    )
        external view
        returns (uint256 _nonce);

    /**
     * Returns true iff the (extensionId, nonce) list is finalized (messageHash set).
     */
    function isMachinePathListFinalized(
        uint256 _extensionId,
        uint256 _nonce
    )
        external view
        returns (bool);

    /**
     * Returns true iff the (extensionId, nonce) list has been signed — every involved governance
     * was satisfied (signature threshold reached, or Safe-approved) at least once.
     */
    function isMachinePathListSigned(
        uint256 _extensionId,
        uint256 _nonce
    )
        external view
        returns (bool);

    /**
     * Returns the messageHash bound to the list after `finalizeMachinePathList` — the value
     * off-chain signers must EIP-191 sign. Returns `bytes32(0)` before finalize.
     */
    function getMachinePathListMessageHash(
        uint256 _extensionId,
        uint256 _nonce
    )
        external view
        returns (bytes32);

    /**
     * Returns the number of lists ever created for the given extension. Allocated nonces run from
     * 1 to this value inclusive.
     */
    function getMachinePathListsCount(
        uint256 _extensionId
    )
        external view
        returns (uint256);

    /**
     * Primary getter intended for off-chain relay clients: returns everything needed to forward
     * the list (alongside an on-chain instruction) to a TEE machine proxy for path verification.
     * Signatures are stored once per unique signer; per-governance threshold progress is queried
     * separately via `getMachinePathListSignatureCount`. Safe msg.sender approvals are returned
     * separately via `getMachinePathListApprovals`.
     * @param _extensionId The extension id.
     * @param _nonce The list nonce.
     * @return _paths The paths in the list.
     * @return _involvedGovernanceHashes The union of all governance hashes that appear in any path.
     * @return _signatures All collected signatures, in submission order, one per unique signer.
     * @return _signed True iff every involved governance has reached its threshold.
     */
    function getMachinePathList(
        uint256 _extensionId,
        uint256 _nonce
    )
        external view
        returns (
            MachinePath[] memory _paths,
            bytes32[] memory _involvedGovernanceHashes,
            Signature[] memory _signatures,
            bool _signed
        );

    /**
     * Returns the number of ECDSA signatures collected so far that count toward a particular
     * involved governance on a given list. Useful for off-chain monitors tracking threshold
     * progress. Safe approvals are tracked separately — see `isMachinePathListSafeApproved`.
     */
    function getMachinePathListSignatureCount(
        uint256 _extensionId,
        uint256 _nonce,
        bytes32 _governanceHash
    )
        external view
        returns (uint64);

    /**
     * Returns true iff the given involved governance has been marked Safe-approved on the list
     * via `approveMachinePathList`. A Safe-approved governance counts as satisfied for activation
     * regardless of its ECDSA signature count.
     */
    function isMachinePathListSafeApproved(
        uint256 _extensionId,
        uint256 _nonce,
        bytes32 _governanceHash
    )
        external view
        returns (bool);

    /**
     * Returns the msg.sender approvals recorded via `approveMachinePathList`, in submission order
     * (one entry per call — repeat approvals append). Complements the ECDSA `_signatures` returned
     * by `getMachinePathList`: relay clients use each approval's block number to locate the Safe
     * `execTransaction` transaction (owner signatures + transaction parameters) and its safeNonce
     * to complete the SafeTxHash preimage forwarded to TEE nodes.
     * @param _extensionId The extension id.
     * @param _nonce The list nonce.
     * @return _approvals The recorded approvals.
     */
    function getMachinePathListApprovals(
        uint256 _extensionId,
        uint256 _nonce
    )
        external view
        returns (Approval[] memory _approvals);
}
