// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../userInterfaces/IFdcHub.sol";
import "../../userInterfaces/IFdcRequestFeeConfigurations.sol";
import "../../protocol/interface/IIRewardManager.sol";
import "../../protocol/implementation/RewardOffersManagerBase.sol";
import "../../utils/lib/SafePct.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * FdcHub contract.
 *
 * This contract is used to manage the FDC attestation requests and receive the inflation.
 * It is triggered by the Flare systems manager to emit the inflation reward offers.
 */
contract FdcHub is RewardOffersManagerBase, IFdcHub {
    using SafePct for uint256;

    /// Total rewards offered by inflation (in wei).
    uint256 public totalInflationRewardsOfferedWei;

    /// The FDC inflation configurations contract.
    IFdcInflationConfigurations public fdcInflationConfigurations;

    /// The FDC request fee configurations contract.
    IFdcRequestFeeConfigurations public fdcRequestFeeConfigurations;

    /// The RewardManager contract.
    IIRewardManager public rewardManager;

    /// The offset (in seconds) for the requests to be processed during the current voting round.
    uint8 public requestsOffsetSeconds;

    /**
    * Constructor.
    * @param _governanceSettings The address of the GovernanceSettings contract.
    * @param _initialGovernance The initial governance address.
    * @param _addressUpdater The address of the AddressUpdater contract.
    * @param _requestsOffsetSeconds The requests offset in seconds.
    */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint8 _requestsOffsetSeconds
    )
        RewardOffersManagerBase(_governanceSettings, _initialGovernance, _addressUpdater)
    {
        requestsOffsetSeconds = _requestsOffsetSeconds;
        emit RequestsOffsetSet(_requestsOffsetSeconds);
    }

    /**
     * Sets the offset for the requests to be processed during the current voting round.
     * @param _requestsOffsetSeconds The requests offset in seconds.
     * @dev Only governance can call this method.
     */
    function setRequestsOffset(uint8 _requestsOffsetSeconds) external onlyGovernance {
        require(_requestsOffsetSeconds < flareSystemsManager.votingEpochDurationSeconds(), "invalid offset");
        requestsOffsetSeconds = _requestsOffsetSeconds;
        emit RequestsOffsetSet(_requestsOffsetSeconds);
    }

    /**
     * @inheritdoc IFdcHub
     */
    function requestAttestation(bytes calldata _data) external payable mustBalance {
        uint256 fee = fdcRequestFeeConfigurations.getRequestFee(_data);
        require(msg.value >= fee, "fee to low, call getRequestFee to get the required fee amount");
        uint24 rewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        uint64 currentRewardEpochExpectedEndTs = flareSystemsManager.currentRewardEpochExpectedEndTs();
        if (block.timestamp >= currentRewardEpochExpectedEndTs - requestsOffsetSeconds) {
            try flareSystemsManager.getStartVotingRoundId(rewardEpochId + 1) returns (uint32 _startVotingRoundId) {
                if (_startVotingRoundId <= flareSystemsManager.getCurrentVotingEpochId() + 1) {
                    rewardEpochId += 1;
                }
            } catch {
                // use the current reward epoch id
            }
        }
        rewardManager.receiveRewards{value: msg.value}(rewardEpochId, false);
        emit AttestationRequest(_data, msg.value);
    }

    /**
     * @inheritdoc IITokenPool
     */
    function getTokenPoolSupplyData()
        external view
        returns (
            uint256 _lockedFundsWei,
            uint256 _totalInflationAuthorizedWei,
            uint256 _totalClaimedWei
        )
    {
        _lockedFundsWei = 0;
        _totalInflationAuthorizedWei = totalInflationAuthorizedWei;
        _totalClaimedWei = totalInflationRewardsOfferedWei;
    }

    /**
     * Implement this function to allow updating inflation receiver contracts through `AddressUpdater`.
     * @return Contract name.
     */
    function getContractName() external pure returns (string memory) {
        return "FdcHub";
    }

    ////////////////////////// Internal functions ///////////////////////////////////////////////

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        super._updateContractAddresses(_contractNameHashes, _contractAddresses);
        fdcInflationConfigurations = IFdcInflationConfigurations(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FdcInflationConfigurations"));
        fdcRequestFeeConfigurations = IFdcRequestFeeConfigurations(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FdcRequestFeeConfigurations"));
        rewardManager = IIRewardManager(_getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
    }

    /**
     * @inheritdoc InflationReceiver
     */
    function _setDailyAuthorizedInflation(uint256 _toAuthorizeWei) internal override {
        // do nothing
    }

    /**
     * @inheritdoc InflationReceiver
     */
    function _receiveInflation() internal override {
        // do nothing
    }

    /**
     * @inheritdoc RewardOffersManagerBase
     */
    function _triggerInflationOffers(
        uint24 _currentRewardEpochId,
        uint64 _currentRewardEpochExpectedEndTs,
        uint64 _rewardEpochDurationSeconds
    ) internal virtual override {
         // start of previous reward epoch
        uint256 intervalStart = _currentRewardEpochExpectedEndTs - 2 * _rewardEpochDurationSeconds;
        uint256 intervalEnd = Math.max(lastInflationReceivedTs + INFLATION_TIME_FRAME_SEC,
            _currentRewardEpochExpectedEndTs - _rewardEpochDurationSeconds); // start of current reward epoch (in past)
        // _rewardEpochDurationSeconds <= intervalEnd - intervalStart
        uint256 totalRewardsAmount = (totalInflationReceivedWei - totalInflationRewardsOfferedWei)
            .mulDiv(_rewardEpochDurationSeconds, intervalEnd - intervalStart);
        uint24 nextRewardEpochId = _currentRewardEpochId + 1;
        // emit offer
        emit InflationRewardsOffered(
            nextRewardEpochId,
            fdcInflationConfigurations.getFdcConfigurations(),
            totalRewardsAmount
        );
        // send reward amount to reward manager
        totalInflationRewardsOfferedWei += totalRewardsAmount;
        rewardManager.receiveRewards{value: totalRewardsAmount} (nextRewardEpochId, true);
    }

    /**
     * @inheritdoc TokenPoolBase
     */
    function _getExpectedBalance() internal view override returns (uint256 _balanceExpectedWei) {
        return totalInflationReceivedWei - totalInflationRewardsOfferedWei;
    }
}
