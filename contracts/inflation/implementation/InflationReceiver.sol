// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/inflation/interface/IIInflationReceiver.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../utils/implementation/TokenPoolBase.sol";

/**
 * InflationReceiver contract.
 *
 * This is a base contract for receiving the inflation.
 */
abstract contract InflationReceiver is TokenPoolBase, IIInflationReceiver, AddressUpdatable {

    // totals
    uint256 public totalInflationAuthorizedWei;
    uint256 public totalInflationReceivedWei;
    uint256 public lastInflationAuthorizationReceivedTs;
    uint256 public lastInflationReceivedTs;
    uint256 public dailyAuthorizedInflation;

    // addresses
    address internal inflation;

    /// Event emitted when a new daily inflation is authorized.
    event DailyAuthorizedInflationSet(uint256 authorizedAmountWei);
    /// Event emitted when new inflation is received.
    event InflationReceived(uint256 amountReceivedWei);

    /// Modifier that checks that only inflation can call this method.
    modifier onlyInflation{
        _checkOnlyInflation();
        _;
    }

    /**
     * Constructor.
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(address _addressUpdater) AddressUpdatable(_addressUpdater) {}

    /**
     * Notify the receiver that it is entitled to receive `_toAuthorizeWei` inflation amount.
     * @param _toAuthorizeWei the amount of inflation that can be awarded in the coming day
     */
    function setDailyAuthorizedInflation(uint256 _toAuthorizeWei) external onlyInflation {
        dailyAuthorizedInflation = _toAuthorizeWei;
        totalInflationAuthorizedWei = totalInflationAuthorizedWei + _toAuthorizeWei;
        lastInflationAuthorizationReceivedTs = block.timestamp;

        _setDailyAuthorizedInflation(_toAuthorizeWei);

        emit DailyAuthorizedInflationSet(_toAuthorizeWei);
    }

    /**
     * Receive native tokens from inflation.
     */
    function receiveInflation() external payable mustBalance onlyInflation {
        totalInflationReceivedWei = totalInflationReceivedWei + msg.value;
        lastInflationReceivedTs = block.timestamp;

        _receiveInflation();

        emit InflationReceived(msg.value);
    }

    /**
     * Inflation receivers have a reference to the inflation contract.
     */
    function getInflationAddress() external view returns(address) {
        return inflation;
    }

    /**
     * Return expected balance of reward manager ignoring sent self-destruct funds.
     */
    function getExpectedBalance() external view returns(uint256) {
        return _getExpectedBalance();
    }

    /**
     * Implementation of the AddressUpdatable abstract method.
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
     * Method that is called when new daily inflation is authorized.
     */
    function _setDailyAuthorizedInflation(uint256 _toAuthorizeWei) internal virtual;

    /**
     * Method that is called when new inflation is received.
     */
    function _receiveInflation() internal virtual;

    /**
     * Checks that the caller is inflation.
     */
    function _checkOnlyInflation() private view {
        require(msg.sender == inflation, "inflation only");
    }
}
