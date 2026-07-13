// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IOwnerAllowlist } from "../../userInterfaces/tee/IOwnerAllowlist.sol";
import { OwnerAllowlist } from "../library/OwnerAllowlist.sol";
import { ExtensionManager } from "../library/ExtensionManager.sol";
import { FlareGovernedAccess } from "../../governance/implementation/FlareGovernedAccess.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title OwnerAllowlistFacet
 * @notice Facet for managing the global extension-owner allowlist (governance-gated)
 *         and the per-extension TEE machine owner / wallet project owner allowlists
 *         (extension-owner-gated).
 */
contract OwnerAllowlistFacet is IOwnerAllowlist, FlareGovernedAccess {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IOwnerAllowlist
    function addAllowedExtensionOwners(
        address[] calldata _owners
    )
        external
        onlyGovernance
    {
        require(_owners.length > 0, NoAddresses());
        OwnerAllowlist.State storage s = OwnerAllowlist.getState();
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), InvalidAddress());
            require(s.allowedExtensionOwners.add(_owners[i]), AddressAlreadyInSet(_owners[i]));
        }
        emit AllowedExtensionOwnersAdded(_owners);
    }

    /// @inheritdoc IOwnerAllowlist
    function removeAllowedExtensionOwners(
        address[] calldata _owners
    )
        external
        onlyImmediateGovernance
    {
        require(_owners.length > 0, NoAddresses());
        OwnerAllowlist.State storage s = OwnerAllowlist.getState();
        for (uint256 i = 0; i < _owners.length; i++) {
            require(s.allowedExtensionOwners.remove(_owners[i]), AddressNotInSet(_owners[i]));
        }
        emit AllowedExtensionOwnersRemoved(_owners);
    }

    /// @inheritdoc IOwnerAllowlist
    function allowAllExtensionOwners()
        external
        onlyGovernance
    {
        OwnerAllowlist.setAllExtensionOwnersAllowed(true);
    }

    /// @inheritdoc IOwnerAllowlist
    function disallowAllExtensionOwners()
        external
        onlyImmediateGovernance
    {
        OwnerAllowlist.setAllExtensionOwnersAllowed(false);
    }

    /// @inheritdoc IOwnerAllowlist
    function addAllowedTeeMachineOwners(
        uint256 _extensionId,
        address[] calldata _owners
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        require(_owners.length > 0, NoAddresses());
        OwnerAllowlist.State storage s = OwnerAllowlist.getState();
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), InvalidAddress());
            require(
                s.allowedTeeMachineOwners[_extensionId].add(_owners[i]),
                AddressAlreadyInSet(_owners[i])
            );
        }
        emit AllowedTeeMachineOwnersAdded(_extensionId, _owners);
    }

    /// @inheritdoc IOwnerAllowlist
    function removeAllowedTeeMachineOwners(
        uint256 _extensionId,
        address[] calldata _owners
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        require(_owners.length > 0, NoAddresses());
        OwnerAllowlist.State storage s = OwnerAllowlist.getState();
        for (uint256 i = 0; i < _owners.length; i++) {
            require(
                s.allowedTeeMachineOwners[_extensionId].remove(_owners[i]),
                AddressNotInSet(_owners[i])
            );
        }
        emit AllowedTeeMachineOwnersRemoved(_extensionId, _owners);
    }

    /// @inheritdoc IOwnerAllowlist
    function addAllowedTeeWalletProjectOwners(
        uint256 _extensionId,
        address[] calldata _owners
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        require(_owners.length > 0, NoAddresses());
        OwnerAllowlist.State storage s = OwnerAllowlist.getState();
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), InvalidAddress());
            require(
                s.allowedTeeWalletProjectOwners[_extensionId].add(_owners[i]),
                AddressAlreadyInSet(_owners[i])
            );
        }
        emit AllowedTeeWalletProjectOwnersAdded(_extensionId, _owners);
    }

    /// @inheritdoc IOwnerAllowlist
    function removeAllowedTeeWalletProjectOwners(
        uint256 _extensionId,
        address[] calldata _owners
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        require(_owners.length > 0, NoAddresses());
        OwnerAllowlist.State storage s = OwnerAllowlist.getState();
        for (uint256 i = 0; i < _owners.length; i++) {
            require(
                s.allowedTeeWalletProjectOwners[_extensionId].remove(_owners[i]),
                AddressNotInSet(_owners[i])
            );
        }
        emit AllowedTeeWalletProjectOwnersRemoved(_extensionId, _owners);
    }

    /// @inheritdoc IOwnerAllowlist
    function allowAllTeeMachineOwners(
        uint256 _extensionId
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        OwnerAllowlist.getState().allTeeMachineOwnersAllowed[_extensionId] = true;
        emit AllTeeMachineOwnersAllowed(_extensionId);
    }

    /// @inheritdoc IOwnerAllowlist
    function disallowAllTeeMachineOwners(
        uint256 _extensionId
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        OwnerAllowlist.getState().allTeeMachineOwnersAllowed[_extensionId] = false;
        emit AllTeeMachineOwnersDisallowed(_extensionId);
    }

    /// @inheritdoc IOwnerAllowlist
    function allowAllTeeWalletProjectOwners(
        uint256 _extensionId
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        OwnerAllowlist.getState().allTeeWalletProjectOwnersAllowed[_extensionId] = true;
        emit AllTeeWalletProjectOwnersAllowed(_extensionId);
    }

    /// @inheritdoc IOwnerAllowlist
    function disallowAllTeeWalletProjectOwners(
        uint256 _extensionId
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        OwnerAllowlist.getState().allTeeWalletProjectOwnersAllowed[_extensionId] = false;
        emit AllTeeWalletProjectOwnersDisallowed(_extensionId);
    }

    /// @inheritdoc IOwnerAllowlist
    function getAllowedExtensionOwners()
        external view
        returns (address[] memory _allowedOwners)
    {
        return OwnerAllowlist.getState().allowedExtensionOwners.values();
    }

    /// @inheritdoc IOwnerAllowlist
    function isAllowedExtensionOwner(
        address _owner
    )
        external view
        returns (bool _isAllowed)
    {
        return OwnerAllowlist.isAllowedExtensionOwner(_owner);
    }

    /// @inheritdoc IOwnerAllowlist
    function allExtensionOwnersAllowed()
        external view
        returns (bool _allAllowed)
    {
        return OwnerAllowlist.getState().allExtensionOwnersAllowed;
    }

    /// @inheritdoc IOwnerAllowlist
    function allTeeMachineOwnersAllowed(
        uint256 _extensionId
    )
        external view
        returns (bool _allAllowed)
    {
        return OwnerAllowlist.getState().allTeeMachineOwnersAllowed[_extensionId];
    }

    /// @inheritdoc IOwnerAllowlist
    function allTeeWalletProjectOwnersAllowed(
        uint256 _extensionId
    )
        external view
        returns (bool _allAllowed)
    {
        return OwnerAllowlist.getState().allTeeWalletProjectOwnersAllowed[_extensionId];
    }

    /// @inheritdoc IOwnerAllowlist
    function getAllowedTeeMachineOwners(
        uint256 _extensionId
    )
        external view
        returns (address[] memory _allowedOwners)
    {
        return OwnerAllowlist.getState().allowedTeeMachineOwners[_extensionId].values();
    }

    /// @inheritdoc IOwnerAllowlist
    function getAllowedTeeWalletProjectOwners(
        uint256 _extensionId
    )
        external view
        returns (address[] memory _allowedOwners)
    {
        return OwnerAllowlist.getState().allowedTeeWalletProjectOwners[_extensionId].values();
    }

    /// @inheritdoc IOwnerAllowlist
    function isAllowedTeeMachineOwner(
        uint256 _extensionId,
        address _owner
    )
        external view
        returns (bool _isAllowed)
    {
        return OwnerAllowlist.isAllowedTeeMachineOwner(_extensionId, _owner);
    }

    /// @inheritdoc IOwnerAllowlist
    function isAllowedTeeWalletProjectOwner(
        uint256 _extensionId,
        address _owner
    )
        external view
        returns (bool _isAllowed)
    {
        return OwnerAllowlist.isAllowedTeeWalletProjectOwner(_extensionId, _owner);
    }
}
