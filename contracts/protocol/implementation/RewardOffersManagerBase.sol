// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../governance/implementation/Governed.sol";
import "../../inflation/implementation/InflationReceiver.sol";
import "../interface/IIFlareSystemManager.sol";
import "../interface/IIRewardEpochSwitchoverTrigger.sol";

/**
 * RewardOffersManagerBase contrat.
 *
 * This contract is used to manage the reward offers and receive the inflation.
 * It is used by the Flare system to trigger the reward offers.
 */
abstract contract RewardOffersManagerBase is Governed, InflationReceiver, IIRewardEpochSwitchoverTrigger {

    uint256 internal constant INFLATION_TIME_FRAME_SEC = 1 days;

    /// The FlareSystemManager contract.
    IIFlareSystemManager public flareSystemManager;

    /// Only FlareSystemManager contract can call this method.
    modifier onlyFlareSystemManager {
        require(msg.sender == address(flareSystemManager), "only flare system manager");
        _;
    }

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
        Governed(_governanceSettings, _initialGovernance) InflationReceiver(_addressUpdater)
    { }

    /**
     * @inheritdoc IIRewardEpochSwitchoverTrigger
     */
    function triggerRewardEpochSwitchover(
        uint24 _currentRewardEpochId,
        uint64 _currentRewardEpochExpectedEndTs,
        uint64 _rewardEpochDurationSeconds
    )
        external
        onlyFlareSystemManager
    {
        _triggerInflationOffers(_currentRewardEpochId, _currentRewardEpochExpectedEndTs, _rewardEpochDurationSeconds);
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal virtual override
    {
        super._updateContractAddresses(_contractNameHashes, _contractAddresses);
        flareSystemManager = IIFlareSystemManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemManager"));
    }

    /**
     * @dev Triggers the inflation offers.
     * @param _currentRewardEpochId The current reward epoch id.
     * @param _currentRewardEpochExpectedEndTs The current reward epoch expected end timestamp.
     * @param _rewardEpochDurationSeconds The reward epoch duration in seconds.
     */
    function _triggerInflationOffers(
        uint24 _currentRewardEpochId,
        uint64 _currentRewardEpochExpectedEndTs,
        uint64 _rewardEpochDurationSeconds
    )
        internal virtual;

}
