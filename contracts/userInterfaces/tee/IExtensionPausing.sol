// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { Signature } from "../ISignature.sol";
import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";

// Domain prefix for the per-extension TEE-pausing-addresses signed payload. See `SignedPayload`.
bytes32 constant TEE_PAUSING_ADDRESSES = bytes32("TEE_PAUSING_ADDRESSES");

/**
 * @title IExtensionPausing
 * @notice Public interface for the ExtensionPausingFacet.
 * @dev Owner posts a pausing-addresses record pinned to one or more governance configurations
 *      (by hash). Signers from those configurations sign the record's messageHash; each pinned
 *      hash maintains its own approval (signers + signatures + thresholdMet). An approval's
 *      thresholdMet flips the first time its signature count reaches its hash-specific threshold;
 *      TeePausingAddressesThresholdMet fires once per approval. Signature collection continues
 *      across all approvals independently of each other.
 */
interface IExtensionPausing is ITeeCommonErrors {

    event NewPausingAddressesSet(
        uint256 indexed extensionId,
        uint256 indexed nonce,
        bytes32[] governanceHashes,
        address[] pausingAddresses
    );

    event NewPausingAddressesSigned(
        uint256 indexed extensionId,
        uint256 indexed nonce,
        bytes32 indexed governanceHash,
        address signer,
        Signature signature
    );

    event TeePausingAddressesThresholdMet(
        uint256 indexed extensionId,
        uint256 indexed nonce,
        bytes32 indexed governanceHash
    );

    error NoGovernanceHashes();
    error DuplicateGovernanceHash();
    error PausingAddressAlreadyExists(address pausingAddress);
    error NotASigner(address signer);
    error AlreadySigned(address signer);
    error PausingAddressesNotSet();

    /**
     * Sets a new TEE pausing-addresses record pinned to a list of governance configurations.
     * Emits NewPausingAddressesSet.
     * @param _extensionId The id of the extension.
     * @param _governanceHashes The governance hashes that may approve this pausing-addresses set.
     *      Must be non-empty, contain no duplicates, and each must be a known governance hash
     *      (validated via ExtensionGovernance.isGovernanceHashValid).
     * @param _pausingAddresses The list of pausing addresses, can be empty.
     * Can only be called by the extension owner.
     */
    function setTeePausingAddresses(
        uint256 _extensionId,
        bytes32[] calldata _governanceHashes,
        address[] calldata _pausingAddresses
    )
        external;

    /**
     * Adds a signature to the pausing-addresses record at the given nonce. The signature is
     * recorded against every pinned governance hash under which the recovered signer is valid;
     * a single call may contribute to multiple approvals. Reverts if the signer is not valid
     * under any pinned hash.
     * Emits NewPausingAddressesSigned for each matching approval, and
     * TeePausingAddressesThresholdMet the first time any approval reaches its hash-specific
     * threshold.
     * @param _extensionId The id of the extension.
     * @param _nonce The nonce of the pausing-addresses record.
     * @param _signature The signature of the record's messageHash.
     */
    function signTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce,
        Signature calldata _signature
    )
        external;

    /**
     * Returns the pausing-addresses record at the given nonce.
     * @param _extensionId The id of the extension.
     * @param _nonce The nonce.
     * @return _pausingAddresses The pausing addresses.
     * @return _governanceHashes The pinned governance hashes (order preserved).
     * @return _signaturesPerHash Signatures collected against each pinned hash; same outer
     *      length as _governanceHashes.
     * @return _thresholdMetPerHash Per-approval thresholdMet flags; same outer length as
     *      _governanceHashes.
     */
    function getTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce
    )
        external view
        returns (
            address[] memory _pausingAddresses,
            bytes32[] memory _governanceHashes,
            Signature[][] memory _signaturesPerHash,
            bool[] memory _thresholdMetPerHash
        );

    /**
     * Returns the latest pausing-addresses record.
     * @param _extensionId The id of the extension.
     * @return _nonce The nonce of the latest record.
     * @return _pausingAddresses The pausing addresses.
     * @return _governanceHashes The pinned governance hashes.
     * @return _signaturesPerHash Signatures collected per pinned hash.
     * @return _thresholdMetPerHash Per-approval thresholdMet flags.
     */
    function getLatestTeePausingAddresses(
        uint256 _extensionId
    )
        external view
        returns (
            uint256 _nonce,
            address[] memory _pausingAddresses,
            bytes32[] memory _governanceHashes,
            Signature[][] memory _signaturesPerHash,
            bool[] memory _thresholdMetPerHash
        );

    /**
     * Returns true if the given signer has signed the record under the given governance hash.
     * @param _extensionId The id of the extension.
     * @param _nonce The nonce of the record.
     * @param _governanceHash The pinned governance hash to scope the query to.
     * @param _signer The signer address to check.
     */
    function hasSignedTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce,
        bytes32 _governanceHash,
        address _signer
    )
        external view
        returns (bool);
}
