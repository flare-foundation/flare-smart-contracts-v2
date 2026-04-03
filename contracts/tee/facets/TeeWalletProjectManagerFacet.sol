// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeWalletProjectManagerFacet } from "../../userInterfaces/tee/ITeeWalletProjectManagerFacet.sol";
import { TeeWalletProjectManager } from "../library/TeeWalletProjectManager.sol";
import { TeeExtensionRegistry } from "../library/TeeExtensionRegistry.sol";
import { TeeOwnerAllowlist } from "../library/TeeOwnerAllowlist.sol";

/**
 * @title TeeWalletProjectManagerFacet
 * @notice Facet for TEE wallet project management.
 */
contract TeeWalletProjectManagerFacet is ITeeWalletProjectManagerFacet {

    /**
     * @inheritdoc ITeeWalletProjectManagerFacet
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
            TeeOwnerAllowlist.isAllowedTeeWalletProjectOwner(_extensionId, msg.sender),
            OwnerNotAllowed()
        );
        require(TeeExtensionRegistry.isKeyTypeSupported(_extensionId, _keyType), KeyTypeNotSupported(_keyType));
        require(TeeExtensionRegistry.isSigningAlgoSupported(_keyType, _signingAlgo), SigningAlgoNotSupported());

        TeeWalletProjectManager.State storage s = TeeWalletProjectManager.getState();
        _projectId = keccak256(abi.encode("PROJECT", msg.sender, ++s.projectCounter));
        TeeWalletProjectManager.TeeWalletProjectState storage project = s.projects[_projectId];
        assert(project.owner == address(0)); // should never revert
        project.owner = msg.sender;
        project.extensionId = _extensionId;
        project.keyType = _keyType;
        project.signingAlgo = _signingAlgo;
        emit ProjectCreated(_projectId, msg.sender, _extensionId, _keyType, _signingAlgo);
    }

    /**
     * @inheritdoc ITeeWalletProjectManagerFacet
     */
    function setBackupManager(
        bytes32 _projectId,
        address _backupManager
    )
        external
    {
        TeeWalletProjectManager.checkOnlyOwner(_projectId);
        TeeWalletProjectManager.getState().projects[_projectId].backupManager = _backupManager;
        emit BackupManagerSet(_projectId, _backupManager);
    }

    /**
     * @inheritdoc ITeeWalletProjectManagerFacet
     */
    function proposeNewOwner(
        bytes32 _projectId,
        address _newOwner
    )
        external
    {
        TeeWalletProjectManager.checkOnlyOwner(_projectId);
        uint256 extensionId = TeeWalletProjectManager.getExtensionId(_projectId);
        require(
            _newOwner == address(0) ||
                TeeOwnerAllowlist.isAllowedTeeWalletProjectOwner(extensionId, _newOwner),
            OwnerNotAllowed()
        );
        TeeWalletProjectManager.getState().proposedProjectOwner[_projectId] = _newOwner;
        emit NewOwnerProposed(_projectId, _newOwner);
    }

    /**
     * @inheritdoc ITeeWalletProjectManagerFacet
     */
    function confirmOwnership(
        bytes32 _projectId
    )
        external
    {
        uint256 extensionId = TeeWalletProjectManager.getExtensionId(_projectId);
        require(
            TeeOwnerAllowlist.isAllowedTeeWalletProjectOwner(extensionId, msg.sender),
            OwnerNotAllowed()
        );
        TeeWalletProjectManager.State storage s = TeeWalletProjectManager.getState();
        require(s.proposedProjectOwner[_projectId] == msg.sender, OnlyProposedOwner());
        s.projects[_projectId].owner = msg.sender;
        delete s.proposedProjectOwner[_projectId];
        emit OwnershipConfirmed(_projectId, msg.sender);
    }

    /**
     * @inheritdoc ITeeWalletProjectManagerFacet
     */
    function getOwner(
        bytes32 _projectId
    )
        external view
        returns (address _owner)
    {
        return TeeWalletProjectManager.getOwner(_projectId);
    }

    /**
     * @inheritdoc ITeeWalletProjectManagerFacet
     */
    function getExtensionId(
        bytes32 _projectId
    )
        external view
        returns (uint256 _extensionId)
    {
        return TeeWalletProjectManager.getExtensionId(_projectId);
    }

    /**
     * @inheritdoc ITeeWalletProjectManagerFacet
     */
    function getKeyType(
        bytes32 _projectId
    )
        external view
        returns (bytes32 _keyType)
    {
        return TeeWalletProjectManager.getKeyType(_projectId);
    }

    /**
     * @inheritdoc ITeeWalletProjectManagerFacet
     */
    function getSigningAlgo(
        bytes32 _projectId
    )
        external view
        returns (bytes32 _signingAlgo)
    {
        return TeeWalletProjectManager.getSigningAlgo(_projectId);
    }

    /**
     * @inheritdoc ITeeWalletProjectManagerFacet
     */
    function getBackupManager(
        bytes32 _projectId
    )
        external view
        returns (address _backupManager)
    {
        return TeeWalletProjectManager.getBackupManager(_projectId);
    }
}
