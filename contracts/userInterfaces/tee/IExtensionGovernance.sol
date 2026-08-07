// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";

/**
 * @title IExtensionGovernance
 * @notice Public interface for the ExtensionGovernanceFacet.
 * @dev Manages per-extension TEE governance configurations: signer sets and thresholds
 *      identified by a content-derived `governanceHash`. Once a hash has been recorded, its
 *      signers and threshold are immutable; re-calling setNewTeeGovernance with the same
 *      (signers, threshold) tuple only updates the latest-hash pointer.
 *
 *      Two governance flavors exist, discriminated by the `_safe` value returned from the getters:
 *      - plain (`setNewTeeGovernance`): caller-supplied signer set;
 *        `governanceHash = keccak256(abi.encode(signers, threshold))`, `safe == address(0)`.
 *      - Safe-backed (`setNewTeeGovernanceSafe`): signer set snapshotted live from a Safe multisig;
 *        `governanceHash = keccak256(abi.encode(teeManager, safe, owners, threshold))`,
 *        where `teeManager` is the FlareTeeManager diamond address. The Safe itself approves machine
 *        path lists via `IMachinePathManager.approveMachinePathList`.
 *      The preimage shapes cannot collide: the plain preimage begins with the ABI array-offset
 *      word (0x40), the Safe-backed one with the diamond address. A future preimage change would
 *      introduce a versioned domain tag as its first word.
 */
interface IExtensionGovernance is ITeeCommonErrors {

    event NewTeeGovernanceSet(
        uint256 indexed extensionId,
        bytes32 indexed governanceHash,
        address[] signers,
        uint64 signersThreshold
    );

    event NewTeeSafeGovernanceSet(
        uint256 indexed extensionId,
        bytes32 indexed governanceHash,
        address safe,
        address[] signers,
        uint64 signersThreshold
    );

    error NoSigners();
    error SignerAlreadyExists(address signer);
    error InvalidSigner();
    error SafeDomainSeparatorMismatch();

    /**
     * Sets new TEE governance for the extension.
     * Emits NewTeeGovernanceSet.
     * @param _extensionId The id of the extension.
     * @param _signers The governance signers. Must be non-empty and contain no `address(0)`
     *      entries; each address must be unique.
     * @param _signersThreshold The governance signers threshold. Must satisfy
     *      0 < threshold <= signers.length.
     * Can only be called by the extension owner.
     */
    function setNewTeeGovernance(
        uint256 _extensionId,
        address[] calldata _signers,
        uint64 _signersThreshold
    )
        external;

    /**
     * Sets new Safe-backed TEE governance for the extension. The signer set and threshold are read
     * live from the Safe contract (`getOwners()` / `getThreshold()`), so they are chain-attested at
     * registration time rather than caller-supplied. The resulting governance hash commits to every
     * anchor an off-chain verifier needs:
     * `keccak256(abi.encode(address(teeManager), _safe, owners, threshold))`.
     * The owners are stored as an ordinary signer set, so they may also sign machine path lists
     * individually via `IMachinePathManager.signMachinePathList`; the Safe itself approves lists
     * via `IMachinePathManager.approveMachinePathList`.
     * Re-calling with a Safe whose (owners, threshold) snapshot was already recorded only re-points
     * the latest-hash pointer, mirroring `setNewTeeGovernance`. After the Safe rotates owners or
     * changes its threshold, call this again to register the new snapshot (new hash) and re-register
     * machines to bind it.
     *
     * The Safe's `domainSeparator()` must equal the Safe >= 1.3.0 formula
     * (`keccak256(abi.encode(typeHash, block.chainid, safe))`) — `SafeDomainSeparatorMismatch`
     * otherwise. `IMachinePathManager.confirmMachinePathListSafeApproval` and TEE nodes
     * reconstruct SafeTxHashes under exactly this domain, so an incompatible wallet fails fast at
     * registration instead of producing approvals that can never be confirmed. The owners should
     * be EOAs: a contract owner can produce neither the ECDSA signature chunk the confirmation
     * verifies nor an EIP-191 signature for `signMachinePathList` (not enforceable on-chain — a
     * registration-time code check would miss owners that become contracts later).
     * Emits NewTeeSafeGovernanceSet.
     * @param _extensionId The id of the extension.
     * @param _safe The Safe multisig contract (version >= 1.3.0). Its owners must be non-empty,
     *      unique and non-zero, and its threshold must satisfy 0 < threshold <= owners.length (a
     *      genuine Safe guarantees all of this; it is validated defensively since the address is
     *      only claimed to be a Safe).
     * Can only be called by the extension owner.
     */
    function setNewTeeGovernanceSafe(
        uint256 _extensionId,
        address _safe
    )
        external;

    /**
     * Returns the governance hash of the latest TEE governance.
     * @param _extensionId The id of the extension.
     */
    function getLatestTeeGovernanceHash(
        uint256 _extensionId
    )
        external view
        returns (bytes32);

    /**
     * Returns the TEE governance threshold for the given governance hash.
     * @param _extensionId The id of the extension.
     * @param _governanceHash The governance hash.
     * @return The TEE governance threshold.
     */
    function getTeeGovernanceThreshold(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns (uint64);

    /**
     * Returns true if the given address is a TEE governance signer for the given governance hash.
     * @param _extensionId The id of the extension.
     * @param _governanceHash The governance hash.
     * @param _signer The address to check.
     * @return True if the address is a TEE governance signer, false otherwise.
     */
    function isTeeGovernanceSigner(
        uint256 _extensionId,
        bytes32 _governanceHash,
        address _signer
    )
        external view
        returns (bool);

    /**
     * Returns the governance for the given governance hash.
     * @param _extensionId The id of the extension.
     * @param _governanceHash The governance hash.
     * @return _signers The governance signers (the Safe owners' snapshot for Safe-backed governance).
     * @return _signersThreshold The governance signers threshold.
     * @return _safe The Safe address for Safe-backed governance, `address(0)` for plain governance.
     */
    function getTeeGovernance(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns (
            address[] memory _signers,
            uint64 _signersThreshold,
            address _safe
        );

    /**
     * Returns the latest governance.
     * @param _extensionId The id of the extension.
     * @return _signers The latest governance signers (the Safe owners' snapshot for Safe-backed
     *      governance).
     * @return _signersThreshold The latest governance signers threshold.
     * @return _safe The Safe address for Safe-backed governance, `address(0)` for plain governance.
     */
    function getLatestTeeGovernance(
        uint256 _extensionId
    )
        external view
        returns (
            address[] memory _signers,
            uint64 _signersThreshold,
            address _safe
        );

    /**
     * Checks if the governance hash is valid (i.e. has been recorded for this extension).
     * @param _extensionId The id of the extension.
     * @param _governanceHash The governance hash.
     * @return True if the governance hash is valid, false otherwise.
     */
    function isGovernanceHashValid(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns (bool);
}
