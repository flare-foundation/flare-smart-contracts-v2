# FDC2

FDC2 is the new generation of the Flare Data Connector. It serves the same attestation-types catalog as the legacy FDC — `Payment`, `EVMTransaction`, `Web2Json`, `AddressValidity`, etc. — but produces confirmations through a fundamentally different mechanism: instead of running a per-round bit-vote across all data providers and finalizing a Merkle root, FDC2 routes each request to a **set of TEE machines** (registered through the FCC system extension) that each verify the request independently and **sign** the response.

This page covers the on-chain pieces: [`Fdc2Hub`](../../../contracts/fdc2/implementation/Fdc2Hub.sol), [`Fdc2Verification`](../../../contracts/fdc2/implementation/Fdc2Verification.sol), and [`Fdc2RequestFeeConfigurations`](../../../contracts/fdc2/implementation/Fdc2RequestFeeConfigurations.sol). For the FCC primitives FDC2 relies on (TEE machines, instructions, system extensions), see [FCC](../FCC/index.md).

## Why FDC2

FDC2 was designed to address three limitations of the voting-based FDC:

- **Latency.** A legacy FDC request takes at least one full voting round (~3 minutes including all phases) to get on chain. An FDC2 attestation can complete as soon as the request reaches a sufficient set of TEE machines and they sign a response — typically a fraction of that.
- **Cross-chain consumption.** FDC2's response is signed by the FSP signing policy (or directly by TEE machines). Since the signing policy hash is a known constant on any chain that monitors Flare, an FDC2 attestation can be verified on chains that don't run FDC at all — useful for bridging.
- **Per-request control.** A consumer can specify *which* TEE machines must respond, *which* cosigners must approve, and *what threshold* of signatures must agree. Legacy FDC's threshold is the FSP signing policy threshold (currently ~50%), with no per-request adjustment.

The trade-off: FDC2's trust model leans on the integrity of the TEE machines and the FCC system extension. Legacy FDC's trust model is the FSP signing policy itself. They are complementary — both are deployed.

## `Fdc2Hub`: making a request

```solidity
function requestAttestation(
    Fdc2AttestationRequest calldata _attestationRequest,
    uint256 _numberOfTees,
    address[] memory _teeIds,
    address[] memory _cosigners,
    uint64 _cosignersThreshold,
    address _claimBackAddress
) external payable;
```

The `Fdc2AttestationRequest` carries:

- A header with `attestationType`, `sourceId`, `proofOwner`, and `thresholdBIPS` (signature threshold the consumer requires for the response, or `0` to defer to the active FSP signing policy threshold).
- A type-specific request body, ABI-encoded.

### Validation

`Fdc2Hub.requestAttestation` enforces:

- **Threshold sanity.** `thresholdBIPS == 0` (use signing policy) or `minThresholdBIPS ≤ thresholdBIPS ≤ MAX_BIPS (10000)`.
- **TEE-set sanity.** Either `_numberOfTees == 0` (let the hub pick), or `_teeIds[]` non-empty, or both consistent (`_numberOfTees == _teeIds.length`).
- **Cosigner sanity.** `_cosigners.length >= _cosignersThreshold`.
- **Multi-response prevention.** If `thresholdBIPS != 0` (and < 50%), at least more than half of cosigners must be required to sign — otherwise multiple distinct response sets could be threshold-valid simultaneously, leaving the consumer uncertain which to honor.
- **Fee.** `msg.value >= fdc2RequestFeeConfigurations.getTypeAndSourceFee(attestationType, sourceId)`.

### TEE selection

If `_teeIds[]` is empty, the hub picks `_numberOfTees` (or `defaultNumberOfTees` if zero) random TEE machines via `flareTeeManager.getRandomTeeIds(0, _numberOfTees)`. The chosen machines must all be in the **system extension** (`extensionId == 0`) and in `PRODUCTION` status.

If `_teeIds[]` is provided, each is checked individually:

