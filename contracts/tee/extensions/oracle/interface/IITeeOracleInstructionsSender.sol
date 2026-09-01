// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

import {
    ITeeOracleInstructionsSender
} from "../../../../userInterfaces/tee/ITeeOracleInstructionsSender.sol";

/**
 * @title IITeeOracleInstructionsSender
 * @notice Internal interface for the TEE oracle instructions sender — adds the
 *         Flare-governance-only methods on top of the public interface.
 */
interface IITeeOracleInstructionsSender is ITeeOracleInstructionsSender {

    /**
     * Publishes a feed's endpoint configuration as the feed's latest, and dispatches it to the
     * extension's active machines.
     * Validates the payload, takes the feed's next consecutive `endpointsVersion`, ABI-encodes the
     * `Endpoints` payload and stores its `keccak256` with the publication timestamp — the payload
     * itself is NOT stored — the event `EndpointsPublished` carries the published `EndpointGroup[]`
     * instead, which is exactly what `pushEndpoints` takes back (the wrapper's other two fields are
     * the event's own indexed topics). Only after that does it attempt delivery.
     * Storing the encoded payload instead cost ~217,000 gas per PUBLIC endpoint, 96% of a
     * publication, which put a 25-group / 5-endpoint configuration (48.2 KB) at ~30.5M gas —
     * above the 28,000,000 block gas limit on flare, songbird, coston2 and coston. Committing to
     * the hash alone and logging the payload costs ~8,000 gas per endpoint, ~1.95M gas for the
     * same configuration. The event is emitted UNCONDITIONALLY, dispatch or no dispatch: when the
     * dispatch is skipped no `TeeInstructionsSent` carries the payload either, so this log is the
     * only record of it and a later push has nothing else to read.
     * The dispatch targets are NOT a parameter — they are read from
     * `getActiveTeeMachines(extensionId)` inside the body and dispatched to VERBATIM. A
     * governance call's arguments are frozen when the timelocked call is recorded, while the
     * fleet's composition is only known when the executor runs it, so a target list in the
     * signature makes a publication unexecutable whenever one named machine restarted, was paused
     * or was re-keyed during the timelock. Reading the active set in the body is a snapshot of the
     * EXECUTING block instead, which is why no machine is MISSED because the target list was
     * frozen at proposal time. That closes the TARGETING gap, not the ADOPTION one: a machine only
     * learns the payload by processing the dispatched instruction off chain, while the feed store
     * enforces the new feed-level generation from the publication block onwards, so every
     * signature still carrying the previous one is rejected (`StaleEndpoints` / `StaleAdmins`) and
     * the feed does not update until enough machines have adopted it — see
     * `ITeeOracleFeedStore.submitFeedUpdates`. Nothing is filtered out of that set: the diamond maintains it as
     * exactly the extension's PRODUCTION machines — no duplicate, no zero address, no foreign
     * extension — and a fresh version is new to every one of them.
     * The dispatch is skipped only in the two cases where no dispatch is possible at all, and
     * only those:
     * - the extension is emergency paused (the diamond hard-rejects every dispatch then), which
     *   is checked BEFORE the active set is read, so a paused publication pays for neither;
     * - its active set is empty, e.g. the fleet is not registered yet.
     *   In both cases the values are published and nothing is dispatched — "published, push
     *   later", with `pushEndpoints` delivering it afterwards. Landing a corrected configuration
     *   on chain has to stay possible during a pause, not least because the pause may exist
     *   BECAUSE the published configuration is wrong. Since no instruction is created at all in
     *   that case, `msg.value` must be zero or the call reverts `ValueNotNeeded`, telling
     *   the executor to re-execute with none attached.
     * Everything the executor CAN fix reverts, inside the diamond with the diamond's own error:
     * a fee below the one the snapshotted targets cost (`FeeTooLow`), an unset or wrong TEE
     * manager, this contract no
     * longer being the extension's registered instructions sender (`OnlyInstructionsSender`).
     * Reverting is the right answer there — it surfaces a funding or deployment mistake instead
     * of hiding it, and it is cheap, because `executeGovernanceCall` bubbles the revert, which
     * rolls back its own deletion of the timelock entry: the pending call survives and is
     * re-executable in the next block with no re-proposal.
     * The method is `payable` so the executor can attach the instruction fee to
     * `executeGovernanceCall` (recording a timelocked call still rejects value with
     * `TimelockValueNotAllowed`). Size it with `getEndpointsPublicationFee`, read in the block
     * the execution lands in. The whole `msg.value` is forwarded, and the diamond hands all of it
     * to `RewardManager.receiveRewards` in the same transaction rather than holding a balance.
     * There is no per-instruction accounting and no on-chain claim method, so the contracts
     * neither separate a surplus from the fee nor return either: too little reverts and is
     * retryable, and whatever is attached is distributed as that epoch's rewards.
     * What the claim-back address IS, then, is a RECORD. The executed body's `msg.sender` is this
     * contract and `FlareGovernance` does not record who called `executeGovernanceCall`, so the
     * funder cannot be identified on chain — which is why it is an explicit ARGUMENT: governance
     * names whoever will fund the execution instead of the contract guessing, and the address is
     * emitted, alongside the full `msg.value`, in `TeeInstructionsSent`. The OFF-CHAIN reward
     * calculation reads that log. Whether it returns a surplus on an executed instruction, or
     * keeps the value of one that never executed, is a reward-script policy decision made there
     * — not a promise made here, and not something this repo controls.
     * Reading the governance address in the body would instead record governance as the funder of
     * an instruction the executor paid for. Unlike a frozen target list, freezing this argument at
     * proposal time cannot make the publication unexecutable — an address cannot revert a
     * dispatch; the worst case is naming a wallet since retired, which governance fixes by
     * cancelling the pending call and re-proposing. `address(0)` is rejected
     * (`ZeroClaimBackAddress`) because the diamond stores the claim-back unvalidated, so a zero
     * would silently leave the off-chain calculation with no payer on record.
     * The version is part of the encoded payload, so republishing identical content still yields
     * a new version and a new hash — and since the feed store enforces the FEED-level hash, a
     * publication immediately invalidates every machine still running the previous generation
     * until it adopts the new one.
     * ORDERING IS A GOVERNANCE RESPONSIBILITY, exactly as it is for every other timelocked setter
     * in this repository. `FlareGovernance` records a pending call under the hash of its ENTIRE
     * calldata, so two publications for the same feed and kind can be pending simultaneously and
     * be executed in either order; the one executed LAST takes the higher version and becomes the
     * feed's configuration, even if it was proposed first. Governance must therefore CANCEL a
     * superseded publication (`cancelGovernanceCall`) rather than leave it queued — the risk it
     * closes is a stale ADMINS payload re-authorising an administrator that governance had just
     * removed. Execution is not permissionless: only the whitelisted executors in
     * `GovernanceSettings` can call `executeGovernanceCall`, so the order in which matured calls
     * land is under the same operational control as the proposals themselves.
     * Operationally this means two rules for governance. A publication must sign the NEXT
     * CONSECUTIVE version, read from `endpointsVersion(_feedId)` (or `getFeedConfig`) at proposal
     * time; and a pending call that a later proposal SUPERSEDES must be CANCELLED
     * (`cancelGovernanceCall`) rather than left queued, since it will otherwise sit there
     * unexecutable. Intentionally sequential publications are fine — sign versions n+1 and n+2 and
     * the second cannot execute before the first. Equality is required rather than "greater than"
     * so that no execution can jump to a value near `type(uint64).max` and exhaust the version
     * space; at the maximum the checked increment reverts instead of wrapping.
     * Only governance can call this method.
     * @param _feedId The feed the configuration serves.
     * @param _groups The tagged endpoint groups; validated on-chain (see the payload structs).
     * @param _claimBackAddress The payer of record for the dispatched instruction — normally the
     * wallet that funds the `executeGovernanceCall`. Recorded in `TeeInstructionsSent` for the
     * off-chain reward calculation; it confers no on-chain claim. Must be non-zero
     * (`ZeroClaimBackAddress`). Unused when the dispatch is skipped, since then no value may be
     * attached at all.
     */
    function setEndpoints(
        bytes21 _feedId,
        EndpointGroup[] calldata _groups,
        address _claimBackAddress
    )
        external payable;

