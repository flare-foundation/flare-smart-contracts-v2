// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../ISignature.sol";

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
        uint256 indexed teeUpgradeId,
        bytes32 sourceTeeGovernanceHash,
        bytes32 targetTeeGovernanceHash
    );

    event TeeUpgradePathAdded(
        uint256 indexed teeUpgradeId,
        TeeUpgradePath upgradePath
    );

    event TeeUpgradeFinalized(
        uint256 indexed teeUpgradeId
    );

    event TeeUpgradeSigned(
        uint256 indexed teeUpgradeId
    );

    event CodeHashPlatformDisabled(bytes32 indexed codeHash, bytes32 platform);

    /**
     * Signs the TEE upgrade.
     * @param _teeUpgradeId The TEE upgrade id.
     * @param _signature The signature.
     */
   function signTeeUpgrade(
        uint256 _teeUpgradeId,
        Signature calldata _signature
    )
        external;

    /**
     * Get the info if the code hash and platform pair is disabled.
     * @param _codeHash The code hash.
     * @param _platform The platform.
     */
    function codeHashPlatformDisabled(
        bytes32 _codeHash,
        bytes32 _platform
    )
        external view
        returns(bool);

    /**
     * Returns the governance hash for the given code hash.
     * @param _codeHash The code hash.
     * @return _governanceHash The governance hash.
     */
    function getTeeGovernanceHash(bytes32 _codeHash)
        external view
        returns(bytes32 _governanceHash);

    /**
     * Returns the code hash info (governance hash, version and platforms).
     * @param _codeHash The code hash.
     * @return _governanceHash The governance hash.
     * @return _version The version.
     * @return _platforms The supported platforms.
     */
    function getCodeHashInfo(bytes32 _codeHash)
        external view
        returns(bytes32 _governanceHash, string memory _version, bytes32[] memory _platforms);

    /**
     * Checks if the code hash and platform are supported.
     * @param _codeHash The code hash.
     * @param _platform The platform.
     * @return True if the code hash and platform are supported, false otherwise.
     */
    function isCodeHashPlatformSupported(
        bytes32 _codeHash,
        bytes32 _platform
    )
        external view
        returns(bool);

    /**
     * Checks if the upgrade path is valid for the given tee upgrade id.
     * @param _teeUpgradeId The tee upgrade id.
     * @param _sourceCodeHash The source code hash.
     * @param _sourcePlatform The source platform.
     * @param _targetCodeHash The target code hash.
     * @param _targetPlatform The target platform.
     * @return True if the upgrade path is valid, false otherwise.
     */
    function isTeeUpgradePathValid(
        uint256 _teeUpgradeId,
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
