# Forbidden address list

[`ForbiddenAddressList`](../../contracts/compliance/implementation/ForbiddenAddressList.sol) (interface [`IForbiddenAddressList`](../../contracts/userInterfaces/IForbiddenAddressList.sol), governance surface [`IIForbiddenAddressList`](../../contracts/compliance/interface/IIForbiddenAddressList.sol), proxy [`ForbiddenAddressListProxy`](../../contracts/compliance/proxy/ForbiddenAddressListProxy.sol)) keeps governed lists of addresses that value may not be accepted from or paid to — sanctions screening. It is not tied to one product: any contract or verifier that must refuse such value reads it — an FDC2 verifier screening the addresses of a proof, or an on-chain consumer checking an address itself (see [Consumers](#consumers)).

## Two kinds of list

- **One list per non-EVM source**, of address strings, named by the source's FDC source id — Bitcoin (`BTC` / `testBTC`) or XRPL (`XRP` / `testXRP`). Each source has its own entries, version and last-addition time, so an addition on one source never makes a verdict about another stale.
- **One EVM list**, of `address` values, for every EVM chain at once — Flare, Songbird, Ethereum, the test networks. An EVM address is the same holder on every EVM chain, so it is listed once; and an `address` has a single value, so it has no spelling to get wrong. EVM addresses are never added to a source's string list.

**Network.** The list serves one external network for the whole deployment ([`IExternalNetwork`](../../contracts/userInterfaces/IExternalNetwork.sol)`.Network`), set at initialisation and read with `getNetwork()`: flare and songbird are `Mainnet`, the costons `Testnet`, a local deployment (scdev, the simulation) `Local`. The source id names the chain; the network decides which of its address networks is valid — mainnet, testnet, or regtest on `Local` — and which kind of id the deployment supports, by the FDC's convention ([`SourceIds`](../../contracts/utils/lib/SourceIds.sol)): ids without the `test` prefix on `Mainnet`, `test…` ids on `Testnet`, both on `Local`. **Every per-source call** — additions and removals, `isForbidden`, `isForbiddenHash`, `isCanonicalAddress`, both pages, `getVersion`, `lastAdditionTimestamp` — **reverts `UnsupportedSourceId(sourceId)`** for any other id: an EVM chain's, one of a chain the list has no rule for, one of the other kind of network. A consumer or verifier configured with a wrong id therefore fails at its first call instead of reading an empty list as clean.

The maintainers are one set for all lists.

## Identity

On a source's list an address is identified by its **standard address hash**, `keccak256(bytes(address))`, the FDC's own convention. It must therefore be added in the **canonical form** the FDC hashes on its chain:

| Chain | Canonical form | Not canonical (never matches) |
|---|---|---|
| Bitcoin | Base58 as written; Bech32 (`bc1…`, `tb1…`, `bcrt1…`) in lowercase — of the deployment's network | uppercase Bech32, which BIP-173 also allows |
| XRPL | the classic `r…` address | an X-address (`X…`, `T…`), which spells the same account |

The list **enforces** the form, with the address validators on the deployment's network ([`BtcAddress`](../../contracts/utils/lib/BtcAddress.sol), which takes Bech32 in lowercase only; [`XrpAddress`](../../contracts/utils/lib/XrpAddress.sol)`.isValidClassic`): `isCanonicalAddress(sourceId, address)` says whether a string is canonical under a supported source (false for a malformed address, `UnsupportedSourceId` for an unsupported id — a configuration error, not a user's), an addition of any other string reverts `NonCanonicalAddress(sourceId, address)`, and so does a check by string. A second spelling can therefore neither be listed nor be answered as clean. Checks are by hash, `isForbiddenHash(sourceId, addressHash)` (one storage read, unchecked: a hash an FDC proof reports is canonical by construction), or by string, `isForbidden(sourceId, address)`, which checks the form, hashes and looks up.

On the EVM list an address is the `address` itself: `isForbiddenEvmAddress(address)`.

## Personal Accounts

An address on a source's chain can own a **Personal Account** on Flare — a smart account the smart-account controller of that source derives deterministically from the owner's address, deployed or not. Value a listed owner moves through its Personal Account must be frozen too, so the list lists the account on its EVM list together with its owner.

Governance sets, per source, a **Personal Account provider** (`setPersonalAccountProvider(sourceId, provider)`, read with `getPersonalAccountProvider(sourceId)`): a contract answering [`IPersonalAccountProvider`](../../contracts/userInterfaces/IPersonalAccountProvider.sol)`.getPersonalAccount(owner)` — the smart-account controller's `PersonalAccountsFacet`. The provider must have code (`PersonalAccountProviderWithoutCode`); the zero address clears it. Emits `PersonalAccountProviderSet(sourceId, provider)`.

When `addForbiddenAddresses` lists an address that was not on the list, and the source has a provider, the list asks the provider for the address's Personal Account and adds it to the EVM list (`ForbiddenEvmAddressAdded`, unless it is listed already), emitting `PersonalAccountDerived(sourceId, owner, personalAccount)`. The EVM list's version and `lastEvmAdditionTimestamp()` move once per call that added a Personal Account.

- **The provider is trusted to answer.** It is a governed contract, set with governance's timelock, and called with a plain (static) call: if it reverts, the addition reverts and lists nothing, and a zero answer reverts `EvmAddressZero` — an owner is never listed without its Personal Account. The smart-account controller's derivation is a pure computation of a CREATE2 address, which cannot fail, for about 12k gas; a batch of a hundred Bitcoin addresses with their Personal Accounts costs about 20M gas, within a Flare block (28M).
- **Only new additions derive.** An address already on the list is skipped with its derivation, so an account governance removed while its owner stays listed is not listed again by a repeated batch. Nothing is derived for the addresses listed before a provider was set — a maintainer adds those accounts directly.
- **A removal never cascades.** Removing an owner leaves its Personal Account on the EVM list; governance removes it separately. An owner removed and added again counts as new and derives again.

## Roles

What freezes value without moving it may be immediate; what releases value is timelocked, so that a governance takeover cannot release anything at once.

| Call | Who | Timelock |
|---|---|---|
| `addForbiddenAddresses(sourceId, addresses)`, `addForbiddenEvmAddresses(addresses)` | a maintainer, or immediate governance | none — an addition must reach the chain within a business day, and it moves no value |
| `removeForbiddenAddresses(sourceId, addresses)`, `removeForbiddenEvmAddresses(addresses)` | governance | yes (`onlyGovernance`) — a removal releases value |
| `addMaintainers(maintainers)` | governance | yes — it grants the power to freeze |
| `setPersonalAccountProvider(sourceId, provider)` | governance | yes, both setting and clearing — a provider decides what additions freeze, and clearing it lets an owner's Personal Account go unlisted |
| `removeMaintainers(maintainers)` | governance | none (`onlyImmediateGovernance`) — a revocation is immediate, as every revocation is |

The **maintainers** are a set governance keeps (`isMaintainer`, `getMaintainers`), typically compliance multisigs smaller than governance; with none, only governance adds (`OnlyMaintainerOrImmediateGovernance` for anyone else). Every maintainer can add on its own, and an addition stays until governance's timelocked removal, so each maintainer is a party that can freeze any address for at least the timelock — keep the set small. The zero address cannot be one (`MaintainerZero`). Every batch call is idempotent: an address already in the state the call asks for is skipped, so repeating a batch is harmless. A string in another form is refused (`NonCanonicalAddress`; a batch reverts at the first, and adds nothing), and so is the zero address on the EVM list (`EvmAddressZero`). A removal is not checked, so whatever was added can be removed. Events: `ForbiddenAddressAdded(sourceId, address)`, `ForbiddenAddressRemoved(sourceId, address)`, `ListVersionChanged(sourceId, version)`, `ForbiddenEvmAddressAdded(address)`, `ForbiddenEvmAddressRemoved(address)`, `EvmListVersionChanged(version)`, `MaintainersAdded(maintainers)`, `MaintainersRemoved(maintainers)`.

## Storage and reading

Each source's list keeps two parallel arrays — the address hash and the address string at the same index — and a mapping from hash to index plus one gives the membership check and finds an entry to remove. The EVM list is an OpenZeppelin `EnumerableSet.AddressSet`, the same layout for `address` values. A removal moves the last entry into the removed one's place, so the order is not the insertion order.

Every list has a **version**, raised by every call that changes it (a call that only repeats or misses addresses leaves it). The pages — `getForbiddenAddressHashes(sourceId, start, count)` and `getForbiddenAddresses(sourceId, start, count)` (the same indices) for a source, `getForbiddenEvmAddresses(start, count)` for the EVM list — return the entries, the total count and the version; `getVersion(sourceId)` and `getEvmVersion()` read the version alone, so a reader that keeps a copy re-reads a list only when it moved, and `ListVersionChanged` / `EvmListVersionChanged` announce every move. A reader that pages through a list compares the version every page returns: one version on every page is one consistent list; another means the list changed while it was read, and the reader starts again. A start at or past the end returns an empty page. A batch of a hundred Bitcoin addresses, validated, costs about 14M gas, half a Flare block; a hundred EVM addresses about 4.8M (`ForbiddenAddressList.t.sol`).

`lastAdditionTimestamp(sourceId)` and `lastEvmAdditionTimestamp()` are the block time of the last call that added an address to the list; a repeated batch and a removal do not move them, since a removal never makes a clean verdict wrong. A consumer of a verdict computed from a list — an FDC2 proof — compares the proof's `header.timestamp` with it: a proof attested before the last addition (plus the verifiers' read lag) may not know the addition.

