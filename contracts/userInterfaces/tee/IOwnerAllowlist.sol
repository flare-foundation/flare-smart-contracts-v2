// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";

/**
 * @title IOwnerAllowlist
 * @notice Public interface for the OwnerAllowlistFacet.
 * @dev The per-extension machine-owner and wallet-project-owner methods are
 *      callable by the extension owner. The global extension-owner methods
 *      (add/remove/allow-all/disallow-all on ExtensionOwners) are callable by
 *      the Flare governance address only.
 */
interface IOwnerAllowlist is ITeeCommonErrors {

    event AllowedExtensionOwnersAdded(address[] owners);
    event AllowedExtensionOwnersRemoved(address[] owners);
    event AllExtensionOwnersAllowed();
    event AllExtensionOwnersDisallowed();
    event AllowedTeeMachineOwnersAdded(uint256 extensionId, address[] owners);
    event AllowedTeeMachineOwnersRemoved(uint256 extensionId, address[] owners);
    event AllowedTeeWalletProjectOwnersAdded(uint256 extensionId, address[] owners);
    event AllowedTeeWalletProjectOwnersRemoved(uint256 extensionId, address[] owners);
    event AllTeeMachineOwnersAllowed(uint256 extensionId);
    event AllTeeMachineOwnersDisallowed(uint256 extensionId);
    event AllTeeWalletProjectOwnersAllowed(uint256 extensionId);
    event AllTeeWalletProjectOwnersDisallowed(uint256 extensionId);

    error InvalidOwner();
    error OwnerAlreadyAllowed(address owner);
    error OwnerNotInAllowlist(address owner);

    /**
     * Adds a list of allowed extension owners to the global allowlist.
     * Addresses on this list (or any address when allExtensionOwnersAllowed is
     * true) may call IExtensionManager.register() and become the proposed/new
     * owner of a public extension.
     * Emits AllowedExtensionOwnersAdded event.
     * @param _owners The list of addresses to add to the allowlist.
     * Can only be called by the Flare governance address.
     */
    function addAllowedExtensionOwners(
        address[] memory _owners
    )
        external;

    /**
     * Removes a list of allowed extension owners from the global allowlist.
     * Emits AllowedExtensionOwnersRemoved event.
     * @param _owners The list of addresses to remove from the allowlist.
     * Can only be called by the Flare governance address.
     */
    function removeAllowedExtensionOwners(
        address[] memory _owners
    )
        external;

    /**
     * Opens public extension creation to any caller (the allowlist is
     * bypassed while this flag is true).
     * Emits AllExtensionOwnersAllowed event.
     * Can only be called by the Flare governance address.
     */
    function allowAllExtensionOwners()
        external;

    /**
     * Re-enables the global extension-owner allowlist (the allowlist is no
     * longer bypassed).
     * Emits AllExtensionOwnersDisallowed event.
     * Can only be called by the Flare governance address.
     */
    function disallowAllExtensionOwners()
        external;

    /**
     * Adds a list of allowed TEE machine owners on the specified extension.
     * Emits AllowedTeeMachineOwnersAdded event.
     * @param _extensionId The id of the extension.
     * @param _owners The list of addresses to add to the allowlist.
     * Can only be called by the extension owner.
     */
    function addAllowedTeeMachineOwners(
        uint256 _extensionId,
        address[] memory _owners
    )
        external;

    /**
     * Removes a list of allowed TEE machine owners on the specified extension.
     * Emits AllowedTeeMachineOwnersRemoved event.
     * @param _extensionId The id of the extension.
     * @param _owners The list of addresses to remove from the allowlist.
     * Can only be called by the extension owner.
     */
    function removeAllowedTeeMachineOwners(
        uint256 _extensionId,
        address[] memory _owners
    )
        external;

    /**
     * Adds a list of allowed TEE wallet project owners on the specified extension.
     * Emits AllowedTeeWalletProjectOwnersAdded event.
     * @param _extensionId The id of the extension.
     * @param _owners The list of addresses to add to the allowlist.
     * Can only be called by the extension owner.
     */
    function addAllowedTeeWalletProjectOwners(
        uint256 _extensionId,
        address[] memory _owners
    )
        external;

    /**
     * Removes a list of allowed TEE wallet project owners on the specified extension.
     * Emits AllowedTeeWalletProjectOwnersRemoved event.
     * @param _extensionId The id of the extension.
     * @param _owners The list of addresses to remove from the allowlist.
     * Can only be called by the extension owner.
     */
    function removeAllowedTeeWalletProjectOwners(
        uint256 _extensionId,
        address[] memory _owners
    )
        external;

