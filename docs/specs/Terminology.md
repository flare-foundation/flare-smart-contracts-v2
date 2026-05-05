# Terminology

Roles and concepts referenced throughout these docs. Cross-protocol — for terms specific to one sub-protocol, see that section's index.

## Roles

### Data provider

Also called a *voter*, *validator*, *infrastructure provider*, or *entity*. An off-chain participant registered through [`EntityManager`](../../contracts/protocol/implementation/EntityManager.sol) and [`VoterRegistry`](../../contracts/protocol/implementation/VoterRegistry.sol). Data providers accrue vote power from delegations of the wrapped-native token (WNat — `WFLR` on Flare, `WSGB` on Songbird, `WCFLR` on Coston, `WC2FLR` on Coston2) and from validator stakes; they participate in every protocol — running a Flare validator, submitting and finalizing voting rounds in [FSP](./FSP/index.md), providing prices in [FTSO](./FTSO/index.md), confirming attestations in [FDC](./FDC/index.md), and (when registered as relay clients) relaying instructions to TEE machines in [FCC](./FCC/index.md). They must self-register every reward epoch (only the top entities by weight, up to `maxVoters`, become voters), and earn rewards in proportion to participation; non-participation or late finalization is penalized.

### Delegator

A WNat holder who delegates their vote power to a data provider's delegation address. Delegators don't run infrastructure; they share in the rewards earned by the data provider they delegate to.

### User

Any address holder who interacts with the protocols — for example, by submitting an FCC instruction through a smart contract, making an [FDC attestation request](./FDC/MakingARequest.md), or simply reading an FTSO price. Users do not need to register or run off-chain infrastructure.

### TEE operator

The party that deploys and maintains TEE machines and their associated TEE proxies. TEE operators register their machines on-chain through the FCC machine-registration flow (see [FCC/MachineLifecycle](./FCC/MachineLifecycle.md)) and must be on the extension's owner allowlist. A TEE operator need not be a data provider.

### Project owner

A Flare address that creates and administers an FCC *project*. Controls wallet creation, key management, and configuration for the project's wallets. See [FCC/WalletManagement](./FCC/WalletManagement.md).

### Key admin

One of a set of addresses associated with a wallet whose public keys are used for encrypting Shamir secret shares during key backup, and which participate in key restoration. Operations requiring admin approval use a $k$-of-$n$ threshold over the admin public keys. See [FCC/KeyManagement](./FCC/KeyManagement.md).

### Cosigner

A Flare address assigned to an FCC instruction to provide additional multisig confirmation. When cosigners are configured for a wallet, each instruction must be relayed by a threshold of cosigners before the TEE executes it. Cosigners run their relay clients in cosigner mode and need not participate in other Flare protocols.

### Governance signer

An address registered on-chain as part of an FCC per-extension governance set. Extension owners configure the set and its threshold; signers approve TEE upgrades by submitting signatures that the contract validates against the set. See [FCC/Governance](./FCC/Governance.md).

### System governance

Outside FCC, governance is administered through [`Governor`](../../contracts/governance/) with a timelock. See [Governance](./Governance.md).

## Concepts

### Address, account, key

An **address** is a 20-byte identifier derived from an ECDSA public key (last 20 bytes of the keccak-256 hash of the uncompressed key). An **account** is the on-chain state behind an address — balance, nonce, code, storage. A **public key** in this repo is sometimes represented as the [`PublicKey`](../../contracts/userInterfaces/IPublicKey.sol) struct with curve coordinates $(x, y)$. Signing follows the standard ECDSA flow with the Ethereum signed-message prefix prepended before hashing.

### Voting epoch and reward epoch

A **voting epoch** is the basic time unit of FSP, lasting **90 seconds**. A **reward epoch** spans **3360 voting epochs** (~3.5 days). Voter registration, signing policies, and reward distribution are all scoped to reward epochs. Sub-protocols (FTSO anchor, FDC) submit one voting round per voting epoch. Block-latency feeds (`FastUpdater`) operate at block granularity — finer than a voting epoch — but their incentive accounting is still settled over voting / reward epochs. See [FSP/Epochs](./FSP/Epochs.md).

