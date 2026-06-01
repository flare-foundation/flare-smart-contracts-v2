// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeExtensionStateVerifier } from "./ITeeExtensionStateVerifier.sol";
import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";

/**
 * @title IExtensionManager
 * @notice Public interface for the ExtensionManagerFacet.
 */
interface IExtensionManager is ITeeCommonErrors {

    event TeeExtensionRegistered(
        uint256 indexed extensionId,
        address indexed owner
    );

    event TeeExtensionContractsSet(
        uint256 indexed extensionId,
        ITeeExtensionStateVerifier indexed teeExtensionStateVerifier,
        address indexed teeExtensionInstructionsSender
    );

    event SystemSupportedPlatformsAdded(
        bytes32[] platforms
    );

    event SystemSupportedKeyTypesAndSigningAlgosAdded(
        bytes32[] keyTypes,
        bytes32[][] _signingAlgosByKeyType
    );

    event TeeVersionAdded(
        uint256 indexed extensionId,
        bytes32 version,
        bytes32 indexed codeHash,
        bytes32[] platforms
    );

    event CodeHashPlatformDisabled(
        uint256 indexed extensionId,
        bytes32 indexed codeHash,
        bytes32 indexed platform
    );

    event SupportedKeyTypesAdded(
        uint256 indexed extensionId,
        bytes32[] keyTypes
    );

    event SupportedKeyTypesRemoved(
        uint256 indexed extensionId,
        bytes32[] keyTypes
    );

    event NewOwnerProposed(
        uint256 indexed extensionId,
        address indexed oldOwner,
        address indexed newOwner
    );

    event NewOwnerConfirmed(
        uint256 indexed extensionId,
        address indexed newOwner
    );

    event ExtensionOperatorSet(
        uint256 indexed extensionId,
        address indexed oldOperator,
        address indexed newOperator
    );

    error InvalidInstructionsSender();
    error VersionEmpty();
    error CodeHashZero();
    error NoPlatforms();
    error UnsupportedPlatform(bytes32 platform);
    error VersionAlreadyExists();
    error PlatformAlreadyExists(bytes32 platform);
    error InvalidCodeHash();
    error CodeHashPlatformAlreadyDisabled();
    error InvalidPlatform();
    error SystemOwnedExtensionId();
    error PlatformEmpty();
    error KeyTypeEmpty();
    error KeyTypeAlreadyExists(bytes32 keyType);
    error NoSigningAlgos(bytes32 keyType);
    error SigningAlgoEmpty();
    error SigningAlgoAlreadyExists(bytes32 keyType, bytes32 signingAlgo);
    error InvalidReservedExtensionId();
    error ReservedExtensionIdAlreadyAssigned();
    error InvalidExtensionOwner();
    error NotAllowedExtensionOwner();

    /**
     * Register a new public TEE extension.
     * The caller must be on the global extension-owner allowlist (governed via
     * IOwnerAllowlist.addAllowedExtensionOwners / allowAllExtensionOwners).
     * The assigned id starts from `type(uint16).max + 1` (= 65536); lower ids
     * are reserved for governance-minted extensions (see registerReserved).
     * Emits TeeExtensionRegistered and TeeExtensionContractsSet events.
     * @param _teeExtensionStateVerifier The TEE extension state verifier contract.
     * @param _teeExtensionInstructionsSender The address that can send instructions to the TEE machines.
     * @return _extensionId The id of the registered extension.
     */
    function register(
        ITeeExtensionStateVerifier _teeExtensionStateVerifier,
        address _teeExtensionInstructionsSender
    )
        external
        returns (uint256 _extensionId);

    /**
     * Mint a reserved TEE extension with id in `[1, type(uint16).max]`.
     * Governance picks both the id and the initial owner. The extension's
     * verifier and instructions-sender are NOT set here — the owner must call
     * setExtensionContracts before the extension is operational.
     * Subsequent ownership transfer follows the same allowlist gating as
     * public extensions (proposeNewOwner / confirmOwnership require the
     * target to be on the global extension-owner allowlist).
     * Emits TeeExtensionRegistered event.
     * @param _extensionId The reserved id to mint (must satisfy 0 < id < 65536).
     * @param _owner The initial owner address (must be non-zero).
     * Can only be called by the immediate governance address.
     */
    function registerReserved(
        uint256 _extensionId,
        address _owner
    )
        external;

