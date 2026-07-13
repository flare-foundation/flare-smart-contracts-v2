# BitVote and Consensus

The hard part of FDC is not "verify a Bitcoin transaction" — it's getting **all the providers** to agree on **which** transactions to verify in a given round. If providers disagree on the set of confirmable requests, their Merkle roots diverge and no root crosses the signing threshold.

The bit-voting protocol solves this. Each provider publishes a single bitmap of "I can confirm this request" decisions, and the network deterministically converges on a consensus bitmap.

This is an off-chain protocol — the contracts (`FdcHub`, `Submission`, `Relay`) only carry the raw bytes. The convergence happens in provider clients running the [Bit Vote algorithm](https://github.com/flare-foundation/flare-specs/blob/main/src/FDC/BitVote.md) before each round's signing phase.

## Phases of an FDC voting round

An FDC round runs over **two voting epochs** but is identified by the start epoch ID `i`:

| Phase | Window | Action |
|-------|--------|--------|
| **Collect** | $[t_\text{start}(i),\ t_\text{start}(i+1))$ | All `AttestationRequest` events from `FdcHub.requestAttestation` in this window are part of round $i$. Providers fetch each request, attempt verification. |
| **Choose** | $[t_\text{start}(i+1),\ t_\text{reveal}(i+1))$ | Each provider builds its bit-vector of confirmable requests and submits it via `Submission.submit2` calldata. Bit-voting consensus runs locally before submission deadline. |
| **Resolve** | $[t_\text{reveal}(i+1),\ t_\text{start}(i+2))$ | Providers who can verify all requests in the consensus bit-vector build the round's Merkle tree, sign the root via `Submission.submitSignatures`, and `Relay.relay()` finalizes once threshold is reached. |

Round $i$'s collect phase is the same as voting epoch $i$'s 90-second window. The choose phase is the first 45 s of epoch $i+1$ — overlapping with the FTSO anchor reveal phase. The resolve phase is the rest of epoch $i+1$.

## Bit-vector encoding

A bit-vector is an unsigned integer with one bit per distinct request in the round, **right-justified** (bit 0 = first request of the round). Encoding for transmission:

```
[ 2 bytes : numberOfRequests ] [ ceil(numberOfRequests / 8) bytes : packed bit-vector ]
```

Example: a round with 5 distinct requests, where the first, second, and fourth are confirmed by this provider:

- Bit-vector: `0b01011`
- Encoded: `0x00050b` — 2 bytes for `5`, 1 byte for `0x0b` (`0b00001011`).

Each provider sends this byte sequence as calldata appended to a `Submission.submit2` transaction from its `submitAddress` before the choose-phase deadline. The provider's `submit2` registration consumes the gas-refund slot (see [FSP/Submission](../FSP/Submission.md)).

## Validity rules for a peer's bit-vector

A provider considers another provider's bit-vector valid only if:

- It is encoded with the same `numberOfRequests` count as the local view of the round (so the peers are voting on the same set of requests).
- It comes from a `submitAddress` registered for an entity in the **active signing policy** for the round.
- It was submitted within the choose phase.

A provider that submits more than one valid bit-vector in a round has **only the last one** counted. Bit-vectors from non-registered addresses are ignored.

## Request merging

If two or more requests in a single round have identical raw `_data` (same `attestationType`, `sourceId`, MIC, and `requestBody`), they are merged into a single bit-position whose effective fee is the sum and whose arrival index is the lowest of the merged requests. This prevents a fee-multiplication attack where someone splits a single request into many copies to dominate the bit-voting value function.

## The bit-vote consensus algorithm

The consensus bit-vector is the deterministic result of a **branch-and-bound search** that maximizes a value function over all candidate bitmaps:

$$V_R = \min(0.8 \cdot T,\ S_R) \cdot F_R$$

where:

- $T$ — total signing weight of providers in the active signing policy.
- $S_R$ — total signing weight of providers whose bit-vector includes **all** the bits in candidate set $R$.
- $F_R$ — sum of fees for the requests included in $R$.
- The cap at $0.8 T$ is the diminishing-returns ceiling: extra weight beyond 80% of the total stops adding value, so the algorithm doesn't penalize candidate sets that "only" 80%-supportable but cover more fees.

The candidate bit-vector that maximizes $V_R$ is the consensus output for the round. All providers, running the same deterministic search on the same inputs, arrive at the same consensus.

### Inputs

- The set of valid `(provider, weight, bit-vector)` triples submitted in the choose phase.
- An array of per-request fees (with merged-request fees summed).
- A maximum step count — currently `20_000_000` — that bounds the branch-and-bound search runtime. Set by governance.

### Pre-processing

1. **Filter** — bits that have less than 50% support are immediately dropped (`AlwaysOutBits`); bits that every remaining vote includes are immediately accepted (`AlwaysInBits`). Votes that include all remaining bits are accepted (`AlwaysInVotes`); votes that include none of them are dropped (`AlwaysOutVotes`).
2. **Aggregate** — bits that all remaining votes agree on (either all-include or all-exclude across the vote set) are merged into a single composite bit; analogously for votes. The aggregated bit's fee is the sum of the merged bits' fees; the aggregated vote's weight is the sum of the merged votes' weights.

### Branch-and-bound

The remaining `RemainingAggregatedBits` and `RemainingAggregatedVotes` define the search space. The algorithm runs **two flavors**:

- **Branch by bits** — at each tree depth $k$, the children are: child 0 drops the $k$-th bit (its fee is deducted from the candidate's `fees`); child 1 drops votes that don't support the $k$-th bit (their weight is deducted from the candidate's `weight`).
- **Branch by votes** — symmetric: child 0 drops the $k$-th vote; child 1 drops bits unsupported by the $k$-th vote.

Pruning rules (any of these halts a branch and backtracks):

- `weight < 0.5 × totalWeight` — the candidate can't reach signing threshold.
- `value(node) ≤ currentBound` — already worse than the best found.
- `stepCount ≥ maxSteps` — search budget exhausted.

Tie-break: the first method's solution wins.

### Strategy

The bit-voting spec calls for **two passes** of the chosen flavor (bits or votes, depending on which space is smaller):

- **Pass A** — order in descending value; first explore the "include this" branch.
- **Pass B** — order in ascending value; first explore the "exclude this" branch.

The two passes' best results are compared; the higher-value bit-vector wins. If neither pass exhausted its space within the step budget, the **other** flavor is run with the first result's value as initial bound, and any improvement is taken.

This deterministic strategy means every honest provider arrives at the same consensus bit-vector, producing the same Merkle tree, signing the same root.

## Submitting the round

Once the consensus bit-vector is computed, providers that can confirm every request in it:

1. Build the Merkle tree over `keccak256(abi.encode(response))` for each confirmed request, with `response.votingRound` set to the current round ID.
2. Compute the round's Merkle root.
3. Submit a signature via `Submission.submitSignatures` from their `submitSignaturesAddress`. Reward eligibility for signing is in the first 10 s of the resolve phase or any time before finalization (whichever is later).
4. After enough signatures accumulate, any selected finalizer (or, after the 20-second grace window, anyone) calls `Relay.relay()` to write the root.

Providers whose bit-vector "dominates" the consensus (`bit-vector & consensus == consensus` — they confirmed at least everything in the consensus set) are eligible for full rewards. Providers whose bit-vector didn't dominate the consensus but who still signed the eventual finalized root are eligible for partial rewards (success coefficient `0.8`). See [Rewarding](./Rewarding.md).

## Why the value function looks the way it does

- **Why fees as a factor?** Without weighting by fees, the algorithm would maximize bit count — a million zero-fee requests would beat a single high-fee request. Weighting by total fees aligns the consensus with what the requesters paid for.
- **Why cap weight at 0.8 T?** Because once a candidate has 80% support, adding more support doesn't help reach threshold — the marginal vote can be spent on broader request inclusion instead. Without this cap, the algorithm would converge on tiny request sets that 100% of providers can confirm, even if those sets carry few fees.
- **Why the explicit step bound?** Branch-and-bound on a real round with hundreds of requests and dozens of providers is exponentially large in the worst case. The 20M step budget gives a near-optimal solution in bounded time and ensures every honest provider finishes in the same number of steps with the same answer.

## Edge cases

- **No converged consensus** — if even the best candidate fails the >50% support test, no Merkle root is produced and the round goes unfinalized. All requests' fees in that round are burned.
- **Empty bit-vector** — if no provider can confirm any request, the bit-vote algorithm returns an all-zeros bit-vector and the round produces an empty Merkle root (just the empty-tree placeholder).
- **Ties on value** — broken by visit order in the search tree (i.e. by candidate ordering, which is itself deterministic from the inputs). All providers thus break ties identically.
