// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./TeeBase.sol";
import "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import "../../userInterfaces/tee/ITeeOwnerAllowlist.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";

/**
 * TeeWalletProjectManager is used for project configurations of TEE wallets.
 */
contract TeeWalletProjectManager is ITeeWalletProjectManager, TeeBase {

    struct TeeWalletProjectState {
        address owner;
        uint256 extensionId; // TEE extension id
        bytes32 opType;
        address submitAddress;
        address backupManager;
        bytes32 defaultWalletId;
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
        bytes32 _opType,
        address _submitAddress
    )
        external
        returns (bytes32 _projectId)
    {
        require(teeOwnerAllowlist.isAllowedTeeWalletProjectOwner(_extensionId, msg.sender), "owner not allowed");
        require(teeExtensionRegistry.isOpTypeSupported(_extensionId, _opType), "op type not supported");
        require(_submitAddress != address(0), "submit address zero");
        _projectId = keccak256(abi.encode("PROJECT", msg.sender, ++projectCounter));
        TeeWalletProjectState storage project = projects[_projectId];
        assert(project.owner == address(0)); // should never revert
        project.owner = msg.sender;
        project.extensionId = _extensionId;
        project.opType = _opType;
        project.submitAddress = _submitAddress;
        emit ProjectCreated(_projectId, msg.sender, _extensionId, _opType, _submitAddress);
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
    function setDefaultWallet(bytes32 _projectId, bytes32 _walletId)
        external onlyOwner(_projectId)
    {
        require(teeWalletManager.getWalletProjectId(_walletId) == _projectId, "wallet not part of the project");
        require(
            teeWalletManager.getWalletStatus(_walletId) == ITeeWalletManager.WalletStatus.PRODUCTION,
            "wallet not production ready"
        );
        projects[_projectId].defaultWalletId = _walletId;
        emit DefaultWalletSet(_projectId, _walletId);
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
            "owner not allowed"
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
        require(teeOwnerAllowlist.isAllowedTeeWalletProjectOwner(extensionId, msg.sender), "owner not allowed");
        require(proposedProjectOwner[_projectId] == msg.sender, "only proposed owner");
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
    function getOpType(bytes32 _projectId)
        external view
        returns (bytes32 _opType)
    {
        return projects[_projectId].opType;
    }

    /**
     * @inheritdoc ITeeWalletProjectManager
     */
    function getSubmitAddress(bytes32 _projectId)
        external view
        returns (address _submitAddress)
    {
        return projects[_projectId].submitAddress;
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
     * @inheritdoc ITeeWalletProjectManager
     */
    function getDefaultWalletInfo(bytes32 _projectId)
        external view
        returns (bytes32 _walletId, bytes32 _opType, address _submitAddress)
    {
        TeeWalletProjectState storage project = projects[_projectId];
        _walletId = project.defaultWalletId;
        _opType = project.opType;
        _submitAddress = project.submitAddress;
    }

    /**
     * @inheritdoc ITeeWalletProjectManager
     */
    function getOpTypeConstants(bytes32 _projectId) external view returns(bytes memory) {
        TeeWalletProjectState storage project = projects[_projectId];
        ITeeWalletProjectOpTypeConstants opTypeConstantsProvider =
            teeExtensionRegistry.getOpTypeConstantsProvider(project.extensionId, project.opType);
        return opTypeConstantsProvider.getOpTypeConstants(_projectId);
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
        require(projects[_projectId].owner == msg.sender, "only owner");
    }
}