### Signing policy

The set of data providers eligible to sign for a given reward epoch and their corresponding weights. A new signing policy is computed each reward epoch from the registered voter set and published through [`FlareSystemsManager`](../../contracts/protocol/implementation/FlareSystemsManager.sol) and [`Relay`](../../contracts/protocol/implementation/Relay.sol). It must itself be signed by the *previous* reward epoch's signing policy before it takes effect. See [FSP/SigningPolicy](./FSP/SigningPolicy.md).

### Vote power, weight, threshold

**Vote power** is the influence a data provider has in protocol voting, derived from WFLR delegations and validator stakes. Vote power is normalized into a **weight** (between $0$ and $1$) for use in signing policies; the weighting formula applies a diversity factor to encourage decentralization. A **threshold** is the minimum proportion of weight (or count of participants) required for a collective action — finalization in `Relay`, instruction acceptance at a TEE proxy, key-management approvals — to proceed. See [FSP/Weighting](./FSP/Weighting.md).

### Voting round, Merkle root, finalization

A **voting round** is one execution of a sub-protocol over a voting epoch — one round of FTSO anchor prices, one batch of FDC attestation requests, one FCC voting cycle. Round results are committed off-chain into a Merkle tree; the **Merkle root** is finalized on-chain by [`Relay`](../../contracts/protocol/implementation/Relay.sol) once a threshold of the signing policy has signed it. Consumers (smart contracts on Flare, off-chain readers) prove individual data items against the finalized root. See [FSP/Finalization](./FSP/Finalization.md).

### Reward offer, reward claim

A **reward offer** is FLR (or other tokens) committed to a sub-protocol for a reward epoch, contributed either by inflation / the incentive pool or by community participants. Sub-protocols' offers managers do **not** calculate rewards: they only validate offers, emit events describing them, and forward the FLR to [`RewardManager`](../../contracts/protocol/implementation/RewardManager.sol). Off-chain reward calculation reads those events plus submission/finalization events and produces a Merkle tree of `(beneficiary, claimType, amount)` rows. The active signing policy threshold-signs the resulting reward hash via [`FlareSystemsManager.signRewards`](../../contracts/protocol/implementation/FlareSystemsManager.sol); only then are claims live on `RewardManager`, which beneficiaries access by Merkle proof. See [FSP/Rewarding](./FSP/Rewarding.md).

### `AddressUpdatable`

The standard inter-contract wiring mechanism in this repo. Every contract that depends on another inherits [`AddressUpdatable`](../../contracts/utils/implementation/AddressUpdatable.sol); a central `AddressUpdater` contract pushes updated addresses to dependents whenever governance changes them. See [Architecture / Address wiring](./Architecture.md#address-wiring-addressupdatable).

### Diamond (EIP-2535)

The FCC implementation uses an EIP-2535 diamond proxy ([`FlareTeeManager`](../../contracts/tee/) is the diamond), so a single address dispatches to many *facets* of behavior. State lives in ERC-7201-namespaced storage (one namespace per library) so that adding or replacing facets does not collide with existing storage. See [FCC/Architecture](./FCC/Architecture.md).

### `II*` vs `I*` interfaces

Public-facing interfaces — the integration surface — live under [`contracts/userInterfaces/`](../../contracts/userInterfaces/) with an `I` prefix (e.g., `IFlareSystemsManager`, `IFdcHub`). Internal interfaces used between contracts in this repo (mostly in FCC, between facets and libraries) use a `II` prefix (e.g., `IIInstructions`). When you pick a doc to integrate against, look at the `I*` form.

## A note on names: TEE vs FCC

**"TEE"** as a protocol name has been folded into **"FCC"** (Flare Confidential Compute). The hardware concept "a TEE" still appears in the docs (one machine), but the protocol section is FCC. The code keeps `Tee*` as a contract-name prefix (e.g., `FlareTeeManager`, `TeeRewardOffersManager`); citations to those names in prose are verbatim.
