// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IUpgradeManager } from "../../userInterfaces/tee/IUpgradeManager.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { UpgradeManager } from "../library/UpgradeManager.sol";
import { ExtensionGovernance } from "../library/ExtensionGovernance.sol";
import { ExtensionManager } from "../library/ExtensionManager.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title UpgradeManagerFacet
 * @notice Facet for managing TEE upgrade versions and signing.
 */
contract UpgradeManagerFacet is IUpgradeManager {

    modifier onlyValidTeeUpgradeId(uint256 _teeUpgradeId) {
        require(
            _teeUpgradeId < UpgradeManager.getState().teeUpgrades.length,
            InvalidUpgradeId()
        );
        _;
    }

    /// @inheritdoc IUpgradeManager
    function createNewTeeUpgrade(
        uint256 _extensionId,
        bytes32 _sourceTeeGovernanceHash,
        bytes32 _targetTeeGovernanceHash
    )
        external
        returns (uint256 _teeUpgradeId)
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        require(
            ExtensionGovernance.isGovernanceHashValid(_extensionId, _sourceTeeGovernanceHash),
            InvalidFromGovernanceHash()
        );
        require(
            ExtensionGovernance.isGovernanceHashValid(_extensionId, _targetTeeGovernanceHash),
            InvalidToGovernanceHash()
        );

        UpgradeManager.State storage s = UpgradeManager.getState();
        _teeUpgradeId = s.teeUpgrades.length;
        UpgradeManager.TeeUpgrade storage upgrade = s.teeUpgrades.push();
        upgrade.extensionId = _extensionId;
        upgrade.sourceTeeGovernanceHash = _sourceTeeGovernanceHash;
        upgrade.targetTeeGovernanceHash = _targetTeeGovernanceHash;
        emit TeeUpgradeStarted(
            _extensionId, _teeUpgradeId, _sourceTeeGovernanceHash, _targetTeeGovernanceHash
        );
    }

    /// @inheritdoc IUpgradeManager
    function addTeeUpgradePaths(
        uint256 _teeUpgradeId,
        TeeUpgradePath[] calldata _upgradePaths
    )
        external
        onlyValidTeeUpgradeId(_teeUpgradeId)
    {
        UpgradeManager.State storage s = UpgradeManager.getState();
        UpgradeManager.TeeUpgrade storage teeUpgrade = s.teeUpgrades[_teeUpgradeId];
        ExtensionManager.checkOnlyExtensionOwner(teeUpgrade.extensionId);
        require(teeUpgrade.messageHash == bytes32(0), UpgradeAlreadyFinalized());
        require(_upgradePaths.length > 0, NoUpgradePaths());

        uint256 extensionId = teeUpgrade.extensionId;
        bytes32 sourceTeeGovernanceHash = teeUpgrade.sourceTeeGovernanceHash;
        bytes32 targetTeeGovernanceHash = teeUpgrade.targetTeeGovernanceHash;

        for (uint256 i = 0; i < _upgradePaths.length; i++) {
            TeeUpgradePath calldata upgradePath = _upgradePaths[i];
            require(upgradePath.sourceVersions.length > 0, NoSourceVersions());
            require(upgradePath.targetVersions.length > 0, NoTargetVersions());
            UpgradeManager.TeeUpgradePathState storage upgradePathState =
                teeUpgrade.upgradePaths.push();
            for (uint256 j = 0; j < upgradePath.sourceVersions.length; j++) {
                TeeNodeVersion calldata sourceVersion = upgradePath.sourceVersions[j];
                require(
                    ExtensionManager.isCodeHashPlatformSupported(
                        extensionId, sourceVersion.codeHash, sourceVersion.platform) ||
                    ExtensionManager.isCodeHashPlatformDisabled(
                        extensionId, sourceVersion.codeHash, sourceVersion.platform),
                    SourceCodeHashAndPlatformNotSupported()
                );
                require(
                    ExtensionManager.getTeeGovernanceHash(extensionId, sourceVersion.codeHash) ==
                        sourceTeeGovernanceHash,
                    SourceGovernanceHashMismatch()
                );
                bytes32 sourceVersionHash = keccak256(abi.encode(sourceVersion));
                require(
                    !upgradePathState.sourceTeeNodeVersionExists[sourceVersionHash],
                    SourceVersionAlreadyExists()
                );
                upgradePathState.sourceTeeNodeVersionExists[sourceVersionHash] = true;
                upgradePathState.upgradePath.sourceVersions.push(sourceVersion);
            }
            for (uint256 j = 0; j < upgradePath.targetVersions.length; j++) {
                TeeNodeVersion calldata targetVersion = upgradePath.targetVersions[j];
                require(
                    ExtensionManager.isCodeHashPlatformSupported(
                        extensionId, targetVersion.codeHash, targetVersion.platform),
                    TargetCodeHashAndPlatformNotSupported()
                );
                require(
                    ExtensionManager.getTeeGovernanceHash(extensionId, targetVersion.codeHash) ==
                        targetTeeGovernanceHash,
                    TargetGovernanceHashMismatch()
                );
                bytes32 targetVersionHash = keccak256(abi.encode(targetVersion));
                require(
                    !upgradePathState.targetTeeNodeVersionExists[targetVersionHash],
                    TargetVersionAlreadyExists()
                );
                upgradePathState.targetTeeNodeVersionExists[targetVersionHash] = true;
                upgradePathState.upgradePath.targetVersions.push(targetVersion);
            }
        }
        emit TeeUpgradePathsAdded(_teeUpgradeId, _upgradePaths);
    }

    /// @inheritdoc IUpgradeManager
    function finalizeTeeUpgrade(
        uint256 _teeUpgradeId
    )
        external
        onlyValidTeeUpgradeId(_teeUpgradeId)
    {
        UpgradeManager.State storage s = UpgradeManager.getState();
        UpgradeManager.TeeUpgrade storage teeUpgrade = s.teeUpgrades[_teeUpgradeId];
        ExtensionManager.checkOnlyExtensionOwner(teeUpgrade.extensionId);
        require(teeUpgrade.messageHash == bytes32(0), UpgradeAlreadyFinalized());
        require(teeUpgrade.upgradePaths.length > 0, NoUpgradePaths());
        // Bind chainid + extensionId + upgradeId + source/target governance hashes into the
        // signed payload, preventing cross-chain, cross-extension, cross-upgrade, and
        // cross-governance signature replay between upgrades that happen to share path content.
        teeUpgrade.messageHash = keccak256(
            abi.encode(
                bytes32("TEE_UPGRADE"),
                block.chainid,
                teeUpgrade.extensionId,
                _teeUpgradeId,
                teeUpgrade.sourceTeeGovernanceHash,
                teeUpgrade.targetTeeGovernanceHash,
                _getTeeUpgradePaths(_teeUpgradeId)
            )
        );
        emit TeeUpgradeFinalized(_teeUpgradeId);
    }

    /// @inheritdoc IUpgradeManager
    function signTeeUpgrade(
        uint256 _teeUpgradeId,
        Signature calldata _signature
    )
        external
        onlyValidTeeUpgradeId(_teeUpgradeId)
    {
        UpgradeManager.State storage s = UpgradeManager.getState();
        UpgradeManager.TeeUpgrade storage teeUpgrade = s.teeUpgrades[_teeUpgradeId];
        require(!teeUpgrade.upgradeSigned, UpgradeAlreadySigned());
        require(teeUpgrade.messageHash != bytes32(0), UpgradeNotFinalized());

        bytes32 sourceTeeGovernanceHash = teeUpgrade.sourceTeeGovernanceHash;
        bytes32 targetTeeGovernanceHash = teeUpgrade.targetTeeGovernanceHash;
        uint256 extensionId = teeUpgrade.extensionId;

        address signer = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(teeUpgrade.messageHash),
            _signature.v,
            _signature.r,
            _signature.s
        );

        bool sourceSig = ExtensionGovernance.isTeeGovernanceSigner(extensionId, sourceTeeGovernanceHash, signer);
        if (sourceSig) {
            if (!teeUpgrade.sourceTeeGovernanceSigners[signer]) {
                teeUpgrade.sourceTeeGovernanceSigners[signer] = true;
                teeUpgrade.sourceTeeGovernanceSignatures.push(_signature);
                emit TeeUpgradeSourceSignatureAdded(_teeUpgradeId, signer);
            }
        }

        bool targetSig = ExtensionGovernance.isTeeGovernanceSigner(extensionId, targetTeeGovernanceHash, signer);
        if (targetSig) {
            if (!teeUpgrade.targetTeeGovernanceSigners[signer]) {
                teeUpgrade.targetTeeGovernanceSigners[signer] = true;
                teeUpgrade.targetTeeGovernanceSignatures.push(_signature);
                emit TeeUpgradeTargetSignatureAdded(_teeUpgradeId, signer);
            }
        }

        require(sourceSig || targetSig, InvalidSignature());

        uint64 sourceThreshold =
            ExtensionGovernance.getTeeGovernanceThreshold(extensionId, sourceTeeGovernanceHash);
        uint64 targetThreshold =
            ExtensionGovernance.getTeeGovernanceThreshold(extensionId, targetTeeGovernanceHash);
        if (teeUpgrade.sourceTeeGovernanceSignatures.length >= sourceThreshold &&
            teeUpgrade.targetTeeGovernanceSignatures.length >= targetThreshold)
        {
            teeUpgrade.upgradeSigned = true;
            emit TeeUpgradeSigned(_teeUpgradeId);
        }
    }

    /// @inheritdoc IUpgradeManager
    function isTeeUpgradePathValid(
        uint256 _teeUpgradeId,
        uint256 _extensionId,
        bytes32 _sourceCodeHash,
        bytes32 _sourcePlatform,
        bytes32 _targetCodeHash,
        bytes32 _targetPlatform
    )
        external view
        returns (bool)
    {
        return UpgradeManager.isTeeUpgradePathValid(
            _teeUpgradeId, _extensionId, _sourceCodeHash, _sourcePlatform, _targetCodeHash, _targetPlatform
        );
    }

    /// @inheritdoc IUpgradeManager
    function isTeeUpgradeFinalized(
        uint256 _teeUpgradeId
    )
        external view
        onlyValidTeeUpgradeId(_teeUpgradeId)
        returns (bool)
    {
        return UpgradeManager.getState().teeUpgrades[_teeUpgradeId].messageHash != bytes32(0);
    }

    /// @inheritdoc IUpgradeManager
    function isTeeUpgradeSigned(
        uint256 _teeUpgradeId
    )
        external view
        returns (bool)
    {
        return UpgradeManager.isTeeUpgradeSigned(_teeUpgradeId);
    }

    /// @inheritdoc IUpgradeManager
    function getTeeUpgradeMessageHash(
        uint256 _teeUpgradeId
    )
        external view
        onlyValidTeeUpgradeId(_teeUpgradeId)
        returns (bytes32)
    {
        return UpgradeManager.getState().teeUpgrades[_teeUpgradeId].messageHash;
    }

    /// @inheritdoc IUpgradeManager
    function getTeeUpgradesCount()
        external view
        returns (uint256)
    {
        return UpgradeManager.getState().teeUpgrades.length;
    }

    /// @inheritdoc IUpgradeManager
    function getTeeUpgradePaths(
        uint256 _teeUpgradeId
    )
        external view
        onlyValidTeeUpgradeId(_teeUpgradeId)
        returns (TeeUpgradePath[] memory upgradePaths)
    {
        return _getTeeUpgradePaths(_teeUpgradeId);
    }

    /// @inheritdoc IUpgradeManager
    function getTeeUpgradeSignatures(
        uint256 _teeUpgradeId
    )
        external view
        onlyValidTeeUpgradeId(_teeUpgradeId)
        returns (
            Signature[] memory sourceTeeGovernanceSignatures,
            Signature[] memory targetTeeGovernanceSignatures
        )
    {
        UpgradeManager.TeeUpgrade storage teeUpgrade =
            UpgradeManager.getState().teeUpgrades[_teeUpgradeId];
        sourceTeeGovernanceSignatures = teeUpgrade.sourceTeeGovernanceSignatures;
        targetTeeGovernanceSignatures = teeUpgrade.targetTeeGovernanceSignatures;
    }

    // =========================================================================
    // Private helpers
    // =========================================================================

    function _getTeeUpgradePaths(
        uint256 _teeUpgradeId
    )
        private view
        returns (TeeUpgradePath[] memory _upgradePaths)
    {
        UpgradeManager.TeeUpgradePathState[] storage teeUpgradePaths =
            UpgradeManager.getState().teeUpgrades[_teeUpgradeId].upgradePaths;
        _upgradePaths = new TeeUpgradePath[](teeUpgradePaths.length);
        for (uint256 i = 0; i < _upgradePaths.length; i++) {
            _upgradePaths[i] = teeUpgradePaths[i].upgradePath;
        }
    }
}
