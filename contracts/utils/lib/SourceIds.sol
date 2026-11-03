// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IExternalNetwork } from "../../userInterfaces/IExternalNetwork.sol";

/**
 * @title SourceIds
 * @notice The FDC's source-id convention: a test network's source id is its mainnet id with a `test` prefix
 *         (`BTC` / `testBTC`, `XRP` / `testXRP`, `DOGE` / `testDOGE`, `FLR` / `testFLR`, …). An id serves the kind of
 *         network it names, because the FDC attests under that id there: a source registered under the other kind
 *         would never receive a proof. A Local deployment admits both kinds, since a local environment stands in for
 *         either (the simulation runs regtest Bitcoin under `BTC`).
 */
library SourceIds {

    bytes4 internal constant TEST_PREFIX = "test";

    /**
     * Whether `_sourceId` names a test network's source: it starts with `test`.
     */
    function isTestId(
        bytes32 _sourceId
    )
        internal pure
        returns (bool)
    {
        return bytes4(_sourceId) == TEST_PREFIX;
    }

    /**
     * Whether `_sourceId` may serve a deployment of `_network`: a mainnet id only Mainnet, a test id only Testnet,
     * and either on Local.
     */
    function fitsNetwork(
        bytes32 _sourceId,
        IExternalNetwork.Network _network
    )
        internal pure
        returns (bool)
    {
        if (_network == IExternalNetwork.Network.Local) {
            return true;
        }
        return isTestId(_sourceId) == (_network == IExternalNetwork.Network.Testnet);
    }

    /**
     * The mainnet id of the chain `_sourceId` names: the id without its `test` prefix (`testBTC` -> `BTC`), or the
     * id itself.
     */
    function mainnetId(
        bytes32 _sourceId
    )
        internal pure
        returns (bytes32)
    {
        return isTestId(_sourceId) ? _sourceId << 32 : _sourceId;
    }
}
