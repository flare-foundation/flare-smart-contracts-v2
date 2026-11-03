// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

import { IExternalNetwork } from "./IExternalNetwork.sol";

/**
 * IForbiddenAddressList interface — governed lists of addresses that value may not be accepted from or paid to
 * (sanctions screening). Any contract or verifier that must refuse such value reads them: FDC2 verifiers screening
 * the addresses of a proof, and on-chain consumers that check an address themselves.
 *
 * Two kinds of list:
 * - **One list per non-EVM source**, of address strings, named by the source's FDC source id (`BTC`, `testBTC`,
 *   `XRP`, `testXRP`). Each has its own entries, version and last-addition time, so an addition on one
 *   source never makes a verdict about another stale. An address is identified by its standard address hash,
 *   `keccak256(bytes(address))`, the FDC's convention, so it is held in the one canonical form the FDC hashes on its
 *   chain: Bitcoin Base58 as written and Bech32 in lowercase, a classic `r…` address on XRPL (never an X-address)
 *   (`isCanonicalAddress`), refusing any other spelling on addition and on a check by
 *   string (`NonCanonicalAddress`), so a second spelling can neither be listed nor pass a check as clean. Checks are
 *   by hash (`isForbiddenHash`), for a hash an FDC proof reports, or by string (`isForbidden`).
 *   The list serves one external network for the whole deployment (`getNetwork`):
 *   the source id names the chain — `BTC` / `testBTC` Bitcoin, `XRP` / `testXRP` XRPL — and the network which of
 *   its address networks is valid (regtest on a Local deployment). A source id must name the deployment's kind of
 *   network (`SourceIds.fitsNetwork`: no `test` prefix on Mainnet, the prefix on Testnet,
 *   either on Local); every per-source call reverts `UnsupportedSourceId` for any other id — an EVM chain's, one the
 *   list has no rule for, one of the other network — so a consumer or verifier configured with a wrong id fails at
 *   once rather than reading an empty list as clean.
 * - **One EVM list**, of `address` values, for every EVM chain at once (Flare, Songbird, Ethereum, the test
 *   networks, …): an EVM address is the same holder on all of them, and an `address` has a single value, so there is
 *   no form to get wrong (`isForbiddenEvmAddress`). EVM addresses are never added to a source's string list.
 *
 * **Personal Accounts.** A source may have a Personal Account provider (`getPersonalAccountProvider`, a smart-account
 * controller, set by governance with its timelock): whenever an address is newly added to the source's list, the list
 * asks the provider for the Personal Account that address owns (`IPersonalAccountProvider.getPersonalAccount`, a
 * deterministic address, deployed or not) and lists it on the EVM list in the same call, so a listed owner's smart
 * account is listed with it (`PersonalAccountDerived`). The provider is a governed contract trusted to answer: if
 * it reverts, so does the addition. A repeated address is skipped with its derivation; a removal never cascades — an
 * owner and its Personal Account are removed by governance one by one.
 *
 * Addresses are added by a maintainer — one of a set governance keeps, typically compliance multisigs smaller than
 * governance, so that an addition reaches the chain quickly — or by governance; adding freezes value and moves none.
 * Only governance removes, with its timelock: removing releases value.
 *
 * Every list has a version, raised by every call that changes it. A reader pages through it
 * (`getForbiddenAddressHashes`, `getForbiddenAddresses`, `getForbiddenEvmAddresses`) and compares the version every
 * page returns: the same version on every page is one consistent list; a different one means it changed while it was
 * read, and the reader starts again. Removal moves the last entry into the removed one's place, so the order is not
 * the insertion order.
 */
interface IForbiddenAddressList {

