// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;
import "./ITeeIdKeyIdPair.sol";

interface ITeeWalletOpTypeSettings {

    /**
     * Returns the wallet operation type.
     * @return _opType The operation type.
     */
    function opType() external view returns (bytes32);
}