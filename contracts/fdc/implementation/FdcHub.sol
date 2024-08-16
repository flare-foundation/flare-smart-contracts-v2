// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../userInterfaces/IFdcHub.sol";
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

    /// Mapping of type and source to fee.
    mapping(bytes32 typeAndSource => uint256 fee) public typeAndSourceFees;

    /// Total rewards offered by inflation (in wei).
    uint256 public totalInflationRewardsOfferedWei;

    /// The RewardManager contract.
    IIRewardManager public rewardManager;

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
        RewardOffersManagerBase(_governanceSettings, _initialGovernance, _addressUpdater)
    { }

    /**
     * Sets the fee for a given type and source.
     * @param _type The type to set the fee for.
     * @param _source The source to set the fee for.
     * @param _fee The fee to set.
     * @dev Only governance can call this method.
     */
    function setTypeAndSourceFee(bytes32 _type, bytes32 _source, uint256 _fee) external onlyGovernance {
        _setSingleTypeAndSourceFee(_type, _source, _fee);
    }

    /**
     * Removes the fee for a given type and source.
     * @param _type The type to remove.
     * @param _source The source to remove.
     * @dev Only governance can call this method.
     */
    function removeTypeAndSourceFee(bytes32 _type, bytes32 _source) external onlyGovernance {
        _removeSingleTypeAndSourceFee(_type, _source);
    }

    /**
     * Sets the fees for multiple types and sources.
     * @param _types The types to set the fees for.
     * @param _sources The sources to set the fees for.
     * @param _fees The fees to set.
     * @dev Only governance can call this method.
     */
    function setTypeAndSourceFees(
        bytes32[] memory _types,
        bytes32[] memory _sources,
        uint256[] memory _fees
    )
        external onlyGovernance
    {
        require(_types.length == _sources.length && _types.length == _fees.length, "length mismatch");
        for (uint256 i = 0; i < _types.length; i++) {
            _setSingleTypeAndSourceFee(_types[i], _sources[i], _fees[i]);
        }
    }

    /**
     * Removes the fees for multiple types and sources.
     * @param _types The types to remove.
     * @param _sources The sources to remove.
     * @dev Only governance can call this method.
     */
    function removeTypeAndSourceFees(
        bytes32[] memory _types,
        bytes32[] memory _sources
    )
        external onlyGovernance
    {
        require(_types.length == _sources.length, "length mismatch");
        for (uint256 i = 0; i < _types.length; i++) {
            _removeSingleTypeAndSourceFee(_types[i], _sources[i]);
        }
    }

    /**
    * @inheritdoc IFdcHub
    */
    function requestAttestation(bytes calldata _data) external payable mustBalance {
        uint256 fee = _getBaseFee(_data);
        require(fee > 0, "No fee specified for this type and source");
        require(msg.value >= fee, "fee to low, call getRequestFee to get the required fee amount");
        uint24 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        rewardManager.receiveRewards{value: msg.value}(currentRewardEpochId, false);
        emit AttestationRequest(_data, msg.value);
    }

    /**
    * @inheritdoc IFdcHub
    */
    function getRequestFee(bytes calldata _data) external view returns (uint256) {
        return _getBaseFee(_data);
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
     * Sets the fee for a given type and source.
     */
    function _setSingleTypeAndSourceFee(bytes32 _type, bytes32 _source, uint256 _fee) internal {
        require(_fee > 0, "Fee must be greater than 0");
        typeAndSourceFees[_joinTypeAndSource(_type, _source)] = _fee;
        emit TypeAndSourceFeeSet(_type, _source, _fee);
    }

    /**
     * Removes a given type and source by setting the fee to 0.
     */
    function _removeSingleTypeAndSourceFee(bytes32 _type, bytes32 _source) internal {
        // Same as setting this to 0 but we want to emit a different event + gas savings
        require(typeAndSourceFees[_joinTypeAndSource(_type, _source)] > 0, "Fee not set");
        delete typeAndSourceFees[_joinTypeAndSource(_type, _source)];
        emit TypeAndSourceFeeRemoved(_type, _source);
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
        super._updateContractAddresses(_contractNameHashes, _contractAddresses);
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

    /**
     * Calculates the base fee for an attestation request.
     */
    function _getBaseFee(bytes calldata _data) internal view returns (uint256) {
        require(_data.length >= 64, "Request data too short, should at least specify type and source");
        bytes32 _type = abi.decode(_data[:32], (bytes32));
        bytes32 _source = abi.decode(_data[32:64], (bytes32));
        return _getTypeAndSourceFee(_type, _source);
    }

    /**
     * Returns the fee for a given type and source.
     */
    function _getTypeAndSourceFee(bytes32 _type, bytes32 _source) internal view returns (uint256 _fee) {
        _fee = typeAndSourceFees[_joinTypeAndSource(_type, _source)];
    }

    /**
     * Joins a type and source into a single bytes32 value.
     */
    function _joinTypeAndSource(bytes32 _type, bytes32 _source) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_type, _source));
    }
}
