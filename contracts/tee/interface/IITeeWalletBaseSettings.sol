// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

interface IITeeWalletBaseSettings {

    /**
     * Returns the operation type.
     * @return The operation type.
     */
    function opType() external view returns(bytes32);

    /**
     * Returns the additionally required base settings.
     * @param _walletId The wallet id.
     * @return The abi encoded base settings.
     * NOTE: Should revert if the required base settings are not set.
     */
    function getBaseSettings(bytes32 _walletId) external view returns(bytes memory);

}
