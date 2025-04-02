// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeVersionManager.sol";

/**
 * TeeVersionManager is used for managing TEE versions.
 */
contract TeeVersionManager is ITeeVersionManager, Governed, AddressUpdatable {

    struct TeeVersionGovernance {
        address[] signers;
        uint256 signersThreshold;
    }

    struct TeeVersion {
        string version;
        bytes32 governanceHash;
        bytes32[] platforms; // utf8 encoded platform
    }

    mapping(bytes32 codeHash => TeeVersion) private codeHashToVersion;
    mapping(bytes32 governanceHash => TeeVersionGovernance) private governanceHashToGovernance;
    /// Disabled code hash and platform mapping.
    mapping(bytes32 codeHash => mapping(bytes32 platform => bool)) public codeHashPlatformDisabled;
    /// The latest TEE governance hash.
    bytes32 public latestTeeGovernanceHash;

    /**
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
    }

    /**
     * Sets new TEE governance.
     * @param _signers The new governance signers.
     * @param _signersThreshold The new governance signers threshold.
     * Can only be called by the governance.
     */
    function setNewTeeGovernance(
        address[] calldata _signers,
        uint256 _signersThreshold
    )
        external onlyGovernance
    {
        require(_signers.length > 0, "no signers");
        require(_signersThreshold > 0 && _signersThreshold <= _signers.length, "invalid threshold");
        latestTeeGovernanceHash = keccak256(abi.encode(_signers, _signersThreshold));
        governanceHashToGovernance[latestTeeGovernanceHash] = TeeVersionGovernance({
            signers: _signers,
            signersThreshold: _signersThreshold
        });
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
        require(bytes(codeHashToVersion[_codeHash].version).length == 0, "version already exists");
        require(governanceHashToGovernance[_governanceHash].signersThreshold > 0, "invalid governance hash");

        codeHashToVersion[_codeHash] = TeeVersion({
            governanceHash: _governanceHash,
            version: _version,
            platforms: _platforms
        });
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
        bytes32[] memory platforms = codeHashToVersion[_codeHash].platforms;
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
     * Returns the governance for the given governance hash.
     * @param _governanceHash The governance hash.
     * @return _signers The governance signers.
     * @return _signersThreshold The governance signers threshold.
     */
    function getTeeGovernance(bytes32 _governanceHash)
        external view
        returns(address[] memory _signers, uint256 _signersThreshold)
    {
        return _getGovernance(_governanceHash);
    }

    /**
     * Returns the latest governance.
     * @return _signers The latest governance signers.
     * @return _signersThreshold The latest governance signers threshold.
     */
    function getLatestTeeGovernance()
        external view
        returns(address[] memory _signers, uint256 _signersThreshold)
    {
        return _getGovernance(latestTeeGovernanceHash);
    }

    /**
     * Returns the code hash info (governance hash, version and platforms).
     * @param _codeHash The code hash.
     * @return _governanceHash The governance hash.
     * @return _version The version.
     * @return _platforms The supported platforms.
     */
    function getCodeHashInfo(bytes32 _codeHash)
        external view
        returns(bytes32 _governanceHash, string memory _version, bytes32[] memory _platforms)
    {
        _governanceHash = codeHashToVersion[_codeHash].governanceHash;
        require(_governanceHash != bytes32(0), "invalid code hash");
        _version = codeHashToVersion[_codeHash].version;
        _platforms = codeHashToVersion[_codeHash].platforms;
    }

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
        if(codeHashToVersion[_codeHash].governanceHash == bytes32(0)) {
            return false; // invalid code hash
        }
        bytes32[] storage platforms = codeHashToVersion[_codeHash].platforms;
        for (uint256 i = 0; i < platforms.length; i++) {
            if (platforms[i] == _platform) {
                return true;
            }
        }
        return false; // invalid platform
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

    }

    function _getGovernance(bytes32 _governanceHash)
        internal view
        returns(address[] memory _signers, uint256 _signersThreshold)
    {
        _signersThreshold = governanceHashToGovernance[_governanceHash].signersThreshold;
        require(_signersThreshold > 0, "invalid governance hash");
        _signers = governanceHashToGovernance[_governanceHash].signers;
    }
}
