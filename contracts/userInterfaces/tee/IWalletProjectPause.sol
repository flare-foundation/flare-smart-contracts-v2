// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";

/**
 * @title IWalletProjectPause
 * @notice Public interface for the WalletProjectPauseFacet.
 * @dev Lets each wallet-project owner configure two delegation lists:
 *      `pausers` (addresses that may call pauseWallets on the project's
 *      wallets) and `unpausers` (addresses that may call unpauseWallets).
 *      The actual pauseWallets / unpauseWallets actions also live on this
 *      facet — see `pauseWallets` and `unpauseWallets` below.
 *      List-management methods are gated by the project owner.
 */
interface IWalletProjectPause is ITeeCommonErrors {

    event WalletProjectPausersAdded(bytes32 indexed projectId, address[] addresses);
    event WalletProjectPausersRemoved(bytes32 indexed projectId, address[] addresses);
    event WalletProjectUnpausersAdded(bytes32 indexed projectId, address[] addresses);
    event WalletProjectUnpausersRemoved(bytes32 indexed projectId, address[] addresses);

    event WalletsPaused(bytes32[] walletIds);
    event WalletsUnpaused(bytes32[] walletIds);

    error NoWalletIds();

    /**
     * Adds addresses to the project's pauser list.
     * Emits WalletProjectPausersAdded event.
     * @param _projectId The project id.
     * @param _addresses The addresses to add.
     * Can only be called by the project owner.
     */
    function addWalletProjectPausers(
        bytes32 _projectId,
        address[] calldata _addresses
    )
        external;

    /**
     * Removes addresses from the project's pauser list.
     * Emits WalletProjectPausersRemoved event.
     * @param _projectId The project id.
     * @param _addresses The addresses to remove.
     * Can only be called by the project owner.
     */
    function removeWalletProjectPausers(
        bytes32 _projectId,
        address[] calldata _addresses
    )
        external;

    /**
     * Adds addresses to the project's unpauser list.
     * Emits WalletProjectUnpausersAdded event.
     * @param _projectId The project id.
     * @param _addresses The addresses to add.
     * Can only be called by the project owner.
     */
    function addWalletProjectUnpausers(
        bytes32 _projectId,
        address[] calldata _addresses
    )
        external;

    /**
     * Removes addresses from the project's unpauser list.
     * Emits WalletProjectUnpausersRemoved event.
     * @param _projectId The project id.
     * @param _addresses The addresses to remove.
     * Can only be called by the project owner.
     */
    function removeWalletProjectUnpausers(
        bytes32 _projectId,
        address[] calldata _addresses
    )
        external;

    /**
     * Pauses a batch of wallets (PRODUCTION -> PAUSED).
     * Emits a single WalletsPaused event carrying the full list of pauses.
     * @param _walletIds The wallets to pause. May span multiple projects.
     * Access is checked per-wallet: for each `walletId`, the caller must
     * be the owner of that wallet's project OR on that project's pauser list.
     * Reverts if any wallet is not in PRODUCTION (no partial application).
     */
    function pauseWallets(
        bytes32[] calldata _walletIds
    )
        external;

    /**
     * Unpauses a batch of wallets (PAUSED -> PRODUCTION).
     * Emits a single WalletsUnpaused event carrying the full list of unpauses.
     * @param _walletIds The wallets to unpause. May span multiple projects.
     * Access is checked per-wallet: for each `walletId`, the caller must
     * be the owner of that wallet's project OR on that project's unpauser list.
     * Reverts if any wallet is not in PAUSED (no partial application).
     */
    function unpauseWallets(
        bytes32[] calldata _walletIds
    )
        external;

    /**
     * Returns the project's pauser addresses.
     * @param _projectId The project id.
     * @return _addresses The pauser addresses.
     */
    function getWalletProjectPausers(
        bytes32 _projectId
    )
        external view
        returns (address[] memory _addresses);

    /**
     * Returns the project's unpauser addresses.
     * @param _projectId The project id.
     * @return _addresses The unpauser addresses.
     */
    function getWalletProjectUnpausers(
        bytes32 _projectId
    )
        external view
        returns (address[] memory _addresses);

    /**
     * Returns true if `_addr` is on the project's pauser list.
     * @param _projectId The project id.
     * @param _addr The address to check.
     * @return _isPauser True if `_addr` is on the pauser list.
     */
    function isWalletProjectPauser(
        bytes32 _projectId,
        address _addr
    )
        external view
        returns (bool _isPauser);

    /**
     * Returns true if `_addr` is on the project's unpauser list.
     * @param _projectId The project id.
     * @param _addr The address to check.
     * @return _isUnpauser True if `_addr` is on the unpauser list.
     */
    function isWalletProjectUnpauser(
        bytes32 _projectId,
        address _addr
    )
        external view
        returns (bool _isUnpauser);
}
