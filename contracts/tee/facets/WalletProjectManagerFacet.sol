// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IWalletProjectManager } from "../../userInterfaces/tee/IWalletProjectManager.sol";
import { WalletProjectManager } from "../library/WalletProjectManager.sol";
import { ExtensionManager } from "../library/ExtensionManager.sol";
import { OwnerAllowlist } from "../library/OwnerAllowlist.sol";

/**
 * @title WalletProjectManagerFacet
 * @notice Facet for TEE wallet project management.
 */
contract WalletProjectManagerFacet is IWalletProjectManager {

    /**
     * @inheritdoc IWalletProjectManager
     */
    function createProject(
        uint256 _extensionId,
        bytes32 _keyType,
        bytes32 _signingAlgo
    )
        external
        returns (bytes32 _projectId)
    {
        require(
            OwnerAllowlist.isAllowedTeeWalletProjectOwner(_extensionId, msg.sender),
            OwnerNotAllowed()
        );
        require(ExtensionManager.isKeyTypeSupported(_extensionId, _keyType), KeyTypeNotSupported(_keyType));
        require(ExtensionManager.isSigningAlgoSupported(_keyType, _signingAlgo), SigningAlgoNotSupported());

        WalletProjectManager.State storage s = WalletProjectManager.getState();
        _projectId = keccak256(abi.encode("PROJECT", msg.sender, ++s.projectCounter));
        WalletProjectManager.TeeWalletProjectState storage project = s.projects[_projectId];
        assert(project.owner == address(0)); // should never revert
        project.owner = msg.sender;
        project.extensionId = _extensionId;
        project.keyType = _keyType;
        project.signingAlgo = _signingAlgo;
        emit ProjectCreated(_projectId, msg.sender, _extensionId, _keyType, _signingAlgo);
    }

    /**
     * @inheritdoc IWalletProjectManager
     */
    function setBackupManager(
        bytes32 _projectId,
        address _backupManager
    )
        external
    {
        WalletProjectManager.checkOnlyOwner(_projectId);
        WalletProjectManager.getState().projects[_projectId].backupManager = _backupManager;
        emit BackupManagerSet(_projectId, _backupManager);
    }

    /**
     * @inheritdoc IWalletProjectManager
     */
    function proposeNewOwner(
        bytes32 _projectId,
        address _newOwner
    )
        external
    {
        WalletProjectManager.checkOnlyOwner(_projectId);
        uint256 extensionId = WalletProjectManager.getExtensionId(_projectId);
        require(
            _newOwner == address(0) ||
                OwnerAllowlist.isAllowedTeeWalletProjectOwner(extensionId, _newOwner),
            OwnerNotAllowed()
        );
        WalletProjectManager.getState().proposedProjectOwner[_projectId] = _newOwner;
        emit NewOwnerProposed(_projectId, _newOwner);
    }

    /**
     * @inheritdoc IWalletProjectManager
     */
    function confirmOwnership(
        bytes32 _projectId
    )
        external
    {
        uint256 extensionId = WalletProjectManager.getExtensionId(_projectId);
        require(
            OwnerAllowlist.isAllowedTeeWalletProjectOwner(extensionId, msg.sender),
            OwnerNotAllowed()
        );
        WalletProjectManager.State storage s = WalletProjectManager.getState();
        require(s.proposedProjectOwner[_projectId] == msg.sender, OnlyProposedOwner());
        s.projects[_projectId].owner = msg.sender;
        delete s.proposedProjectOwner[_projectId];
        emit OwnershipConfirmed(_projectId, msg.sender);
    }

    /**
     * @inheritdoc IWalletProjectManager
     */
    function getOwner(
        bytes32 _projectId
    )
        external view
        returns (address _owner)
    {
        return WalletProjectManager.getOwner(_projectId);
    }

    /**
     * @inheritdoc IWalletProjectManager
     */
    function getExtensionId(
        bytes32 _projectId
    )
        external view
        returns (uint256 _extensionId)
    {
        return WalletProjectManager.getExtensionId(_projectId);
    }

    /**
     * @inheritdoc IWalletProjectManager
     */
    function getKeyType(
        bytes32 _projectId
    )
        external view
        returns (bytes32 _keyType)
    {
        return WalletProjectManager.getKeyType(_projectId);
    }

    /**
     * @inheritdoc IWalletProjectManager
     */
    function getSigningAlgo(
        bytes32 _projectId
    )
        external view
        returns (bytes32 _signingAlgo)
    {
        return WalletProjectManager.getSigningAlgo(_projectId);
    }

    /**
     * @inheritdoc IWalletProjectManager
     */
    function getBackupManager(
        bytes32 _projectId
    )
        external view
        returns (address _backupManager)
    {
        return WalletProjectManager.getBackupManager(_projectId);
    }
}
