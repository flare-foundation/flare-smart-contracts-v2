// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { Relay } from "../munged/contracts/protocol/implementation/Relay.sol";
import { IRelay } from "../munged/contracts/userInterfaces/IRelay.sol";

/**
 * Certora verification harness (NOT deployed; not part of the production build).
 *
 * Adds two plain-Solidity view getters over the write-once mappings so the CVL rules in
 * `certora/specs/RelayWriteOnce.spec` can observe them before/after each method call. The getters read the
 * mappings via ordinary solc-generated storage loads — no assembly — at the exact same storage locations
 * the production contract writes. The parent is the MUNGED Relay (`certora/munged/…`, regenerated and
 * faithfulness-checked by `certora/munge.sh`), whose only difference from production is
 * `private -> internal` on these two mappings.
 *
 * (The production getters are unusable for this purpose: `toSigningPolicyHash()` delegates to `oldRelay`
 * below the initial epoch, and `merkleRoots()`/`isFinalized()` gate on protocol id — both would entangle
 * the invariant with delegation/gating logic that is irrelevant to storage write-once-ness.)
 */
contract RelayHarness is Relay {
    constructor(
        RelayInitialConfig memory _initialConfig,
        address _signingPolicySetter,
        IRelay _oldRelay
    ) Relay(_initialConfig, _signingPolicySetter, _oldRelay) {}

    /// Raw read of toSigningPolicyHashPrivate[rewardEpochId] — no delegation, no gating.
    function policyHashAt(uint256 _rewardEpochId) external view returns (bytes32) {
        return toSigningPolicyHashPrivate[_rewardEpochId];
    }

    /// Raw read of merkleRootsPrivate[protocolId][votingRoundId] — no delegation, no gating.
    function merkleRootAt(uint256 _protocolId, uint256 _votingRoundId) external view returns (bytes32) {
        return merkleRootsPrivate[_protocolId][_votingRoundId];
    }
}
