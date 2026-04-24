// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IWalletManager } from "../../userInterfaces/tee/IWalletManager.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { PublicKey } from "../../userInterfaces/IPublicKey.sol";
import { PublicKeyUtils } from "../../utils/lib/PublicKeyUtils.sol";

/**
 * @title WalletManager
 * @notice Library for TEE wallet management.
 * @dev Uses ERC-7201 namespaced storage. Contains only logic that is
 *      reused by other libraries/facets.
 */
library WalletManager {

    struct TeeWalletState {
        bytes32 projectId;
        IWalletManager.WalletStatus status;
        PublicKey[] adminsPublicKeys;
        uint64 adminsThreshold;
        mapping(address admin => bool) adminConfirmations;
        address[] cosigners;
        uint64 cosignersThreshold;
        mapping(address cosigner => bool) cosignerConfirmations;
    }

    /// @custom:storage-location erc7201:tee.WalletManager.State
    struct State {
        uint256 walletCounter;
        mapping(bytes32 walletId => TeeWalletState) wallets;
        mapping(bytes32 projectId => bytes32[] walletIds) projectWallets;
    }

    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("tee.WalletManager.State")) - 1)
    ) & ~bytes32(uint256(0xff));

    function getWalletProjectId(
        bytes32 _walletId
    )
        internal view
        returns (bytes32)
    {
        return getState().wallets[_walletId].projectId;
    }

    function getWalletStatus(
        bytes32 _walletId
    )
        internal view
        returns (IWalletManager.WalletStatus)
    {
        return getState().wallets[_walletId].status;
    }

    function getWalletAdminsPublicKeysAndThreshold(
        bytes32 _walletId
    )
        internal view
        returns (
            PublicKey[] memory _adminsPublicKeys,
            uint64 _adminsThreshold
        )
    {
        TeeWalletState storage wallet = getState().wallets[_walletId];
        _adminsPublicKeys = wallet.adminsPublicKeys;
        _adminsThreshold = wallet.adminsThreshold;
    }

    function getWalletAdminsAndThreshold(
        bytes32 _walletId
    )
        internal view
        returns (
            address[] memory _admins,
            uint64 _adminsThreshold
        )
    {
        TeeWalletState storage wallet = getState().wallets[_walletId];
        _admins = new address[](wallet.adminsPublicKeys.length);
        for (uint256 i = 0; i < wallet.adminsPublicKeys.length; i++) {
            _admins[i] = PublicKeyUtils.getAddress(wallet.adminsPublicKeys[i]);
        }
        _adminsThreshold = wallet.adminsThreshold;
    }

    function getWalletCosignersAndThreshold(
        bytes32 _walletId
    )
        internal view
        returns (
            address[] memory _cosigners,
            uint64 _cosignersThreshold
        )
    {
        TeeWalletState storage wallet = getState().wallets[_walletId];
        _cosigners = wallet.cosigners;
        _cosignersThreshold = wallet.cosignersThreshold;
    }

    function checkWalletStatus(
        IWalletManager.WalletStatus _actualStatus,
        IWalletManager.WalletStatus _expectedStatus
    )
        internal pure
    {
        require(_actualStatus == _expectedStatus, ITeeCommonErrors.InvalidWalletStatus());
    }

    function getState()
        internal pure
        returns (State storage _state)
    {
        bytes32 position = STATE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _state.slot := position
        }
    }
}
