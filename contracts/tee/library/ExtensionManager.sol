// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { ITeeExtensionStateVerifier } from "../../userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { FlareGovernance } from "./FlareGovernance.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title ExtensionManager
 * @notice Library for TEE extension registration and instruction routing.
 * @dev Uses ERC-7201 namespaced storage. Contains only logic that is
 *      reused by other libraries/facets. Registration setters and instruction
 *      routing live in ExtensionManagerFacet directly.
 */
library ExtensionManager {
    using EnumerableSet for EnumerableSet.Bytes32Set;

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

        // Supported code hashes.
        EnumerableSet.Bytes32Set supportedCodeHashes;
    }

    /// @custom:storage-location erc7201:tee.ExtensionManager.State
    struct State {
        /// List of system supported platforms.
        EnumerableSet.Bytes32Set systemSupportedPlatforms;
        /// List of system supported key types.
        EnumerableSet.Bytes32Set systemSupportedKeyTypes;
        /// Signing algorithms per key type.
        mapping(bytes32 keyType => EnumerableSet.Bytes32Set) systemSupportedSigningAlgos;
        /// Extensions counter.
        uint256 extensionsCounter;
        /// Extension data.
        mapping(uint256 extensionId => TeeExtension) extensions;
        /// Proposed new extension owner.
        mapping(uint256 extensionId => address) proposedExtensionOwner;
    }

    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("tee.ExtensionManager.State")) - 1)
    ) & ~bytes32(uint256(0xff));

    function getExtensionOwner(
        uint256 _extensionId
    )
        internal view
        returns (address)
    {
        if (_extensionId == 0) {
            return FlareGovernance.governance();
        }
        return getState().extensions[_extensionId].owner;
    }

    function checkOnlyExtensionOwner(
        uint256 _extensionId
    )
        internal view
    {
        require(
            msg.sender == getExtensionOwner(_extensionId),
            ITeeCommonErrors.OnlyExtensionOwner()
        );
    }

    function isCodeHashPlatformDisabled(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        internal view
        returns (bool)
    {
        return getState().extensions[_extensionId].codeHashPlatformDisabled[_codeHash][_platform];
    }

    function getTeeGovernanceHash(
        uint256 _extensionId,
        bytes32 _codeHash
    )
        internal view
        returns (bytes32)
    {
        return getState().extensions[_extensionId].codeHashToVersion[_codeHash].governanceHash;
    }

    function isCodeHashPlatformSupported(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        internal view
        returns (bool)
    {
        State storage s = getState();
        if (s.extensions[_extensionId].codeHashPlatformDisabled[_codeHash][_platform]) {
            return false;
        }
        return s.extensions[_extensionId].codeHashToVersion[_codeHash].platforms.contains(_platform);
    }

    function isKeyTypeSupported(
        uint256 _extensionId,
        bytes32 _keyType
    )
        internal view
        returns (bool)
    {
        return getState().extensions[_extensionId].supportedKeyTypes.contains(_keyType);
    }

    function isSigningAlgoSupported(
        bytes32 _keyType,
        bytes32 _signingAlgo
    )
        internal view
        returns (bool)
    {
        return getState().systemSupportedSigningAlgos[_keyType].contains(_signingAlgo);
    }

    function getTeeExtensionStateVerifier(
        uint256 _extensionId
    )
        internal view
        returns (ITeeExtensionStateVerifier)
    {
        return getState().extensions[_extensionId].stateVerifier;
    }

    function getExtensionInstructionsSender(
        uint256 _extensionId
    )
        internal view
        returns (address)
    {
        return getState().extensions[_extensionId].instructionsSender;
    }

    function isSystemSupportedPlatform(
        bytes32 _platform
    )
        internal view
        returns (bool)
    {
        return getState().systemSupportedPlatforms.contains(_platform);
    }

    function isSystemSupportedKeyType(
        bytes32 _keyType
    )
        internal view
        returns (bool)
    {
        return getState().systemSupportedKeyTypes.contains(_keyType);
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
