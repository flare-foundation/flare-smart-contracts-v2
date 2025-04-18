// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeVersionManager.sol";
import "../../userInterfaces/tee/ITeeGovernance.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../../governance/implementation/GovernedProxyImplementation.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * TeeVersionManager is used for managing TEE versions.
 */
contract TeeVersionManager is ITeeVersionManager, GovernedProxyImplementation, AddressUpdatable, UUPSUpgradeable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    struct TeeVersion {
        string version;
        bytes32 governanceHash;
        EnumerableSet.Bytes32Set platforms;
    }

    struct TeeUpgradePathState {
        TeeUpgradePath upgradePath;
        mapping(bytes32 sourceTeeNodeVersionHash => bool) sourceTeeNodeVersionExists;
        mapping(bytes32 targetTeeNodeVersionHash => bool) targetTeeNodeVersionExists;
    }

    struct TeeUpgrade {
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

    /// The TEE governance contract.
    ITeeGovernance public teeGovernance;

    mapping(bytes32 codeHash => TeeVersion) private codeHashToVersion;
    /// Disabled code hash and platform mapping.
    mapping(bytes32 codeHash => mapping(bytes32 platform => bool)) public codeHashPlatformDisabled;

    /// TEE upgrade mapping.
    TeeUpgrade[] private teeUpgrades;

    modifier onlyValidTeeUpgradeId(uint256 _teeUpgradeId) {
        require(_teeUpgradeId < teeUpgrades.length, "invalid upgrade id");
        _;
    }

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor()
        GovernedProxyImplementation() AddressUpdatable(address(0))
    { }

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
        GovernedBase.initialise(_governanceSettings, _initialGovernance);
        AddressUpdatable.setAddressUpdaterValue(_addressUpdater);
    }

    /**
     * Creates a new TEE upgrade.
     * @param _sourceTeeGovernanceHash The source TEE governance hash.
     * @param _targetTeeGovernanceHash The target TEE governance hash.
     * @return _teeUpgradeId The TEE upgrade id.
     * Can only be called by the governance.
     */
    function createNewTeeUpgrade(bytes32 _sourceTeeGovernanceHash, bytes32 _targetTeeGovernanceHash)
        external onlyImmediateGovernance returns(uint256 _teeUpgradeId)
    {
        require(teeGovernance.isGovernanceHashValid(_sourceTeeGovernanceHash), "invalid from governance hash");
        require(teeGovernance.isGovernanceHashValid(_targetTeeGovernanceHash), "invalid to governance hash");

        _teeUpgradeId = teeUpgrades.length;
        TeeUpgrade storage upgrade = teeUpgrades.push();
        upgrade.sourceTeeGovernanceHash = _sourceTeeGovernanceHash;
        upgrade.targetTeeGovernanceHash = _targetTeeGovernanceHash;
        emit TeeUpgradeStarted(_teeUpgradeId, _sourceTeeGovernanceHash, _targetTeeGovernanceHash);
    }

    /**
     * Adds TEE upgrade paths.
     * @param _teeUpgradeId The TEE upgrade id.
     * @param _upgradePaths The TEE upgrade paths.
     * Can only be called by the governance.
     */
    function addTeeUpgradePaths(
        uint256 _teeUpgradeId,
        TeeUpgradePath[] calldata _upgradePaths
    )
        external onlyImmediateGovernance onlyValidTeeUpgradeId(_teeUpgradeId)
    {
        require(teeUpgrades[_teeUpgradeId].messageHash == bytes32(0), "upgrade already finalized");
        require(_upgradePaths.length > 0, "no upgrade paths");

        TeeUpgrade storage teeUpgrade = teeUpgrades[_teeUpgradeId];
        bytes32 sourceTeeGovernanceHash = teeUpgrade.sourceTeeGovernanceHash;
        bytes32 targetTeeGovernanceHash = teeUpgrade.targetTeeGovernanceHash;

        for (uint256 i = 0; i < _upgradePaths.length; i++) {
            TeeUpgradePath calldata upgradePath = _upgradePaths[i];
            require(upgradePath.sourceVersions.length > 0, "no source versions");
            require(upgradePath.targetVersions.length > 0, "no target versions");
            TeeUpgradePathState storage upgradePathState = teeUpgrade.upgradePaths.push();
            for (uint256 j = 0; j < upgradePath.sourceVersions.length; j++) {
                TeeNodeVersion calldata sourceVersion = upgradePath.sourceVersions[j];
                require(codeHashToVersion[sourceVersion.codeHash].platforms.contains(sourceVersion.platform),
                    "source codeHash and platform not supported");
                require(codeHashToVersion[sourceVersion.codeHash].governanceHash == sourceTeeGovernanceHash,
                    "source governance hash mismatch");
                bytes32 sourceVersionHash = keccak256(abi.encode(sourceVersion));
                require(!upgradePathState.sourceTeeNodeVersionExists[sourceVersionHash],
                    "source version already exists");
                upgradePathState.sourceTeeNodeVersionExists[sourceVersionHash] = true;
                upgradePathState.upgradePath.sourceVersions.push(sourceVersion);
            }
            for (uint256 j = 0; j < upgradePath.targetVersions.length; j++) {
                TeeNodeVersion calldata targetVersion = upgradePath.targetVersions[j];
                require(codeHashToVersion[targetVersion.codeHash].platforms.contains(targetVersion.platform),
                    "target codeHash and platform not supported");
                require(codeHashToVersion[targetVersion.codeHash].governanceHash == targetTeeGovernanceHash,
                    "target governance hash mismatch");
                bytes32 targetVersionHash = keccak256(abi.encode(targetVersion));
                require(!upgradePathState.targetTeeNodeVersionExists[targetVersionHash],
                    "target version already exists");
                upgradePathState.targetTeeNodeVersionExists[targetVersionHash] = true;
                upgradePathState.upgradePath.targetVersions.push(targetVersion);
            }
            emit TeeUpgradePathAdded(_teeUpgradeId, upgradePath);
        }
    }

    /**
     * Finalizes the TEE upgrade and makes it ready for signing.
     * @param _teeUpgradeId The TEE upgrade id.
     * Can only be called by the governance.
     */
    function finalizeTeeUpgrade(
        uint256 _teeUpgradeId
    )
        external onlyImmediateGovernance onlyValidTeeUpgradeId(_teeUpgradeId)
    {
        TeeUpgrade storage teeUpgrade = teeUpgrades[_teeUpgradeId];
        require(teeUpgrade.messageHash == bytes32(0), "upgrade already finalized");
        require(teeUpgrade.upgradePaths.length > 0, "no upgrade paths");
        teeUpgrade.messageHash = keccak256(abi.encode(_getTeeUpgradePaths(_teeUpgradeId)));
        emit TeeUpgradeFinalized(_teeUpgradeId);
    }

    /**
     * Add a new TEE version.
     * @param _version The version.
     * @param _codeHash The code hash.
     * @param _platforms The supported platforms.
     * Can only be called by the governance.
     */
    function addNewTeeVersion(
        bytes32 _governanceHash,
        string calldata _version,
        bytes32 _codeHash,
        bytes32[] calldata _platforms // utf8 encoded platforms
    )
        external onlyImmediateGovernance
    {
        require(bytes(_version).length > 0, "version empty");
        require(_codeHash != bytes32(0), "code hash zero");
        require(_platforms.length > 0, "no platforms");
        require(codeHashToVersion[_codeHash].governanceHash == bytes32(0), "version already exists");
        require(teeGovernance.isGovernanceHashValid(_governanceHash), "invalid governance hash");

        TeeVersion storage teeVersion = codeHashToVersion[_codeHash];
        teeVersion.version = _version;
        teeVersion.governanceHash = _governanceHash;
        for (uint256 i = 0; i < _platforms.length; i++) {
            require(teeVersion.platforms.add(_platforms[i]), "platform already exists");
        }
    }

    /**
     * Disable a TEE code hash and platform.
     * @param _codeHash The code hash.
     * @param _platform The platform to disable. If empty, all platforms will be disabled.
     * Can only be called by the governance.
     */
    function disableCodeHashPlatform(
        bytes32 _codeHash,
        bytes32 _platform
    )
        external onlyImmediateGovernance
    {
        require(codeHashToVersion[_codeHash].governanceHash != bytes32(0), "invalid code hash");
        bytes32[] memory platforms = codeHashToVersion[_codeHash].platforms.values();
        if (_platform != bytes32(0)) {
            for (uint256 i = 0; i < platforms.length; i++) {
                if (platforms[i] == _platform) {
                    codeHashPlatformDisabled[_codeHash][_platform] = true;
                    emit CodeHashPlatformDisabled(_codeHash, _platform);
                    return;
                }
            }
            revert("invalid platform");
        } else {
            for (uint256 i = 0; i < platforms.length; i++) {
                codeHashPlatformDisabled[_codeHash][platforms[i]] = true;
                emit CodeHashPlatformDisabled(_codeHash, platforms[i]);
            }
        }
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
        require(!teeUpgrade.upgradeSigned, "upgrade already signed");
        require(teeUpgrade.messageHash != bytes32(0), "upgrade not finalized");

        bytes32 sourceTeeGovernanceHash = teeUpgrade.sourceTeeGovernanceHash;
        bytes32 targetTeeGovernanceHash = teeUpgrade.targetTeeGovernanceHash;

        address signer = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(teeUpgrade.messageHash),
            _signature.v,
            _signature.r,
            _signature.s
        );

        uint64 sourceTeeGovernanceThreshold = teeGovernance.getTeeGovernanceThreshold(sourceTeeGovernanceHash);
        // check if we need more signatures and the signer is an source TEE governance signer
        if (teeUpgrade.sourceTeeGovernanceSignatures.length < sourceTeeGovernanceThreshold &&
            teeGovernance.isTeeGovernanceSigner(sourceTeeGovernanceHash, signer))
        {
            // add the signer to the source TEE governance signers if not already added
            if (!teeUpgrade.sourceTeeGovernanceSigners[signer]) {
                teeUpgrade.sourceTeeGovernanceSigners[signer] = true;
                teeUpgrade.sourceTeeGovernanceSignatures.push(_signature);
            }
        }

        uint64 targetTeeGovernanceThreshold = teeGovernance.getTeeGovernanceThreshold(targetTeeGovernanceHash);
        // check if we need more signatures and the signer is a target TEE governance signer
        if (teeUpgrade.targetTeeGovernanceSignatures.length < targetTeeGovernanceThreshold &&
            teeGovernance.isTeeGovernanceSigner(targetTeeGovernanceHash, signer))
        {
            // add the signer to the target TEE governance signers if not already added
            if (!teeUpgrade.targetTeeGovernanceSigners[signer]) {
                teeUpgrade.targetTeeGovernanceSigners[signer] = true;
                teeUpgrade.targetTeeGovernanceSignatures.push(_signature);
            }
        }


        // check if the upgrade is signed by the required number of signers
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
    function getTeeGovernanceHash(bytes32 _codeHash)
        external view
        returns(bytes32 _governanceHash)
    {
        _governanceHash = codeHashToVersion[_codeHash].governanceHash;
        require(_governanceHash != bytes32(0), "invalid code hash");
    }

    /**
     * @inheritdoc ITeeVersionManager
     */
    function getCodeHashInfo(bytes32 _codeHash)
        external view
        returns(bytes32 _governanceHash, string memory _version, bytes32[] memory _platforms)
    {
        _governanceHash = codeHashToVersion[_codeHash].governanceHash;
        require(_governanceHash != bytes32(0), "invalid code hash");
        _version = codeHashToVersion[_codeHash].version;
        _platforms = codeHashToVersion[_codeHash].platforms.values();
    }

    /**
     * @inheritdoc ITeeVersionManager
     */
    function isCodeHashPlatformSupported(
        bytes32 _codeHash,
        bytes32 _platform
    )
        external view
        returns(bool)
    {
        if (codeHashPlatformDisabled[_codeHash][_platform]) {
            return false; // platform disabled
        }
        return codeHashToVersion[_codeHash].platforms.contains(_platform);
    }

    /**
     * @inheritdoc ITeeVersionManager
     */
    function isTeeUpgradePathValid(
        uint256 _teeUpgradeId,
        bytes32 _sourceCodeHash,
        bytes32 _sourcePlatform,
        bytes32 _targetCodeHash,
        bytes32 _targetPlatform
    )
        external view onlyValidTeeUpgradeId(_teeUpgradeId)
        returns(bool)
    {
        TeeUpgrade storage teeUpgrade = teeUpgrades[_teeUpgradeId];
        require(teeUpgrade.messageHash != bytes32(0), "upgrade not finalized");
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

    /////////////////////////////// UUPS UPGRADABLE ///////////////////////////////

    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Only governance can call this method.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data)
        public payable override
        onlyGovernance
        onlyProxy
    {
        super.upgradeToAndCall(newImplementation, data);
    }

    /**
     * Unused. Present just to satisfy UUPSUpgradeable requirement.
     * The real check is in onlyGovernance modifier on upgradeToAndCall.
     */
    function _authorizeUpgrade(address newImplementation) internal override {}

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        teeGovernance = ITeeGovernance(_getContractAddress(_contractNameHashes, _contractAddresses, "TeeGovernance"));
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
