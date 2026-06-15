// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IMachineEmergencyPause } from "../../userInterfaces/tee/IMachineEmergencyPause.sol";
import { IIMachineEmergencyPause } from "../interface/IIMachineEmergencyPause.sol";
import { MachineEmergencyPause } from "../library/MachineEmergencyPause.sol";
import { ExtensionManager } from "../library/ExtensionManager.sol";
import { FlareGovernedAccess } from "../../governance/implementation/FlareGovernedAccess.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title MachineEmergencyPauseFacet
 * @notice Facet for per-extension emergency pause: pauser/unpauser delegation lists,
 *         the pause/unpause action flips, and the governance-tunable grace duration.
 * @dev List-management methods are gated by the extension owner.
 *      Pause/unpause actions accept the extension owner OR a list member.
 *      The grace setter is `onlyGovernance` (timelocked).
 */
contract MachineEmergencyPauseFacet is IIMachineEmergencyPause, FlareGovernedAccess {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IMachineEmergencyPause
    function addExtensionEmergencyPausers(
        uint256 _extensionId,
        address[] calldata _addresses
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        require(_addresses.length > 0, NoAddresses());
        EnumerableSet.AddressSet storage set = MachineEmergencyPause.getState().pausers[_extensionId];
        for (uint256 i = 0; i < _addresses.length; i++) {
            address a = _addresses[i];
            require(a != address(0), InvalidAddress());
            require(set.add(a), AddressAlreadyInSet(a));
        }
        emit ExtensionEmergencyPausersAdded(_extensionId, _addresses);
    }

    /// @inheritdoc IMachineEmergencyPause
    function removeExtensionEmergencyPausers(
        uint256 _extensionId,
        address[] calldata _addresses
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        require(_addresses.length > 0, NoAddresses());
        EnumerableSet.AddressSet storage set = MachineEmergencyPause.getState().pausers[_extensionId];
        for (uint256 i = 0; i < _addresses.length; i++) {
            require(set.remove(_addresses[i]), AddressNotInSet(_addresses[i]));
        }
        emit ExtensionEmergencyPausersRemoved(_extensionId, _addresses);
    }

    /// @inheritdoc IMachineEmergencyPause
    function addExtensionEmergencyUnpausers(
        uint256 _extensionId,
        address[] calldata _addresses
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        require(_addresses.length > 0, NoAddresses());
        EnumerableSet.AddressSet storage set = MachineEmergencyPause.getState().unpausers[_extensionId];
        for (uint256 i = 0; i < _addresses.length; i++) {
            address a = _addresses[i];
            require(a != address(0), InvalidAddress());
            require(set.add(a), AddressAlreadyInSet(a));
        }
        emit ExtensionEmergencyUnpausersAdded(_extensionId, _addresses);
    }

    /// @inheritdoc IMachineEmergencyPause
    function removeExtensionEmergencyUnpausers(
        uint256 _extensionId,
        address[] calldata _addresses
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        require(_addresses.length > 0, NoAddresses());
        EnumerableSet.AddressSet storage set = MachineEmergencyPause.getState().unpausers[_extensionId];
        for (uint256 i = 0; i < _addresses.length; i++) {
            require(set.remove(_addresses[i]), AddressNotInSet(_addresses[i]));
        }
        emit ExtensionEmergencyUnpausersRemoved(_extensionId, _addresses);
    }

    /// @inheritdoc IMachineEmergencyPause
    function emergencyPauseExtension(
        uint256 _extensionId
    )
        external
    {
        require(
            msg.sender == ExtensionManager.getExtensionOwner(_extensionId) ||
                MachineEmergencyPause.isPauser(_extensionId, msg.sender),
            NotOwnerOrPauser(msg.sender)
        );
        MachineEmergencyPause.ExtensionPauseState storage e =
            MachineEmergencyPause.getState().extensions[_extensionId];
        require(!e.emergencyPaused, ExtensionAlreadyEmergencyPaused(_extensionId));
        e.emergencyPaused = true;
        emit ExtensionEmergencyPaused(_extensionId);
    }

    /// @inheritdoc IMachineEmergencyPause
    function emergencyUnpauseExtension(
        uint256 _extensionId
    )
        external
    {
        require(
            msg.sender == ExtensionManager.getExtensionOwner(_extensionId) ||
                MachineEmergencyPause.isUnpauser(_extensionId, msg.sender),
            NotOwnerOrUnpauser(msg.sender)
        );
        MachineEmergencyPause.ExtensionPauseState storage e =
            MachineEmergencyPause.getState().extensions[_extensionId];
        require(e.emergencyPaused, ExtensionNotEmergencyPaused(_extensionId));
        e.emergencyPaused = false;
        uint64 ts = uint64(block.timestamp);
        e.lastUnpauseTs = ts;
        emit ExtensionEmergencyUnpaused(_extensionId, ts);
    }

    /// @inheritdoc IIMachineEmergencyPause
    function setEmergencyUnpauseGracePeriodSeconds(
        uint256 _seconds
    )
        external
        onlyGovernance
    {
        MachineEmergencyPause.setGracePeriodSeconds(_seconds);
    }

    /// @inheritdoc IMachineEmergencyPause
    function getExtensionEmergencyPausers(
        uint256 _extensionId
    )
        external view
        returns (address[] memory _addresses)
    {
        return MachineEmergencyPause.getState().pausers[_extensionId].values();
    }

    /// @inheritdoc IMachineEmergencyPause
    function getExtensionEmergencyUnpausers(
        uint256 _extensionId
    )
        external view
        returns (address[] memory _addresses)
    {
        return MachineEmergencyPause.getState().unpausers[_extensionId].values();
    }

    /// @inheritdoc IMachineEmergencyPause
    function isExtensionEmergencyPauser(
        uint256 _extensionId,
        address _addr
    )
        external view
        returns (bool _isPauser)
    {
        return MachineEmergencyPause.isPauser(_extensionId, _addr);
    }

    /// @inheritdoc IMachineEmergencyPause
    function isExtensionEmergencyUnpauser(
        uint256 _extensionId,
        address _addr
    )
        external view
        returns (bool _isUnpauser)
    {
        return MachineEmergencyPause.isUnpauser(_extensionId, _addr);
    }

    /// @inheritdoc IMachineEmergencyPause
    function isExtensionEmergencyPaused(
        uint256 _extensionId
    )
        external view
        returns (bool _paused)
    {
        return MachineEmergencyPause.isExtensionEmergencyPaused(_extensionId);
    }

    /// @inheritdoc IMachineEmergencyPause
    function getLastUnpauseTs(
        uint256 _extensionId
    )
        external view
        returns (uint64 _ts)
    {
        return MachineEmergencyPause.getState().extensions[_extensionId].lastUnpauseTs;
    }

    /// @inheritdoc IMachineEmergencyPause
    function getEmergencyUnpauseGracePeriodSeconds()
        external view
        returns (uint256 _seconds)
    {
        return MachineEmergencyPause.getState().emergencyUnpauseGracePeriodSeconds;
    }
}
