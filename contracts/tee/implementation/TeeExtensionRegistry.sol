// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./TeeBase.sol";
import "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import "../../userInterfaces/tee/ITeeGovernance.sol";
import "../../userInterfaces/tee/ITeeWalletProjectOpTypeConstants.sol";
import "../../userInterfaces/tee/ITeeMachineRegistry.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../protocol/interface/IIRewardManager.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * TeeExtensionRegistry is used for registration of TEE extensions.
 */
contract TeeExtensionRegistry is ITeeExtensionRegistry, TeeBase {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct TeeVersion {
        string version;
        bytes32 governanceHash;
        /// Supported platforms.
        EnumerableSet.Bytes32Set platforms;
    }

    struct TeeExtension {
        address owner;
        ITeeExtensionStateVerifier stateVerifier;
        address instructionsSender;

        mapping(bytes32 codeHash => TeeVersion) codeHashToVersion;
        /// Disabled code hash and platform mapping.
        mapping(bytes32 codeHash => mapping(bytes32 platform => bool)) codeHashPlatformDisabled;

        bytes32[] supportedOpTypes;
        /// Mapping of operation type to operation type constants provider.
        mapping(bytes32 opType => ITeeWalletProjectOpTypeConstants) opTypeConstantsProviders;
    }

    /// Prefix reserved for system-owned extension.
    bytes2 public constant SYSTEM_OP_TYPE_PREFIX = bytes2("F_");

    /// TEE governance contract.
    ITeeGovernance public teeGovernance;
    /// TEE machine registry contract.
    ITeeMachineRegistry public teeMachineRegistry;
    /// TEE fee calculator contract.
    ITeeFeeCalculator public teeFeeCalculator;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// Reward manager contract.
    IIRewardManager public rewardManager;

    /// List of system instruction initiator contracts.
    EnumerableSet.AddressSet private systemInstructionInitiators;

    /// List of supported platforms.
    EnumerableSet.Bytes32Set private supportedPlatforms;

    /// Extensions counter.
    uint256 public extensionsCounter;
    mapping(uint256 extensionId => TeeExtension) private extensions;

    /// Proposed new extension owner.
    mapping(uint256 extensionId => address) public proposedExtensionOwner;

    modifier onlyOwner(uint256 _extensionId) {
        _checkOnlyOwner(_extensionId);
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
        extensionsCounter++; // Extension 0 is system-owned.
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function sendInstructions(
        bytes32 _instructionId,
        address[] memory _teeIds,
        bytes32 _opType,
        bytes32 _opCommand,
        bytes memory _message
    )
        external payable
    {
        require(_instructionId != bytes32(0), "instruction ID empty");
        require(_teeIds.length > 0, "no TEE machines specified");
        require(_opType != bytes32(0), "operation type empty");
        require(_opCommand != bytes32(0), "operation command empty");
        require(_message.length > 0, "message empty");
        uint256 extensionId = teeMachineRegistry.getExtensionId(_teeIds[0]);
        for (uint256 i = 1; i < _teeIds.length; i++) {
            require(teeMachineRegistry.getExtensionId(_teeIds[i]) == extensionId, "extension id mismatch");
        }
        bool isSystemOpType = _isSystemOpType(_opType);
        if (!systemInstructionInitiators.contains(msg.sender)) {
            require(msg.sender == extensions[extensionId].instructionsSender, "only instructions sender");
            require(extensionId == 0 || !isSystemOpType, "system op type not allowed");
        }

        // Check fee
        require(teeFeeCalculator.calculateFeeByTeeIds(_opType, _opCommand, _teeIds) <= msg.value, "fee too low");

        // Get the TEE machines and check their status.
        ITeeMachineRegistry.TeeMachine[] memory teeMachines = new ITeeMachineRegistry.TeeMachine[](_teeIds.length);
        for (uint256 i = 0; i < _teeIds.length; i++) {
            if (!isSystemOpType) {
                require(
                    teeMachineRegistry.getTeeMachineStatus(_teeIds[i]) == ITeeMachineRegistry.TeeStatus.PRODUCTION,
                    "tee machine not available"
                );
            }
            teeMachines[i] = teeMachineRegistry.getTeeMachine(_teeIds[i]);
        }

        // send fee to the reward manager
        uint24 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        rewardManager.receiveRewards{value: msg.value}(currentRewardEpochId, false);

        // emit the event
        emit TeeInstructionsSent(
            _instructionId,
            currentRewardEpochId,
            teeMachines,
            _opType,
            _opCommand,
            _message,
            msg.value
        );
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function register(
        ITeeExtensionStateVerifier _teeExtensionStateVerifier,
        address _teeExtensionInstructionsSender
    )
        external payable
    {
        require(_teeExtensionInstructionsSender != address(0), "invalid instructions sender");
        uint256 extensionId = extensionsCounter++;
        TeeExtension storage newExtension = extensions[extensionId];
        newExtension.owner = msg.sender;
        newExtension.stateVerifier = _teeExtensionStateVerifier;
        newExtension.instructionsSender = _teeExtensionInstructionsSender;
        emit ExtensionRegistered(extensionId, msg.sender);
        emit ExtensionContractsSet(extensionId, _teeExtensionStateVerifier, _teeExtensionInstructionsSender);
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function setExtensionContracts(
        uint256 _extensionId,
        ITeeExtensionStateVerifier _teeExtensionStateVerifier,
        address _teeExtensionInstructionsSender
    )
        external onlyOwner(_extensionId)
    {
        require(_teeExtensionInstructionsSender != address(0), "invalid instructions sender");
        TeeExtension storage extension = extensions[_extensionId];
        extension.stateVerifier = _teeExtensionStateVerifier;
        extension.instructionsSender = _teeExtensionInstructionsSender;
        emit ExtensionContractsSet(_extensionId, _teeExtensionStateVerifier, _teeExtensionInstructionsSender);
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function addTeeVersion(
        uint256 _extensionId,
        string calldata _version,
        bytes32 _codeHash,
        bytes32[] calldata _platforms,
        bytes32 _governanceHash
    )
        external onlyOwner(_extensionId)
    {
        require(bytes(_version).length > 0, "version empty");
        require(_codeHash != bytes32(0), "code hash zero");
        require(_platforms.length > 0, "no platforms");
        for (uint256 i = 0; i < _platforms.length; i++) {
            require(supportedPlatforms.contains(_platforms[i]), "unsupported platform");
        }
        TeeExtension storage extension = extensions[_extensionId];
        require(extension.codeHashToVersion[_codeHash].platforms.length() == 0, "version already exists");

        require(
            _governanceHash == bytes32(0) || teeGovernance.getLatestTeeGovernanceHash(_extensionId) == _governanceHash,
            "invalid governance hash"
        );

        TeeVersion storage teeVersion = extension.codeHashToVersion[_codeHash];
        teeVersion.version = _version;
        for (uint256 i = 0; i < _platforms.length; i++) {
            require(teeVersion.platforms.add(_platforms[i]), "platform already exists");
        }
        teeVersion.governanceHash = _governanceHash;
        emit TeeVersionAdded(_extensionId, _codeHash, _version, _platforms, _governanceHash);
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function disableCodeHashPlatform(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external onlyOwner(_extensionId)
    {
        TeeExtension storage extension = extensions[_extensionId];
        require(extension.codeHashToVersion[_codeHash].platforms.length() > 0, "invalid code hash");
        bytes32[] memory platforms = extension.codeHashToVersion[_codeHash].platforms.values();
        if (_platform != bytes32(0)) {
            for (uint256 i = 0; i < platforms.length; i++) {
                if (platforms[i] == _platform) {
                    extension.codeHashPlatformDisabled[_codeHash][_platform] = true;
                    emit CodeHashPlatformDisabled(_extensionId, _codeHash, _platform);
                    return;
                }
            }
            revert("invalid platform");
        } else {
            for (uint256 i = 0; i < platforms.length; i++) {
                extension.codeHashPlatformDisabled[_codeHash][platforms[i]] = true;
                emit CodeHashPlatformDisabled(_extensionId, _codeHash, platforms[i]);
            }
        }
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function addOrUpdateSupportedWalletProjectOpTypes(
        uint256 _extensionId,
        ITeeWalletProjectOpTypeConstants[] calldata _opTypeConstantsProviders
    )
        external onlyOwner(_extensionId)
    {
        TeeExtension storage extension = extensions[_extensionId];
        for (uint256 i = 0; i < _opTypeConstantsProviders.length; i++) {
            ITeeWalletProjectOpTypeConstants opTypeConstantsProvider = _opTypeConstantsProviders[i];
            bytes32 opType = opTypeConstantsProvider.getOpType();
            require(opType != bytes32(0), "op type empty");
            require(_extensionId == 0 || !_isSystemOpType(opType), "system op type not allowed");
            if (address(extension.opTypeConstantsProviders[opType]) == address(0)) {
                extension.supportedOpTypes.push(opType);
                emit OpTypeAdded(_extensionId, opType);
            }
            extension.opTypeConstantsProviders[opType] = opTypeConstantsProvider;
        }
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function removeSupportedWalletProjectOpTypes(
        uint256 _extensionId,
        bytes32[] memory _opTypes
    )
        external onlyOwner(_extensionId)
    {
        TeeExtension storage extension = extensions[_extensionId];
        bytes32[] storage supportedOpTypes = extension.supportedOpTypes;
        for (uint256 i = 0; i < _opTypes.length; i++) {
            for (uint256 j = 0; j < supportedOpTypes.length; j++) {
                if (supportedOpTypes[j] == _opTypes[i]) {
                    supportedOpTypes[j] = supportedOpTypes[supportedOpTypes.length - 1];
                    supportedOpTypes.pop();
                    delete extension.opTypeConstantsProviders[_opTypes[i]];
                    emit OpTypeRemoved(_extensionId, _opTypes[i]);
                    break;
                }
            }
        }
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function proposeNewOwner(uint256 _extensionId, address _newOwner)
        external onlyOwner(_extensionId)
    {
        require(_extensionId != 0, "system-owned extension id");
        proposedExtensionOwner[_extensionId] = _newOwner;
        emit NewOwnerProposed(_extensionId, msg.sender, _newOwner);
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function confirmOwnership(uint256 _extensionId)
        external
    {
        require(proposedExtensionOwner[_extensionId] == msg.sender, "only proposed owner");
        extensions[_extensionId].owner = msg.sender;
        delete proposedExtensionOwner[_extensionId];
        emit NewOwnerConfirmed(_extensionId, msg.sender);
    }

    /**
     * Registers supported platforms.
     * @param _platforms List of platforms to add.
     * @dev Only governance can call this method.
     */
    function addSupportedPlatforms(bytes32[] calldata _platforms)
        external onlyGovernance
    {
        for (uint256 i = 0; i < _platforms.length; i++) {
            require(_platforms[i] != bytes32(0), "platform empty");
            require(supportedPlatforms.add(_platforms[i]), "platform already exists");
            emit PlatformAdded(_platforms[i]);
        }
    }

    /**
     * Registers system instruction initiator contracts.
     * @param _instructionInitiators List of contracts to register.
     * @dev Only governance can call this method.
     */
    function registerSystemInstructionInitiators(
        address[] calldata _instructionInitiators
    )
        external onlyGovernance
    {
        for (uint256 i = 0; i < _instructionInitiators.length; ++i) {
            systemInstructionInitiators.add(_instructionInitiators[i]);
        }
    }

    /**
     * Unregisters system instruction initiator contracts.
     * @param _instructionInitiators List of contracts to unregister.
     * @dev Only governance can call this method.
     */
    function unregisterSystemInstructionInitiators(
        address[] calldata _instructionInitiators
    )
        external onlyGovernance
    {
        for (uint256 i = 0; i < _instructionInitiators.length; ++i) {
            systemInstructionInitiators.remove(_instructionInitiators[i]);
        }
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function getSystemInstructionInitiators() external view returns(address[] memory) {
        return systemInstructionInitiators.values();
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function getExtensionOwner(uint256 _extensionId)
        external view
        returns(address)
    {
        return _getExtensionOwner(_extensionId);
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function getTeeExtensionStateVerifier(uint256 _extensionId)
        external view
        returns (ITeeExtensionStateVerifier)
    {
        return extensions[_extensionId].stateVerifier;
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function getTeeExtensionInstructionsSender(uint256 _extensionId)
        external view
        returns (address)
    {
        return extensions[_extensionId].instructionsSender;
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function getWalletProjectOpTypeConstantsProvider(
        uint256 _extensionId,
        bytes32 _opType
    )
        external view
        returns (ITeeWalletProjectOpTypeConstants _opTypeConstantsProvider)
    {
        _opTypeConstantsProvider = extensions[_extensionId].opTypeConstantsProviders[_opType];
        require(address(_opTypeConstantsProvider) != address(0), "operation type constants provider not set");
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function getSupportedWalletProjectOpTypes(
        uint256 _extensionId
    )
        external view
        returns (bytes32[] memory _supportedOpTypes)
    {
        return extensions[_extensionId].supportedOpTypes;
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function isWalletProjectOpTypeSupported(
        uint256 _extensionId,
        bytes32 _opType
    )
        external view
        returns (bool)
    {
        return address(extensions[_extensionId].opTypeConstantsProviders[_opType]) != address(0);
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function isCodeHashPlatformSupported(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external view
        returns(bool)
    {
        if (extensions[_extensionId].codeHashPlatformDisabled[_codeHash][_platform]) {
            return false; // platform disabled
        }
        return extensions[_extensionId].codeHashToVersion[_codeHash].platforms.contains(_platform);
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function codeHashPlatformDisabled(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external view
        returns(bool)
    {
        return extensions[_extensionId].codeHashPlatformDisabled[_codeHash][_platform];
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function getTeeGovernanceHash(
        uint256 _extensionId,
        bytes32 _codeHash
    )
        external view
        returns(bytes32)
    {
        return extensions[_extensionId].codeHashToVersion[_codeHash].governanceHash;
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function getCodeHashInfo(
        uint256 _extensionId,
        bytes32 _codeHash
    )
        external view
        returns(bytes32 _governanceHash, string memory _version, bytes32[] memory _platforms)
    {
        TeeExtension storage extension = extensions[_extensionId];
        _governanceHash = extension.codeHashToVersion[_codeHash].governanceHash;
        _version = extension.codeHashToVersion[_codeHash].version;
        _platforms = extension.codeHashToVersion[_codeHash].platforms.values();
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
        teeGovernance = ITeeGovernance(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeGovernance"));
        teeMachineRegistry = ITeeMachineRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeMachineRegistry"));
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        rewardManager = IIRewardManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
    }

    function _checkOnlyOwner(uint256 _extensionId) internal view {
        require(msg.sender == _getExtensionOwner(_extensionId), "only owner");
    }

    /**
     * Internal function to get the owner of an extension.
     * Extension 0 is system-owned, it returns the governance address.
     * @param _extensionId The id of the extension.
     * @return The address of the extension owner.
     */
    function _getExtensionOwner(uint256 _extensionId)
        internal view
        returns(address)
    {
        if (_extensionId == 0) {
            return governance();
        }
        return extensions[_extensionId].owner;
    }

    function _isSystemOpType(bytes32 _opType)
        internal pure
        returns(bool)
    {
        return _opType[0] == SYSTEM_OP_TYPE_PREFIX[0] && _opType[1] == SYSTEM_OP_TYPE_PREFIX[1];
    }
}
