// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/inflation/interface/IIInflationReceiver.sol";
import "../../governance/implementation/AddressUpdatable.sol";
import "./TokenPoolBase.sol";


abstract contract InflationReceiver is TokenPoolBase, IIInflationReceiver, AddressUpdatable {

    // totals
    uint256 internal totalInflationAuthorizedWei;
    uint256 internal totalInflationReceivedWei;
    uint256 internal lastInflationAuthorizationReceivedTs;
    uint256 internal dailyAuthorizedInflation;

    // addresses
    address internal inflation;

    event DailyAuthorizedInflationSet(uint256 authorizedAmountWei);
    event InflationReceived(uint256 amountReceivedWei);

    /**
     * @dev This modifier ensures that method can only be called by inflation.
     */
    modifier onlyInflation{
        _checkOnlyInflation();
        _;
    }

    constructor(address _addressUpdater) AddressUpdatable(_addressUpdater) {}

    /**
     * @notice Notify the receiver that it is entitled to receive `_toAuthorizeWei` inflation amount.
     * @param _toAuthorizeWei the amount of inflation that can be awarded in the coming day
     */
    function setDailyAuthorizedInflation(uint256 _toAuthorizeWei) external override onlyInflation {
        dailyAuthorizedInflation = _toAuthorizeWei;
        totalInflationAuthorizedWei = totalInflationAuthorizedWei + _toAuthorizeWei;
        lastInflationAuthorizationReceivedTs = block.timestamp;

        _setDailyAuthorizedInflation(_toAuthorizeWei);

        emit DailyAuthorizedInflationSet(_toAuthorizeWei);
    }

    /**
     * @notice Receive native tokens from inflation.
     */
    function receiveInflation() external payable override mustBalance onlyInflation {
        totalInflationReceivedWei = totalInflationReceivedWei + msg.value;

        _receiveInflation();

        emit InflationReceived(msg.value);
    }

    /**
     * @notice Inflation receivers have a reference to the inflation contract.
     */
    function getInflationAddress() external view override returns(address) {
        return inflation;
    }

    /**
     * @notice Return expected balance of reward manager ignoring sent self-destruct funds
     */
    function getExpectedBalance() external view override returns(uint256) {
        return _getExpectedBalance();
    }

    /**
     * @notice Implementation of the AddressUpdatable abstract method.
     * @dev It can be overridden if other contracts are needed.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal virtual override
    {
        inflation = _getContractAddress(_contractNameHashes, _contractAddresses, "Inflation");
    }

    /**
     * @dev Method that is called when new daily inflation is authorized.
     */
    function _setDailyAuthorizedInflation(uint256 _toAuthorizeWei) internal virtual {}

    /**
     * @dev Method that is called when new inflation is received.
     */
    function _receiveInflation() internal virtual {}

    function _checkOnlyInflation() private view {
        require(msg.sender == inflation, "inflation only");
    }
}
