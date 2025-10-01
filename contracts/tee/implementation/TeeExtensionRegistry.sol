// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeBase } from "./TeeBase.sol";
import { IITeeExtensionRegistry } from "../interface/IITeeExtensionRegistry.sol";
import { ITeeExtensionStateVerifier } from "../../userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { ITeeGovernance } from "../../userInterfaces/tee/ITeeGovernance.sol";
import { ITeeMachineRegistry } from "../../userInterfaces/tee/ITeeMachineRegistry.sol";
import { ITeeFeeCalculator } from "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { IIRewardManager } from "../../protocol/interface/IIRewardManager.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import { ITeeExtensionRegistry } from "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";

/**
 * TeeExtensionRegistry is used for registration of TEE extensions.
 */
contract TeeExtensionRegistry is IITeeExtensionRegistry, TeeBase {
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

        // Supported key types.
        EnumerableSet.Bytes32Set supportedKeyTypes;
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

    /// List of system instructions sender contracts.
    EnumerableSet.AddressSet private systemInstructionsSenders;

    /// List of system supported platforms.
    EnumerableSet.Bytes32Set private systemSupportedPlatforms;

    /// List of system supported key types and signing algorithms.
    EnumerableSet.Bytes32Set private systemSupportedKeyTypes;
    mapping(bytes32 keyType => EnumerableSet.Bytes32Set) private systemSupportedSigningAlgos;

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
        bytes memory _message,
        address[] memory _cosigners,
        uint64 _cosignersThreshold
    )
        external payable
    {
        // remove duplicates
        _removeDuplicates(_teeIds);
        // get TEE machines
        ITeeMachineRegistry.TeeMachine[] memory teeMachines = new ITeeMachineRegistry.TeeMachine[](_teeIds.length);
        for (uint256 i = 0; i < _teeIds.length; i++) {
            teeMachines[i] = teeMachineRegistry.getTeeMachine(_teeIds[i]);
        }

        _sendInstructions(
            _instructionId,
            teeMachines,
            _opType,
            _opCommand,
            _message,
            _cosigners,
            _cosignersThreshold
        );
    }

    /**
     * @inheritdoc IITeeExtensionRegistry
     */
    function sendSystemInstructions(
        bytes32 _instructionId,
        ITeeMachineRegistry.TeeMachine[] memory _teeMachines,
        bytes32 _opType,
        bytes32 _opCommand,
        bytes memory _message,
        address[] memory _cosigners,
        uint64 _cosignersThreshold
    )
        external payable
    {
        require(systemInstructionsSenders.contains(msg.sender), OnlySystemInstructionsSender());

        _sendInstructions(
            _instructionId,
            _teeMachines,
            _opType,
            _opCommand,
            _message,
            _cosigners,
            _cosignersThreshold
        );
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function register(
        ITeeExtensionStateVerifier _teeExtensionStateVerifier,
        address _teeExtensionInstructionsSender
    )
        external
        returns (uint256 _extensionId)
    {
        require(_teeExtensionInstructionsSender != address(0), InvalidInstructionsSender());
        _extensionId = extensionsCounter++;
        TeeExtension storage newExtension = extensions[_extensionId];
        newExtension.owner = msg.sender;
        newExtension.stateVerifier = _teeExtensionStateVerifier;
        newExtension.instructionsSender = _teeExtensionInstructionsSender;
        emit TeeExtensionRegistered(_extensionId, msg.sender);
        emit TeeExtensionContractsSet(_extensionId, _teeExtensionStateVerifier, _teeExtensionInstructionsSender);
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
        // Extension 0 is using system instructions initiators and system state verifier.
        require(_extensionId != 0, SystemOwnedExtensionId());
        require(_teeExtensionInstructionsSender != address(0), InvalidInstructionsSender());
        TeeExtension storage extension = extensions[_extensionId];
        extension.stateVerifier = _teeExtensionStateVerifier;
        extension.instructionsSender = _teeExtensionInstructionsSender;
        emit TeeExtensionContractsSet(_extensionId, _teeExtensionStateVerifier, _teeExtensionInstructionsSender);
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
        require(bytes(_version).length > 0, VersionEmpty());
        require(_codeHash != bytes32(0), CodeHashZero());
        require(_platforms.length > 0, NoPlatforms());
        for (uint256 i = 0; i < _platforms.length; i++) {
            require(systemSupportedPlatforms.contains(_platforms[i]), UnsupportedPlatform(_platforms[i]));
        }
        TeeExtension storage extension = extensions[_extensionId];
        require(extension.codeHashToVersion[_codeHash].platforms.length() == 0, VersionAlreadyExists());

        require(
            _governanceHash == bytes32(0) || teeGovernance.getLatestTeeGovernanceHash(_extensionId) == _governanceHash,
            InvalidGovernanceHash()
        );

        TeeVersion storage teeVersion = extension.codeHashToVersion[_codeHash];
        teeVersion.version = _version;
        for (uint256 i = 0; i < _platforms.length; i++) {
            require(teeVersion.platforms.add(_platforms[i]), PlatformAlreadyExists(_platforms[i]));
        }
        teeVersion.governanceHash = _governanceHash;
        emit TeeVersionAdded(_extensionId, _version, _codeHash, _platforms, _governanceHash);
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
        require(extension.codeHashToVersion[_codeHash].platforms.length() > 0, InvalidCodeHash());
        bytes32[] memory platforms = extension.codeHashToVersion[_codeHash].platforms.values();
        if (_platform != bytes32(0)) {
            for (uint256 i = 0; i < platforms.length; i++) {
                if (platforms[i] == _platform) {
                    extension.codeHashPlatformDisabled[_codeHash][_platform] = true;
                    emit CodeHashPlatformDisabled(_extensionId, _codeHash, _platform);
                    return;
                }
            }
            revert InvalidPlatform();
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
    function addSupportedKeyTypes(
        uint256 _extensionId,
        bytes32[] calldata _keyTypes
    )
        external onlyOwner(_extensionId)
    {
        TeeExtension storage extension = extensions[_extensionId];
        for (uint256 i = 0; i < _keyTypes.length; i++) {
            bytes32 keyType = _keyTypes[i];
            require(keyType != bytes32(0), KeyTypeEmpty());
            require(systemSupportedKeyTypes.contains(keyType), KeyTypeNotSupported(keyType));
            require(extension.supportedKeyTypes.add(keyType), KeyTypeAlreadyExists(keyType));
            emit SupportedKeyTypeAdded(_extensionId, keyType);
        }
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function removeSupportedKeyTypes(
        uint256 _extensionId,
        bytes32[] memory _keyTypes
    )
        external onlyOwner(_extensionId)
    {
        TeeExtension storage extension = extensions[_extensionId];
        for (uint256 i = 0; i < _keyTypes.length; i++) {
            bytes32 keyType = _keyTypes[i];
            require(extension.supportedKeyTypes.remove(keyType), KeyTypeNotSupported(keyType));
            emit SupportedKeyTypeRemoved(_extensionId, keyType);
        }
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function proposeNewOwner(uint256 _extensionId, address _newOwner)
        external onlyOwner(_extensionId)
    {
        require(_extensionId != 0, SystemOwnedExtensionId());
        proposedExtensionOwner[_extensionId] = _newOwner;
        emit NewOwnerProposed(_extensionId, msg.sender, _newOwner);
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function confirmOwnership(uint256 _extensionId)
        external
    {
        require(proposedExtensionOwner[_extensionId] == msg.sender, OnlyProposedOwner());
        extensions[_extensionId].owner = msg.sender;
        delete proposedExtensionOwner[_extensionId];
        emit NewOwnerConfirmed(_extensionId, msg.sender);
    }

    /**
     * Add system supported platforms.
     * @param _platforms List of platforms to add.
     * @dev Only governance can call this method.
     */
    function addSystemSupportedPlatforms(bytes32[] calldata _platforms)
        external onlyGovernance
    {
        for (uint256 i = 0; i < _platforms.length; i++) {
            require(_platforms[i] != bytes32(0), PlatformEmpty());
            require(systemSupportedPlatforms.add(_platforms[i]), PlatformAlreadyExists(_platforms[i]));
            emit SystemSupportedPlatformAdded(_platforms[i]);
        }
    }

    /**
     * Add system supported key types and signing algorithms.
     * @param _keyTypes List of key types to add.
     * @param _signingAlgosByKeyType List of signing algorithms for each key type.
     * @dev Only governance can call this method.
     */
    function addSystemSupportedKeyTypesAndSigningAlgos(
        bytes32[] calldata _keyTypes,
        bytes32[][] calldata _signingAlgosByKeyType
    )
        external onlyGovernance
    {
        require(_keyTypes.length == _signingAlgosByKeyType.length, LengthsMismatch());
        for (uint256 i = 0; i < _keyTypes.length; i++) {
            bytes32 keyType = _keyTypes[i];
            require(keyType != bytes32(0), KeyTypeEmpty());
            bytes32[] calldata signingAlgos = _signingAlgosByKeyType[i];
            require(signingAlgos.length > 0, NoSigningAlgos(keyType));
            systemSupportedKeyTypes.add(keyType);

            for (uint256 j = 0; j < signingAlgos.length; j++) {
                bytes32 signingAlgo = signingAlgos[j];
                require(signingAlgo != bytes32(0), SigningAlgoEmpty());
                require(
                    systemSupportedSigningAlgos[keyType].add(signingAlgo),
                    SigningAlgoAlreadyExists(keyType, signingAlgo)
                );
                emit SystemSupportedKeyTypeAndSigningAlgoAdded(keyType, signingAlgo);
            }
        }
    }

    /**
     * Register system instructions sender contracts.
     * @param _instructionsSenders List of contracts to register.
     * @dev Only governance can call this method.
     */
    function registerSystemInstructionsSenders(
        address[] calldata _instructionsSenders
    )
        external onlyGovernance
    {
        for (uint256 i = 0; i < _instructionsSenders.length; ++i) {
            systemInstructionsSenders.add(_instructionsSenders[i]);
        }
    }

    /**
     * Unregister system instructions sender contracts.
     * @param _instructionsSenders List of contracts to unregister.
     * @dev Only governance can call this method.
     */
    function unregisterSystemInstructionsSenders(
        address[] calldata _instructionsSenders
    )
        external onlyGovernance
    {
        for (uint256 i = 0; i < _instructionsSenders.length; ++i) {
            systemInstructionsSenders.remove(_instructionsSenders[i]);
        }
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function getSystemSupportedPlatforms() external view returns(bytes32[] memory) {
        return systemSupportedPlatforms.values();
    }

    /**
    * @inheritdoc ITeeExtensionRegistry
    */
    function getSystemSupportedKeyTypes() external view returns(bytes32[] memory) {
        return systemSupportedKeyTypes.values();
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function getSystemSupportedSigningAlgos(bytes32 _keyType) external view returns(bytes32[] memory) {
        return systemSupportedSigningAlgos[_keyType].values();
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function getSystemInstructionsSenders() external view returns(address[] memory) {
        return systemInstructionsSenders.values();
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
    function isSigningAlgoSupported(
        bytes32 _keyType,
        bytes32 _signingAlgo
    )
        external view
        returns (bool)
    {
        return systemSupportedSigningAlgos[_keyType].contains(_signingAlgo);
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function getSupportedKeyTypes(
        uint256 _extensionId
    )
        external view
        returns (bytes32[] memory _supportedKeyTypes)
    {
        return extensions[_extensionId].supportedKeyTypes.values();
    }

    /**
     * @inheritdoc ITeeExtensionRegistry
     */
    function isKeyTypeSupported(
        uint256 _extensionId,
        bytes32 _keyType
    )
        external view
        returns (bool)
    {
        return extensions[_extensionId].supportedKeyTypes.contains(_keyType);
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
    function isCodeHashPlatformDisabled(
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
     * Internal function to send instructions to TEE machines.
     */
    function _sendInstructions(
        bytes32 _instructionId,
        ITeeMachineRegistry.TeeMachine[] memory _teeMachines,
        bytes32 _opType,
        bytes32 _opCommand,
        bytes memory _message,
        address[] memory _cosigners,
        uint64 _cosignersThreshold
    )
        internal
    {
        require(_instructionId != bytes32(0), InstructionIdEmpty());
        require(_teeMachines.length > 0, NoTeeMachinesSpecified());
        require(_opType != bytes32(0), OperationTypeEmpty());
        require(_opCommand != bytes32(0), OperationCommandEmpty());
        require(_message.length > 0, MessageEmpty());
        require(_cosignersThreshold <= _cosigners.length, CosignersThresholdTooHigh());
        address[] memory teeIds = new address[](_teeMachines.length);
        uint256 extensionId = teeMachineRegistry.getExtensionId(_teeMachines[0].teeId);
        bool isSystemOpType = _isSystemOpType(_opType);
        for (uint256 i = 0; i < _teeMachines.length; i++) {
            address teeId = _teeMachines[i].teeId;
            require(i == 0 || teeMachineRegistry.getExtensionId(teeId) == extensionId, ExtensionIdMismatch());
            // some system operation types can be executed on non-production TEEs - status checked elsewhere
            if (!isSystemOpType) {
                require(
                    teeMachineRegistry.getTeeMachineStatus(teeId) == ITeeMachineRegistry.TeeStatus.PRODUCTION,
                    TeeMachineNotAvailable()
                );
            }
            teeIds[i] = teeId;
        }
        if (!systemInstructionsSenders.contains(msg.sender)) {
            require(msg.sender == extensions[extensionId].instructionsSender, OnlyInstructionsSender());
            require(extensionId == 0 || !isSystemOpType, SystemOpTypeNotAllowed(_opType));
        }

        // Check fee
        require(teeFeeCalculator.calculateFeeByTeeIds(_opType, _opCommand, teeIds) <= msg.value, FeeTooLow());

        // send fee to the reward manager
        uint24 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        rewardManager.receiveRewards{value: msg.value}(currentRewardEpochId, false);

        // emit the event
        emit TeeInstructionsSent(
            extensionId,
            _instructionId,
            currentRewardEpochId,
            _teeMachines,
            _opType,
            _opCommand,
            _message,
            _cosigners,
            _cosignersThreshold,
            msg.value
        );
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
        require(msg.sender == _getExtensionOwner(_extensionId), OnlyOwner());
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

    function _removeDuplicates(address[] memory _teeIds) internal pure {
        uint256 length = _teeIds.length;
        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = i + 1; j < length; j++) {
                if (_teeIds[i] == _teeIds[j]) {
                    // move the last element to the current position
                    _teeIds[j] = _teeIds[length - 1];
                    // reduce the array size
                    length--;
                    // check the new element at position j
                    j--;
                }
            }
        }
        // resize the array to the new length which is <= original length, which is always safe
        // this is done using inline assembly as Solidity does not provide a way to resize memory arrays
        // solhint-disable-next-line no-inline-assembly
        assembly { mstore(_teeIds, length) }
    }
}