    /// An address was added to a source's list.
    event ForbiddenAddressAdded(bytes32 indexed sourceId, string forbiddenAddress);
    /// An address was removed from a source's list.
    event ForbiddenAddressRemoved(bytes32 indexed sourceId, string forbiddenAddress);
    /// A source's list changed: its version rose to `version`, once per call that changed it.
    event ListVersionChanged(bytes32 indexed sourceId, uint64 version);
    /// An address was added to the EVM list.
    event ForbiddenEvmAddressAdded(address indexed forbiddenAddress);
    /// An address was removed from the EVM list.
    event ForbiddenEvmAddressRemoved(address indexed forbiddenAddress);
    /// The EVM list changed: its version rose to `version`, once per call that changed it.
    event EvmListVersionChanged(uint64 version);
    /// Governance set a source's personal account provider (zero: none).
    event PersonalAccountProviderSet(bytes32 indexed sourceId, address provider);
    /// An address newly added under a source owns this Personal Account, which the EVM list now holds (it may have
    /// held it already).
    event PersonalAccountDerived(bytes32 indexed sourceId, string ownerAddress, address personalAccount);
    /// Governance added maintainers.
    event MaintainersAdded(address[] maintainers);
    /// Governance removed maintainers.
    event MaintainersRemoved(address[] maintainers);

    /// The string is not a valid address of the source's chain, on the deployment's network, in its canonical form.
    error NonCanonicalAddress(bytes32 sourceId, string sourceAddress);
    /// The list holds no string list under this source id: an EVM chain's (its addresses go to the EVM list), one the
    /// list has no rule for, or one naming the other kind of network than the deployment's.
    error UnsupportedSourceId(bytes32 sourceId);
    /// Only a maintainer or governance (without timelock) adds addresses.
    error OnlyMaintainerOrImmediateGovernance();
    /// The zero address cannot be a maintainer.
    error MaintainerZero();
    /// The zero address is no holder's and is never added to the EVM list (nor accepted as a Personal Account).
    error EvmAddressZero();
    /// A personal account provider must be a contract.
    error PersonalAccountProviderWithoutCode();

    /**
     * Adds addresses to a source's list; an address already on it is skipped, so repeating a batch is harmless.
     * Raises the source's version and sets its `lastAdditionTimestamp` if any address was added. Emits
     * ForbiddenAddressAdded for each, and ListVersionChanged once if any was added.
     * @param _sourceId The source (`UnsupportedSourceId` unless the list holds one under it).
     * @param _addresses The addresses, each in its chain's canonical form (`isCanonicalAddress`); the batch reverts
     * `NonCanonicalAddress` at the first that is not.
     * Can only be called by a maintainer or by governance (without timelock).
     */
    function addForbiddenAddresses(
        bytes32 _sourceId,
        string[] calldata _addresses
    )
        external;

    /**
     * Adds addresses to the EVM list, which covers every EVM chain; an address already on it is skipped, so repeating
     * a batch is harmless. Raises the EVM list's version and sets its `lastEvmAdditionTimestamp` if any address was
     * added. Emits ForbiddenEvmAddressAdded for each, and EvmListVersionChanged once if any was added.
     * @param _addresses The addresses (`EvmAddressZero` for the zero address).
     * Can only be called by a maintainer or by governance (without timelock).
     */
    function addForbiddenEvmAddresses(
        address[] calldata _addresses
    )
        external;

    /**
     * Whether the address with this standard address hash is on the source's list.
     * @param _sourceId The source (`UnsupportedSourceId` unless the list holds one under it).
     * @param _addressHash `keccak256(bytes(address))`.
     */
    function isForbiddenHash(
        bytes32 _sourceId,
        bytes32 _addressHash
    )
        external view
        returns (bool);

    /**
     * Whether the address is on the source's list: `isForbiddenHash(_sourceId, keccak256(bytes(_address)))`, for an
     * address a user supplied. Reverts `NonCanonicalAddress` unless the address is in its chain's canonical form
     * (`isCanonicalAddress`): no other spelling can be on the list, so answering `false` for one would read as clean.
     * @param _sourceId The source.
     * @param _address The address.
     */
    function isForbidden(
        bytes32 _sourceId,
        string calldata _address
    )
        external view
        returns (bool);

    /**
     * Whether the address is on the EVM list, forbidden on every EVM chain.
     * @param _address The address.
     */
    function isForbiddenEvmAddress(
        address _address
    )
        external view
        returns (bool);

    /**
     * Whether `_address` is a valid address of the source's chain on the deployment's network, in the canonical form
     * the source's list holds — the only form that can match an entry: Bitcoin Base58 as written and Bech32 in
     * lowercase (regtest on a Local deployment); XRPL a classic `r…` address. False for a malformed
     * address; reverts `UnsupportedSourceId` for a source the list holds no string list under, so a wrong id is a
     * configuration error, not a user's.
     * @param _sourceId The source.
     * @param _address The address.
     */
    function isCanonicalAddress(
        bytes32 _sourceId,
        string calldata _address
    )
        external view
        returns (bool);

