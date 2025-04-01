// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeePayments.sol";

/**
 * TeePaymentsEVM interface.
 */
interface ITeePaymentsEVM is ITeePayments {

    struct BaseSettingsEVM{
        uint256 chainId;
    }

    event ChainIdSet(
        bytes32 indexed projectId,
        uint256 chainId
    );

    /**
     * Sets the chain id for the wallet.
     * @param _walletId The wallet id.
     * @param _chainId The chain id.
     */
    function setChainId(bytes32 _walletId, uint256 _chainId)
        external;

    /**
     * Returns the chain id for the wallet.
     * @param _walletId The wallet id.
     * @return The chain id.
     */
    function getChainId(bytes32 _walletId)
        external view returns(uint256);
}