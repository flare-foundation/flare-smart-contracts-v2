// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeExtensionStateVerifier } from "./ITeeExtensionStateVerifier.sol";
import { ITeeMachineRegistryFacet } from "./ITeeMachineRegistryFacet.sol";
import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";

/**
 * @title ITeeExtensionRegistryFacet
 * @notice Public interface for the TeeExtensionRegistryFacet.
 */
interface ITeeExtensionRegistryFacet is ITeeCommonErrors {

    /**
     * Struct containing the instruction parameters.
     * @param opType The operation type.
     * @param opCommand The operation command.
     * @param message The message.
     * @param cosigners The cosigners.
     * @param cosignersThreshold The cosigners threshold.
     * @param claimBackAddress An address that can claim back the fee if the instructions are not executed (optional).
     */
    struct TeeInstructionParams {
        bytes32 opType;
        bytes32 opCommand;
        bytes message;
        address[] cosigners;
        uint64 cosignersThreshold;
        address claimBackAddress;
    }

    event TeeInstructionsSent(
        uint256 indexed extensionId,
        bytes32 indexed instructionId,
        uint32 indexed rewardEpochId,
        ITeeMachineRegistryFacet.TeeMachine[] teeMachines,
        bytes32 opType,
        bytes32 opCommand,
        bytes message,
        address[] cosigners,
        uint64 cosignersThreshold,
        address claimBackAddress,
        uint256 fee
    );

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
        string version,
        bytes32 indexed codeHash,
        bytes32[] platforms,
        bytes32 governanceHash
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

    event SystemInstructionsSendersRegistered(
        address[] instructionsSenders
    );

    event SystemInstructionsSendersUnregistered(
        address[] instructionsSenders
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

    error NoTeeMachinesSpecified();
    error OperationTypeEmpty();
    error OperationCommandEmpty();
    error MessageEmpty();
    error OnlyInstructionsSender();
    error OnlySystemInstructionsSender();
    error SystemOpTypeNotAllowed(bytes32 opType);
    error FeeTooLow();
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
    error CosignersThresholdTooHigh();
    error KeyTypeEmpty();
    error KeyTypeAlreadyExists(bytes32 keyType);
    error SystemInstructionsSenderAlreadyExists(address instructionsSender);
    error SystemInstructionsSenderNotFound(address instructionsSender);
    error NoSigningAlgos(bytes32 keyType);
    error SigningAlgoEmpty();
    error SigningAlgoAlreadyExists(bytes32 keyType, bytes32 signingAlgo);

    /**
     * Send instructions to the TEE machines. Instruction ID will be generated internally and returned.
     * Emits TeeInstructionsSent event.
     * @param _teeIds The TEE machine IDs to which the instructions are sent (must all belong to the same extension).
     * @param _instructionParams The instruction parameters.
     * @return _instructionId The generated instruction ID.
     * Can only be called by the TEE machines extension instructions sender.
     */
    function sendInstructions(
        address[] calldata _teeIds,
        TeeInstructionParams calldata _instructionParams
    )
        external payable
        returns (bytes32 _instructionId);

    /**
     * Register a new TEE extension.
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
     * @param _version The version.
     * @param _codeHash The code hash.
     * @param _platforms The supported platforms.
     * @param _governanceHash The governance hash.
     * Can only be called by the extension owner.
     */
    function addTeeVersion(
        uint256 _extensionId,
        string calldata _version,
        bytes32 _codeHash,
        bytes32[] calldata _platforms,
        bytes32 _governanceHash
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
     * Get number of registered TEE extensions.
     * @return The number of registered TEE extensions.
     */
    function extensionsCounter()
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
     * Get system instructions senders.
     * @return The list of system instructions senders.
     */
    function getSystemInstructionsSenders()
        external view
        returns (address[] memory);

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
     * Returns the governance hash for the given code hash.
     * @param _extensionId The id of the extension.
     * @param _codeHash The code hash.
     * @return _governanceHash The governance hash.
     */
    function getTeeGovernanceHash(
        uint256 _extensionId,
        bytes32 _codeHash
    )
        external view
        returns (bytes32 _governanceHash);

    /**
     * Returns the code hash info (governance hash, version and platforms).
     * @param _extensionId The id of the extension.
     * @param _codeHash The code hash.
     * @return _governanceHash The governance hash.
     * @return _version The version.
     * @return _platforms The supported platforms.
     */
    function getCodeHashInfo(
        uint256 _extensionId,
        bytes32 _codeHash
    )
        external view
        returns (
            bytes32 _governanceHash,
            string memory _version,
            bytes32[] memory _platforms
        );
}
