// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IWalletProjectPause } from "../../userInterfaces/tee/IWalletProjectPause.sol";
import { IWalletManager } from "../../userInterfaces/tee/IWalletManager.sol";
import { WalletProjectPause } from "../library/WalletProjectPause.sol";
import { WalletProjectManager } from "../library/WalletProjectManager.sol";
import { WalletManager } from "../library/WalletManager.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title WalletProjectPauseFacet
 * @notice Facet for managing per-project pauser/unpauser delegation lists and
 *         for the resulting batch pauseWallets / unpauseWallets actions.
 * @dev List-management methods are gated by the project owner.
 *      pauseWallets / unpauseWallets check authorization per wallet (project
 *      owner OR list member for that wallet's project), so a single call may
 *      span multiple projects.
 */
contract WalletProjectPauseFacet is IWalletProjectPause {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IWalletProjectPause
    function addWalletProjectPausers(
        bytes32 _projectId,
        address[] calldata _addresses
    )
        external
    {
        WalletProjectManager.checkOnlyOwner(_projectId);
        require(_addresses.length > 0, NoAddresses());
        EnumerableSet.AddressSet storage set = WalletProjectPause.getState().pausers[_projectId];
        for (uint256 i = 0; i < _addresses.length; i++) {
            address a = _addresses[i];
            require(a != address(0), InvalidAddress());
            require(set.add(a), AddressAlreadyInSet(a));
        }
        emit WalletProjectPausersAdded(_projectId, _addresses);
    }

    /// @inheritdoc IWalletProjectPause
    function removeWalletProjectPausers(
        bytes32 _projectId,
        address[] calldata _addresses
    )
        external
    {
        WalletProjectManager.checkOnlyOwner(_projectId);
        require(_addresses.length > 0, NoAddresses());
        EnumerableSet.AddressSet storage set = WalletProjectPause.getState().pausers[_projectId];
        for (uint256 i = 0; i < _addresses.length; i++) {
            require(set.remove(_addresses[i]), AddressNotInSet(_addresses[i]));
        }
        emit WalletProjectPausersRemoved(_projectId, _addresses);
    }

    /// @inheritdoc IWalletProjectPause
    function addWalletProjectUnpausers(
        bytes32 _projectId,
        address[] calldata _addresses
    )
        external
    {
        WalletProjectManager.checkOnlyOwner(_projectId);
        require(_addresses.length > 0, NoAddresses());
        EnumerableSet.AddressSet storage set = WalletProjectPause.getState().unpausers[_projectId];
        for (uint256 i = 0; i < _addresses.length; i++) {
            address a = _addresses[i];
            require(a != address(0), InvalidAddress());
            require(set.add(a), AddressAlreadyInSet(a));
        }
        emit WalletProjectUnpausersAdded(_projectId, _addresses);
    }

    /// @inheritdoc IWalletProjectPause
    function removeWalletProjectUnpausers(
        bytes32 _projectId,
        address[] calldata _addresses
    )
        external
    {
        WalletProjectManager.checkOnlyOwner(_projectId);
        require(_addresses.length > 0, NoAddresses());
        EnumerableSet.AddressSet storage set = WalletProjectPause.getState().unpausers[_projectId];
        for (uint256 i = 0; i < _addresses.length; i++) {
            require(set.remove(_addresses[i]), AddressNotInSet(_addresses[i]));
        }
        emit WalletProjectUnpausersRemoved(_projectId, _addresses);
    }

    /// @inheritdoc IWalletProjectPause
    function pauseWallets(
        bytes32[] calldata _walletIds
    )
        external
    {
        require(_walletIds.length > 0, NoWalletIds());
        WalletManager.State storage s = WalletManager.getState();
        for (uint256 i = 0; i < _walletIds.length; i++) {
            WalletManager.TeeWalletState storage wallet = s.wallets[_walletIds[i]];
            bytes32 projectId = wallet.projectId;
            require(
                msg.sender == WalletProjectManager.getOwner(projectId) ||
                    WalletProjectPause.isPauser(projectId, msg.sender),
                NotOwnerOrPauser(msg.sender)
            );
            WalletManager.checkWalletStatus(wallet.status, IWalletManager.WalletStatus.PRODUCTION);
            wallet.status = IWalletManager.WalletStatus.PAUSED;
        }
        emit WalletsPaused(_walletIds);
    }

    /// @inheritdoc IWalletProjectPause
    function unpauseWallets(
        bytes32[] calldata _walletIds
    )
        external
    {
        require(_walletIds.length > 0, NoWalletIds());
        WalletManager.State storage s = WalletManager.getState();
        for (uint256 i = 0; i < _walletIds.length; i++) {
            WalletManager.TeeWalletState storage wallet = s.wallets[_walletIds[i]];
            bytes32 projectId = wallet.projectId;
            require(
                msg.sender == WalletProjectManager.getOwner(projectId) ||
                    WalletProjectPause.isUnpauser(projectId, msg.sender),
                NotOwnerOrUnpauser(msg.sender)
            );
            WalletManager.checkWalletStatus(wallet.status, IWalletManager.WalletStatus.PAUSED);
            wallet.status = IWalletManager.WalletStatus.PRODUCTION;
        }
        emit WalletsUnpaused(_walletIds);
    }

    /// @inheritdoc IWalletProjectPause
    function getWalletProjectPausers(
        bytes32 _projectId
    )
        external view
        returns (address[] memory _addresses)
    {
        return WalletProjectPause.getState().pausers[_projectId].values();
    }

    /// @inheritdoc IWalletProjectPause
    function getWalletProjectUnpausers(
        bytes32 _projectId
    )
        external view
        returns (address[] memory _addresses)
    {
        return WalletProjectPause.getState().unpausers[_projectId].values();
    }

    /// @inheritdoc IWalletProjectPause
    function isWalletProjectPauser(
        bytes32 _projectId,
        address _addr
    )
        external view
        returns (bool _isPauser)
    {
        return WalletProjectPause.isPauser(_projectId, _addr);
    }

    /// @inheritdoc IWalletProjectPause
    function isWalletProjectUnpauser(
        bytes32 _projectId,
        address _addr
    )
        external view
        returns (bool _isUnpauser)
    {
        return WalletProjectPause.isUnpauser(_projectId, _addr);
    }
}
