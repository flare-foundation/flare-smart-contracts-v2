// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IFdcHub.sol";
import "../../protocol/interface/IIRewardManager.sol";
import "../../protocol/implementation/RewardOffersManagerBase.sol";

// contract FdcHub is IFdcHub {
contract FdcHub is RewardOffersManagerBase, IFdcHub {
  mapping(bytes32 => uint256) public typeAndSourceFees;

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
  ) RewardOffersManagerBase(_governanceSettings, _initialGovernance, _addressUpdater) {
    // Pass
  }

  function setTypeAndSourceFee(bytes32 _type, bytes32 source, uint256 fee) external onlyGovernance {
    _setSingleTypeAndSourceFee(_type, source, fee);
  }

  function removeTypeAndSourceFee(bytes32 _type, bytes32 source) external onlyGovernance {
    _removeSingleTypeAndSourceFee(_type, source);
  }

  function setTypeAndSourceFees(
    bytes32[] memory _types,
    bytes32[] memory _sources,
    uint256[] memory _fees
  ) external onlyGovernance {
    require(_types.length == _sources.length && _types.length == _fees.length, "length mismatch");
    for (uint256 i = 0; i < _types.length; i++) {
      _setSingleTypeAndSourceFee(_types[i], _sources[i], _fees[i]);
    }
  }

  function removeTypeAndSourceFees(bytes32[] memory _types, bytes32[] memory _sources) external onlyGovernance {
    require(_types.length == _sources.length, "length mismatch");
    for (uint256 i = 0; i < _types.length; i++) {
      _removeSingleTypeAndSourceFee(_types[i], _sources[i]);
    }
  }

  /**
   * @inheritdoc IFdcHub
   */
  function requestAttestation(bytes calldata _data) external payable {
    uint256 fee = _getBaseFee(_data);
    require(msg.value >= fee, "fee to low, call getBaseFee to get the required fee amount");
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

  function _setSingleTypeAndSourceFee(bytes32 _type, bytes32 _source, uint256 _fee) private onlyGovernance {
    require(_fee > 0, "Fee must be greater than 0");
    typeAndSourceFees[_joinTypeAndSource(_type, _source)] = _fee;
    emit TypeAndSourceFeeSet(_type, _source, _fee);
  }

  function _removeSingleTypeAndSourceFee(bytes32 _type, bytes32 _source) private onlyGovernance {
    // Same as setting this to 0 but we want to emit a different event + gas savings
    delete typeAndSourceFees[_joinTypeAndSource(_type, _source)];
    emit TypeAndSourceFeeRemoved(_type, _source);
  }

  function _getBaseFee(bytes calldata _data) private view returns (uint256) {
    require(_data.length >= 64, "Request data too short, shoudl at least specify type and source");
    bytes32 _type = abi.decode(_data[:32], (bytes32));
    bytes32 _source = abi.decode(_data[32:64], (bytes32));
    return _getTypeAndSourceFee(_type, _source);
  }

  function _getTypeAndSourceFee(bytes32 _type, bytes32 _source) private view returns (uint256 value) {
    value = typeAndSourceFees[_joinTypeAndSource(_type, _source)];
  }

  function _joinTypeAndSource(bytes32 _type, bytes32 _source) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(_type, _source));
  }

  ////////////////////////////////////////////
  // Virtual methods implementations
  ////////////////////////////////////////////

  /**
   * @inheritdoc IITokenPool
   */
  function getTokenPoolSupplyData()
    external
    override
    returns (uint256 _lockedFundsWei, uint256 _totalInflationAuthorizedWei, uint256 _totalClaimedWei)
  {}

  function _getExpectedBalance() internal view virtual override returns (uint256 _balanceExpectedWei) {}

  function getContractName() external view override returns (string memory) {
    return "FdcHub";
  }

  function _setDailyAuthorizedInflation(uint256 _toAuthorizeWei) internal virtual override {}

  function _receiveInflation() internal virtual override {}

  function _triggerInflationOffers(
    uint24 _currentRewardEpochId,
    uint64 _currentRewardEpochExpectedEndTs,
    uint64 _rewardEpochDurationSeconds
  ) internal virtual override {}
}
