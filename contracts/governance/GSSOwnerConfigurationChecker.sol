// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GSSGovernance} from "./GSSGovernance.sol";

interface IGSSSafeView {
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
    function nonce() external view returns (uint256);
}

contract GSSOwnerConfigurationChecker {
    struct FeeUpdate {
        uint256 targetChainId;
        uint256 protocolId;
        uint256 feeInWei;
    }

    uint256 public immutable sourceChainId;
    address public immutable gss;
    uint256 public latestSafeNonce;
    bytes32 public activeOwnerConfigHash;
    uint256 public activeOwnerConfigSafeNonce;
    uint256 private constant MAX_GOVERNANCE_OWNERS = 256;
    uint256 private constant MAX_GOVERNANCE_FEE_UPDATES = 256;

    event OwnerConfigurationChanged(
        uint256 indexed safeNonce, bytes32 indexed ownerConfigHash, uint256 threshold, address[] owners
    );

    event ProtocolFeesChecked(uint256 indexed safeNonce, bytes32 indexed ownerConfigHash, uint256 updateCount);

    error OnlyGSS();
    error WrongSourceChain();
    error WrongSafeNonce(uint256 supplied, uint256 actual);
    error NonMonotonicNonce();
    error InvalidOwnerConfiguration();
    error InvalidFeeUpdates();
    error OwnerConfigurationMismatch(bytes32 supplied, bytes32 actual);

    constructor(uint256 sourceChainId_, address gss_) {
        require(sourceChainId_ != 0 && gss_ != address(0), "invalid governance source");
        sourceChainId = sourceChainId_;
        gss = gss_;
    }

    function changeOwners(
        uint256 safeNonce,
        bytes32 currentOwnerConfigHash,
        uint256 threshold,
        address[] calldata owners
    ) external returns (bytes32 newHash) {
        if (msg.sender != gss) revert OnlyGSS();
        if (block.chainid != sourceChainId) revert WrongSourceChain();
        uint256 actualNonce = IGSSSafeView(gss).nonce();
        if (safeNonce != actualNonce) revert WrongSafeNonce(safeNonce, actualNonce);
        if (safeNonce <= latestSafeNonce) revert NonMonotonicNonce();
        if (currentOwnerConfigHash != activeOwnerConfigHash) {
            revert OwnerConfigurationMismatch(currentOwnerConfigHash, activeOwnerConfigHash);
        }
        if (owners.length > MAX_GOVERNANCE_OWNERS) revert InvalidOwnerConfiguration();
        _validate(owners, threshold);
        bytes32 liveHash =
            _liveOwnerConfigHash(activeOwnerConfigHash == bytes32(0) ? safeNonce : activeOwnerConfigSafeNonce);
        newHash = _hashCalldata(safeNonce, threshold, owners);
        if (activeOwnerConfigHash == bytes32(0)) {
            // Bootstrap attests the Safe's already-live owner configuration.
            if (newHash != liveHash) revert OwnerConfigurationMismatch(newHash, liveHash);
        } else if (liveHash != activeOwnerConfigHash) {
            // Rotations are authorized by the currently live/active owners and may propose
            // a new configuration. Fee actions remain blocked until the Safe adopts it.
            revert OwnerConfigurationMismatch(liveHash, activeOwnerConfigHash);
        }
        latestSafeNonce = safeNonce;
        activeOwnerConfigSafeNonce = safeNonce;
        activeOwnerConfigHash = newHash;
        emit OwnerConfigurationChanged(safeNonce, newHash, threshold, owners);
    }

    /// @notice Source-chain checker for the same governance calldata relayed to target chains.
    /// @dev It deliberately does not store target-chain fees; target Relays extract their own updates.
    function changeProtocolFees(uint256 safeNonce, bytes32 ownerConfigHash, FeeUpdate[] calldata updates) external {
        if (msg.sender != gss) revert OnlyGSS();
        if (block.chainid != sourceChainId) revert WrongSourceChain();
        uint256 actualNonce = IGSSSafeView(gss).nonce();
        if (safeNonce != actualNonce) revert WrongSafeNonce(safeNonce, actualNonce);
        if (safeNonce <= latestSafeNonce) revert NonMonotonicNonce();
        if (ownerConfigHash != activeOwnerConfigHash) {
            revert OwnerConfigurationMismatch(ownerConfigHash, activeOwnerConfigHash);
        }
        bytes32 liveHash = _liveOwnerConfigHash(activeOwnerConfigSafeNonce);
        if (liveHash != activeOwnerConfigHash) {
            revert OwnerConfigurationMismatch(liveHash, activeOwnerConfigHash);
        }
        _validateFeeUpdates(updates);
        latestSafeNonce = safeNonce;
        emit ProtocolFeesChecked(safeNonce, ownerConfigHash, updates.length);
    }

    /// @notice Returns whether the admitted owner generation exactly matches the live Safe.
    /// @dev Deployment tooling must require true; false also identifies a staged rotation.
    function activeOwnerConfigurationIsLive() external view returns (bool) {
        if (activeOwnerConfigHash == bytes32(0)) return false;
        return _liveOwnerConfigHash(activeOwnerConfigSafeNonce) == activeOwnerConfigHash;
    }

    function _hashMemory(uint256 ownerConfigSafeNonce, uint256 threshold, address[] memory owners)
        internal
        view
        returns (bytes32)
    {
        return GSSGovernance.ownerConfigHash(sourceChainId, gss, ownerConfigSafeNonce, threshold, owners);
    }

    function _hashCalldata(uint256 ownerConfigSafeNonce, uint256 threshold, address[] calldata owners)
        internal
        view
        returns (bytes32)
    {
        return GSSGovernance.ownerConfigHash(sourceChainId, gss, ownerConfigSafeNonce, threshold, owners);
    }

    function _liveOwnerConfigHash(uint256 ownerConfigSafeNonce) internal view returns (bytes32) {
        address[] memory owners = IGSSSafeView(gss).getOwners();
        uint256 threshold = IGSSSafeView(gss).getThreshold();
        _sort(owners);
        if (owners.length == 0 || owners.length > MAX_GOVERNANCE_OWNERS || threshold == 0 || threshold > owners.length)
        {
            revert InvalidOwnerConfiguration();
        }
        for (uint256 i; i < owners.length; ++i) {
            if (owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])) {
                revert InvalidOwnerConfiguration();
            }
        }
        return _hashMemory(ownerConfigSafeNonce, threshold, owners);
    }

    function _validate(address[] calldata owners, uint256 threshold) internal pure {
        if (owners.length == 0 || threshold == 0 || threshold > owners.length) revert InvalidOwnerConfiguration();
        for (uint256 i; i < owners.length; ++i) {
            if (owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])) {
                revert InvalidOwnerConfiguration();
            }
        }
    }

    function _sort(address[] memory values) internal pure {
        for (uint256 i = 1; i < values.length; ++i) {
            address value = values[i];
            uint256 j = i;
            while (j > 0 && values[j - 1] > value) {
                values[j] = values[j - 1];
                --j;
            }
            values[j] = value;
        }
    }

    function _validateFeeUpdates(FeeUpdate[] calldata updates) internal pure {
        if (updates.length == 0 || updates.length > MAX_GOVERNANCE_FEE_UPDATES) {
            revert InvalidFeeUpdates();
        }
        for (uint256 i; i < updates.length; ++i) {
            FeeUpdate calldata update = updates[i];
            if (update.targetChainId == 0 || update.protocolId <= 1) {
                revert InvalidFeeUpdates();
            }
            if (i > 0) {
                FeeUpdate calldata previous = updates[i - 1];
                if (
                    update.targetChainId < previous.targetChainId
                        || (update.targetChainId == previous.targetChainId && update.protocolId <= previous.protocolId)
                ) {
                    revert InvalidFeeUpdates();
                }
            }
        }
    }
}
