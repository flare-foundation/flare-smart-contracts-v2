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
 */
interface IExtensionGovernance is ITeeCommonErrors {

    event NewTeeGovernanceSet(
        uint256 indexed extensionId,
        bytes32 indexed governanceHash,
        address[] signers,
        uint64 signersThreshold
    );

    error NoSigners();
    error SignerAlreadyExists(address signer);
    error InvalidSigner();

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
     * @return _signers The governance signers.
     * @return _signersThreshold The governance signers threshold.
     */
    function getTeeGovernance(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns (
            address[] memory _signers,
            uint64 _signersThreshold
        );

    /**
     * Returns the latest governance.
     * @param _extensionId The id of the extension.
     * @return _signers The latest governance signers.
     * @return _signersThreshold The latest governance signers threshold.
     */
    function getLatestTeeGovernance(
        uint256 _extensionId
    )
        external view
        returns (
            address[] memory _signers,
            uint64 _signersThreshold
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