- No duplicates.
- Status must be `INITIALIZED` or `PRODUCTION`. If `PAUSED_FOR_UPGRADE`, the hub looks up the **replicating** TEE (`flareTeeManager.getReplicatingTeeId(teeId)`) and substitutes it (preserving the original `teeId` for the consumer's view); reverts if there is no replicating machine.
- Must belong to the system extension (`extensionId == 0`).

### Fee handling and routing

```solidity
rewardManager.receiveRewards{value: fee}(currentRewardEpochId, false);
flareTeeManager.sendSystemInstructions{value: msg.value - fee}(
    bytes32(0),
    teeMachines,
    IInstructions.TeeInstructionParams(
        FDC2_OP_TYPE,            // operation type identifier
        bytes32("PROVE"),         // operation
        abi.encode(_attestationRequest),
        _cosigners,
        _cosignersThreshold,
        _claimBackAddress
    )
);
```

The fee floor goes to `RewardManager` as a community offer for the current reward epoch (joining FDC's existing reward stream). The remainder pays the **FCC instruction fee** — the cost of running the TEE machines through the operation. The instruction's `claimBackAddress` is where any unspent FCC fee gets returned (if the actual FCC operation costs less than what was paid).

The TEE side then receives a `PROVE` operation of type `FDC2_OP_TYPE` and runs the per-attestation-type verification logic, signing the response. Off-chain delivery of the signed response back to the requester is up to the FCC infrastructure (relay clients, indexer); see [FCC/Instructions](../FCC/Instructions.md).

The hub emits:

```solidity
event AttestationRequested(
    bytes32 instructionId,
    bytes32 attestationType,
    bytes32 sourceId,
    address proofOwner,
    address claimBackAddress,
    uint256 fee
);
```

`instructionId` is the FCC instruction handle; the requester (or an indexer on their behalf) tracks it through to a signed response.

## `Fdc2Verification`: verifying responses

[`Fdc2Verification`](../../../contracts/fdc2/implementation/Fdc2Verification.sol) is the consumer-facing verifier. Three flavors:

### `verifySigningPolicySignatures`

```solidity
function verifySigningPolicySignatures(
    bytes calldata _signingPolicySignatures,
    bytes32 _messageHash
) external returns (uint256 _rewardEpochId);
```

Delegates to [`Relay.verifyCustomSignature`](../../../contracts/protocol/implementation/Relay.sol). Verifies a packed batch of FSP signing-policy signatures against `_messageHash` (the response's keccak hash). Returns the reward epoch ID of the signing policy that was used. This is the **cross-chain** verification path — applications on other chains that have access to the signing-policy hash can run the same logic.

### `verifyTeeSignature` / `verifyTeeSignatures`

```solidity
function verifyTeeSignature(Signature calldata, bytes32) external view returns (address teeId);
function verifyTeeSignatures(Signature[] calldata, bytes32) external view returns (address[] memory teeIds);
```

ECDSA-recovers the signer of `_messageHash`, then checks via `flareTeeManager`:

- `getExtensionId(signingTeeId) == 0` — must be the system extension.
- `getTeeMachineStatus(signingTeeId) == PRODUCTION` — must be live.

The plural variant additionally rejects duplicate signers. Used for direct on-Flare verification when the consumer's threshold is some N-of-M of TEE machines.

### `recoverCosigners`

```solidity
function recoverCosigners(Signature[] calldata, bytes32) external pure returns (address[] memory cosigners);
```

Pure ECDSA recovery (no TEE-status checks). Used to extract the cosigner addresses for further authorization checks at the consumer layer. Rejects duplicates.

## `Fdc2RequestFeeConfigurations`

A simpler clone of the legacy [`FdcRequestFeeConfigurations`](../../../contracts/fdc/implementation/FdcRequestFeeConfigurations.sol):

```solidity
function setTypeAndSourceFee(bytes32 type, bytes32 source, uint256 fee) external onlyGovernance;
function removeTypeAndSourceFee(bytes32 type, bytes32 source) external onlyGovernance;
function setTypeAndSourceFees(bytes32[] types, bytes32[] sources, uint256[] fees) external onlyGovernance;
function removeTypeAndSourceFees(bytes32[] types, bytes32[] sources) external onlyGovernance;
function getTypeAndSourceFee(bytes32 type, bytes32 source) external view returns (uint256);
```

The mapping is keyed by `keccak256(abi.encodePacked(type, source))`. A fee of `0` means "not configured" and `getTypeAndSourceFee` reverts. This contract is **UUPS-upgradeable** (unlike the legacy one), behind a proxy.

## Inflation and reward offers

FDC2 inflation flows through two dedicated contracts that sit **alongside** [`Fdc2Hub`](../../../contracts/fdc2/implementation/Fdc2Hub.sol) rather than inside it — the same structural choice the TEE protocol made with [`TeeRewardOffersManager`](../../../contracts/tee/implementation/TeeRewardOffersManager.sol). `Fdc2Hub` itself only handles per-attestation request fees (already covered above); the inflation pool is the concern of these two contracts:

### `Fdc2InflationConfigurations`

A governance-managed array of `Fdc2Configuration` entries — one per `(attestationType, sourceId)` pair that should receive a slice of FDC2 inflation:

```solidity
struct Fdc2Configuration {
    bytes32 attestationType;
    bytes32 sourceId;
    uint24 inflationShare;
    uint8 minRequestsThreshold;
    uint224 mode;
}

function addFdc2Configurations(Fdc2Configuration[] calldata) external onlyGovernance;
function replaceFdc2Configurations(uint256[] calldata indices, Fdc2Configuration[] calldata) external onlyGovernance;
function removeFdc2Configuration(uint256 index) external onlyGovernance;
function getFdc2Configuration(uint256 index) external view returns (Fdc2Configuration memory);
function getFdc2Configurations() external view returns (Fdc2Configuration[] memory);
```

Each `addFdc2Configurations` / `replaceFdc2Configurations` call validates the entry by calling `Fdc2RequestFeeConfigurations.getTypeAndSourceFee(attestationType, sourceId)` — this reverts with `TypeAndSourceCombinationNotSupported` if no fee has been registered, preventing inflation entries for pairs the hub will not accept.

### `Fdc2RewardOffersManager`

A standalone inflation receiver and reward-offers emitter. It extends [`RewardOffersManagerProxyBase`](../../../contracts/protocol/implementation/RewardOffersManagerProxyBase.sol) — the UUPS-upgradeable base also used by [`TeeRewardOffersManager`](../../../contracts/tee/implementation/TeeRewardOffersManager.sol), and the proxy analogue of the [`RewardOffersManagerBase`](../../../contracts/protocol/implementation/RewardOffersManagerBase.sol) that the legacy [`FdcHub`](../../../contracts/fdc/implementation/FdcHub.sol) inherits — and follows the same lifecycle:

1. The `Inflation` contract calls `setDailyAuthorizedInflation(amount)` and later `receiveInflation()` (with native value), accruing `totalInflationReceivedWei` on this contract.
2. At each reward-epoch switchover, `FlareSystemsManager` calls `triggerRewardEpochSwitchover(epochId, endTs, durationSeconds)`. The manager pro-rates the unoffered inflation balance over the time frame, emits

   ```solidity
   event InflationRewardsOffered(
       uint24 indexed rewardEpochId,
       IFdc2InflationConfigurations.Fdc2Configuration[] fdc2Configurations,
       uint256 amount
   );
   ```

   carrying the full configurations array so off-chain reward-distribution clients can split the pool by `inflationShare`, and forwards the native value to `RewardManager.receiveRewards{value: amount}(rewardEpochId, true)` (the `true` flag marks the funds as inflation-derived, in contrast to per-request fees from `Fdc2Hub` which use `false`).

Both `Fdc2RewardOffersManager` and `Fdc2InflationConfigurations` are UUPS-upgradeable through governance: each is deployed as an implementation contract behind an [`ERC1967Proxy`](contracts/fdc2/proxy/Fdc2RewardOffersManagerProxy.sol) and shares the [`RewardOffersManagerProxyBase`](contracts/protocol/implementation/RewardOffersManagerProxyBase.sol) / [`FlareUpgradeableBase`](contracts/governance/implementation/FlareUpgradeableBase.sol) boilerplate (governance timelock + `upgradeToAndCall` gated by `onlyGovernance`). `Fdc2RewardOffersManager` is wired to `RewardManager`, `FlareSystemsManager`, `Inflation`, and `Fdc2InflationConfigurations` through `AddressUpdater`; deployment seeds the configurations array from chain-config (`fdc2InflationConfigurations` block).

## How a typical FDC2 flow looks

1. Application contract on Flare:
   ```solidity
   fdc2Hub.requestAttestation{value: msg.value}(
       request,
       /*_numberOfTees=*/ 5,
       /*_teeIds=*/ new address[](0),  // let hub pick
       /*_cosigners=*/ cosignersList,
       /*_cosignersThreshold=*/ 3,
       /*_claimBackAddress=*/ msg.sender
   );
   ```
   `requestAttestation` returns nothing; the FCC `instructionId` is surfaced through the `AttestationRequested` event.
2. Hub picks 5 random system-extension TEEs in `PRODUCTION` status. Sends a `(FDC2_OP_TYPE, "PROVE", abi.encode(request), cosigners, 3, sender)` instruction to all of them through `flareTeeManager.sendSystemInstructions`.
3. Each selected TEE machine fetches the source data (Bitcoin RPC, EVM chain RPC, Web2 endpoint, etc.), produces the response, and signs it.
4. Cosigners (off-chain) collect the TEE responses, verify they agree, and produce a cosigner-signed acknowledgement.
5. The off-chain layer collects sufficient signatures (TEE machines and cosigners), forms the response payload, and either:
   - Submits the response on Flare itself, where a consumer contract calls `Fdc2Verification.verifyTeeSignatures(...)` and `Fdc2Verification.recoverCosigners(...)`, then acts on the verified `responseBody`.
   - **Or** routes the response through a cross-chain message (e.g. LayerZero) to another chain, where the recipient verifies via `verifySigningPolicySignatures` against the published signing-policy hash.

The FCC fee paid up-front by the requester gets settled at the TEE machine layer; any unspent portion returns to `_claimBackAddress`. The fee floor goes to the FDC reward pool. See [FCC/OperationFees](../FCC/OperationFees.md).

## Differences from legacy FDC at a glance

| Aspect | FDC | FDC2 |
|--------|-----|------|
| Confirmation by | Threshold of FSP signing policy over a Merkle root | Set of TEE machines signing the response (+ optional cosigners) |
| Latency | One full voting round (~minutes) | Fraction of a round (TEE response time) |
| Threshold | Fixed by signing policy (>50%) | Per-request `thresholdBIPS`, defaults to signing-policy threshold |
| Per-request TEE selection | N/A | Random or explicit |
| Cosigner approval | N/A | Up to `_cosignersThreshold` of `_cosigners[]` |
| Cross-chain verification | Difficult (proves Merkle root which references signing policy) | Direct (signing-policy signatures verifiable anywhere policy hash is known) |
| Inflation pool | Yes ([`FdcInflationConfigurations`](../../../contracts/fdc/implementation/FdcInflationConfigurations.sol)) | Yes ([`Fdc2InflationConfigurations`](../../../contracts/fdc2/implementation/Fdc2InflationConfigurations.sol) + standalone [`Fdc2RewardOffersManager`](../../../contracts/fdc2/implementation/Fdc2RewardOffersManager.sol)) |
| Verification primitive | Merkle proof against `Relay` root | ECDSA signature verification |

Both modules are simultaneously active. Applications choose based on latency / cross-chain / threshold needs.