    /**
     * Set the extension contracts for a given extension id.
     * Emits TeeExtensionContractsSet event.
     * @param _extensionId The id of the extension.
     * @param _teeExtensionStateVerifier The TEE extension state verifier contract.
     * @param _teeExtensionInstructionsSender The address that can send instructions to the TEE machines.
     * Can only be called by the extension owner.
     */
    function setExtensionContracts(
        uint256 _extensionId,
        ITeeExtensionStateVerifier _teeExtensionStateVerifier,
        address _teeExtensionInstructionsSender
    )
        external;

    /**
     * Add a new TEE version.
     * Emits TeeVersionAdded event.
     * @param _extensionId The id of the extension.
     * @param _version The version (UTF-8 encoded name, for off-chain use only).
     * @param _codeHash The code hash.
     * @param _platforms The supported platforms.
     * Can only be called by the extension owner.
     */
    function addTeeVersion(
        uint256 _extensionId,
        bytes32 _version,
        bytes32 _codeHash,
        bytes32[] calldata _platforms
    )
        external;

    /**
     * Disable a TEE code hash and platform.
     * Emits CodeHashPlatformDisabled event.
     * @param _extensionId The id of the extension.
     * @param _codeHash The code hash.
     * @param _platform The platform to disable. If empty, all platforms will be disabled.
     * Can only be called by the extension owner.
     */
    function disableCodeHashPlatform(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external;

    /**
     * Add supported key types.
     * Emits SupportedKeyTypesAdded event.
     * @param _extensionId The id of the extension.
     * @param _keyTypes The key types to add.
     * Can only be called by the extension owner.
     */
    function addSupportedKeyTypes(
        uint256 _extensionId,
        bytes32[] calldata _keyTypes
    )
        external;

    /**
     * Remove supported key types.
     * Emits SupportedKeyTypesRemoved event.
     * @param _extensionId The id of the extension.
     * @param _keyTypes The key types to remove.
     * Can only be called by the extension owner.
     */
    function removeSupportedKeyTypes(
        uint256 _extensionId,
        bytes32[] memory _keyTypes
    )
        external;

    /**
     * It is a two-step process, the new owner has to confirm the ownership.
     * Emits NewOwnerProposed event.
     * @param _extensionId The id of the extension.
     * @param _newOwner The new owner address.
     * Can only be called by the current TEE extension owner.
     */
    function proposeNewOwner(
        uint256 _extensionId,
        address _newOwner
    )
        external;

    /**
     * Confirm the ownership of a TEE extension.
     * Emits NewOwnerConfirmed event.
     * @param _extensionId The id of the extension.
     * Can only be called by the proposed new owner.
     */
    function confirmOwnership(
        uint256 _extensionId
    )
        external;

    /**
     * Set (or clear, by passing `address(0)`) the optional extension operator.
     * The operator may call the *prep* steps for flows whose real security gate
     * is a downstream governance threshold signature: machine-path-list
     * lifecycle (createNewMachinePathList / addMachinePaths /
     * finalizeMachinePathList) and pausing-addresses record creation
     * (setTeePausingAddresses).
     *
     * Emits ExtensionOperatorSet event.
     * @param _extensionId The id of the extension.
     * @param _operator The new operator address, or `address(0)` to clear.
     * Can only be called by the extension owner.
     */
    function setExtensionOperator(
        uint256 _extensionId,
        address _operator
    )
        external;

    /**
     * Get the id that the next public `register()` call will assign.
     * Initialised to `type(uint16).max + 1` (= 65536) and incremented on each
     * successful public registration. Reserved ids (1..65535) do not flow
     * through this counter — they are picked explicitly by governance via
     * registerReserved.
     * @return The next public extension id.
     */
    function nextPublicExtensionId()
        external view
        returns (uint256);

    /**
     * Get system supported platforms.
     * @return The list of system supported platforms.
     */
    function getSystemSupportedPlatforms()
        external view
        returns (bytes32[] memory);

    /**
     * Get system supported key types.
     * @return The list of system supported key types.
     */
    function getSystemSupportedKeyTypes()
        external view
        returns (bytes32[] memory);

    /**
     * Get system supported signing algorithms for the given key type.
     * @param _keyType The key type.
     * @return The list of supported signing algorithms.
     */
    function getSystemSupportedSigningAlgos(
        bytes32 _keyType
    )
        external view
        returns (bytes32[] memory);

    /**
     * Get the owner of a TEE extension.
     * @param _extensionId The id of the extension.
     * @return The owner address.
     */
    function getExtensionOwner(
        uint256 _extensionId
    )
        external view
        returns (address);

    /**
     * Get the operator of a TEE extension.
     * @param _extensionId The id of the extension.
     * @return The operator address, or `address(0)` if no operator is set.
     */
    function getExtensionOperator(
        uint256 _extensionId
    )
        external view
        returns (address);

    /**
     * Get the TEE extension state verifier contract.
     * @param _extensionId The id of the extension.
     * @return The TEE extension state verifier contract address.
     */
    function getTeeExtensionStateVerifier(
        uint256 _extensionId
    )
        external view
        returns (ITeeExtensionStateVerifier);

    /**
     * Get the TEE extension instructions sender address.
     * @param _extensionId The id of the extension.
     * @return The TEE extension instructions sender address.
     */
    function getTeeExtensionInstructionsSender(
        uint256 _extensionId
    )
        external view
        returns (address);

    /**
     * Checks if the signing algorithm is supported for the given key type.
     * @param _keyType The key type.
     * @param _signingAlgo The signing algorithm.
     * @return True if the signing algorithm is supported.
     */
    function isSigningAlgoSupported(
        bytes32 _keyType,
        bytes32 _signingAlgo
    )
        external view
        returns (bool);

    /**
     * Returns supported wallet/project key types for the given extension.
     * @param _extensionId The id of the extension.
     * @return _supportedKeyTypes The supported key types.
     */
    function getSupportedKeyTypes(
        uint256 _extensionId
    )
        external view
        returns (bytes32[] memory _supportedKeyTypes);

    /**
     * Checks if the key type is supported for the given extension.
     * @param _extensionId The id of the extension.
     * @param _keyType The key type.
     * @return True if the key type is supported.
     */
    function isKeyTypeSupported(
        uint256 _extensionId,
        bytes32 _keyType
    )
        external view
        returns (bool);

    /**
     * Returns supported code hashes for the given extension.
     * @param _extensionId The id of the extension.
     * @return _supportedCodeHashes The supported code hashes.
     */
    function getSupportedCodeHashes(
        uint256 _extensionId
    )
        external view
        returns (bytes32[] memory _supportedCodeHashes);

    /**
     * Checks if the code hash and platform are supported for the given extension.
     * @param _extensionId The id of the extension.
     * @param _codeHash The code hash.
     * @param _platform The platform.
     * @return True if the code hash and platform are supported, false otherwise.
     */
    function isCodeHashPlatformSupported(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external view
        returns (bool);

    /**
     * Get the info if the code hash and platform pair is disabled for the given extension.
     * @param _extensionId The id of the extension.
     * @param _codeHash The code hash.
     * @param _platform The platform.
     */
    function isCodeHashPlatformDisabled(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external view
        returns (bool);

    /**
     * Returns the code hash info (version and platforms).
     * @param _extensionId The id of the extension.
     * @param _codeHash The code hash.
     * @return _version The version (UTF-8 encoded name, for off-chain use only).
     * @return _platforms The supported platforms.
     */
    function getCodeHashInfo(
        uint256 _extensionId,
        bytes32 _codeHash
    )
        external view
        returns (
            bytes32 _version,
            bytes32[] memory _platforms
        );
}
