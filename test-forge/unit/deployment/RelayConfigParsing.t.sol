// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Test} from "forge-std/Test.sol";

/**
 * Verifies the committed per-source relay configs parse via the exact JSON key paths the deploy
 * scripts use (`.home.*`, `.expectedDeployer`, and `.mirrors["<name>"].*` incl. hyphenated names
 * and the nested feeConfigs/feeExemptAddresses arrays). Guards against a config/script key-path
 * drift that the JSON schema alone cannot catch.
 */
contract RelayConfigParsingTest is Test {
    function _read(string memory _network) internal view returns (string memory) {
        return vm.readFile(string.concat("deployment/chain-config/relay/", _network, ".json"));
    }

    function test_homeConfigKeyPathsParse() public view {
        string memory cfg = _read("flare");
        assertTrue(vm.keyExistsJson(cfg, ".expectedDeployer"));
        assertTrue(vm.keyExistsJson(cfg, ".home"));
        // Home carries ONLY the owner-timelock duration; epoch/protocol params are read from the
        // currently deployed Relay's stateData() at deploy time, and the initial signing-policy
        // hash is always reconstructed from chain state — neither lives in the config.
        vm.parseJsonUint(cfg, ".home.timelockDurationSeconds");
        assertFalse(vm.keyExistsJson(cfg, ".home.oldRelayPolicyHashScheme"));
        assertFalse(vm.keyExistsJson(cfg, ".home.randomNumberProtocolId"));
        assertFalse(vm.keyExistsJson(cfg, ".home.rewardEpochDurationInVotingEpochs"));
        assertFalse(vm.keyExistsJson(cfg, ".home.messageFinalizationWindowInRewardEpochs"));
    }

    function test_mirrorEntryKeyPathsParse() public view {
        string memory cfg = _read("flare");
        string memory base = ".mirrors[\"arbitrum\"]";
        assertTrue(vm.keyExistsJson(cfg, base));
        assertEq(vm.parseJsonUint(cfg, string.concat(base, ".chainId")), 42161);
        // required address + scalar + array fields parse (placeholders: zero address / empty arrays)
        vm.parseJsonAddress(cfg, string.concat(base, ".relayOwner"));
        vm.parseJsonAddress(cfg, string.concat(base, ".feeCollectionAddress"));
        vm.parseJsonUint(cfg, string.concat(base, ".timelockDurationSeconds"));
        assertEq(vm.parseJsonAddressArray(cfg, string.concat(base, ".feeExemptAddresses")).length, 0);
        // feeToken is REQUIRED — an explicit zero address means native-coin fees, so a
        // missing key can never silently select a payment medium.
        assertEq(vm.parseJsonAddress(cfg, string.concat(base, ".feeToken")), address(0));
    }

    function test_hyphenatedMirrorNameParsesViaBracketKey() public view {
        // coston2 carries a hyphenated mirror name; the deploy script bracket-quotes the key.
        string memory cfg = _read("coston2");
        string memory base = ".mirrors[\"arbitrum-sepolia\"]";
        assertTrue(vm.keyExistsJson(cfg, base));
        assertEq(vm.parseJsonUint(cfg, string.concat(base, ".chainId")), 421614);
    }

    function test_homeOnlyConfigsHaveNoMirrors() public view {
        assertFalse(vm.keyExistsJson(_read("songbird"), ".mirrors"));
        assertFalse(vm.keyExistsJson(_read("coston"), ".mirrors"));
    }
}