## Consumers

Which call fits depends on what the consumer holds:

| The consumer holds | Call | Examples |
|---|---|---|
| an EVM `address` (a Flare account, an executor, a recipient, an EVM sender) | `isForbiddenEvmAddress(address)` | a minting recipient, a redeemer, a collateral reserver; a smart account and its executor |
| a standard address hash from an FDC proof (`sourceAddressHash`, `receivingAddressHash`, `standardAddressHash`) | `isForbiddenHash(sourceId, hash)` | the XRPL sender of a smart-account instruction, an FDC1 minting payment |
| an address string a user supplied (a redemption destination, a receiver) | `isForbidden(sourceId, address)`, which reverts `NonCanonicalAddress` for another spelling; `isCanonicalAddress` first, to refuse with the consumer's own error | a Bitcoin or XRPL destination |

- **A user-supplied string in a non-canonical spelling is refused**, not converted — uppercase Bech32, an XRPL X-address. `isForbidden` does it itself, by reverting; a non-canonical string can never be on the list, so a `false` for one would read as clean. Refusing keeps one spelling end to end: a consumer that lowercased only for the lookup would still store and pay the string it was given, and every later match by hash (an FDC proof's `receivingAddressHash`) would disagree with it. Hashes from FDC proofs are canonical by construction — the verifiers produce them.
- **Freshness.** A verdict from a proof is as of its attestation; a consumer that needs it current compares the proof's `header.timestamp` with `lastAdditionTimestamp(sourceId)` (`lastEvmAdditionTimestamp()` for an EVM source). A direct lookup reads the list as it is.
- **Source ids per network.** A consumer looks an address up under its own network's FDC source id — `testBTC`, `testXRP`, … on the costons — and any other reverts `UnsupportedSourceId`. The EVM list is the same on every network.

## Deployment

A UUPS proxy on [`FlareUpgradeableBase`](../../contracts/governance/implementation/FlareUpgradeableBase.sol), one per network; it reads no other contract. [`DeployForbiddenAddressList.s.sol`](../../deployment/scripts/DeployForbiddenAddressList.s.sol) (`pnpm deploy_forbidden_address_list <network>`, a dry run unless `--broadcast`) deploys it with the deployer as initial governance and loads its initial contents, so the list starts full rather than through later maintainer or governance calls:

- the maintainers of the chain profile's `forbiddenAddressListMaintainers`;
- the Personal Account providers of `forbiddenAddressListPersonalAccountProviders`, before anything is loaded, so the initial contents list the Personal Accounts of their sources' addresses too: the XRPL smart-account controller under `XRP` on flare and songbird and under `testXRP` on coston2, none on coston and scdev, where no controller runs. A Bitcoin controller is added to a profile once it is deployed;
- for each source of `forbiddenAddressListSources`, every address [`forbidden-addresses.json`](../../deployment/chain-config/forbidden-addresses.json) (OFAC's) and [`forbidden-addresses-manual.json`](../../deployment/chain-config/forbidden-addresses-manual.json) (added by hand) list for it. The data file is one for every network: its `lists` are groups, each naming the addresses and the sources they apply to, so an address forbidden on several sources is written once; an address in two groups of the same source is loaded once (the second is skipped);
- on every network, both files' EVM addresses into the EVM list.

Each list is loaded 100 addresses per transaction, and the script then checks every address is on it, and, for a source with a provider, its Personal Account on the EVM list. The proxy takes the deployment's external network (`_externalChainEnvironment`). The data file's Bitcoin addresses are mainnet ones, so the profiles name `BTC` and `XRP` on flare and songbird, only `XRP` on scdev (a `Local` deployment, where Bitcoin is regtest), and only `testXRP` on coston and coston2 — an XRPL classic address names no network, so the file files its XRPL addresses under `testXRP` too, while it has no test group for Bitcoin, whose testnet addresses differ — and every network loads the EVM list.

The data file is generated from OFAC's [SDN list](https://sanctionslist.ofac.treas.gov/Home/SdnList) by [`update-forbidden-addresses.ts`](../../deployment/scripts/update-forbidden-addresses.ts) (`pnpm update_forbidden_addresses`, or `--file <SDN.XML>` for a downloaded copy), which records the list's publish date in the file: `BTC` takes the list's `XBT` addresses and the `USDT` ones that are Bitcoin addresses (USDT issued on Bitcoin through Omni), `XRP` and `testXRP` (one group) its `XRP` addresses, and `evmAddresses` every `0x` address whatever currency OFAC files it under (ETH, USDT, USDC, ETC, BSC, ARB, …). Bitcoin and XRPL addresses are written in canonical form; EVM addresses as OFAC writes them, since they are loaded as `address` values; one without its list's shape is reported and left out. The generator writes the whole file, so nothing is added to it by hand.

The addresses added by hand live in [`forbidden-addresses-manual.json`](../../deployment/chain-config/forbidden-addresses-manual.json), which nothing rewrites and the deploy script loads with the generated file, for the same sources. Its `lists` are groups of the same shape, and its EVM addresses are grouped too (`evmLists`, each with its `addresses`); every group names its `source` — why its addresses are listed — unique in the file, and the deploy script refuses a file that does not. It lists XRPL's ACCOUNT_ZERO (`rrrrrrrrrrrrrrrrrrrrrhoLvTp`, the AccountID of 20 zero bytes: no one holds its key, and the XRPL rejects every transaction to it, so an FAssets redemption to it cannot work). An address in both files is loaded once.

Since the list refuses any other form, `DeployForbiddenAddressList.t.sol`, which loads both real files' mainnet groups into a `Mainnet` list and their `test…` groups into a `Testnet` one, fails in CI for a regeneration or a hand edit that wrote one, naming the address, before a real deploy could.

The script then hands the address updater role to the AddressUpdater and publishes the name `ForbiddenAddressList` on it (directly when the deployer governs the AddressUpdater, as governance calldata otherwise), and refuses to run where a `ForbiddenAddressList` is already recorded. Switching it to production mode — governance to `GovernanceSettings`, removals and new maintainers timelocked — is the separate step `pnpm deploy_forbidden_address_list <network> --switch-to-production` (the script's `switchToProduction()`), run once the loaded contents are checked; it refuses a list the deployer does not govern and leaves one already in production alone.
