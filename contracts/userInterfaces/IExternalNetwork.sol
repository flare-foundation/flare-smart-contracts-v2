// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

/**
 * IExternalNetwork interface — the network of the external chains a deployment serves.
 *
 * A contract that validates or screens addresses of external chains (Bitcoin, XRPL, EVM chains) serves one such
 * network for its whole deployment, set once when it is deployed: flare and songbird serve `Mainnet`, the costons
 * `Testnet`, a local deployment (scdev, the simulation) `Local`. The FDC source id names the chain; the network
 * decides which of its address networks is valid and which kind of source id the deployment supports
 * (`SourceIds.fitsNetwork`).
 */
interface IExternalNetwork {

    /// `Local` is resolved by each chain to its supported local or non-mainnet domain (for example Bitcoin regtest,
    /// XRPL's test-network address bit, or an EVM local chain). A new network is appended, so the existing ones keep
    /// their numbers.
    enum Network {
        Mainnet,
        Testnet,
        Local
    }
}
