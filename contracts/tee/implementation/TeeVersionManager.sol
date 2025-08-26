// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeBase } from "./TeeBase.sol";
import { ITeeVersionManager } from "../../userInterfaces/tee/ITeeVersionManager.sol";
import { ITeeExtensionRegistry } from "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeGovernance } from "../../userInterfaces/tee/ITeeGovernance.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";

/**
 * TeeVersionManager is used for managing TEE versions.
 */
contract TeeVersionManager is ITeeVersionManager, TeeBase {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    struct TeeUpgradePathState {
        TeeUpgradePath upgradePath;
        mapping(bytes32 sourceTeeNodeVersionHash => bool) sourceTeeNodeVersionExists;
        mapping(bytes32 targetTeeNodeVersionHash => bool) targetTeeNodeVersionExists;
    }

    struct TeeUpgrade {
        uint256 extensionId;
        bytes32 sourceTeeGovernanceHash;
        Signature[] sourceTeeGovernanceSignatures;
        mapping(address => bool) sourceTeeGovernanceSigners;
        bytes32 targetTeeGovernanceHash;
        Signature[] targetTeeGovernanceSignatures;
        mapping(address => bool) targetTeeGovernanceSigners;
        TeeUpgradePathState[] upgradePaths;
        bytes32 messageHash; // keccak256(abi.encode(upgrade paths)), set when upgrade is finalized -> enables signing
        bool upgradeSigned;
    }

    /// TEE extension registry contract.
    ITeeExtensionRegistry public teeExtensionRegistry;
    /// The TEE governance contract.
    ITeeGovernance public teeGovernance;

    /// TEE upgrade mapping.
    TeeUpgrade[] private teeUpgrades;

    modifier onlyValidTeeUpgradeId(uint256 _teeUpgradeId) {
        require(_teeUpgradeId < teeUpgrades.length, InvalidUpgradeId());
        _;
    }

    modifier onlyExtensionOwner(uint256 _extensionId) {
        require(
            msg.sender == teeExtensionRegistry.getExtensionOwner(_extensionId),
            OnlyExtensionOwner()
        );
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
    }

    /**
     * @inheritdoc ITeeVersionManager
     */
    function createNewTeeUpgrade(
        uint256 _extensionId,
        bytes32 _sourceTeeGovernanceHash,
        bytes32 _targetTeeGovernanceHash
    )
        external onlyExtensionOwner(_extensionId)
        returns(uint256 _teeUpgradeId)
    {
        require(
            teeGovernance.isGovernanceHashValid(_extensionId, _sourceTeeGovernanceHash),
            InvalidFromGovernanceHash()
        );
        require(
            teeGovernance.isGovernanceHashValid(_extensionId, _targetTeeGovernanceHash),
            InvalidToGovernanceHash()
        );

        _teeUpgradeId = teeUpgrades.length;
        TeeUpgrade storage upgrade = teeUpgrades.push();
        upgrade.extensionId = _extensionId;
        upgrade.sourceTeeGovernanceHash = _sourceTeeGovernanceHash;
        upgrade.targetTeeGovernanceHash = _targetTeeGovernanceHash;
        emit TeeUpgradeStarted(_extensionId, _teeUpgradeId, _sourceTeeGovernanceHash, _targetTeeGovernanceHash);
    }

    /**
     * @inheritdoc ITeeVersionManager
     */
    function addTeeUpgradePaths(
        uint256 _teeUpgradeId,
        TeeUpgradePath[] calldata _upgradePaths
    )
        external onlyValidTeeUpgradeId(_teeUpgradeId) onlyExtensionOwner(teeUpgrades[_teeUpgradeId].extensionId)
    {
        require(teeUpgrades[_teeUpgradeId].messageHash == bytes32(0), UpgradeAlreadyFinalized());
        require(_upgradePaths.length > 0, NoUpgradePaths());

        TeeUpgrade storage teeUpgrade = teeUpgrades[_teeUpgradeId];
        bytes32 sourceTeeGovernanceHash = teeUpgrade.sourceTeeGovernanceHash;
        bytes32 targetTeeGovernanceHash = teeUpgrade.targetTeeGovernanceHash;

        for (uint256 i = 0; i < _upgradePaths.length; i++) {
            TeeUpgradePath calldata upgradePath = _upgradePaths[i];
            require(upgradePath.sourceVersions.length > 0, NoSourceVersions());
            require(upgradePath.targetVersions.length > 0, NoTargetVersions());
            TeeUpgradePathState storage upgradePathState = teeUpgrade.upgradePaths.push();
            for (uint256 j = 0; j < upgradePath.sourceVersions.length; j++) {
                TeeNodeVersion calldata sourceVersion = upgradePath.sourceVersions[j];
                require(
                    teeExtensionRegistry.isCodeHashPlatformSupported(
                        teeUpgrade.extensionId, sourceVersion.codeHash, sourceVersion.platform) ||
                    teeExtensionRegistry.codeHashPlatformDisabled(
                        teeUpgrade.extensionId, sourceVersion.codeHash, sourceVersion.platform),
                    SourceCodeHashAndPlatformNotSupported()
                );
                require(
                    teeExtensionRegistry.getTeeGovernanceHash(teeUpgrade.extensionId, sourceVersion.codeHash) ==
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
                    teeExtensionRegistry.isCodeHashPlatformSupported(
                        teeUpgrade.extensionId, targetVersion.codeHash, targetVersion.platform),
                    TargetCodeHashAndPlatformNotSupported()
                );
                require(
                    teeExtensionRegistry.getTeeGovernanceHash(teeUpgrade.extensionId, targetVersion.codeHash) ==
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
            emit TeeUpgradePathAdded(_teeUpgradeId, upgradePath);
        }
    }

    /**
     * @inheritdoc ITeeVersionManager
     */
    function finalizeTeeUpgrade(
        uint256 _teeUpgradeId
    )
        external onlyValidTeeUpgradeId(_teeUpgradeId) onlyExtensionOwner(teeUpgrades[_teeUpgradeId].extensionId)
    {
        TeeUpgrade storage teeUpgrade = teeUpgrades[_teeUpgradeId];
        require(teeUpgrade.messageHash == bytes32(0), UpgradeAlreadyFinalized());
        require(teeUpgrade.upgradePaths.length > 0, NoUpgradePaths());
        teeUpgrade.messageHash = keccak256(abi.encode(_getTeeUpgradePaths(_teeUpgradeId)));
        emit TeeUpgradeFinalized(_teeUpgradeId);
    }

    /**
     * @inheritdoc ITeeVersionManager
     */
   function signTeeUpgrade(
        uint256 _teeUpgradeId,
        Signature calldata _signature
    )
        external onlyValidTeeUpgradeId(_teeUpgradeId)
    {
        TeeUpgrade storage teeUpgrade = teeUpgrades[_teeUpgradeId];
        require(!teeUpgrade.upgradeSigned, UpgradeAlreadySigned());
        require(teeUpgrade.messageHash != bytes32(0), UpgradeNotFinalized());

        bytes32 sourceTeeGovernanceHash = teeUpgrade.sourceTeeGovernanceHash;
        bytes32 targetTeeGovernanceHash = teeUpgrade.targetTeeGovernanceHash;

        address signer = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(teeUpgrade.messageHash),
            _signature.v,
            _signature.r,
            _signature.s
        );

        // check if the signer is an source TEE governance signer
        if (teeGovernance.isTeeGovernanceSigner(teeUpgrade.extensionId, sourceTeeGovernanceHash, signer)) {
            // add the signer to the source TEE governance signers if not already added
            if (!teeUpgrade.sourceTeeGovernanceSigners[signer]) {
                teeUpgrade.sourceTeeGovernanceSigners[signer] = true;
                teeUpgrade.sourceTeeGovernanceSignatures.push(_signature);
            }
        }

        // check if the signer is a target TEE governance signer
        if (teeGovernance.isTeeGovernanceSigner(teeUpgrade.extensionId, targetTeeGovernanceHash, signer)) {
            // add the signer to the target TEE governance signers if not already added
            if (!teeUpgrade.targetTeeGovernanceSigners[signer]) {
                teeUpgrade.targetTeeGovernanceSigners[signer] = true;
                teeUpgrade.targetTeeGovernanceSignatures.push(_signature);
            }
        }

        // check if the upgrade is signed by the required number of signers
        uint64 sourceTeeGovernanceThreshold =
            teeGovernance.getTeeGovernanceThreshold(teeUpgrade.extensionId, sourceTeeGovernanceHash);
        uint64 targetTeeGovernanceThreshold =
            teeGovernance.getTeeGovernanceThreshold(teeUpgrade.extensionId, targetTeeGovernanceHash);
        if (teeUpgrade.sourceTeeGovernanceSignatures.length >= sourceTeeGovernanceThreshold &&
            teeUpgrade.targetTeeGovernanceSignatures.length >= targetTeeGovernanceThreshold)
        {
            teeUpgrade.upgradeSigned = true;
            emit TeeUpgradeSigned(_teeUpgradeId);
        }
    }

    /**
     * @inheritdoc ITeeVersionManager
     */
    function isTeeUpgradePathValid(
        uint256 _teeUpgradeId,
        uint256 _extensionId,
        bytes32 _sourceCodeHash,
        bytes32 _sourcePlatform,
        bytes32 _targetCodeHash,
        bytes32 _targetPlatform
    )
        external view onlyValidTeeUpgradeId(_teeUpgradeId)
        returns(bool)
    {
        TeeUpgrade storage teeUpgrade = teeUpgrades[_teeUpgradeId];
        require(_extensionId == teeUpgrade.extensionId, ExtensionIdMismatch());
        require(teeUpgrade.messageHash != bytes32(0), UpgradeNotFinalized());
        bytes32 sourceVersionHash = keccak256(abi.encode(TeeNodeVersion(_sourceCodeHash, _sourcePlatform)));
        bytes32 targetVersionHash = keccak256(abi.encode(TeeNodeVersion(_targetCodeHash, _targetPlatform)));
        for (uint256 i = 0; i < teeUpgrade.upgradePaths.length; i++) {
            TeeUpgradePathState storage upgradePathState = teeUpgrade.upgradePaths[i];
            if (upgradePathState.sourceTeeNodeVersionExists[sourceVersionHash] &&
                upgradePathState.targetTeeNodeVersionExists[targetVersionHash]) {
                return true; // upgrade path exists
            }
        }
        return false;
    }

    /**
     * @inheritdoc ITeeVersionManager
     */
    function isTeeUpgradeFinalized(
        uint256 _teeUpgradeId
    )
        external view onlyValidTeeUpgradeId(_teeUpgradeId)
        returns(bool)
    {
        return teeUpgrades[_teeUpgradeId].messageHash != bytes32(0);
    }

    /**
     * @inheritdoc ITeeVersionManager
     */
    function isTeeUpgradeSigned(
        uint256 _teeUpgradeId
    )
        external view onlyValidTeeUpgradeId(_teeUpgradeId)
        returns(bool)
    {
        return teeUpgrades[_teeUpgradeId].upgradeSigned;
    }

    /**
     * @inheritdoc ITeeVersionManager
     */
    function getTeeUpgradesCount()
        external view
        returns(uint256)
    {
        return teeUpgrades.length;
    }

    /**
     * @inheritdoc ITeeVersionManager
     */
    function getTeeUpgradePaths(
        uint256 _teeUpgradeId
    )
        external view onlyValidTeeUpgradeId(_teeUpgradeId)
        returns(TeeUpgradePath[] memory upgradePaths)
    {
        return _getTeeUpgradePaths(_teeUpgradeId);
    }

    /**
     * @inheritdoc ITeeVersionManager
     */
    function getTeeUpgradeSignatures(
        uint256 _teeUpgradeId
    )
        external view onlyValidTeeUpgradeId(_teeUpgradeId)
        returns(Signature[] memory sourceTeeGovernanceSignatures, Signature[] memory targetTeeGovernanceSignatures)
    {
        TeeUpgrade storage teeUpgrade = teeUpgrades[_teeUpgradeId];
        sourceTeeGovernanceSignatures = teeUpgrade.sourceTeeGovernanceSignatures;
        targetTeeGovernanceSignatures = teeUpgrade.targetTeeGovernanceSignatures;
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
        teeExtensionRegistry = ITeeExtensionRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeExtensionRegistry"));
        teeGovernance = ITeeGovernance(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeGovernance"));
    }

    function _getTeeUpgradePaths(
        uint256 _teeUpgradeId
    )
        internal view
        returns(TeeUpgradePath[] memory _upgradePaths)
    {
        TeeUpgradePathState[] storage teeUpgradePaths = teeUpgrades[_teeUpgradeId].upgradePaths;
        _upgradePaths = new TeeUpgradePath[](teeUpgradePaths.length);
        for (uint256 i = 0; i < _upgradePaths.length; i++) {
            _upgradePaths[i] = teeUpgradePaths[i].upgradePath;
        }
    }
}
