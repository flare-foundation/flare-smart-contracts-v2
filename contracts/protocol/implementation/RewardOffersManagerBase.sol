// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../governance/implementation/Governed.sol";
import "../../inflation/implementation/InflationReceiver.sol";
import "../../protocol/implementation/FlareSystemManager.sol";
import "../interface/IRewardEpochSwitchoverTrigger.sol";


abstract contract RewardOffersManagerBase is Governed, InflationReceiver, IRewardEpochSwitchoverTrigger {

    uint256 internal constant INFLATION_TIME_FRAME_SEC = 1 days;

    /// The FlareSystemManager contract.
    FlareSystemManager public flareSystemManager;

    /// Only FlareSystemManager contract can call this method.
    modifier onlyFlareSystemManager {
        require(msg.sender == address(flareSystemManager), "only flare system manager");
        _;
    }

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        Governed(_governanceSettings, _initialGovernance) InflationReceiver(_addressUpdater)
    { }

    function triggerRewardEpochSwitchover(
        uint24 _currentRewardEpochId,
        uint64 _currentRewardEpochExpectedEndTs,
        uint64 _rewardEpochDurationSeconds
    )
        external override
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
        flareSystemManager = FlareSystemManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemManager"));
    }

    function _triggerInflationOffers(
        uint24 _currentRewardEpochId,
        uint64 _currentRewardEpochExpectedEndTs,
        uint64 _rewardEpochDurationSeconds
    )
        internal virtual;

}
