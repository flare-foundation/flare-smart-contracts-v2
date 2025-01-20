// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";

/**
 * TeeWalletConfig interface.
 */
interface ITeeWalletConfig {

    struct TeeWallet {
        address walletAdmin;
        string walletAddress;
        address paymentInitiator;
        ITeeRegistry.TeeMachine[] teeMachines;
    }

    /**
     * Returns the wallet.
     * @param _walletId The wallet ID.
     * @return The wallet.
     */
    function getWallet(bytes32 _walletId) external view returns (TeeWallet memory);
}