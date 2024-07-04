// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "flare-smart-contracts/contracts/userInterfaces/IClaimSetupManager.sol";
import "../../userInterfaces/IWNat.sol";

/**
 * Internal interface for the `ClaimSetupManager contract.
 */
interface IIClaimSetupManager is IClaimSetupManager {
    /**
     * Emitted when the `libraryAddress` has been set.
     */
    event SetLibraryAddress(address libraryAddress);

    /**
     * Sets new library address.
     */
    function setLibraryAddress(address _libraryAddress) external;

    /**
     * Sets minimum fee allowed for executors, in wei.
     */
    function setMinFeeValueWei(uint256 _minFeeValueWei) external;

    /**
     * Sets maximum fee allowed for executors, in wei.
     */
    function setMaxFeeValueWei(uint256 _maxFeeValueWei) external;

    /**
     * Sets the fee required to register an executor, which must be higher than 0.
     */
    function setRegisterExecutorFeeValueWei(uint256 _registerExecutorFeeValueWei) external;

    /**
     * Returns the `WNat` contract.
     */
    function wNat() external view returns(IWNat);

    /**
     * Gets the [Personal Delegation Account](https://docs.flare.network/tech/personal-delegation-account) (PDA) for
     * a list of accounts for which an executor is claiming.
     * Returns owner address instead if the PDA is not created yet or not enabled.
     * @param _executor Executor to query.
     * @param _owners Array of reward owners which must have set `_executor` as their executor.
     * @return _recipients Addresses which will receive the claimed rewards. Can be the reward owners or their PDAs.
     * @return _executorFeeValue Executor's fee value, in wei.
     */
    function getAutoClaimAddressesAndExecutorFee(address _executor, address[] memory _owners)
        external view returns (address[] memory _recipients, uint256 _executorFeeValue);

    /**
     * Checks if an executor can claim on behalf of a given account and send funds to a given recipient address.
     *
     * Reverts if claiming is not possible, does nothing otherwise.
     * @param _executor The executor to query.
     * @param _owner The reward owner to query.
     * @param _recipient The address where the reward would be sent.
     */
    function checkExecutorAndAllowedRecipient(address _executor, address _owner, address _recipient)
        external view;
}
