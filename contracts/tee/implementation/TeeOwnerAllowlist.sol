// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeBase } from "./TeeBase.sol";
import { ITeeOwnerAllowlist } from "../../userInterfaces/tee/ITeeOwnerAllowlist.sol";
import { ITeeExtensionRegistry } from "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";

/**
 * TeeOwnerAllowlist is used for allowlisting TEE machine owners and TEE wallet project owners.
 */
contract TeeOwnerAllowlist is ITeeOwnerAllowlist, TeeBase  {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(uint256 extensionId => EnumerableSet.AddressSet) private allowedTeeMachineOwners;
    mapping(uint256 extensionId => EnumerableSet.AddressSet) private allowedTeeWalletProjectOwners;

    mapping(uint256 extensionId => bool) public allTeeMachineOwnersAllowed;
    mapping(uint256 extensionId => bool) public allTeeWalletProjectOwnersAllowed;

    /// TeeExtensionRegistry contract.
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
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), InvalidOwner());
            require(allowedTeeMachineOwners[_extensionId].add(_owners[i]), OwnerAlreadyAllowed(_owners[i]));
        }
        emit AllowedTeeMachineOwnersAdded(_extensionId, _owners);
    }

    /**
     * @inheritdoc ITeeOwnerAllowlist
     */
    function removeAllowedTeeMachineOwners(
        uint256 _extensionId,
        address[] memory _owners
    )
        external onlyExtensionOwner(_extensionId)
    {
        for (uint256 i = 0; i < _owners.length; i++) {
            require(allowedTeeMachineOwners[_extensionId].remove(_owners[i]), OwnerNotAllowed(_owners[i]));
        }
        emit AllowedTeeMachineOwnersRemoved(_extensionId, _owners);
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
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), InvalidOwner());
            require(allowedTeeWalletProjectOwners[_extensionId].add(_owners[i]), OwnerAlreadyAllowed(_owners[i]));
        }
        emit AllowedTeeWalletProjectOwnersAdded(_extensionId, _owners);
    }

    /**
     * @inheritdoc ITeeOwnerAllowlist
     */
    function removeAllowedTeeWalletProjectOwners(
        uint256 _extensionId,
        address[] memory _owners
    )
        external onlyExtensionOwner(_extensionId)
    {
        for (uint256 i = 0; i < _owners.length; i++) {
            require(allowedTeeWalletProjectOwners[_extensionId].remove(_owners[i]), OwnerNotAllowed(_owners[i]));
        }
        emit AllowedTeeWalletProjectOwnersRemoved(_extensionId, _owners);
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
    function disallowAllTeeMachineOwners(
        uint256 _extensionId
    )
        external onlyExtensionOwner(_extensionId)
    {
        allTeeMachineOwnersAllowed[_extensionId] = false;
        emit AllTeeMachineOwnersDisallowed(_extensionId);
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
    function disallowAllTeeWalletProjectOwners(
        uint256 _extensionId
    )
        external onlyExtensionOwner(_extensionId)
    {
        allTeeWalletProjectOwnersAllowed[_extensionId] = false;
        emit AllTeeWalletProjectOwnersDisallowed(_extensionId);
    }

    /**
     * @inheritdoc ITeeOwnerAllowlist
     */
    function getAllowedTeeMachineOwners(uint256 _extensionId)
        external view
        returns (address[] memory)
    {
        return allowedTeeMachineOwners[_extensionId].values();
    }

    /**
     * @inheritdoc ITeeOwnerAllowlist
     */
    function getAllowedTeeWalletProjectOwners(uint256 _extensionId)
        external view
        returns (address[] memory)
    {
        return allowedTeeWalletProjectOwners[_extensionId].values();
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
        return allTeeMachineOwnersAllowed[_extensionId] ||
            allowedTeeMachineOwners[_extensionId].contains(_owner);
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
            allowedTeeWalletProjectOwners[_extensionId].contains(_owner);
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
