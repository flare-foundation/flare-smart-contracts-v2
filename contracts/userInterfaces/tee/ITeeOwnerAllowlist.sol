// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TeeOwnerAllowlist interface.
 */
interface ITeeOwnerAllowlist {

    event AllowedTeeMachineOwnersAdded(uint256 extensionId, address[] owners);
    event AllowedTeeWalletProjectOwnersAdded(uint256 extensionId, address[] owners);
    event AllTeeMachineOwnersAllowed(uint256 extensionId);
    event AllTeeWalletProjectOwnersAllowed(uint256 extensionId);

    error OnlyExtensionOwner();

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
     * Returns true if all addresses are allowed to own a TEE machine on the specified extension.
     * @param _extensionId The id of the extension.
     * @return _allAllowed True if all addresses are allowed, false otherwise.
     */
    function allTeeMachineOwnersAllowed(uint256 _extensionId)
        external view
        returns (bool _allAllowed);

    /**
     * Returns true if all addresses are allowed to own a TEE wallet project on the specified extension.
     * @param _extensionId The id of the extension.
     * @return _allAllowed True if all addresses are allowed, false otherwise.
     */
    function allTeeWalletProjectOwnersAllowed(uint256 _extensionId)
        external view
        returns (bool _allAllowed);

    /**
     * Returns the list of allowed TEE machine owners on the specified extension.
     * @param _extensionId The id of the extension.
     * @return _allowedOwners The list of allowed TEE machine owners.
     */
    function getAllowedTeeMachineOwners(uint256 _extensionId)
        external view
        returns (address[] memory _allowedOwners);

    /**
     * Returns the list of allowed TEE wallet project owners on the specified extension.
     * @param _extensionId The id of the extension.
     * @return _allowedOwners The list of allowed TEE wallet project owners.
     */
    function getAllowedTeeWalletProjectOwners(uint256 _extensionId)
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

}