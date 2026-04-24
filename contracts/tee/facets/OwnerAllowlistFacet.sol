// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IOwnerAllowlist } from "../../userInterfaces/tee/IOwnerAllowlist.sol";
import { OwnerAllowlist } from "../library/OwnerAllowlist.sol";
import { ExtensionManager } from "../library/ExtensionManager.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title OwnerAllowlistFacet
 * @notice Facet for managing TEE machine owner and wallet project owner allowlists.
 */
contract OwnerAllowlistFacet is IOwnerAllowlist {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IOwnerAllowlist
    function addAllowedTeeMachineOwners(
        uint256 _extensionId,
        address[] memory _owners
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        OwnerAllowlist.State storage s = OwnerAllowlist.getState();
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), InvalidOwner());
            require(
                s.allowedTeeMachineOwners[_extensionId].add(_owners[i]),
                OwnerAlreadyAllowed(_owners[i])
            );
        }
        emit AllowedTeeMachineOwnersAdded(_extensionId, _owners);
    }

    /// @inheritdoc IOwnerAllowlist
    function removeAllowedTeeMachineOwners(
        uint256 _extensionId,
        address[] memory _owners
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        OwnerAllowlist.State storage s = OwnerAllowlist.getState();
        for (uint256 i = 0; i < _owners.length; i++) {
            require(
                s.allowedTeeMachineOwners[_extensionId].remove(_owners[i]),
                OwnerNotInAllowlist(_owners[i])
            );
        }
        emit AllowedTeeMachineOwnersRemoved(_extensionId, _owners);
    }

    /// @inheritdoc IOwnerAllowlist
    function addAllowedTeeWalletProjectOwners(
        uint256 _extensionId,
        address[] memory _owners
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        OwnerAllowlist.State storage s = OwnerAllowlist.getState();
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), InvalidOwner());
            require(
                s.allowedTeeWalletProjectOwners[_extensionId].add(_owners[i]),
                OwnerAlreadyAllowed(_owners[i])
            );
        }
        emit AllowedTeeWalletProjectOwnersAdded(_extensionId, _owners);
    }

    /// @inheritdoc IOwnerAllowlist
    function removeAllowedTeeWalletProjectOwners(
        uint256 _extensionId,
        address[] memory _owners
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        OwnerAllowlist.State storage s = OwnerAllowlist.getState();
        for (uint256 i = 0; i < _owners.length; i++) {
            require(
                s.allowedTeeWalletProjectOwners[_extensionId].remove(_owners[i]),
                OwnerNotInAllowlist(_owners[i])
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
