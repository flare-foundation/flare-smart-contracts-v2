// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

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

    /// A verified Safe-approval artifact stored by `confirmMachinePathListSafeApproval`: the signed
    /// Safe nonce plus the packed 65-byte owner signatures extracted from the Safe `execTransaction`
    /// calldata. Together with data the verifier already holds (this contract's address, the list's
    /// paths, the Safe address and owner snapshot bound into the governance hash, and the chain id)
    /// it is the COMPLETE artifact a TEE node needs — the fixed transaction shape (`operation ==
    /// CALL`, zero value/gas fields — see `approveMachinePathList`) supplies every other SafeTxHash
    /// ingredient, so the artifact is fully chain-served with no historical transaction lookup.
    struct SafeApprovalArtifact {
        uint256 safeNonce;
        bytes signatures;
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
    /// `satisfiedGovernanceHashes` lists the involved snapshots the calling Safe's live quorum
    /// could still cover at approval time — an advisory screening result; the governances are
    /// marked Safe-approved only by `confirmMachinePathListSafeApproval`.
    event MachinePathListApproved(
        uint256 indexed extensionId,
        uint256 indexed nonce,
        address indexed safe,
        uint32 safeNonce,
        bytes32[] satisfiedGovernanceHashes
    );

    /// Emitted by `confirmMachinePathListSafeApproval` when the owner signatures of a recorded
    /// Safe approval have been verified on-chain against the frozen snapshot of `governanceHash`.
    /// The verified artifact is stored and retrievable via `getMachinePathListSafeApprovalArtifact`.
    event MachinePathListSafeApprovalConfirmed(
        uint256 indexed extensionId,
        uint256 indexed nonce,
        bytes32 indexed governanceHash,
        address safe,
        uint256 safeNonce
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
    error SafeApprovalNotRecorded();
    error SafeApprovalAlreadyConfirmed();
    error InvalidSignaturesLength();
    error InvalidSignatureType();
    error UnorderedSignatures();
    error ThresholdNotReached(uint256 required, uint256 counted);

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
     * signature count reached its threshold, or its Safe approval was confirmed via
     * `confirmMachinePathListSafeApproval`.
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
     * First step of the Safe counterpart of `signMachinePathList` for Safe-backed governances
     * (see `IExtensionGovernance.setNewTeeGovernanceSafe`). The calling Safe cannot produce an
     * ECDSA signature, so the flow is split in two: this call — executed BY the Safe as one
     * ordinary Safe transaction — records that the Safe executed the approval (an `Approval`
     * entry + the `MachinePathListApproved` event, a complete artifact pointer), and
     * `confirmMachinePathListSafeApproval` — callable by anyone — verifies the owner signatures
     * from that Safe transaction on-chain against the frozen governance snapshot and marks the
     * governance Safe-approved. This call alone NEVER satisfies a governance and never touches
     * the ECDSA signature counts (`getMachinePathListSignatureCount` always reflects real
     * signatures only).
     *
     * Screening (advisory only): every involved governance whose registered Safe address equals
     * `msg.sender` AND whose owner/threshold snapshot is still satisfiable by the Safe's live
     * quorum (live threshold not below the snapshot threshold, and at least
     * snapshot-threshold-many snapshot signers still live owners) counts as screened. Both
     * screening inputs are under the Safe's own control, so the screen is NOT an authorization
     * check — it exists to fail an honestly-stale Safe fast, BEFORE its nonce is consumed on an
     * approval that `confirmMachinePathListSafeApproval` could never accept. If no matching
     * snapshot passes, the call reverts `SafeGovernanceStale` (bridge via direct snapshot-owner
     * signatures through `signMachinePathList`, or re-register governance and machines). Callers
     * matching no involved governance revert `UnrecognizedSigner`. Repeat approvals are
     * permitted; each appends another `Approval` entry — the recovery path when an earlier Safe
     * transaction turns out unconfirmable (executed by an owner, or proposed with a nonzero
     * value/gas field): execute a fresh approval at a new Safe nonce and confirm that one.
     *
     * `_messageHash` must equal the list's stored messageHash (`MessageHashMismatch` otherwise).
     * Embedding it in the transaction calldata makes the Safe owners' signatures over the Safe
     * transaction hash bind the full path-list content.
     *
     * REQUIRED TRANSACTION SHAPE — the on-chain confirmation and TEE nodes reconstruct the
     * EIP-712 SafeTxHash from a fixed recipe, so the Safe transaction MUST be proposed as a plain
     * single contract interaction: `to` = this contract, `operation` = CALL, `data` = this
     * selector + (extensionId, nonce, messageHash), and `value` / `safeTxGas` / `baseGas` /
     * `gasPrice` / `gasToken` / `refundReceiver` all zero. Batched execution (e.g. MultiSend,
     * which runs as a delegatecall to the MultiSend contract) is NOT supported, and neither are
     * gas-refund parameters — the approval executes on-chain either way (msg.sender is the Safe),
     * but its signatures can then never be confirmed nor verified by TEE nodes (`to` / `operation`
     * / gas-field mismatch), so the consumed Safe nonce is wasted. Execute the Safe transaction
     * from a NON-OWNER account so all threshold signatures in the blob are real ECDSA signatures
     * (an executing owner is represented by an approved-hash `v=1` entry, which neither the
     * confirmation nor TEE nodes accept). The recorded `Approval.blockNumber` (see
     * `getMachinePathListApprovals`) locates the transaction, and `Approval.safeNonce` supplies
     * the signed Safe nonce — the one SafeTxHash ingredient not present in the `execTransaction`
     * calldata (captured here as `safe.nonce() - 1`, since the Safe increments its nonce before
     * making the inner call).
     *
     * Emits MachinePathListApproved.
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
     * Second step of the Safe approval flow: verifies, fully on-chain, that the owner signatures
     * of a Safe approval recorded via `approveMachinePathList` meet the frozen snapshot of
     * `_governanceHash`, then marks the governance Safe-approved. Callable by ANYONE — the caller
     * only relays data the Safe transaction already published: `_signatures` is the packed
     * signature blob from the `execTransaction` calldata (already sorted by the Safe's own
     * validation; copy it verbatim) and `_safeNonce` is the signed Safe nonce from the matching
     * `Approval` entry / `MachinePathListApproved` event.
     *
     * Verification is against the SNAPSHOT, not the live Safe — no live Safe state is read, so
     * later owner rotations of the Safe can neither help nor harm a confirmation:
     * 1. `_governanceHash` must be involved on the list and Safe-backed (`UnrecognizedSigner`
     *    otherwise).
     * 2. An `Approval` entry with the governance's Safe and `_safeNonce` must exist
     *    (`SafeApprovalNotRecorded` otherwise) — the Safe really executed the approval at that
     *    nonce; a signature blob collected off-chain but never executed can never confirm.
     *    (Entries store the nonce as uint32, so the match is modulo 2^32 — non-load-bearing,
     *    since a wrong `_safeNonce` fails signature recovery below.)
     * 3. The EIP-712 SafeTxHash is reconstructed from the fixed transaction shape documented at
     *    `approveMachinePathList` (this contract, CALL, the approval calldata with the list's
     *    stored messageHash, zero value/gas fields, `_safeNonce`) under the Safe's domain
     *    (chainId + Safe address, Safe >= 1.3.0).
     * 4. `_signatures` must parse into 65-byte `{r,s,v}` chunks (`InvalidSignaturesLength`),
     *    each an ECDSA signature over the SafeTxHash (`v` in {27,28}) or over its
     *    EIP-191-prefixed form (`v` in {31,32}); approved-hash `v=1` and contract-signature
     *    `v=0` chunks revert `InvalidSignatureType` (not verifiable — trim them off, and execute
     *    approvals from a non-owner account so they never appear). Recovered signers must be
     *    strictly ascending (`UnorderedSignatures`) — the Safe's own ordering rule, which also
     *    guarantees uniqueness; genuine blobs already satisfy it.
     * 5. At least snapshot-threshold-many recovered signers must be members of the snapshot's
     *    signer set (`ThresholdNotReached(required, counted)` otherwise). Recovered non-members
     *    are skipped, not rejected — the executing quorum may span several snapshots of the same
     *    Safe; each snapshot counts only its own members.
     *
     * On success the governance is marked Safe-approved (`isMachinePathListSafeApproved`) — a
     * satisfaction path independent of the ECDSA signature counts — and the verified artifact
     * `{safeNonce, signatures}` is stored for chain-served retrieval
     * (`getMachinePathListSafeApprovalArtifact`). Confirmation is ONE-SHOT per governance hash
     * (`SafeApprovalAlreadyConfirmed` on a repeat): the artifact verifies against the frozen
     * snapshot, so it stays valid forever — a replacement could never be fresher, and
     * immutability lets consumers cache it.
     * When several snapshots of the same Safe are involved, confirm each governance hash
     * separately with the same `(_safeNonce, _signatures)` — the extension owner must coordinate
     * the confirming owners so they satisfy each involved snapshot's threshold within that
     * snapshot's owner set (fail-closed per snapshot; bridge via direct snapshot-owner signatures,
     * a fresh list nonce, or machine re-registration).
     *
     * Emits MachinePathListSafeApprovalConfirmed; emits MachinePathListSigned when the list
     * becomes fully signed (activation and active-nonce promotion happen only on the first
     * transition, so MachinePathListSigned is emitted at most once per list).
     * @param _extensionId The extension id.
     * @param _nonce The list nonce.
     * @param _governanceHash The involved Safe-backed governance hash to confirm.
     * @param _safeNonce The Safe nonce the owners signed (from the `Approval` entry).
     * @param _signatures The packed 65-byte owner signatures from the `execTransaction` calldata.
     */
    function confirmMachinePathListSafeApproval(
        uint256 _extensionId,
        uint256 _nonce,
        bytes32 _governanceHash,
        uint256 _safeNonce,
        bytes calldata _signatures
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
     * was satisfied (signature threshold reached, or its Safe approval confirmed) at least once.
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
     * via `confirmMachinePathListSafeApproval` (on-chain verification of the owner signatures
     * against the frozen snapshot). A Safe-approved governance counts as satisfied for activation
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
     * Returns the verified Safe-approval artifact stored by `confirmMachinePathListSafeApproval`
     * for the given involved governance — the signed Safe nonce plus the packed owner signatures
     * (see `SafeApprovalArtifact`). Zero nonce and empty signatures if the governance has not been
     * confirmed; immutable once set (confirmation is one-shot per governance hash). Relay clients
     * serve TEE nodes from this getter alone — no historical transaction or log lookup is needed.
     * @param _extensionId The extension id.
     * @param _nonce The list nonce.
     * @param _governanceHash The involved Safe-backed governance hash.
     * @return _artifact The verified artifact (`safeNonce`, `signatures`).
     */
    function getMachinePathListSafeApprovalArtifact(
        uint256 _extensionId,
        uint256 _nonce,
        bytes32 _governanceHash
    )
        external view
        returns (SafeApprovalArtifact memory _artifact);

    /**
     * Returns the msg.sender approvals recorded via `approveMachinePathList`, in submission order
     * (one entry per call — repeat approvals append). Each entry is the execution evidence that
     * `confirmMachinePathListSafeApproval` cross-checks (Safe + signed nonce), and its block
     * number locates the Safe `execTransaction` transaction — the submission path for the
     * signature blob, and a fallback artifact source next to
     * `getMachinePathListSafeApprovalArtifact`.
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
