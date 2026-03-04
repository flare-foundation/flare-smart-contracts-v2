// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeBase } from "./TeeBase.sol";
import { ITeeWalletProjectManager } from "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import { ITeeExtensionRegistry } from "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeOwnerAllowlist } from "../../userInterfaces/tee/ITeeOwnerAllowlist.sol";
import { ITeeWalletManager } from "../../userInterfaces/tee/ITeeWalletManager.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";

/**
 * TeeWalletProjectManager is used for project configurations of TEE wallets.
 */
contract TeeWalletProjectManager is ITeeWalletProjectManager, TeeBase {

    struct TeeWalletProjectState {
        address owner;
        uint256 extensionId;
        bytes32 keyType;
        bytes32 signingAlgo;
        address backupManager;
    }

    uint256 public projectCounter = 0;
    mapping(bytes32 projectId => TeeWalletProjectState) private projects;
    mapping(bytes32 projectId => address) public proposedProjectOwner;

    /// TEE extension registry contract.
    ITeeExtensionRegistry public teeExtensionRegistry;
    /// TEE owner allowlist contract.
    ITeeOwnerAllowlist public teeOwnerAllowlist;
    /// TEE wallet manager contract.
    ITeeWalletManager public teeWalletManager;

    modifier onlyOwner(bytes32 _projectId) {
        _checkOnlyOwner(_projectId);
        _;
    }

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() TeeBase() {}

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
     * @inheritdoc ITeeWalletProjectManager
     */
    function createProject(
        uint256 _extensionId,
        bytes32 _keyType,
        bytes32 _signingAlgo
    )
        external
        returns (bytes32 _projectId)
    {
        require(teeOwnerAllowlist.isAllowedTeeWalletProjectOwner(_extensionId, msg.sender), OwnerNotAllowed());
        require(teeExtensionRegistry.isKeyTypeSupported(_extensionId, _keyType), KeyTypeNotSupported());
        require(teeExtensionRegistry.isSigningAlgoSupported(_keyType, _signingAlgo), SigningAlgoNotSupported());
        _projectId = keccak256(abi.encode("PROJECT", msg.sender, ++projectCounter));
        TeeWalletProjectState storage project = projects[_projectId];
        assert(project.owner == address(0)); // should never revert
        project.owner = msg.sender;
        project.extensionId = _extensionId;
        project.keyType = _keyType;
        project.signingAlgo = _signingAlgo;
        emit ProjectCreated(_projectId, msg.sender, _extensionId, _keyType, _signingAlgo);
    }

    /**
     * @inheritdoc ITeeWalletProjectManager
     */
    function setBackupManager(bytes32 _projectId, address _backupManager)
        external onlyOwner(_projectId)
    {
        projects[_projectId].backupManager = _backupManager;
        emit BackupManagerSet(_projectId, _backupManager);
    }

    /**
     * @inheritdoc ITeeWalletProjectManager
     */
    function proposeNewOwner(bytes32 _projectId, address _newOwner)
        external onlyOwner(_projectId)
    {
        uint256 extensionId = projects[_projectId].extensionId;
        require(
            _newOwner == address(0) || teeOwnerAllowlist.isAllowedTeeWalletProjectOwner(extensionId, _newOwner),
            OwnerNotAllowed()
        );
        proposedProjectOwner[_projectId] = _newOwner;
        emit NewOwnerProposed(_projectId, _newOwner);
    }

    /**
     * @inheritdoc ITeeWalletProjectManager
     */
    function confirmOwnership(bytes32 _projectId)
        external
    {
        uint256 extensionId = projects[_projectId].extensionId;
        require(teeOwnerAllowlist.isAllowedTeeWalletProjectOwner(extensionId, msg.sender), OwnerNotAllowed());
        require(proposedProjectOwner[_projectId] == msg.sender, OnlyProposedOwner());
        projects[_projectId].owner = msg.sender;
        delete proposedProjectOwner[_projectId];
        emit OwnershipConfirmed(_projectId, msg.sender);
    }

    /**
     * @inheritdoc ITeeWalletProjectManager
     */
    function getOwner(bytes32 _projectId)
        external view
        returns (address _projectOwner)
    {
        return projects[_projectId].owner;
    }

    /**
     * @inheritdoc ITeeWalletProjectManager
     */
    function getExtensionId(bytes32 _projectId)
        external view
        returns (uint256 _extensionId)
    {
        return projects[_projectId].extensionId;
    }

    /**
     * @inheritdoc ITeeWalletProjectManager
     */
    function getKeyType(bytes32 _projectId)
        external view
        returns (bytes32 _keyType)
    {
        return projects[_projectId].keyType;
    }

    /**
     * @inheritdoc ITeeWalletProjectManager
     */
    function getSigningAlgo(bytes32 _projectId)
        external view
        returns (bytes32 _signingAlgo)
    {
        return projects[_projectId].signingAlgo;
    }

    /**
     * @inheritdoc ITeeWalletProjectManager
     */
    function getBackupManager(bytes32 _projectId)
        external view
        returns (address _backupManager)
    {
        return projects[_projectId].backupManager;
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
        teeOwnerAllowlist = ITeeOwnerAllowlist(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeOwnerAllowlist"));
        teeWalletManager = ITeeWalletManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletManager"));
    }

    function _checkOnlyOwner(bytes32 _projectId)
        internal view
    {
        require(projects[_projectId].owner == msg.sender, OnlyOwner());
    }
}
