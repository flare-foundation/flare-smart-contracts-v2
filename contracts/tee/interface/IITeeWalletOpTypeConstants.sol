// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

interface IITeeWalletOpTypeConstants {

    /**
     * Returns the operation type.
     * @return The operation type.
     */
    function opType() external view returns(bytes32);

    /**
     * Returns the required operation type constants.
     * @param _walletId The wallet id.
     * @return The abi encoded operation type constants.
     * NOTE: Should revert if the required operation type constants are not set.
     */
    function getOpTypeConstants(bytes32 _walletId) external view returns(bytes memory);

}
