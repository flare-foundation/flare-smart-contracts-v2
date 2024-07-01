// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IFdcHub.sol";
import "../../protocol/interface/IIRewardManager.sol";
import "../../protocol/implementation/RewardOffersManagerBase.sol";

// contract FdcHub is IFdcHub {
contract FdcHub is RewardOffersManagerBase, IFdcHub {
  uint256 public constant MINIMAL_FEE = 1 wei;

  mapping(bytes32 => uint256) public typeAndSourcePrices;

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

  function setTypeAndSourcePrice(bytes32 _type, bytes32 _source, uint256 _price) external onlyGovernance {
    _setSingleTypeAndSourcePrice(_type, _source, _price);
  }

  function setTypeAndSourcePrices(
    bytes32[] memory _types,
    bytes32[] memory _source,
    uint256[] memory _price
  ) external onlyGovernance {
    require(_types.length == _source.length && _types.length == _price.length, "length mismatch");
    for (uint256 i = 0; i < _types.length; i++) {
      _setSingleTypeAndSourcePrice(_types[i], _source[i], _price[i]);
    }
  }

  function _setSingleTypeAndSourcePrice(bytes32 _type, bytes32 _source, uint256 _price) private onlyGovernance {
    typeAndSourcePrices[_joinTypeAndSource(_type, _source)] = _price;
    emit TypeAndSourcePriceSet(_type, _source, _price);
  }

  function requestAttestation(bytes calldata _data) external payable {
    uint256 fee = _getBaseFee(_data);
    require(msg.value >= fee, "fee to low, call getBaseFee to get the required fee amount");
    uint24 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
    rewardManager.receiveRewards{value: msg.value} (currentRewardEpochId, false);


    emit AttestationRequest(_data, msg.value);
  }

  function getBaseFee(bytes calldata _data) external view returns (uint256) {
    return _getBaseFee(_data);
  }

  function _getBaseFee(bytes calldata _data) internal view returns (uint256) {
    require(_data.length >= 64, "Request data too short, shoudl at least specify type and source");
    bytes32 _type = abi.decode(_data[:32], (bytes32));
    bytes32 _source = abi.decode(_data[32:64], (bytes32));
    return _getTypeAndSourcePrice(_type, _source);
  }

  function _getTypeAndSourcePrice(bytes32 _type, bytes32 _source) internal view returns (uint256 value) {
    value = typeAndSourcePrices[_joinTypeAndSource(_type, _source)];
    if (value == 0) {
      value = MINIMAL_FEE;
    }
  }

  function _joinTypeAndSource(bytes32 _type, bytes32 _source) internal pure returns (bytes32) {
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
