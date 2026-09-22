# Operation Fees

Each instruction sent through `InstructionsFacet` charges a **per-operation, per-machine** fee. The fee structure is:

$$\mathrm{fee} = \mathrm{perOperationFee}(\mathrm{opType},\, \mathrm{opCommand}) \times |\mathrm{teeMachines}|$$

with `perOperationFee` falling back to a global `defaultFee` if no specific entry is configured for the `(opType, opCommand)` pair.

The on-chain pieces:

- [`OperationFeesFacet`](../../../contracts/tee/facets/OperationFeesFacet.sol) — governance-only setters and external read methods.
- [`library/OperationFees`](../../../contracts/tee/library/OperationFees.sol) — fee storage and calculation.
- [`TeePayments`](../../../contracts/tee/implementation/TeePayments.sol) suite — outside the diamond, handles per-extension payment streams (separate from per-instruction fees).

This page covers the in-diamond per-instruction fee logic. The `TeePayments*` contracts handle longer-lived per-extension payment streams (PMW per-wallet upkeep, etc.) and are described in [Architecture / TeePayments](./Architecture.md#teepayments-outside-the-diamond).

## In-diamond fee calculation

```solidity
// library/OperationFees.sol
struct State {
    uint256 defaultFee;
    mapping(bytes32 opType => mapping(bytes32 opCommand => uint256 fee)) operationFee;
}

function calculateFeeByTeeIds(
    bytes32 _opType,
    bytes32 _opCommand,
    address[] memory _teeIds
)
    internal view returns (uint256 _fee)
{
    State storage s = getState();
    _fee = s.operationFee[_opType][_opCommand];
    if (_fee == 0) {
        _fee = s.defaultFee;
    }
    _fee *= _teeIds.length;
}
```

The fee is **linear in the number of TEE machines** the instruction targets. This reflects actual cost: each additional machine that has to execute the instruction is an additional unit of paid work. Doubling the TEE set doubles the fee.

The `defaultFee` is set at diamond init (`FlareTeeManagerInit.init`: `OperationFees.setDefaultFee(_defaultFee);`) and updatable by governance via `OperationFeesFacet`. It applies to every `(opType, opCommand)` that doesn't have an explicit override.

## Setting per-operation fees

`OperationFeesFacet` exposes governance-only setters (signatures vary per the current iteration of the facet — see [`IOperationFees`](../../../contracts/userInterfaces/tee/IOperationFees.sol) for the live interface). The pattern:

- `setOperationFees(opTypes[], opCommands[], fees[])` — bulk setter for one or more `(opType, opCommand)` pairs (the three arrays must be equal length, else `LengthsMismatch()`). A fee of `0` means "fall back to `defaultFee`". Emits `OperationFeesSet`.
- `setDefaultFee(fee)` — change the global default. Emits `DefaultFeeSet`.

Reading is open:

- `getOperationFee(opType, opCommand)` — returns the configured fee for that pair, or `0` if it falls back to default.
- `getDefaultFee()` — current default.
- `calculateFeeByTeeIds(opType, opCommand, teeIds[])` — full fee for a hypothetical instruction.
- `calculateFeeByWalletId(walletId, opType, opCommand)` — full fee for a PMW wallet operation. It resolves the wallet's receiving TEEs the same way `pay`/`reissue` do — via [`WalletKeyManager.getReceivingTeeIds`](../../../contracts/tee/library/WalletKeyManager.sol) (the deduplicated, PRODUCTION-only TEE set, see [Key Management](./KeyManagement.md#receiving-tees-for-a-wallet)) — then multiplies by the per-operation fee. Reverts with `ThresholdNotMet()` if the wallet does not currently have enough available keys. This is what a wallet should call to pre-flight the fee for a `PAY` or `REISSUE` before submitting.

## Why this scheme

A per-`(opType, opCommand)` fee schedule lets governance tune economics without contract upgrades. Examples (illustrative — actual mainnet values are governance-set):

- A simple key generate (`F_WALLET / KEY_GENERATE`) is cheap — single-machine TEE work, no external chain interaction.
- An XRPL payment signing (`F_WALLET / PAY`) is moderate — the TEE has to construct, sign, and broadcast a transaction.
- A VRF (`F_VRF`) is moderate — TEE compute but no external interaction.
- An FDC2 attestation (`F_FDC2 / PROVE`) is expensive — the TEE must fetch external chain data, verify it, and sign.

Each operation type can have its fee tuned independently as off-chain costs change.

## Where the fee goes

The full `msg.value` paid by the caller (not just the calculated fee — see [Instructions / Validation and fee](./Instructions.md#validation-and-fee)) is forwarded to `RewardManager.receiveRewards(currentRewardEpochId, false)` — booked as a **community offer** for the current reward epoch.

Reward distribution is then off-chain. The reward calculator splits the FCC reward pool across:

- **Relay clients** that signed and forwarded the instruction (proportional to their FSP signing-policy weight).
- **TEE operators** for each TEE that executed the instruction.
- **Cosigners**, if any participated.

Different extensions have different reward weights for these classes. The operation fee feeds the pool; the rules for splitting the pool are a per-extension concern.

## What about PMW / per-wallet payments

The PMW extension has additional fees that are **not** per-instruction — they're per-wallet upkeep, accruing over time. Those are handled by [`TeePaymentsFeeScheduleManager`](../../../contracts/tee/implementation/TeePaymentsFeeScheduleManager.sol), a stand-alone UUPS contract outside the diamond. The PMW extension consults it when calculating "what does this wallet owe right now" and surfaces the answer through a per-extension payment-stream mechanism.

The split — per-instruction fees in `OperationFees` (in the diamond), per-wallet streams in `TeePayments*` (outside) — exists because:

- Per-instruction fees are simple lookups on a hot path; they belong in the diamond storage where the instruction-dispatch logic already runs.
- Per-wallet streams accumulate continuous amounts and need their own UUPS upgradeability lifecycle (different governance, different release cadence than the diamond cuts). They sit outside the diamond as their own contracts.

The diamond's `OperationFees` is unaware of the `TeePayments*` stack; an extension that wants both charges through both. PMW does this via its extension-specific instructions sender, which calls into both layers at the right moments.

## Fee for system instructions

System instructions (those with `opType` starting with `F_`) go through the same fee calculation. The system pays itself — when the registration-attestation path (`Verification.requestTeeAttestation`, invoked from `MachineManagerFacet.register`) fires an `F_REG / TEE_ATTESTATION` instruction during machine registration, it forwards `msg.value` (whatever the registering owner paid) to `RewardManager`. The fact that it's a "system" instruction doesn't make it free; it just means it can target machines in `INITIALIZED` status.

The default fee at deployment is set so that initial machine attestations are reasonably priced — large enough to deter spam, small enough that legitimate operators can register without prohibitive cost.

## What if the fee is wrong

Two obvious failure modes:

- **Underpayment** — `msg.value < fee`. The transaction reverts with `FeeTooLow()`. Callers should call `OperationFees.calculateFeeByTeeIds(opType, opCommand, teeIds)` first.
- **Overpayment** — `msg.value > fee`. The transaction succeeds. The full amount is forwarded to `RewardManager`. There is no automatic refund. Callers concerned with this should check the fee and pay exactly.

The `claimBackAddress` field on `TeeInstructionParams` is for *off-chain* refund of unused TEE work (e.g. if FDC2 picks 5 TEEs but only 3 successfully respond, the off-chain layer can refund the unused fees to `claimBackAddress`). It is **not** the on-chain refund of `msg.value - fee` overpayment.

## Reading the fee schedule

A simple integration pattern:

```solidity
uint256 fee = teeManager.calculateFeeByTeeIds(
    bytes32("F_WALLET"),
    bytes32("PAY"),
    teeIds
);
teeManager.sendInstructions{value: fee}(teeIds, params);
```

The view is gas-cheap; calling it before every dispatch is the recommended pattern.
