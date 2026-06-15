// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { TeeIdKeyIdPair } from "./ITeeIdKeyIdPair.sol";
import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";
import { IWalletManager } from "./IWalletManager.sol";

/**
 * @title IWalletResume
 * @notice Public interface for the WalletResumeFacet.
 */
interface IWalletResume is ITeeCommonErrors {

    struct SetPausingAddresses {
        bytes32 walletId;
        uint256 nonce;
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        address[] pausingAddresses;
    }

    struct ResumeKeyData {
        uint64 keyId;
        address teeId;
        uint256 nonce;
    }

    struct Resume {
        bytes32 walletId;
        ResumeKeyData[] keysData;
    }

    event PausingAddressesSet(bytes32 indexed walletId, uint256 nonce, address[] pausingAddresses);
    event WalletResumed(bytes32 indexed walletId, ResumeKeyData[] keysData);

    error WrongKeyId();

    /**
     * Set pausing addresses (for pausing keys) instruction method.
     * @param _walletId The wallet id.
     * @param _pausingAddresses The list of pausing addresses, can be empty.
     * @param _claimBackAddress An address that can claim back the fee if the instructions are not executed (optional).
     * Can only be called by the wallet owner.
     */
    function setPausingAddresses(
        bytes32 _walletId,
        address[] calldata _pausingAddresses,
        address _claimBackAddress
    )
        external payable;

    /**
     * Resume paused keys instruction method.
     * @param _walletId The wallet id.
     * @param _keysData The list of keys's data.
     * @param _claimBackAddress An address that can claim back the fee if the instructions are not executed (optional).
     * Can only be called by the wallet owner.
     */
    function resume(
        bytes32 _walletId,
        ResumeKeyData[] calldata _keysData,
        address _claimBackAddress
    )
        external payable;
}
