// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { Signature } from "../ISignature.sol";

// Domain prefix for the per-extension machine-path-list signed payload. See `SignedPayload`.
bytes32 constant TEE_MACHINE_PATH_LIST = bytes32("TEE_MACHINE_PATH_LIST");

/**
 * @title IMachinePathManager
 * @notice Public interface for the MachinePathManagerFacet.
 *
 * @dev Per-extension governance-signed allow-list of (sourceTeeIds[], destinationTeeIds[]) paths.
 *      Sibling primitive to UpgradeManagerFacet (which signs (codeHash, platform) version paths),
 *      but addresses TEE machines directly by `address teeId`. The primitive is intentionally generic
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

    event MachinePathListSigned(
        uint256 indexed extensionId,
        uint256 indexed nonce
    );

    // `InvalidNonce` is inherited from `ITeeCommonErrors` (via the aggregate interface) and raised by
    // the library when the (extensionId, nonce) pair does not resolve to a stored list.
    error ListAlreadyFinalized();
    error ListNotFinalized();
    error ListAlreadySigned();
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

    /**
     * Creates a new (empty) machine-path list for the given extension and returns its nonce.
     * The returned nonce is `getMachinePathListsCount(extensionId)` immediately after the call
     * (1-indexed within the extension; strictly increasing).
     * Emits MachinePathListStarted.
     * Can only be called by the extension owner.
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
     * Can only be called by the extension owner.
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
     * Can only be called by the extension owner.
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
     * its nonce exceeds the current active) once every involved governance has reached its threshold.
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
     * Returns true iff the (extensionId, nonce) list has reached its signing threshold across every
     * involved governance.
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
     * separately via `getMachinePathListSignatureCount`.
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
     * Returns the number of signatures collected so far that count toward a particular involved
     * governance on a given list. Useful for off-chain monitors tracking threshold progress.
     */
    function getMachinePathListSignatureCount(
        uint256 _extensionId,
        uint256 _nonce,
        bytes32 _governanceHash
    )
        external view
        returns (uint64);
}
