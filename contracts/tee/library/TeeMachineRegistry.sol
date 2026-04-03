// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeMachineRegistryFacet, REG_OP_TYPE } from "../../userInterfaces/tee/ITeeMachineRegistryFacet.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { ITeeAvailabilityCheck } from "../../userInterfaces/fdc2/ITeeAvailabilityCheck.sol";
import { PublicKey } from "../../userInterfaces/IPublicKey.sol";
import { TeeExtensionRegistry } from "./TeeExtensionRegistry.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title TeeMachineRegistry
 * @notice Library for TEE machine registration and status management.
 * @dev Uses ERC-7201 namespaced storage. Contains only logic that is
 *      reused by other libraries/facets. Registration and status-change
 *      methods live in TeeMachineRegistryFacet directly.
 */
library TeeMachineRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct TeeMachineState {
        uint256 extensionId;
        PublicKey teePublicKey;
        address initialTeeId;
        uint32 initialSigningPolicyId;
        address owner;
        address teeProxyId;
        ITeeMachineRegistryFacet.TeeStatus status;
        uint256 lastStatusChangeTs;
        bytes32 codeHash;
        bytes32 platform;
        string url;
    }

    /// @custom:storage-location erc7201:tee.TeeMachineRegistry.State
    struct State {
        EnumerableSet.AddressSet activeTeeIds;
        mapping(uint256 extensionId => EnumerableSet.AddressSet) extensionActiveTeeIds;
        mapping(address teeId => TeeMachineState) teeMachineStates;
        /// Proposed new TEE owner.
        mapping(address teeId => address) proposedTeeOwner;
    }

    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("tee.TeeMachineRegistry.State")) - 1)
    ) & ~bytes32(uint256(0xff));

    function getTeeMachine(
        address _teeId
    )
        internal view
        returns (ITeeMachineRegistryFacet.TeeMachine memory _teeMachine)
    {
        TeeMachineState storage s = getTeeMachineState(_teeId);
        _teeMachine = ITeeMachineRegistryFacet.TeeMachine({
            teeId: _teeId,
            teeProxyId: s.teeProxyId,
            url: s.url
        });
    }

    function getTeeMachineWithAttestationData(
        address _teeId
    )
        internal view
        returns (ITeeMachineRegistryFacet.TeeMachineWithAttestationData memory)
    {
        TeeMachineState storage s = getTeeMachineState(_teeId);
        return ITeeMachineRegistryFacet.TeeMachineWithAttestationData({
            teeId: _teeId,
            initialTeeId: s.initialTeeId,
            url: s.url,
            codeHash: s.codeHash,
            platform: s.platform
        });
    }

    function getExtensionId(
        address _teeId
    )
        internal view
        returns (uint256)
    {
        return getTeeMachineState(_teeId).extensionId;
    }

    function getTeeMachineStatus(
        address _teeId
    )
        internal view
        returns (ITeeMachineRegistryFacet.TeeStatus)
    {
        return getTeeMachineState(_teeId).status;
    }

    function getTeeMachineOwner(
        address _teeId
    )
        internal view
        returns (address)
    {
        return getTeeMachineState(_teeId).owner;
    }

    function getPublicKey(
        address _teeId
    )
        internal view
        returns (PublicKey memory)
    {
        return getTeeMachineState(_teeId).teePublicKey;
    }

    function getInitialSigningPolicyId(
        address _teeId
    )
        internal view
        returns (uint32)
    {
        return getTeeMachineState(_teeId).initialSigningPolicyId;
    }

    function getLastStatusChangeTs(
        address _teeId
    )
        internal view
        returns (uint256)
    {
        return getTeeMachineState(_teeId).lastStatusChangeTs;
    }

    function changeStatus(
        address _teeId,
        ITeeMachineRegistryFacet.TeeStatus _newStatus
    )
        internal
    {
        State storage s = getState();
        TeeMachineState storage state = s.teeMachineStates[_teeId];
        state.status = _newStatus;
        state.lastStatusChangeTs = block.timestamp;
        if (_newStatus == ITeeMachineRegistryFacet.TeeStatus.PRODUCTION) {
            s.extensionActiveTeeIds[state.extensionId].add(_teeId);
            s.activeTeeIds.add(_teeId);
        } else if (
            _newStatus == ITeeMachineRegistryFacet.TeeStatus.PAUSED ||
            _newStatus == ITeeMachineRegistryFacet.TeeStatus.PAUSED_FOR_UPGRADE
        ) {
            s.extensionActiveTeeIds[state.extensionId].remove(_teeId);
            s.activeTeeIds.remove(_teeId);
        }
        emit ITeeMachineRegistryFacet.TeeMachineStatusChanged(_teeId, _newStatus);
    }

    function checkCodeHashPlatformSupported(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        internal view
    {
        require(
            TeeExtensionRegistry.isCodeHashPlatformSupported(_extensionId, _codeHash, _platform),
            ITeeCommonErrors.VersionNotSupported()
        );
    }

    function checkTeeStatus(
        ITeeMachineRegistryFacet.TeeStatus _actualStatus,
        ITeeMachineRegistryFacet.TeeStatus _expectedStatus
    )
        internal pure
    {
        require(_actualStatus == _expectedStatus, ITeeMachineRegistryFacet.InvalidTeeStatus());
    }

    function checkTeeStatus(
        ITeeMachineRegistryFacet.TeeStatus _actualStatus,
        ITeeMachineRegistryFacet.TeeStatus _expectedStatus1,
        ITeeMachineRegistryFacet.TeeStatus _expectedStatus2
    )
        internal pure
    {
        require(
            _actualStatus == _expectedStatus1 || _actualStatus == _expectedStatus2,
            ITeeMachineRegistryFacet.InvalidTeeStatus()
        );
    }

    function validateAvailabilityCheckStatus(
        ITeeAvailabilityCheck.AvailabilityCheckStatus _status
    )
        internal pure
    {
        require(
            _status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            ITeeCommonErrors.InvalidAvailabilityCheckStatus()
        );
    }

    function validateAvailabilityCheckTs(
        address _teeId,
        uint256 _availabilityCheckTs
    )
        internal view
    {
        require(
            _availabilityCheckTs >= getState().teeMachineStates[_teeId].lastStatusChangeTs,
            ITeeCommonErrors.AvailabilityCheckTimestampInvalid()
        );
    }

    function getTeeMachineState(
        address _teeId
    )
        internal view
        returns (TeeMachineState storage _state)
    {
        _state = getState().teeMachineStates[_teeId];
        require(_state.owner != address(0), ITeeMachineRegistryFacet.TeeNotFound());
    }

    function getState()
        internal pure
        returns (State storage _state)
    {
        bytes32 position = STATE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _state.slot := position
        }
    }
}
