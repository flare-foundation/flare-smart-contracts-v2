# Mathematical model

## Policy and signatures

Let a signing policy contain `N` slots:

```text
P = [(address_0, weight_0), ..., (address_(N-1), weight_(N-1))]
```

Let an accepted signature stream select indices:

```text
i_0 < i_1 < ... < i_(K-1) < N
```

The strict ordering implies that every index occurs at most once. Define:

```text
signedWeight = sum(weight_(i_j), j = 0 .. K-1)
totalWeight  = sum(weight_i, i = 0 .. N-1)
```

Then:

```text
signedWeight <= totalWeight
```

This inequality is independent of ECDSA. It follows from index bounds,
nonnegative weights, and no repeated index.

## Loop invariant

After processing a prefix of the signature stream, let `u` be the next unused
index and `w` the accumulator. Define:

```text
prefixSum(u) = sum(weight_i, 0 <= i < u)
```

The inductive invariant is:

```text
w <= prefixSum(u)  and  u <= N
```

If the next accepted index is `i >= u`, its weight is added and the next unused
index becomes `i + 1`. Every weight in the new accumulator lies in the prefix
ending at `i`, so the invariant is preserved.

If Relay accepts only when `w > threshold`, the invariant yields:

```text
accept -> threshold < w <= prefixSum(u) <= totalWeight
```

## Slots versus identities

The mathematics above counts slots. If `address_a = address_b` for `a != b`,
one private key can satisfy both slots using the same signature while preserving
strict index order. The distinct-signer conclusion needs the extra premise:

```text
forall a != b, address_a != address_b
```

and a nonzero-address premise. Those are policy-admission properties, not
consequences of the signature-loop invariant.

## BIPS threshold

For `b` basis points, Relay computes:

```text
t = floor(totalWeight * b / 10000)
```

and requires `signedWeight > t`. Because all quantities are nonnegative:

```text
signedWeight > floor(totalWeight * b / 10000)
iff
signedWeight * 10000 > totalWeight * b
```

The strict comparison matters when the product is not divisible by 10000. Any
formal or off-chain specification must use the same rounding and strictness.

## Random pointer

For accepted random rounds `r`, the intended live-state invariant is:

```text
liveRound = max(accepted local random rounds)
```

Monotonicity alone is insufficient. A liveness-safe state machine also requires:

```text
liveRound is readable
and
there exists a representable later valid round when time advances
```

Accepting the maximum value violates the second condition and can violate the
first through narrow arithmetic.

## Migration partition

Let `B` be the read-delegation boundary and `S` the start round embedded in the
initial local policy. A gap-free, overlap-free partition requires:

```text
S = B
```

If `S < B`, locally written state can be shadowed by delegated reads. If `S > B`,
the local policy may not cover the interval beginning at the read cutover.