    /**
     * Publishes a feed's role-tagged admin signer sets as the feed's latest, and dispatches them
     * to the extension's active machines.
     * Same shape as `setEndpoints`: validate, take the feed's next consecutive `adminsVersion`,
     * store the
     * `keccak256` of the encoded `Admins` payload with the timestamp, emit `AdminsPublished`
     * carrying the published `AdminRole[]`, then dispatch to the live active set with the same
     * skip, revert, fee and payer-of-record semantics. Size the executor's fee with
     * `getAdminsPublicationFee`.
     * The admin sets have their own consecutive version stream. See `setEndpoints` for the
     * ordering rule that follows: cancel a superseded pending publication rather than leaving it
     * queued. Stale ADMINS are the most serious case it guards against — a removed administrator
     * re-authorised by a publication that was proposed earlier but executed later.
     * Only governance can call this method.
     * @param _feedId The feed the admin sets serve.
     * @param _roles The role-tagged admin sets; validated on-chain (role-agnostic rules only).
     * @param _claimBackAddress The payer of record for the dispatched instruction, recorded in
     * `TeeInstructionsSent` and conferring no on-chain claim; must be non-zero
     * (`ZeroClaimBackAddress`). See `setEndpoints`.
     */
    function setAdmins(
        bytes21 _feedId,
        AdminRole[] calldata _roles,
        address _claimBackAddress
    )
        external payable;
}
