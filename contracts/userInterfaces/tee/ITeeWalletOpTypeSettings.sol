// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeIdKeyIdPair.sol";

interface ITeeWalletOpTypeSettings {

    struct SetPausingAddresses {
        bytes32 walletId;
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        address[] pausingAddresses;
    }

    /**
     * Set pausing addresses instruction method.
     * Can only be called by the wallet owner address.
     * @param _walletId The wallet id.
     * @param _pausingAddresses The pausing addresses.
     */
    function setPausingAddresses(
        bytes32 _walletId,
        address[] calldata _pausingAddresses
    )
        external payable;

    /**
     * Returns the wallet operation type.
     * @return _opType The operation type.
     */
    function opType() external view returns (bytes32);
}