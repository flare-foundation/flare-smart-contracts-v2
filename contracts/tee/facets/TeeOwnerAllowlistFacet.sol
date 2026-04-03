// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeOwnerAllowlistFacet } from "../../userInterfaces/tee/ITeeOwnerAllowlistFacet.sol";
import { TeeOwnerAllowlist } from "../library/TeeOwnerAllowlist.sol";
import { TeeExtensionRegistry } from "../library/TeeExtensionRegistry.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title TeeOwnerAllowlistFacet
 * @notice Facet for managing TEE machine owner and wallet project owner allowlists.
 */
contract TeeOwnerAllowlistFacet is ITeeOwnerAllowlistFacet {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc ITeeOwnerAllowlistFacet
    function addAllowedTeeMachineOwners(
        uint256 _extensionId,
        address[] memory _owners
    )
        external
    {
        TeeExtensionRegistry.checkOnlyExtensionOwner(_extensionId);
        TeeOwnerAllowlist.State storage s = TeeOwnerAllowlist.getState();
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), InvalidOwner());
            require(
                s.allowedTeeMachineOwners[_extensionId].add(_owners[i]),
                OwnerAlreadyAllowed(_owners[i])
            );
        }
        emit AllowedTeeMachineOwnersAdded(_extensionId, _owners);
    }

    /// @inheritdoc ITeeOwnerAllowlistFacet
    function removeAllowedTeeMachineOwners(
        uint256 _extensionId,
        address[] memory _owners
    )
        external
    {
        TeeExtensionRegistry.checkOnlyExtensionOwner(_extensionId);
        TeeOwnerAllowlist.State storage s = TeeOwnerAllowlist.getState();
        for (uint256 i = 0; i < _owners.length; i++) {
            require(
                s.allowedTeeMachineOwners[_extensionId].remove(_owners[i]),
                OwnerNotInAllowlist(_owners[i])
            );
        }
        emit AllowedTeeMachineOwnersRemoved(_extensionId, _owners);
    }

    /// @inheritdoc ITeeOwnerAllowlistFacet
    function addAllowedTeeWalletProjectOwners(
        uint256 _extensionId,
        address[] memory _owners
    )
        external
    {
        TeeExtensionRegistry.checkOnlyExtensionOwner(_extensionId);
        TeeOwnerAllowlist.State storage s = TeeOwnerAllowlist.getState();
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), InvalidOwner());
            require(
                s.allowedTeeWalletProjectOwners[_extensionId].add(_owners[i]),
                OwnerAlreadyAllowed(_owners[i])
            );
        }
        emit AllowedTeeWalletProjectOwnersAdded(_extensionId, _owners);
    }

    /// @inheritdoc ITeeOwnerAllowlistFacet
    function removeAllowedTeeWalletProjectOwners(
        uint256 _extensionId,
        address[] memory _owners
    )
        external
    {
        TeeExtensionRegistry.checkOnlyExtensionOwner(_extensionId);
        TeeOwnerAllowlist.State storage s = TeeOwnerAllowlist.getState();
        for (uint256 i = 0; i < _owners.length; i++) {
            require(
                s.allowedTeeWalletProjectOwners[_extensionId].remove(_owners[i]),
                OwnerNotInAllowlist(_owners[i])
            );
        }
        emit AllowedTeeWalletProjectOwnersRemoved(_extensionId, _owners);
    }

    /// @inheritdoc ITeeOwnerAllowlistFacet
    function allowAllTeeMachineOwners(
        uint256 _extensionId
    )
        external
    {
        TeeExtensionRegistry.checkOnlyExtensionOwner(_extensionId);
        TeeOwnerAllowlist.getState().allTeeMachineOwnersAllowed[_extensionId] = true;
        emit AllTeeMachineOwnersAllowed(_extensionId);
    }

    /// @inheritdoc ITeeOwnerAllowlistFacet
    function disallowAllTeeMachineOwners(
        uint256 _extensionId
    )
        external
    {
        TeeExtensionRegistry.checkOnlyExtensionOwner(_extensionId);
        TeeOwnerAllowlist.getState().allTeeMachineOwnersAllowed[_extensionId] = false;
        emit AllTeeMachineOwnersDisallowed(_extensionId);
    }

    /// @inheritdoc ITeeOwnerAllowlistFacet
    function allowAllTeeWalletProjectOwners(
        uint256 _extensionId
    )
        external
    {
        TeeExtensionRegistry.checkOnlyExtensionOwner(_extensionId);
        TeeOwnerAllowlist.getState().allTeeWalletProjectOwnersAllowed[_extensionId] = true;
        emit AllTeeWalletProjectOwnersAllowed(_extensionId);
    }

    /// @inheritdoc ITeeOwnerAllowlistFacet
    function disallowAllTeeWalletProjectOwners(
        uint256 _extensionId
    )
        external
    {
        TeeExtensionRegistry.checkOnlyExtensionOwner(_extensionId);
        TeeOwnerAllowlist.getState().allTeeWalletProjectOwnersAllowed[_extensionId] = false;
        emit AllTeeWalletProjectOwnersDisallowed(_extensionId);
    }

    /// @inheritdoc ITeeOwnerAllowlistFacet
    function allTeeMachineOwnersAllowed(
        uint256 _extensionId
    )
        external view
        returns (bool _allAllowed)
    {
        return TeeOwnerAllowlist.getState().allTeeMachineOwnersAllowed[_extensionId];
    }

    /// @inheritdoc ITeeOwnerAllowlistFacet
    function allTeeWalletProjectOwnersAllowed(
        uint256 _extensionId
    )
        external view
        returns (bool _allAllowed)
    {
        return TeeOwnerAllowlist.getState().allTeeWalletProjectOwnersAllowed[_extensionId];
    }

    /// @inheritdoc ITeeOwnerAllowlistFacet
    function getAllowedTeeMachineOwners(
        uint256 _extensionId
    )
        external view
        returns (address[] memory _allowedOwners)
    {
        return TeeOwnerAllowlist.getState().allowedTeeMachineOwners[_extensionId].values();
    }

    /// @inheritdoc ITeeOwnerAllowlistFacet
    function getAllowedTeeWalletProjectOwners(
        uint256 _extensionId
    )
        external view
        returns (address[] memory _allowedOwners)
    {
        return TeeOwnerAllowlist.getState().allowedTeeWalletProjectOwners[_extensionId].values();
    }

    /// @inheritdoc ITeeOwnerAllowlistFacet
    function isAllowedTeeMachineOwner(
        uint256 _extensionId,
        address _owner
    )
        external view
        returns (bool _isAllowed)
    {
        return TeeOwnerAllowlist.isAllowedTeeMachineOwner(_extensionId, _owner);
    }

    /// @inheritdoc ITeeOwnerAllowlistFacet
    function isAllowedTeeWalletProjectOwner(
        uint256 _extensionId,
        address _owner
    )
        external view
        returns (bool _isAllowed)
    {
        return TeeOwnerAllowlist.isAllowedTeeWalletProjectOwner(_extensionId, _owner);
    }
}
