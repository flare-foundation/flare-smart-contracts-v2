// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { Signature } from "../ISignature.sol";

/**
 * TeeVersionManager interface.
 */
interface ITeeVersionManager {

    struct TeeNodeVersion {
        bytes32 codeHash;
        bytes32 platform;
    }

    struct TeeUpgradePath {
        TeeNodeVersion[] sourceVersions;
        TeeNodeVersion[] targetVersions;
    }

    event TeeUpgradeStarted(
        uint256 indexed extensionId,
        uint256 indexed teeUpgradeId,
        bytes32 sourceTeeGovernanceHash,
        bytes32 targetTeeGovernanceHash
    );

    event TeeUpgradePathsAdded(
        uint256 indexed teeUpgradeId,
        TeeUpgradePath[] upgradePaths
    );

    event TeeUpgradeFinalized(
        uint256 indexed teeUpgradeId
    );

    event TeeUpgradeSourceSignatureAdded(
        uint256 indexed teeUpgradeId,
        address indexed signer
    );

    event TeeUpgradeTargetSignatureAdded(
        uint256 indexed teeUpgradeId,
        address indexed signer
    );

    event TeeUpgradeSigned(
        uint256 indexed teeUpgradeId
    );

    error InvalidUpgradeId();
    error OnlyExtensionOwner();
    error InvalidFromGovernanceHash();
    error InvalidToGovernanceHash();
    error UpgradeAlreadyFinalized();
    error NoUpgradePaths();
    error NoSourceVersions();
    error NoTargetVersions();
    error SourceCodeHashAndPlatformNotSupported();
    error SourceGovernanceHashMismatch();
    error SourceVersionAlreadyExists();
    error TargetCodeHashAndPlatformNotSupported();
    error TargetGovernanceHashMismatch();
    error TargetVersionAlreadyExists();
    error UpgradePathAlreadyFinalized();
    error UpgradeAlreadySigned();
    error UpgradeNotFinalized();
    error InvalidSignature();
    error ExtensionIdMismatch();

    /**
     * Creates a new TEE upgrade.
     * Emits TeeUpgradeStarted event.
     * @param _extensionId The id of the extension.
     * @param _sourceTeeGovernanceHash The source TEE governance hash.
     * @param _targetTeeGovernanceHash The target TEE governance hash.
     * @return _teeUpgradeId The TEE upgrade id.
     * Can only be called by the extension owner.
     */
    function createNewTeeUpgrade(
        uint256 _extensionId,
        bytes32 _sourceTeeGovernanceHash,
        bytes32 _targetTeeGovernanceHash
    )
        external
        returns(uint256 _teeUpgradeId);

    /**
     * Adds TEE upgrade paths.
     * Emits TeeUpgradePathsAdded event.
     * @param _teeUpgradeId The TEE upgrade id.
     * @param _upgradePaths The TEE upgrade paths.
     * Can only be called by the upgrade path extension owner.
     */
    function addTeeUpgradePaths(
        uint256 _teeUpgradeId,
        TeeUpgradePath[] calldata _upgradePaths
    )
        external;

    /**
     * Finalizes the TEE upgrade and makes it ready for signing.
     * Emits TeeUpgradeFinalized event.
     * @param _teeUpgradeId The TEE upgrade id.
     * Can only be called by the upgrade path extension owner.
     */
    function finalizeTeeUpgrade(
        uint256 _teeUpgradeId
    )
        external;

    /**
     * Signs the TEE upgrade.
     * Emits TeeUpgradeSourceSignatureAdded and/or TeeUpgradeTargetSignatureAdded event when a signature is added.
     * Emits TeeUpgradeSigned event when all required signatures are collected.
     * @param _teeUpgradeId The TEE upgrade id.
     * @param _signature The signature.
     */
   function signTeeUpgrade(
        uint256 _teeUpgradeId,
        Signature calldata _signature
    )
        external;

    /**
     * Checks if the upgrade path is valid for the given tee upgrade id.
     * @param _teeUpgradeId The tee upgrade id.
     * @param _extensionId The id of the extension.
     * @param _sourceCodeHash The source code hash.
     * @param _sourcePlatform The source platform.
     * @param _targetCodeHash The target code hash.
     * @param _targetPlatform The target platform.
     * @return True if the upgrade path is valid, false otherwise.
     */
    function isTeeUpgradePathValid(
        uint256 _teeUpgradeId,
        uint256 _extensionId,
        bytes32 _sourceCodeHash,
        bytes32 _sourcePlatform,
        bytes32 _targetCodeHash,
        bytes32 _targetPlatform
    )
        external view
        returns(bool);

    /**
     * Checks if the TEE upgrade is finalized.
     * @param _teeUpgradeId The TEE upgrade id.
     * @return True if the TEE upgrade is finalized, false otherwise.
     */
    function isTeeUpgradeFinalized(
        uint256 _teeUpgradeId
    )
        external view
        returns(bool);

    /**
     * Checks if the TEE upgrade is signed.
     * @param _teeUpgradeId The TEE upgrade id.
     * @return True if the TEE upgrade is signed, false otherwise.
     */
    function isTeeUpgradeSigned(
        uint256 _teeUpgradeId
    )
        external view
        returns(bool);

    /**
     * Returns TEE upgrades count.
     * @return The TEE upgrades count.
     */
    function getTeeUpgradesCount()
        external view
        returns(uint256);

    /**
     * Returns the TEE upgrade paths for the given TEE upgrade id.
     * @param _teeUpgradeId The TEE upgrade id.
     * @return upgradePaths List of TEE upgrade paths.
     */
    function getTeeUpgradePaths(
        uint256 _teeUpgradeId
    )
        external view
        returns(TeeUpgradePath[] memory upgradePaths);

    /**
     * Returns the TEE upgrade signatures for the given TEE upgrade id.
     * @param _teeUpgradeId The TEE upgrade id.
     * @return sourceTeeGovernanceSignatures The source TEE governance signatures.
     * @return targetTeeGovernanceSignatures The target TEE governance signatures.
     */
    function getTeeUpgradeSignatures(
        uint256 _teeUpgradeId
    )
        external view
        returns(Signature[] memory sourceTeeGovernanceSignatures, Signature[] memory targetTeeGovernanceSignatures);
}
