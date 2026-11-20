// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { Test } from "forge-std/Test.sol";
import { SourceIds } from "../../../../contracts/utils/lib/SourceIds.sol";
import { IExternalNetwork } from "../../../../contracts/userInterfaces/IExternalNetwork.sol";

contract SourceIdsTest is Test {

    function testIsTestId() public pure {
        assertTrue(SourceIds.isTestId("testBTC"));
        assertTrue(SourceIds.isTestId("testXRP"));
        assertFalse(SourceIds.isTestId("BTC"));
        assertFalse(SourceIds.isTestId("tesBTC"));
        assertFalse(SourceIds.isTestId("TESTBTC"), "the prefix is lowercase, as the FDC writes it");
        assertFalse(SourceIds.isTestId(bytes32(0)));
    }

    /// A mainnet id serves only Mainnet, a test id only Testnet; Local takes both.
    function testFitsNetwork() public pure {
        assertTrue(SourceIds.fitsNetwork("BTC", IExternalNetwork.Network.Mainnet));
        assertFalse(SourceIds.fitsNetwork("testBTC", IExternalNetwork.Network.Mainnet));
        assertTrue(SourceIds.fitsNetwork("testBTC", IExternalNetwork.Network.Testnet));
        assertFalse(SourceIds.fitsNetwork("BTC", IExternalNetwork.Network.Testnet));
        assertTrue(SourceIds.fitsNetwork("BTC", IExternalNetwork.Network.Local));
        assertTrue(SourceIds.fitsNetwork("testBTC", IExternalNetwork.Network.Local));
    }

    function testMainnetId() public pure {
        assertEq(SourceIds.mainnetId("testBTC"), bytes32("BTC"));
        assertEq(SourceIds.mainnetId("testDOGE"), bytes32("DOGE"));
        assertEq(SourceIds.mainnetId("XRP"), bytes32("XRP"));
    }
}
