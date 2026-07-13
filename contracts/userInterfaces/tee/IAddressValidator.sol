// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * IAddressValidator interface.
 *
 * Validates external-chain payout address strings on-chain, per source. Each `sourceId` is mapped by
 * governance to a `{chainKind, network}` profile; `isValidAddress` then runs the matching chain
 * validator (Bitcoin / Dogecoin / XRPL / EVM) against the address. Validation is boolean only — no
 * address is decoded or returned.
 *
 * Fail-closed: an unconfigured `sourceId` is always invalid (tracked by the `configured` flag), so
 * governance must configure every active source before payments to it can pass validation.
 *
 * Discoverable via the AddressUpdater by the name `"AddressValidator"`.
 */
interface IAddressValidator {

    enum ChainKind {
        Bitcoin,
        Dogecoin,
        Xrpl,
        Evm
    }

    enum Network {
        Mainnet,
        Testnet,
        Regtest
    }

    /// Per-source validation profile.
    struct SourceConfig {
        bytes32 sourceId;
        ChainKind chainKind;
        Network network;
    }

    event SourceConfigSet(bytes32 indexed sourceId, ChainKind chainKind, Network network);

    error EmptyArray();

    /**
     * Returns whether `_address` is a valid payout address for the chain/network configured for
     * `_sourceId`. Returns false for an unconfigured source. Never reverts.
     * @param _sourceId The source id whose configured chain/network the address is validated against.
     * @param _address The address string to validate.
     * @return _valid True iff the address is valid for the configured chain and network.
     */
    function isValidAddress(
        bytes32 _sourceId,
        string calldata _address
    )
        external view
        returns (bool _valid);

    /**
     * Returns the configured validation profile for `_sourceId`.
     * @param _sourceId The source id.
     * @return _chainKind The configured chain kind (meaningful only when `_configured` is true).
     * @return _network The configured network.
     * @return _configured Whether a profile has been set for this source.
     */
    function getSourceConfig(
        bytes32 _sourceId
    )
        external view
        returns (
            ChainKind _chainKind,
            Network _network,
            bool _configured
        );
}