    /**
     * Returns a page of a source's address hashes.
     * @param _sourceId The source.
     * @param _start The index of the first entry (an index at or past the end returns an empty page).
     * @param _count The most entries to return.
     * @return _hashes The hashes, `keccak256(bytes(address))`.
     * @return _totalCount How many addresses the source's list holds.
     * @return _version The source's version; pages read under one version are one consistent list.
     */
    function getForbiddenAddressHashes(
        bytes32 _sourceId,
        uint256 _start,
        uint256 _count
    )
        external view
        returns (
            bytes32[] memory _hashes,
            uint256 _totalCount,
            uint64 _version
        );

    /**
     * Returns a page of a source's addresses, at the same indices as `getForbiddenAddressHashes`.
     * @param _sourceId The source.
     * @param _start The index of the first entry (an index at or past the end returns an empty page).
     * @param _count The most entries to return.
     * @return _addresses The addresses, as they were added.
     * @return _totalCount How many addresses the source's list holds.
     * @return _version The source's version; pages read under one version are one consistent list.
     */
    function getForbiddenAddresses(
        bytes32 _sourceId,
        uint256 _start,
        uint256 _count
    )
        external view
        returns (
            string[] memory _addresses,
            uint256 _totalCount,
            uint64 _version
        );

    /**
     * Returns a page of the EVM list.
     * @param _start The index of the first entry (an index at or past the end returns an empty page).
     * @param _count The most entries to return.
     * @return _addresses The addresses.
     * @return _totalCount How many addresses the EVM list holds.
     * @return _version The EVM list's version; pages read under one version are one consistent list.
     */
    function getForbiddenEvmAddresses(
        uint256 _start,
        uint256 _count
    )
        external view
        returns (
            address[] memory _addresses,
            uint256 _totalCount,
            uint64 _version
        );

    /**
     * The version of the source's list, raised by every call that changes it (zero until the first addition). A reader
     * that keeps a copy of the list re-reads it only when the version moved.
     * @param _sourceId The source.
     */
    function getVersion(
        bytes32 _sourceId
    )
        external view
        returns (uint64 _version);

    /**
     * The block timestamp of the last call that added an address to the source's list; zero if none has. A call
     * that only repeats listed addresses does not move it, and neither does a removal: a removal never makes a clean
     * verdict wrong. A consumer of a verdict computed from the list — an FDC2 proof about that source — compares the
     * proof's `header.timestamp` with it: a proof attested before the last addition (plus the verifiers' read lag)
     * may not know the addition.
     * @param _sourceId The source.
     */
    function lastAdditionTimestamp(
        bytes32 _sourceId
    )
        external view
        returns (uint64);

    /**
     * The version of the EVM list, raised by every call that changes it (zero until the first addition).
     */
    function getEvmVersion()
        external view
        returns (uint64 _version);

    /**
     * The block timestamp of the last call that added an address to the EVM list; zero if none has. As
     * `lastAdditionTimestamp`, for a verdict computed from the EVM list — an FDC2 proof about an EVM source.
     */
    function lastEvmAdditionTimestamp()
        external view
        returns (uint64);

    /**
     * The source's personal account provider, whose Personal Account of every newly added address is listed on the EVM
     * list; zero for none.
     * @param _sourceId The source (`UnsupportedSourceId` unless the list holds one under it).
     */
    function getPersonalAccountProvider(
        bytes32 _sourceId
    )
        external view
        returns (address);

    /**
     * The external network this deployment's lists serve: which address network a Bitcoin address must be of, and
     * which kind of source id is supported.
     */
    function getNetwork()
        external view
        returns (IExternalNetwork.Network);

    /**
     * Whether the address is a maintainer, one of the addresses besides governance that may add addresses to any
     * list.
     * @param _address The address.
     */
    function isMaintainer(
        address _address
    )
        external view
        returns (bool);

    /**
     * Returns the maintainers.
     */
    function getMaintainers()
        external view
        returns (address[] memory _maintainers);
}
