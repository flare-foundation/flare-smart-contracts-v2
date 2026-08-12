// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { Relay } from "../munged/contracts/protocol/implementation/Relay.sol";
import { IRelay } from "../munged/contracts/userInterfaces/IRelay.sol";

/**
 * Certora verification harness (NOT deployed; not part of the production build).
 *
 * Adds plain-Solidity view getters over the write-once mappings so the CVL rules in
 * `certora/specs/RelayWriteOnce.spec` can observe them before/after each method call. Those getters read the
 * mappings via ordinary solc-generated storage loads — no assembly — at the exact same storage locations
 * the production contract writes. The parent is the MUNGED Relay (`certora/munged/…`, regenerated and
 * faithfulness-checked by `certora/munge.sh`), whose only difference from production is
 * `private -> internal` on these two mappings. A separate assembly getter exposes only the fixed
 * EIP-1153 override slot needed to state Certora's external-transaction-boundary precondition.
 *
 * (The production getters are unusable for this purpose: `toSigningPolicyHash()` delegates to `oldRelay`
 * below the initial epoch, and `merkleRoots()`/`isFinalized()` gate on protocol id — both would entangle
 * the invariant with delegation/gating logic that is irrelevant to storage write-once-ness.)
 */
contract RelayHarness is Relay {

    /// Raw read of Relay's EIP-1153 threshold-override slot. Certora starts rules in an
    /// already-active transaction, where transient storage is otherwise unconstrained;
    /// the threshold rules use this getter to state the real external-boundary condition.
    function thresholdOverrideAtBoundary() external view returns (uint256 value) {
        uint256 slot = 0x6cea5c73f8043432390b6161c6418f07a6dc8cc07557416a3f28d2fd6007a2c3;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            value := tload(slot)
        }
    }

    /// Raw read of toSigningPolicyHashPrivate[rewardEpochId] — no delegation, no gating.
    function policyHashAt(uint256 _rewardEpochId) external view returns (bytes32) {
        return toSigningPolicyHashPrivate[_rewardEpochId];
    }

    /// Raw read of merkleRootsPrivate[protocolId][votingRoundId] — no delegation, no gating.
    function merkleRootAt(uint256 _protocolId, uint256 _votingRoundId) external view returns (bytes32) {
        return merkleRootsPrivate[_protocolId][_votingRoundId];
    }

    /// Raw read of the ERC-7201 timelock queue, without the production getter's nonzero guard.
    function timelockedCallTimestampAt(bytes calldata _encodedCall) external view returns (uint256) {
        return getState().timelockedCalls[keccak256(_encodedCall)];
    }

    /// Exposes the single-use self-call authorization bit at transaction boundaries.
    function timelockExecuting() external view returns (bool) {
        return getState().executing;
    }
}
