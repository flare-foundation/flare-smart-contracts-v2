// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/tokenPools/interface/IIFtsoRewardManager.sol";
import "flare-smart-contracts/contracts/ftso/interface/IIFtsoManager.sol";
import "flare-smart-contracts/contracts/genesis/interface/IIPriceSubmitter.sol";
import "flare-smart-contracts/contracts/utils/interface/IIFtsoRegistry.sol";
import "../../protocol/interface/IIRewardManager.sol";
import "../../protocol/interface/IIFlareSystemsManager.sol";
import "../../fastUpdates/interface/IIFastUpdater.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/IFastUpdatesConfiguration.sol";
import "../../userInterfaces/ISubmission.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";


/**
 * FtsoManagerProxy is a compatibility contract replacing FtsoManager
 * that is used for proxying data from FlareSystemsManager.
 */

contract FtsoManagerProxy is IFtsoManager, Governed, ReentrancyGuard, AddressUpdatable {
    using SafeCast for uint256;

    // for redeploy (name is kept for compatibility)
    address public immutable oldFtsoManager;

    // contract addresses
    /// FtsoRewardManagerProxy contract address (name is kept for compatibility)
    address public rewardManager;
    /// FtsoRegistry contract address.
    IIFtsoRegistry public ftsoRegistry;
    /// Flare systems manager contract address.
    IIFlareSystemsManager public flareSystemsManager;
    /// Reward manager (V2) contract address.
    IIRewardManager public rewardManagerV2;
    /// FastUpdater contract address.
    IIFastUpdater public fastUpdater;
    /// The FastUpdatesConfiguration contract.
    IFastUpdatesConfiguration public fastUpdatesConfiguration;
    /// Submission contract.
    ISubmission public submission;

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        address _oldFtsoManager
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        oldFtsoManager = _oldFtsoManager; // or old ftso manager proxy address
    }

    /**
     * Adds FtsoProxy contracts to the FtsoRegistry.
     */
    function addFtsos(IFtso[] memory _ftsos) external onlyGovernance {
        for (uint256 i = 0; i < _ftsos.length; i++) {
            IIFtso ftso = IIFtso(address(_ftsos[i]));
            require(address(this) == ftso.ftsoManager(), "invalid ftso manager");
            ftsoRegistry.addFtso(ftso);
        }
    }

    /**
     * Removes FtsoProxy contracts from the FtsoRegistry.
     */
    function removeFtsos(IFtso[] memory _ftsos) external onlyGovernance {
        for (uint256 i = 0; i < _ftsos.length; i++) {
            IIFtso ftso = IIFtso(address(_ftsos[i]));
            require(address(this) == ftso.ftsoManager(), "invalid ftso manager");
            ftsoRegistry.removeFtso(ftso);
        }
    }

    /**
     * This method should be called only once by governance in order to remove the trusted addresses.
     */
    function removeTrustedAddresses() external onlyGovernance {
        IIPriceSubmitter(0x1000000000000000000000000000000000000003).setTrustedAddresses(new address[](0));
    }

    /**
     * @inheritdoc IFtsoManager
     */
    function getCurrentRewardEpoch() external view returns (uint256) {
        return flareSystemsManager.getCurrentRewardEpoch();
    }

    /**
     * @inheritdoc IFtsoManager
     */
    function getRewardEpochVotePowerBlock(uint256 _rewardEpoch) external view returns (uint256) {
        return flareSystemsManager.getVotePowerBlock(_rewardEpoch);
    }

    /**
     * @inheritdoc IFtsoManager
     */
    function getRewardEpochToExpireNext() external view returns (uint256) {
        return rewardManagerV2.getRewardEpochIdToExpireNext();
    }

    /**
     * @inheritdoc IFtsoManagerGenesis
     */
    function getCurrentPriceEpochId() external view returns (uint256 _priceEpochId) {
        return flareSystemsManager.getCurrentVotingEpochId();
    }

    /**
     * @inheritdoc IFtsoManager
     */
    function getCurrentPriceEpochData() external view
        returns (
            uint256 _priceEpochId,
            uint256 _priceEpochStartTimestamp,
            uint256 _priceEpochEndTimestamp,
            uint256 _priceEpochRevealEndTimestamp,
            uint256 _currentTimestamp
        )
    {
        uint256 firstVotingEpochStartTs = flareSystemsManager.firstVotingRoundStartTs();
        uint256 votingEpochDurationSec = flareSystemsManager.votingEpochDurationSeconds();
        _priceEpochId = (block.timestamp - firstVotingEpochStartTs) / votingEpochDurationSec;
        _priceEpochStartTimestamp = firstVotingEpochStartTs + _priceEpochId * votingEpochDurationSec;
        _priceEpochEndTimestamp = _priceEpochStartTimestamp + votingEpochDurationSec;
        _priceEpochRevealEndTimestamp = _priceEpochEndTimestamp + votingEpochDurationSec / 2;
        _currentTimestamp = block.timestamp;
    }

    /**
     * @inheritdoc IFtsoManager
     */
    function getPriceEpochConfiguration() external view
        returns (
            uint256 _firstPriceEpochStartTs,
            uint256 _priceEpochDurationSeconds,
            uint256 _revealEpochDurationSeconds
        )
    {
        _firstPriceEpochStartTs = flareSystemsManager.firstVotingRoundStartTs();
        _priceEpochDurationSeconds = flareSystemsManager.votingEpochDurationSeconds();
        _revealEpochDurationSeconds = _priceEpochDurationSeconds / 2;
    }

    /**
     * @inheritdoc IFtsoManager
     */
    function getRewardEpochConfiguration() external view
        returns (
            uint256 _firstRewardEpochStartTs,
            uint256 _rewardEpochDurationSeconds
        )
    {
        _firstRewardEpochStartTs = flareSystemsManager.firstRewardEpochStartTs();
        _rewardEpochDurationSeconds = flareSystemsManager.rewardEpochDurationSeconds();
    }

    /**
     * Timestamp when the first reward epoch started, in seconds since UNIX epoch.
     */
    function firstRewardEpochStartTs() external view returns (uint64) {
        return flareSystemsManager.firstRewardEpochStartTs();
    }

    /**
     * Duration of reward epoch, in seconds.
     */
    function rewardEpochDurationSeconds() external view returns (uint64) {
        return flareSystemsManager.rewardEpochDurationSeconds();
    }

    /**
     * Timestamp when the first voting epoch started, in seconds since UNIX epoch.
     */
    function firstVotingRoundStartTs() external view returns (uint64) {
        return flareSystemsManager.firstVotingRoundStartTs();
    }

    /**
     * Duration of voting epoch, in seconds.
     */
    function votingEpochDurationSeconds() external view returns (uint64) {
        return flareSystemsManager.votingEpochDurationSeconds();
    }

    /**
     * Returns the vote power block for given reward epoch id.
     */
    function getVotePowerBlock(uint256 _rewardEpochId) external view returns(uint64 _votePowerBlock) {
        return flareSystemsManager.getVotePowerBlock(_rewardEpochId);
    }

    /**
     * Returns the start voting round id for given reward epoch id.
     */
    function getStartVotingRoundId(uint256 _rewardEpochId) external view returns(uint32) {
        return flareSystemsManager.getStartVotingRoundId(_rewardEpochId);
    }

    /**
     * Returns the current reward epoch id.
     */
    function getCurrentRewardEpochId() external view returns(uint24) {
        return flareSystemsManager.getCurrentRewardEpochId();
    }

    /**
     * Returns the current voting epoch id.
     */
    function getCurrentVotingEpochId() external view returns(uint32) {
        return flareSystemsManager.getCurrentVotingEpochId();
    }

    /**
     * @inheritdoc IFtsoManager
     */
    function getFtsos() external view returns (IIFtso[] memory) {
        return _getFtsos();
    }

    /**
     * @inheritdoc IFtsoManager
     */
    function getFallbackMode() external view
        returns (
            bool _fallbackMode,
            IIFtso[] memory _ftsos,
            bool[] memory _ftsoInFallbackMode
        )
    {
        _fallbackMode = false;
        _ftsos = _getFtsos();
        uint256 len = _ftsos.length;
        _ftsoInFallbackMode = new bool[](len); // all false
    }

    /**
     * @inheritdoc IFtsoManager
     */
    function active() external pure returns (bool) {
        return true;
    }

    /**
     * Implementation of the AddressUpdatable abstract method.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        rewardManager = _getContractAddress(_contractNameHashes, _contractAddresses, "FtsoRewardManager");
        ftsoRegistry = IIFtsoRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtsoRegistry"));
        rewardManagerV2 = IIRewardManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
        flareSystemsManager = IIFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        fastUpdater = IIFastUpdater(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FastUpdater"));
        fastUpdatesConfiguration = IFastUpdatesConfiguration(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FastUpdatesConfiguration"));
        submission = ISubmission(
            _getContractAddress(_contractNameHashes, _contractAddresses, "Submission"));
    }

    /**
     * Returns the supported FTSOs.
     */
    function _getFtsos() internal view returns (IIFtso[] memory) {
        return ftsoRegistry.getSupportedFtsos();
    }
}
