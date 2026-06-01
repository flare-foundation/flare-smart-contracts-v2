// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IIExtensionManager } from "../interface/IIExtensionManager.sol";
import { IExtensionManager } from "../../userInterfaces/tee/IExtensionManager.sol";
import { ITeeExtensionStateVerifier } from "../../userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { ExtensionManager } from "../library/ExtensionManager.sol";
import { ExtensionGovernance } from "../library/ExtensionGovernance.sol";
import { OwnerAllowlist } from "../library/OwnerAllowlist.sol";
import { FlareGovernedAccess } from "../../governance/implementation/FlareGovernedAccess.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title ExtensionManagerFacet
 * @notice Facet for TEE extension registration and instruction routing.
 */
contract ExtensionManagerFacet is IIExtensionManager, FlareGovernedAccess {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @inheritdoc IExtensionManager
    function register(
        ITeeExtensionStateVerifier _teeExtensionStateVerifier,
        address _teeExtensionInstructionsSender
    )
        external
        returns (uint256 _extensionId)
    {
        require(OwnerAllowlist.isAllowedExtensionOwner(msg.sender), NotAllowedExtensionOwner());
        require(_teeExtensionInstructionsSender != address(0), InvalidInstructionsSender());
        ExtensionManager.State storage s = ExtensionManager.getState();
        _extensionId = s.nextPublicExtensionId++;
        ExtensionManager.TeeExtension storage newExtension = s.extensions[_extensionId];
        newExtension.owner = msg.sender;
        newExtension.stateVerifier = _teeExtensionStateVerifier;
        newExtension.instructionsSender = _teeExtensionInstructionsSender;
        emit TeeExtensionRegistered(_extensionId, msg.sender);
        emit TeeExtensionContractsSet(_extensionId, _teeExtensionStateVerifier, _teeExtensionInstructionsSender);
    }

    /// @inheritdoc IExtensionManager
    function registerReserved(
        uint256 _extensionId,
        address _owner
    )
        external
        onlyImmediateGovernance
    {
        require(
            _extensionId > 0 && _extensionId < ExtensionManager.PUBLIC_EXTENSION_ID_START,
            InvalidReservedExtensionId()
        );
        require(_owner != address(0), InvalidExtensionOwner());
        ExtensionManager.State storage s = ExtensionManager.getState();
        require(s.extensions[_extensionId].owner == address(0), ReservedExtensionIdAlreadyAssigned());
        s.extensions[_extensionId].owner = _owner;
        emit TeeExtensionRegistered(_extensionId, _owner);
    }

    /// @inheritdoc IExtensionManager
    function setExtensionContracts(
        uint256 _extensionId,
        ITeeExtensionStateVerifier _teeExtensionStateVerifier,
        address _teeExtensionInstructionsSender
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        require(_extensionId != 0, SystemOwnedExtensionId());
        require(_teeExtensionInstructionsSender != address(0), InvalidInstructionsSender());
        ExtensionManager.TeeExtension storage extension =
            ExtensionManager.getState().extensions[_extensionId];
        extension.stateVerifier = _teeExtensionStateVerifier;
        extension.instructionsSender = _teeExtensionInstructionsSender;
        emit TeeExtensionContractsSet(
            _extensionId, _teeExtensionStateVerifier, _teeExtensionInstructionsSender
        );
    }

    /// @inheritdoc IExtensionManager
    function addTeeVersion(
        uint256 _extensionId,
        bytes32 _version,
        bytes32 _codeHash,
        bytes32[] calldata _platforms
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        require(_version != bytes32(0), VersionEmpty());
        require(_codeHash != bytes32(0), CodeHashZero());
        require(_platforms.length > 0, NoPlatforms());
        for (uint256 i = 0; i < _platforms.length; i++) {
            require(ExtensionManager.isSystemSupportedPlatform(_platforms[i]), UnsupportedPlatform(_platforms[i]));
        }

        ExtensionManager.TeeExtension storage extension =
            ExtensionManager.getState().extensions[_extensionId];
        require(extension.supportedCodeHashes.add(_codeHash), VersionAlreadyExists());
        ExtensionManager.TeeVersion storage teeVersion = extension.codeHashToVersion[_codeHash];
        teeVersion.version = _version;
        for (uint256 i = 0; i < _platforms.length; i++) {
            require(teeVersion.platforms.add(_platforms[i]), PlatformAlreadyExists(_platforms[i]));
        }
        emit TeeVersionAdded(_extensionId, _version, _codeHash, _platforms);
    }

    /// @inheritdoc IExtensionManager
    function disableCodeHashPlatform(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        ExtensionManager.TeeExtension storage extension =
            ExtensionManager.getState().extensions[_extensionId];
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

    /// @inheritdoc IExtensionManager
    function addSupportedKeyTypes(
        uint256 _extensionId,
        bytes32[] calldata _keyTypes
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        ExtensionManager.TeeExtension storage extension =
            ExtensionManager.getState().extensions[_extensionId];
        for (uint256 i = 0; i < _keyTypes.length; i++) {
            bytes32 keyType = _keyTypes[i];
            require(keyType != bytes32(0), KeyTypeEmpty());
            require(ExtensionManager.isSystemSupportedKeyType(keyType), KeyTypeNotSupported(keyType));
            require(extension.supportedKeyTypes.add(keyType), KeyTypeAlreadyExists(keyType));
        }
        emit SupportedKeyTypesAdded(_extensionId, _keyTypes);
    }

    /// @inheritdoc IExtensionManager
    function removeSupportedKeyTypes(
        uint256 _extensionId,
        bytes32[] memory _keyTypes
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        ExtensionManager.TeeExtension storage extension =
            ExtensionManager.getState().extensions[_extensionId];
        for (uint256 i = 0; i < _keyTypes.length; i++) {
            bytes32 keyType = _keyTypes[i];
            require(extension.supportedKeyTypes.remove(keyType), KeyTypeNotSupported(keyType));
        }
        emit SupportedKeyTypesRemoved(_extensionId, _keyTypes);
    }

    /// @inheritdoc IExtensionManager
    function proposeNewOwner(
        uint256 _extensionId,
        address _newOwner
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        require(_extensionId != 0, SystemOwnedExtensionId());
        require(
            _newOwner == address(0) || OwnerAllowlist.isAllowedExtensionOwner(_newOwner),
            NotAllowedExtensionOwner()
        );
        ExtensionManager.getState().proposedExtensionOwner[_extensionId] = _newOwner;
        emit NewOwnerProposed(_extensionId, msg.sender, _newOwner);
    }

    /// @inheritdoc IExtensionManager
    function confirmOwnership(
        uint256 _extensionId
    )
        external
    {
        ExtensionManager.State storage s = ExtensionManager.getState();
        require(s.proposedExtensionOwner[_extensionId] == msg.sender, OnlyProposedOwner());
        require(OwnerAllowlist.isAllowedExtensionOwner(msg.sender), NotAllowedExtensionOwner());
        s.extensions[_extensionId].owner = msg.sender;
        delete s.proposedExtensionOwner[_extensionId];
        emit NewOwnerConfirmed(_extensionId, msg.sender);
    }

    /// @inheritdoc IExtensionManager
    function setExtensionOperator(
        uint256 _extensionId,
        address _operator
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        ExtensionManager.TeeExtension storage extension =
            ExtensionManager.getState().extensions[_extensionId];
        address oldOperator = extension.operator;
        extension.operator = _operator;
        emit ExtensionOperatorSet(_extensionId, oldOperator, _operator);
    }

    /// @inheritdoc IIExtensionManager
    function addSystemSupportedPlatforms(
        bytes32[] calldata _platforms
    )
        external
        onlyGovernance
    {
        ExtensionManager.State storage s = ExtensionManager.getState();
        for (uint256 i = 0; i < _platforms.length; i++) {
            require(_platforms[i] != bytes32(0), PlatformEmpty());
            require(s.systemSupportedPlatforms.add(_platforms[i]), PlatformAlreadyExists(_platforms[i]));
        }
        emit SystemSupportedPlatformsAdded(_platforms);
    }

    /// @inheritdoc IIExtensionManager
    function addSystemSupportedKeyTypesAndSigningAlgos(
        bytes32[] calldata _keyTypes,
        bytes32[][] calldata _signingAlgosByKeyType
    )
        external
        onlyGovernance
    {
        require(_keyTypes.length == _signingAlgosByKeyType.length, LengthsMismatch());
        ExtensionManager.State storage s = ExtensionManager.getState();
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

    // =========================================================================
    // Getters
    // =========================================================================

    /// @inheritdoc IExtensionManager
    function nextPublicExtensionId()
        external view
        returns (uint256)
    {
        return ExtensionManager.getState().nextPublicExtensionId;
    }

    /// @inheritdoc IExtensionManager
    function getSystemSupportedPlatforms()
        external view
        returns (bytes32[] memory)
    {
        return ExtensionManager.getState().systemSupportedPlatforms.values();
    }

    /// @inheritdoc IExtensionManager
    function getSystemSupportedKeyTypes()
        external view
        returns (bytes32[] memory)
    {
        return ExtensionManager.getState().systemSupportedKeyTypes.values();
    }

    /// @inheritdoc IExtensionManager
    function getSystemSupportedSigningAlgos(
        bytes32 _keyType
    )
        external view
        returns (bytes32[] memory)
    {
        return ExtensionManager.getState().systemSupportedSigningAlgos[_keyType].values();
    }

    /// @inheritdoc IExtensionManager
    function getExtensionOwner(
        uint256 _extensionId
    )
        external view
        returns (address)
    {
        return ExtensionManager.getExtensionOwner(_extensionId);
    }

    /// @inheritdoc IExtensionManager
    function getExtensionOperator(
        uint256 _extensionId
    )
        external view
        returns (address)
    {
        return ExtensionManager.getExtensionOperator(_extensionId);
    }

    /// @inheritdoc IExtensionManager
    function getTeeExtensionStateVerifier(
        uint256 _extensionId
    )
        external view
        returns (ITeeExtensionStateVerifier)
    {
        return ExtensionManager.getTeeExtensionStateVerifier(_extensionId);
    }

    /// @inheritdoc IExtensionManager
    function getTeeExtensionInstructionsSender(
        uint256 _extensionId
    )
        external view
        returns (address)
    {
        return ExtensionManager.getExtensionInstructionsSender(_extensionId);
    }

    /// @inheritdoc IExtensionManager
    function isSigningAlgoSupported(
        bytes32 _keyType,
        bytes32 _signingAlgo
    )
        external view
        returns (bool)
    {
        return ExtensionManager.isSigningAlgoSupported(_keyType, _signingAlgo);
    }

    /// @inheritdoc IExtensionManager
    function getSupportedKeyTypes(
        uint256 _extensionId
    )
        external view
        returns (bytes32[] memory _supportedKeyTypes)
    {
        return ExtensionManager.getState().extensions[_extensionId].supportedKeyTypes.values();
    }

    /// @inheritdoc IExtensionManager
    function isKeyTypeSupported(
        uint256 _extensionId,
        bytes32 _keyType
    )
        external view
        returns (bool)
    {
        return ExtensionManager.isKeyTypeSupported(_extensionId, _keyType);
    }

    /// @inheritdoc IExtensionManager
    function getSupportedCodeHashes(
        uint256 _extensionId
    )
        external view
        returns (bytes32[] memory _supportedCodeHashes)
    {
        return ExtensionManager.getState().extensions[_extensionId].supportedCodeHashes.values();
    }

    /// @inheritdoc IExtensionManager
    function isCodeHashPlatformSupported(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external view
        returns (bool)
    {
        return ExtensionManager.isCodeHashPlatformSupported(_extensionId, _codeHash, _platform);
    }

    /// @inheritdoc IExtensionManager
    function isCodeHashPlatformDisabled(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external view
        returns (bool)
    {
        return ExtensionManager.isCodeHashPlatformDisabled(_extensionId, _codeHash, _platform);
    }

    /// @inheritdoc IExtensionManager
    function getCodeHashInfo(
        uint256 _extensionId,
        bytes32 _codeHash
    )
        external view
        returns (
            bytes32 _version,
            bytes32[] memory _platforms
        )
    {
        ExtensionManager.TeeExtension storage extension =
            ExtensionManager.getState().extensions[_extensionId];
        _version = extension.codeHashToVersion[_codeHash].version;
        _platforms = extension.codeHashToVersion[_codeHash].platforms.values();
    }
}
