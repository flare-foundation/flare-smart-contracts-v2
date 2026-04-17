// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";

/**
 * @title WalletProjectManager
 * @notice Library for TEE wallet project management.
 * @dev Uses ERC-7201 namespaced storage. Contains only logic that is
 *      reused by other libraries/facets.
 */
library WalletProjectManager {

    struct TeeWalletProjectState {
        address owner;
        uint256 extensionId;
        bytes32 keyType;
        bytes32 signingAlgo;
        address backupManager;
    }

    /// @custom:storage-location erc7201:tee.WalletProjectManager.State
    struct State {
        uint256 projectCounter;
        mapping(bytes32 projectId => TeeWalletProjectState) projects;
        mapping(bytes32 projectId => address) proposedProjectOwner;
    }

    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("tee.WalletProjectManager.State")) - 1)
    ) & ~bytes32(uint256(0xff));

    function getOwner(
        bytes32 _projectId
    )
        internal view
        returns (address)
    {
        return getState().projects[_projectId].owner;
    }

    function getExtensionId(
        bytes32 _projectId
    )
        internal view
        returns (uint256)
    {
        return getState().projects[_projectId].extensionId;
    }

    function getKeyType(
        bytes32 _projectId
    )
        internal view
        returns (bytes32)
    {
        return getState().projects[_projectId].keyType;
    }

    function getSigningAlgo(
        bytes32 _projectId
    )
        internal view
        returns (bytes32)
    {
        return getState().projects[_projectId].signingAlgo;
    }

    function getBackupManager(
        bytes32 _projectId
    )
        internal view
        returns (address)
    {
        return getState().projects[_projectId].backupManager;
    }

    function checkOnlyOwner(
        bytes32 _projectId
    )
        internal view
    {
        require(
            getState().projects[_projectId].owner == msg.sender,
            ITeeCommonErrors.OnlyOwner()
        );
    }

    function checkOnlyOwnerOrBackupManager(
        bytes32 _projectId
    )
        internal view
    {
        TeeWalletProjectState storage project = getState().projects[_projectId];
        require(
            project.owner == msg.sender || project.backupManager == msg.sender,
            ITeeCommonErrors.OnlyOwnerOrBackupManager()
        );
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
