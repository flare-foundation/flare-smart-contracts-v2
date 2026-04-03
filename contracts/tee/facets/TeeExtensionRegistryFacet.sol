// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IITeeExtensionRegistryFacet } from "../interface/IITeeExtensionRegistryFacet.sol";
import { ITeeExtensionRegistryFacet } from "../../userInterfaces/tee/ITeeExtensionRegistryFacet.sol";
import { ITeeExtensionStateVerifier } from "../../userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { ITeeMachineRegistryFacet } from "../../userInterfaces/tee/ITeeMachineRegistryFacet.sol";
import { TeeExtensionRegistry } from "../library/TeeExtensionRegistry.sol";
import { TeeMachineRegistry } from "../library/TeeMachineRegistry.sol";
import { TeeGovernance } from "../library/TeeGovernance.sol";
import { TeeInstructionSender } from "../library/TeeInstructionSender.sol";
import { GovernedFacet } from "./GovernedFacet.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title TeeExtensionRegistryFacet
 * @notice Facet for TEE extension registration and instruction routing.
 */
contract TeeExtensionRegistryFacet is IITeeExtensionRegistryFacet, GovernedFacet {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc ITeeExtensionRegistryFacet
    function sendInstructions(
        address[] memory _teeIds,
        TeeInstructionParams memory _instructionParams
    )
        external payable
        returns (bytes32)
    {
        TeeExtensionRegistry.removeDuplicates(_teeIds);
        ITeeMachineRegistryFacet.TeeMachine[] memory teeMachines =
            new ITeeMachineRegistryFacet.TeeMachine[](_teeIds.length);
        for (uint256 i = 0; i < _teeIds.length; i++) {
            teeMachines[i] = TeeMachineRegistry.getTeeMachine(_teeIds[i]);
        }
        // Validate sender for non-system callers
        require(teeMachines.length > 0, NoTeeMachinesSpecified());
        uint256 extensionId = TeeMachineRegistry.getExtensionId(teeMachines[0].teeId);
        if (!TeeExtensionRegistry.isSystemInstructionsSender(msg.sender)) {
            require(
                msg.sender == TeeExtensionRegistry.getExtensionInstructionsSender(extensionId),
                OnlyInstructionsSender()
            );
            require(
                extensionId == 0 || !TeeExtensionRegistry.isSystemOpType(_instructionParams.opType),
                SystemOpTypeNotAllowed(_instructionParams.opType)
            );
        }
        return TeeInstructionSender.sendInstructions(bytes32(0), teeMachines, _instructionParams);
    }

    /// @inheritdoc IITeeExtensionRegistryFacet
    function sendSystemInstructions(
        bytes32 _instructionId,
        address[] memory _teeIds,
        TeeInstructionParams memory _instructionParams
    )
        external payable
        returns (bytes32)
    {
        require(
            TeeExtensionRegistry.isSystemInstructionsSender(msg.sender),
            OnlySystemInstructionsSender()
        );
        TeeExtensionRegistry.removeDuplicates(_teeIds);
        ITeeMachineRegistryFacet.TeeMachine[] memory teeMachines =
            new ITeeMachineRegistryFacet.TeeMachine[](_teeIds.length);
        for (uint256 i = 0; i < _teeIds.length; i++) {
            teeMachines[i] = TeeMachineRegistry.getTeeMachine(_teeIds[i]);
        }
        return TeeInstructionSender.sendInstructions(_instructionId, teeMachines, _instructionParams);
    }

    /// @inheritdoc IITeeExtensionRegistryFacet
    function sendSystemInstructions(
        bytes32 _instructionId,
        ITeeMachineRegistryFacet.TeeMachine[] memory _teeMachines,
        TeeInstructionParams memory _instructionParams
    )
        external payable
        returns (bytes32)
    {
        require(
            TeeExtensionRegistry.isSystemInstructionsSender(msg.sender),
            OnlySystemInstructionsSender()
        );
        return TeeInstructionSender.sendInstructions(_instructionId, _teeMachines, _instructionParams);
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function register(
        ITeeExtensionStateVerifier _teeExtensionStateVerifier,
        address _teeExtensionInstructionsSender
    )
        external
        returns (uint256 _extensionId)
    {
        require(_teeExtensionInstructionsSender != address(0), InvalidInstructionsSender());
        TeeExtensionRegistry.State storage s = TeeExtensionRegistry.getState();
        _extensionId = s.extensionsCounter++;
        TeeExtensionRegistry.TeeExtension storage newExtension = s.extensions[_extensionId];
        newExtension.owner = msg.sender;
        newExtension.stateVerifier = _teeExtensionStateVerifier;
        newExtension.instructionsSender = _teeExtensionInstructionsSender;
        emit TeeExtensionRegistered(_extensionId, msg.sender);
        emit TeeExtensionContractsSet(_extensionId, _teeExtensionStateVerifier, _teeExtensionInstructionsSender);
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function setExtensionContracts(
        uint256 _extensionId,
        ITeeExtensionStateVerifier _teeExtensionStateVerifier,
        address _teeExtensionInstructionsSender
    )
        external
    {
        TeeExtensionRegistry.checkOnlyExtensionOwner(_extensionId);
        require(_extensionId != 0, SystemOwnedExtensionId());
        require(_teeExtensionInstructionsSender != address(0), InvalidInstructionsSender());
        TeeExtensionRegistry.TeeExtension storage extension =
            TeeExtensionRegistry.getState().extensions[_extensionId];
        extension.stateVerifier = _teeExtensionStateVerifier;
        extension.instructionsSender = _teeExtensionInstructionsSender;
        emit TeeExtensionContractsSet(
            _extensionId, _teeExtensionStateVerifier, _teeExtensionInstructionsSender
        );
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function addTeeVersion(
        uint256 _extensionId,
        string calldata _version,
        bytes32 _codeHash,
        bytes32[] calldata _platforms,
        bytes32 _governanceHash
    )
        external
    {
        TeeExtensionRegistry.checkOnlyExtensionOwner(_extensionId);
        require(bytes(_version).length > 0, VersionEmpty());
        require(_codeHash != bytes32(0), CodeHashZero());
        require(_platforms.length > 0, NoPlatforms());
        for (uint256 i = 0; i < _platforms.length; i++) {
            require(TeeExtensionRegistry.isSystemSupportedPlatform(_platforms[i]), UnsupportedPlatform(_platforms[i]));
        }
        require(
            _governanceHash == bytes32(0) ||
                TeeGovernance.getLatestTeeGovernanceHash(_extensionId) == _governanceHash,
            InvalidGovernanceHash()
        );

        TeeExtensionRegistry.TeeExtension storage extension =
            TeeExtensionRegistry.getState().extensions[_extensionId];
        require(extension.supportedCodeHashes.add(_codeHash), VersionAlreadyExists());
        TeeExtensionRegistry.TeeVersion storage teeVersion = extension.codeHashToVersion[_codeHash];
        teeVersion.version = _version;
        for (uint256 i = 0; i < _platforms.length; i++) {
            require(teeVersion.platforms.add(_platforms[i]), PlatformAlreadyExists(_platforms[i]));
        }
        teeVersion.governanceHash = _governanceHash;
        emit TeeVersionAdded(_extensionId, _version, _codeHash, _platforms, _governanceHash);
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function disableCodeHashPlatform(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external
    {
        TeeExtensionRegistry.checkOnlyExtensionOwner(_extensionId);
        TeeExtensionRegistry.TeeExtension storage extension =
            TeeExtensionRegistry.getState().extensions[_extensionId];
        require(extension.codeHashToVersion[_codeHash].platforms.length() > 0, InvalidCodeHash());
        bytes32[] memory platforms = extension.codeHashToVersion[_codeHash].platforms.values();
        if (_platform != bytes32(0)) {
            for (uint256 i = 0; i < platforms.length; i++) {
                if (platforms[i] == _platform) {
                    require(
                        !extension.codeHashPlatformDisabled[_codeHash][_platform],
                        CodeHashPlatformAlreadyDisabled()
                    );
                    extension.codeHashPlatformDisabled[_codeHash][_platform] = true;
                    emit CodeHashPlatformDisabled(_extensionId, _codeHash, _platform);
                    return;
                }
            }
            revert InvalidPlatform();
        } else {
            for (uint256 i = 0; i < platforms.length; i++) {
                if (extension.codeHashPlatformDisabled[_codeHash][platforms[i]]) {
                    continue;
                }
                extension.codeHashPlatformDisabled[_codeHash][platforms[i]] = true;
                emit CodeHashPlatformDisabled(_extensionId, _codeHash, platforms[i]);
            }
        }
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function addSupportedKeyTypes(
        uint256 _extensionId,
        bytes32[] calldata _keyTypes
    )
        external
    {
        TeeExtensionRegistry.checkOnlyExtensionOwner(_extensionId);
        TeeExtensionRegistry.TeeExtension storage extension =
            TeeExtensionRegistry.getState().extensions[_extensionId];
        for (uint256 i = 0; i < _keyTypes.length; i++) {
            bytes32 keyType = _keyTypes[i];
            require(keyType != bytes32(0), KeyTypeEmpty());
            require(TeeExtensionRegistry.isSystemSupportedKeyType(keyType), KeyTypeNotSupported(keyType));
            require(extension.supportedKeyTypes.add(keyType), KeyTypeAlreadyExists(keyType));
        }
        emit SupportedKeyTypesAdded(_extensionId, _keyTypes);
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function removeSupportedKeyTypes(
        uint256 _extensionId,
        bytes32[] memory _keyTypes
    )
        external
    {
        TeeExtensionRegistry.checkOnlyExtensionOwner(_extensionId);
        TeeExtensionRegistry.TeeExtension storage extension =
            TeeExtensionRegistry.getState().extensions[_extensionId];
        for (uint256 i = 0; i < _keyTypes.length; i++) {
            bytes32 keyType = _keyTypes[i];
            require(extension.supportedKeyTypes.remove(keyType), KeyTypeNotSupported(keyType));
        }
        emit SupportedKeyTypesRemoved(_extensionId, _keyTypes);
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function proposeNewOwner(
        uint256 _extensionId,
        address _newOwner
    )
        external
    {
        TeeExtensionRegistry.checkOnlyExtensionOwner(_extensionId);
        require(_extensionId != 0, SystemOwnedExtensionId());
        TeeExtensionRegistry.getState().proposedExtensionOwner[_extensionId] = _newOwner;
        emit NewOwnerProposed(_extensionId, msg.sender, _newOwner);
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function confirmOwnership(
        uint256 _extensionId
    )
        external
    {
        TeeExtensionRegistry.State storage s = TeeExtensionRegistry.getState();
        require(s.proposedExtensionOwner[_extensionId] == msg.sender, OnlyProposedOwner());
        s.extensions[_extensionId].owner = msg.sender;
        delete s.proposedExtensionOwner[_extensionId];
        emit NewOwnerConfirmed(_extensionId, msg.sender);
    }

    /// @inheritdoc IITeeExtensionRegistryFacet
    function addSystemSupportedPlatforms(
        bytes32[] calldata _platforms
    )
        external
        onlyGovernance
    {
        TeeExtensionRegistry.State storage s = TeeExtensionRegistry.getState();
        for (uint256 i = 0; i < _platforms.length; i++) {
            require(_platforms[i] != bytes32(0), PlatformEmpty());
            require(s.systemSupportedPlatforms.add(_platforms[i]), PlatformAlreadyExists(_platforms[i]));
        }
        emit SystemSupportedPlatformsAdded(_platforms);
    }

    /// @inheritdoc IITeeExtensionRegistryFacet
    function addSystemSupportedKeyTypesAndSigningAlgos(
        bytes32[] calldata _keyTypes,
        bytes32[][] calldata _signingAlgosByKeyType
    )
        external
        onlyGovernance
    {
        require(_keyTypes.length == _signingAlgosByKeyType.length, LengthsMismatch());
        TeeExtensionRegistry.State storage s = TeeExtensionRegistry.getState();
        for (uint256 i = 0; i < _keyTypes.length; i++) {
            bytes32 keyType = _keyTypes[i];
            require(keyType != bytes32(0), KeyTypeEmpty());
            bytes32[] calldata signingAlgos = _signingAlgosByKeyType[i];
            require(signingAlgos.length > 0, NoSigningAlgos(keyType));
            s.systemSupportedKeyTypes.add(keyType);

            for (uint256 j = 0; j < signingAlgos.length; j++) {
                bytes32 signingAlgo = signingAlgos[j];
                require(signingAlgo != bytes32(0), SigningAlgoEmpty());
                require(
                    s.systemSupportedSigningAlgos[keyType].add(signingAlgo),
                    SigningAlgoAlreadyExists(keyType, signingAlgo)
                );
            }
        }
        emit SystemSupportedKeyTypesAndSigningAlgosAdded(_keyTypes, _signingAlgosByKeyType);
    }

    /// @inheritdoc IITeeExtensionRegistryFacet
    function registerSystemInstructionsSenders(
        address[] calldata _instructionsSenders
    )
        external
        onlyGovernance
    {
        TeeExtensionRegistry.State storage s = TeeExtensionRegistry.getState();
        for (uint256 i = 0; i < _instructionsSenders.length; ++i) {
            require(_instructionsSenders[i] != address(0), InvalidInstructionsSender());
            require(
                s.systemInstructionsSenders.add(_instructionsSenders[i]),
                SystemInstructionsSenderAlreadyExists(_instructionsSenders[i])
            );
        }
        emit SystemInstructionsSendersRegistered(_instructionsSenders);
    }

    /// @inheritdoc IITeeExtensionRegistryFacet
    function unregisterSystemInstructionsSenders(
        address[] calldata _instructionsSenders
    )
        external
        onlyGovernance
    {
        TeeExtensionRegistry.State storage s = TeeExtensionRegistry.getState();
        for (uint256 i = 0; i < _instructionsSenders.length; ++i) {
            require(
                s.systemInstructionsSenders.remove(_instructionsSenders[i]),
                SystemInstructionsSenderNotFound(_instructionsSenders[i])
            );
        }
        emit SystemInstructionsSendersUnregistered(_instructionsSenders);
    }

    // =========================================================================
    // Getters
    // =========================================================================

    /// @inheritdoc ITeeExtensionRegistryFacet
    function extensionsCounter()
        external view
        returns (uint256)
    {
        return TeeExtensionRegistry.getState().extensionsCounter;
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function getSystemSupportedPlatforms()
        external view
        returns (bytes32[] memory)
    {
        return TeeExtensionRegistry.getState().systemSupportedPlatforms.values();
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function getSystemSupportedKeyTypes()
        external view
        returns (bytes32[] memory)
    {
        return TeeExtensionRegistry.getState().systemSupportedKeyTypes.values();
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function getSystemSupportedSigningAlgos(
        bytes32 _keyType
    )
        external view
        returns (bytes32[] memory)
    {
        return TeeExtensionRegistry.getState().systemSupportedSigningAlgos[_keyType].values();
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function getSystemInstructionsSenders()
        external view
        returns (address[] memory)
    {
        return TeeExtensionRegistry.getState().systemInstructionsSenders.values();
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function getExtensionOwner(
        uint256 _extensionId
    )
        external view
        returns (address)
    {
        return TeeExtensionRegistry.getExtensionOwner(_extensionId);
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function getTeeExtensionStateVerifier(
        uint256 _extensionId
    )
        external view
        returns (ITeeExtensionStateVerifier)
    {
        return TeeExtensionRegistry.getTeeExtensionStateVerifier(_extensionId);
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function getTeeExtensionInstructionsSender(
        uint256 _extensionId
    )
        external view
        returns (address)
    {
        return TeeExtensionRegistry.getExtensionInstructionsSender(_extensionId);
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function isSigningAlgoSupported(
        bytes32 _keyType,
        bytes32 _signingAlgo
    )
        external view
        returns (bool)
    {
        return TeeExtensionRegistry.isSigningAlgoSupported(_keyType, _signingAlgo);
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function getSupportedKeyTypes(
        uint256 _extensionId
    )
        external view
        returns (bytes32[] memory _supportedKeyTypes)
    {
        return TeeExtensionRegistry.getState().extensions[_extensionId].supportedKeyTypes.values();
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function isKeyTypeSupported(
        uint256 _extensionId,
        bytes32 _keyType
    )
        external view
        returns (bool)
    {
        return TeeExtensionRegistry.isKeyTypeSupported(_extensionId, _keyType);
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function getSupportedCodeHashes(
        uint256 _extensionId
    )
        external view
        returns (bytes32[] memory _supportedCodeHashes)
    {
        return TeeExtensionRegistry.getState().extensions[_extensionId].supportedCodeHashes.values();
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function isCodeHashPlatformSupported(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external view
        returns (bool)
    {
        return TeeExtensionRegistry.isCodeHashPlatformSupported(_extensionId, _codeHash, _platform);
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function isCodeHashPlatformDisabled(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external view
        returns (bool)
    {
        return TeeExtensionRegistry.isCodeHashPlatformDisabled(_extensionId, _codeHash, _platform);
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function getTeeGovernanceHash(
        uint256 _extensionId,
        bytes32 _codeHash
    )
        external view
        returns (bytes32)
    {
        return TeeExtensionRegistry.getTeeGovernanceHash(_extensionId, _codeHash);
    }

    /// @inheritdoc ITeeExtensionRegistryFacet
    function getCodeHashInfo(
        uint256 _extensionId,
        bytes32 _codeHash
    )
        external view
        returns (
            bytes32 _governanceHash,
            string memory _version,
            bytes32[] memory _platforms
        )
    {
        TeeExtensionRegistry.TeeExtension storage extension =
            TeeExtensionRegistry.getState().extensions[_extensionId];
        _governanceHash = extension.codeHashToVersion[_codeHash].governanceHash;
        _version = extension.codeHashToVersion[_codeHash].version;
        _platforms = extension.codeHashToVersion[_codeHash].platforms.values();
    }
}
