// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITEERegistry.sol";

/**
 * TEEConfig interface.
 */
interface ITEEConfig {

    struct Wallet {
        address walletAdmin;
        string walletAddress;
        address paymentInitiator;
        ITEERegistry.TEEMachine[] teeMachines;
    }

    /**
     * Returns the wallet.
     * @param _walletId The wallet ID.
     * @return The wallet.
     */
    function getWallet(bytes32 _walletId) external view returns (Wallet memory);
}