# Submission

[`Submission`](../../../contracts/protocol/implementation/Submission.sol) is the gas-refunded entry point that registered voters use to publish per-round protocol data. It is intentionally minimal: it does not interpret payloads or store data. It exists so that registered voters get one **gas-refunded** transaction per voting round per submission type, and so off-chain consumers have a single contract address to filter for protocol traffic.

The actual data (commit hashes, reveals, signatures, attestation bitvotes, etc.) rides as **calldata appended after the function selector**. The `Submission` contract reads no bytes of it — it only checks that the caller is registered for this voting round and consumes the registration. Off-chain indexers parse the calldata.

## The four entry points

```solidity
function submit1() external returns (bool);
function submit2() external returns (bool);
function submit3() external returns (bool);
function submitSignatures() external returns (bool);
```

Each is a no-arg, single-shot per voting round per registered address. The body is identical:

```solidity
if (submitXAddresses[msg.sender]) {
    delete submitXAddresses[msg.sender];
    return true;
}
return false;
```

If the caller's address is in the per-round allowlist, it is consumed and the function returns `true` — the validator's gas-refund hook keys off this `true` return to refund the transaction's gas. If not, the function returns `false` and the transaction simply succeeds with no refund. The convention by which sub-protocols use the four functions:

| Method | Conventional use |
|--------|------------------|
| `submit1` | Phase-1 / commit data (e.g. FTSO anchor commit hashes). |
| `submit2` | Phase-2 / reveal data (e.g. FTSO anchor reveals). |
| `submit3` | Reserved for future use. Currently disabled by default; `setSubmit3MethodEnabled(bool)` toggles it. |
| `submitSignatures` | Threshold signatures over Merkle roots, used as input to [`Relay.relay`](../../../contracts/protocol/implementation/Relay.sol). |

There is no on-chain dispatch to specific protocols. Each transaction's calldata is conventionally a sequence of `PayloadMessage` frames (see the [FSP encoding spec](https://github.com/flare-foundation/flare-specs/blob/main/src/FSP/Encoding.md) — one frame per protocol ID, with the last frame for any given protocol ID winning at parse time.

## Address registration per voting round

`FlareSystemsManager.daemonize()` calls

```solidity
submission.initNewVotingRound(
    submit1Addresses,
    submit2Addresses,
    submit3Addresses,
    submitSignaturesAddresses
);
```

once per new voting epoch. The address arrays come from `VoterRegistry`:

- `submit2Addresses` and `submitSignaturesAddresses` are read for the reward epoch we *started* in (so an in-flight voting round still uses the previous epoch's addresses for its reveal / signatures).
- `submit1Addresses` is read for the *current* reward epoch — when a new reward epoch starts mid-round, commits for the new round use the new addresses while reveals for the previous round still use the old.
- `submit3Addresses` is set to `submit1Addresses` if `submit3Aligned` (default), otherwise to `submit2Addresses`. Governance can flip the alignment with `FlareSystemsManager.setSubmit3Aligned`.

`initNewVotingRound` pushes each address into the corresponding `submitXAddresses` mapping (per-method allowlist) and emits `NewVotingRoundInitiated`. Any address that doesn't call `submitX` during the round simply leaves a stale `true` in the mapping — the next `initNewVotingRound` writes over it.

Calls to `Submission` from non-registered addresses always return `false` and are ignored by the gas-refund hook. They cost normal gas; the protocol expects them to never happen but doesn't reject them.

## `submitAndPass`

```solidity
function submitAndPass(bytes calldata _data) external returns (bool);
```

A configurable forwarder used by sub-protocols that want a third-party gas-refunded entry point distinct from the four standard ones. It does an `address.call(submitAndPassSelector, _data)` with the configured target. Disabled by default (`submitAndPassContract == 0`); enabled by governance via `setSubmitAndPassData`. Reverts of the inner call are bubbled with the original revert message reconstructed via the `_getRevertMsg` helper (skips the 4-byte selector).

This is the only way `Submission` ever calls into another contract — and it does so only when explicitly configured.

## Random number passthrough

`Submission` also implements [`IRandomProvider`](../../../contracts/userInterfaces/IRandomProvider.sol), exposing the FSP-secure random as three convenience views:

```solidity
function getCurrentRandom()                       external view returns(uint256);
function getCurrentRandomWithQuality()            external view returns(uint256, bool);
function getCurrentRandomWithQualityAndTimestamp() external view returns(uint256, bool, uint256);
```

All three call `relay.getRandomNumber()`. `getCurrentRandom()` reverts with `"Not secure"` if the latest FTSO random isn't flagged as secure. The other two return the secure flag (and timestamp) so callers can decide what to do. See [Random Number](./RandomNumber.md).

## Why no payload validation

Putting payload validation here would force every sub-protocol's encoding into a single contract — and would re-do the work that off-chain indexers and per-protocol verification contracts (`Relay.relay`, `FdcVerification`, `Fdc2Verification`, etc.) are already doing on the data. The design is "submit is dumb on purpose": the only on-chain semantics are *who* called it and that they were registered for this round. Everything else is a reading concern.

A consequence: a registered voter that calls `submit1` with garbage calldata still gets the gas refund. The protocol-level penalty for submitting wrong data is applied off-chain at reward calculation, by ignoring submissions that don't decode or that miss the protocol-specific timestamp window. See [FSP Rewarding](./Rewarding.md) for the validity rules.
