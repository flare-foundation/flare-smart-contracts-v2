
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeExtensionStateVerifier.sol";
import "./ITeeWalletProjectOpTypeConstants.sol";
import "./ITeeMachineRegistry.sol";
import "../ftdc/ITeeAvailabilityCheck.sol";

/**
 * TeeExtensionRegistry interface.
 */
interface ITeeExtensionRegistry {

    event ExtensionRegistered(
        uint256 indexed extensionId,
        address indexed owner
    );

    event ExtensionContractsSet(
        uint256 indexed extensionId,
        ITeeExtensionStateVerifier indexed teeExtensionStateVerifier,
        address indexed teeExtensionInstructionsSender
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

    event PlatformAdded(
        bytes32 indexed platform
    );

    event TeeVersionAdded(
        uint256 indexed extensionId,
        bytes32 indexed codeHash,
        string version,
        bytes32[] platforms,
        bytes32 governanceHash
    );

    event CodeHashPlatformDisabled(
        uint256 indexed extensionId,
        bytes32 indexed codeHash,
        bytes32 indexed platform
    );

    event OpTypeAdded(
        uint256 indexed extensionId,
        bytes32 indexed opType
    );

    event OpTypeRemoved(
        uint256 indexed extensionId,
        bytes32 indexed opType
    );

    event TeeInstructionsSent(
        bytes32 indexed instructionId,
        uint32 indexed rewardEpochId,
        ITeeMachineRegistry.TeeMachine[] teeMachines,
        bytes32 opType,
        bytes32 opCommand,
        bytes message,
        uint256 fee
    );

    /**
     * Send instructions to the TEE machines.
     * Emits a TeeInstructionsSent event.
     * @param _instructionId The instruction ID.
     * @param _extensionId The id of the extension.
     * @param _teeIds The TEE machine IDs to which the instructions are sent (must all belong to the given extension).
     * @param _opType The operation type.
     * @param _opCommand The operation command.
     * @param _message The message.
     */
    function sendInstructions(
        bytes32 _instructionId,
        uint256 _extensionId,
        address[] memory _teeIds,
        bytes32 _opType,
        bytes32 _opCommand,
        bytes memory _message
    )
        external payable;

    /**
     * Register a new TEE extension.
     * @param _teeExtensionStateVerifier The TEE extension state verifier contract.
     * @param _teeExtensionInstructionsSender The address that can send instructions to the TEE machines.
     */
    function register(
        ITeeExtensionStateVerifier _teeExtensionStateVerifier,
        address _teeExtensionInstructionsSender
    )
        external payable;

    /**
     * Set the extension contracts for a given extension id.
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
     * Add or update supported wallet project operation types and their constants providers.
     * @param _extensionId The id of the extension.
     * @param _opTypeConstantsProviders The operation type constants providers for the operation types.
     * Can only be called by the extension owner.
     */
    function addOrUpdateSupportedWalletProjectOpTypes(
        uint256 _extensionId,
        ITeeWalletProjectOpTypeConstants[] calldata _opTypeConstantsProviders
    )
        external;

    /**
     * Remove supported wallet project operation types.
     * @param _extensionId The id of the extension.
     * @param _opTypes The operation types to remove.
     * Can only be called by the extension owner.
     */
    function removeSupportedWalletProjectOpTypes(
        uint256 _extensionId,
        bytes32[] memory _opTypes
    )
        external;

    /**
     * Propose a new owner for the extension. Can only be called by the current owner.
     * It is a two-step process, the new owner has to confirm the ownership.
     * @param _extensionId The id of the extension.
     * @param _newOwner The new owner address.
     */
    function proposeNewOwner(uint256 _extensionId, address _newOwner)
        external;

    /**
     * Confirm the ownership of a TEE extension. Can only be called by the proposed new owner.
     * @param _extensionId The id of the extension.
     */
    function confirmOwnership(uint256 _extensionId)
        external;

    /**
     * Get number of registered TEE extensions.
     * @return The number of registered TEE extensions.
     */
    function extensionsCounter()
        external view
        returns (uint256);

    /**
     * Get system instruction initiators.
     * @return The list of system instruction initiators.
     */
    function getSystemInstructionInitiators() external view returns(address[] memory);

    /**
     * Get the owner of a TEE extension.
     * @param _extensionId The id of the extension.
     * @return The owner address.
     */
    function getExtensionOwner(uint256 _extensionId)
        external view
        returns (address);

    /**
     * Get the TEE extension state verifier contract.
     * @param _extensionId The id of the extension.
     * @return The TEE extension state verifier contract address.
     */
    function getTeeExtensionStateVerifier(uint256 _extensionId)
        external view
        returns (ITeeExtensionStateVerifier);

    /**
     * Get the TEE extension instructions sender address.
     * @param _extensionId The id of the extension.
     * @return The TEE extension instructions sender address.
     */
    function getTeeExtensionInstructionsSender(uint256 _extensionId)
        external view
        returns (address);

    /**
     * Get wallet project operation type constants provider for the specified extension and operation type.
     * @param _extensionId The id of the extension.
     * @param _opType The operation type.
     * @return The wallet project operation type constants provider.
     * NOTE: Should revert if the operation type constants provider is not set.
     */
    function getWalletProjectOpTypeConstantsProvider(
        uint256 _extensionId,
        bytes32 _opType
    )
        external view
        returns (ITeeWalletProjectOpTypeConstants);

    /**
     * Returns supported wallet project operation types for the given extension.
     * @param _extensionId The id of the extension.
     * @return _supportedOpTypes The supported operation types.
     */
    function getSupportedWalletProjectOpTypes(
        uint256 _extensionId
    )
        external view
        returns (bytes32[] memory _supportedOpTypes);

    /**
     * Checks if wallet project operation type is supported for the given extension.
     * @param _extensionId The id of the extension.
     * @param _opType The operation type.
     * @return True if the operation type is supported.
     */
    function isWalletProjectOpTypeSupported(uint256 _extensionId, bytes32 _opType)
        external view
        returns (bool);

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
        returns(bool);

    /**
     * Get the info if the code hash and platform pair is disabled for the given extension.
     * @param _extensionId The id of the extension.
     * @param _codeHash The code hash.
     * @param _platform The platform.
     */
    function codeHashPlatformDisabled(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external view
        returns(bool);

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
        returns(bytes32 _governanceHash);

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
        returns(bytes32 _governanceHash, string memory _version, bytes32[] memory _platforms);
}
