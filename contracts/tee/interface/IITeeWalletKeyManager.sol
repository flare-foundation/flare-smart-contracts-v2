// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeeWalletKeyManager.sol";

interface IITeeWalletKeyManager is ITeeWalletKeyManager {

    /**
     * Increases the key nonce for the given tee id and wallet id.
     * @param _teeId The tee id.
     * @param _walletId The wallet id.
     * @param _keyId The key id.
     * @return _nonce The new nonce.
     * NOTE: The nonce is used to prevent replay attacks.
     * Can only be called by the TEE machine backup manager.
     */
    function increaseKeyNonce(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId
    )
        external
        returns (uint256 _nonce);
}