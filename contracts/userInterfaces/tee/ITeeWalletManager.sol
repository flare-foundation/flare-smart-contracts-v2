// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeeRegistry.sol";

/**
 * TeeWalletManager interface.
 */
interface ITeeWalletManager {

    enum WalletStatus {
        INITIALIZED,
        CONFIRMED,
        PAUSED
    }

    /**
     * Returns information about the tee wallet.
     * @param _walletId The wallet id.
     * @param _submitAddress The submit address.
     * @param _status The wallet status.
     * @param _functionality The wallet functionality.
     */
    function getTeeWalletInfo(bytes32 _walletId) external view returns (
        address _submitAddress,
        WalletStatus _status,
        bytes32 _functionality
    );

    /**
     * Returns wallet's receiving tees.
     * @param _walletId The wallet id.
     * @return _receivingTees The receiving tees.
     */
    function receivingTees(bytes32 _walletId) external view returns (ITeeRegistry.TeeMachine[] memory _receivingTees);

    /**
     * Returns the wallet owner.
     * @param _walletId The wallet id.
     * @return _walletOwner The wallet owner.
     */
    function getWalletOwner(bytes32 _walletId) external view returns (address _walletOwner);
}