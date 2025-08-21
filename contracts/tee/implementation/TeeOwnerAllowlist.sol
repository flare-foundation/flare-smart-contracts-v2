// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeBase } from "./TeeBase.sol";
import { ITeeOwnerAllowlist } from "../../userInterfaces/tee/ITeeOwnerAllowlist.sol";
import { ITeeExtensionRegistry } from "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import { AddressSet } from "../../utils/lib/AddressSet.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";

/**
 * TeeOwnerAllowlist is used for allowlisting TEE machine owners and TEE wallet project owners.
 */
contract TeeOwnerAllowlist is ITeeOwnerAllowlist, TeeBase  {
    using AddressSet for AddressSet.State;

    mapping(uint256 extensionId => AddressSet.State) private allowedTeeMachineOwners;
    mapping(uint256 extensionId => AddressSet.State) private allowedTeeWalletProjectOwners;

    mapping(uint256 extensionId => bool) public allTeeMachineOwnersAllowed;
    mapping(uint256 extensionId => bool) public allTeeWalletProjectOwnersAllowed;

    ITeeExtensionRegistry public teeExtensionRegistry;

    modifier onlyExtensionOwner(uint256 _extensionId) {
        require(
            msg.sender == teeExtensionRegistry.getExtensionOwner(_extensionId),
            OnlyExtensionOwner()
        );
        _;
    }

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() TeeBase() { }

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        external
    {
        TeeBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
    }

    /**
     * @inheritdoc ITeeOwnerAllowlist
     */
    function addAllowedTeeMachineOwners(
        uint256 _extensionId,
        address[] memory _owners
    )
        external onlyExtensionOwner(_extensionId)
    {
        allowedTeeMachineOwners[_extensionId].addAll(_owners);
        emit AllowedTeeMachineOwnersAdded(_extensionId, _owners);
    }

    /**
     * @inheritdoc ITeeOwnerAllowlist
     */
    function addAllowedTeeWalletProjectOwners(
        uint256 _extensionId,
        address[] memory _owners
    )
        external onlyExtensionOwner(_extensionId)
    {
        allowedTeeWalletProjectOwners[_extensionId].addAll(_owners);
        emit AllowedTeeWalletProjectOwnersAdded(_extensionId, _owners);
    }

    /**
     * @inheritdoc ITeeOwnerAllowlist
     */
    function allowAllTeeMachineOwners(
        uint256 _extensionId
    )
        external onlyExtensionOwner(_extensionId)
    {
        allTeeMachineOwnersAllowed[_extensionId] = true;
        emit AllTeeMachineOwnersAllowed(_extensionId);
    }

    /**
     * @inheritdoc ITeeOwnerAllowlist
     */
    function allowAllTeeWalletProjectOwners(
        uint256 _extensionId
    )
        external onlyExtensionOwner(_extensionId)
    {
        allTeeWalletProjectOwnersAllowed[_extensionId] = true;
        emit AllTeeWalletProjectOwnersAllowed(_extensionId);
    }

    /**
     * @inheritdoc ITeeOwnerAllowlist
     */
    function getAllowedTeeMachineOwners(uint256 _extensionId)
        external view
        returns (address[] memory)
    {
        return allowedTeeMachineOwners[_extensionId].list;
    }

    /**
     * @inheritdoc ITeeOwnerAllowlist
     */
    function getAllowedTeeWalletProjectOwners(uint256 _extensionId)
        external view
        returns (address[] memory)
    {
        return allowedTeeWalletProjectOwners[_extensionId].list;
    }

    /**
     * @inheritdoc ITeeOwnerAllowlist
     */
    function isAllowedTeeMachineOwner(
        uint256 _extensionId,
        address _owner
    )
        external view
        returns (bool _isAllowed)
    {
        return allTeeMachineOwnersAllowed[_extensionId] || allowedTeeMachineOwners[_extensionId].index[_owner] != 0;
    }

    /**
     * @inheritdoc ITeeOwnerAllowlist
     */
    function isAllowedTeeWalletProjectOwner(
        uint256 _extensionId,
        address _owner
    )
        external view
        returns (bool _isAllowed)
    {
        return allTeeWalletProjectOwnersAllowed[_extensionId] ||
            allowedTeeWalletProjectOwners[_extensionId].index[_owner] != 0;
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        teeExtensionRegistry = ITeeExtensionRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeExtensionRegistry"));
    }
}