    /**
     * Allows all addresses to be TEE machine owners on the specified extension.
     * Emits AllTeeMachineOwnersAllowed event.
     * @param _extensionId The id of the extension.
     * Can only be called by the extension owner.
     */
    function allowAllTeeMachineOwners(
        uint256 _extensionId
    )
        external;

    /**
     * Disallows all addresses to be TEE machine owners on the specified extension.
     * Emits AllTeeMachineOwnersDisallowed event.
     * @param _extensionId The id of the extension.
     * Can only be called by the extension owner.
     */
    function disallowAllTeeMachineOwners(
        uint256 _extensionId
    )
        external;

    /**
     * Allows all addresses to be TEE wallet project owners on the specified extension.
     * Emits AllTeeWalletProjectOwnersAllowed event.
     * @param _extensionId The id of the extension.
     * Can only be called by the extension owner.
     */
    function allowAllTeeWalletProjectOwners(
        uint256 _extensionId
    )
        external;

    /**
     * Disallows all addresses to be TEE wallet project owners on the specified extension.
     * Emits AllTeeWalletProjectOwnersDisallowed event.
     * @param _extensionId The id of the extension.
     * Can only be called by the extension owner.
     */
    function disallowAllTeeWalletProjectOwners(
        uint256 _extensionId
    )
        external;

    /**
     * Returns the list of allowed extension owners (global allowlist).
     * @return _allowedOwners The list of allowed extension owners.
     */
    function getAllowedExtensionOwners()
        external view
        returns (address[] memory _allowedOwners);

    /**
     * Returns true if `_owner` is allowed to become a public extension owner.
     * @param _owner The address to check.
     * @return _isAllowed True if `_owner` is on the allowlist or
     *         allExtensionOwnersAllowed is true.
     */
    function isAllowedExtensionOwner(
        address _owner
    )
        external view
        returns (bool _isAllowed);

    /**
     * Returns true if the global extension-owner allowlist is bypassed (any
     * address can become a public extension owner).
     * @return _allAllowed True if the allowlist is bypassed.
     */
    function allExtensionOwnersAllowed()
        external view
        returns (bool _allAllowed);

    /**
     * Returns the list of allowed TEE machine owners on the specified extension.
     * @param _extensionId The id of the extension.
     * @return _allowedOwners The list of allowed TEE machine owners.
     */
    function getAllowedTeeMachineOwners(
        uint256 _extensionId
    )
        external view
        returns (address[] memory _allowedOwners);

    /**
     * Returns the list of allowed TEE wallet project owners on the specified extension.
     * @param _extensionId The id of the extension.
     * @return _allowedOwners The list of allowed TEE wallet project owners.
     */
    function getAllowedTeeWalletProjectOwners(
        uint256 _extensionId
    )
        external view
        returns (address[] memory _allowedOwners);

    /**
     * Returns true if the owner is allowed to own a TEE machine on the specified extension.
     * @param _extensionId The id of the extension.
     * @param _owner The address of the owner.
     * @return _isAllowed True if the owner is allowed, false otherwise.
     */
    function isAllowedTeeMachineOwner(
        uint256 _extensionId,
        address _owner
    )
        external view
        returns (bool _isAllowed);

    /**
     * Returns true if the owner is allowed to own a TEE wallet project on the specified extension.
     * @param _extensionId The id of the extension.
     * @param _owner The address of the owner.
     * @return _isAllowed True if the owner is allowed, false otherwise.
     */
    function isAllowedTeeWalletProjectOwner(
        uint256 _extensionId,
        address _owner
    )
        external view
        returns (bool _isAllowed);

    /**
     * Returns true if all addresses are allowed to own a TEE machine on the specified extension.
     * @param _extensionId The id of the extension.
     * @return _allAllowed True if all addresses are allowed, false otherwise.
     */
    function allTeeMachineOwnersAllowed(
        uint256 _extensionId
    )
        external view
        returns (bool _allAllowed);

    /**
     * Returns true if all addresses are allowed to own a TEE wallet project on the specified extension.
     * @param _extensionId The id of the extension.
     * @return _allAllowed True if all addresses are allowed, false otherwise.
     */
    function allTeeWalletProjectOwnersAllowed(
        uint256 _extensionId
    )
        external view
        returns (bool _allAllowed);
}
