// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { Relay } from "../../contracts/protocol/implementation/Relay.sol";
import { RelayProxy } from "../../contracts/protocol/implementation/RelayProxy.sol";
import { IRelay } from "../../contracts/userInterfaces/IRelay.sol";
import { ISafeGovernance } from "../../contracts/userInterfaces/ISafeGovernance.sol";

// Per-chain owner placeholder (Relay's OZ Ownable upgrade authority) used by tests that
// do not exercise upgrades.
address constant RELAY_TEST_GOVERNANCE = address(uint160(uint256(keccak256("relay.test.governance"))));

// Safe placeholders for fixtures that do not exercise governance actions.
address constant RELAY_TEST_SAFE = address(uint160(uint256(keccak256("relay.test.safe"))));
address constant RELAY_TEST_SAFE_OWNER = address(uint160(uint256(keccak256("relay.test.safe.owner"))));

// Minimal valid Safe governance block (governance is mandatory on every deployment): the
// single owner has no known private key, so processSafeMessage can never verify — inert.
function testGovernanceConfig(uint256 sourceChainId) pure returns (ISafeGovernance.GovernanceConfig memory g) {
    g.sourceChainId = sourceChainId;
    g.safe = RELAY_TEST_SAFE;
    g.threshold = 1;
    g.owners = new address[](1);
    g.owners[0] = RELAY_TEST_SAFE_OWNER;
}

// Drop-in replacement for the pre-proxy `new Relay(config, setter, oldRelay)`:
// deploys an implementation + RelayProxy and returns the proxied handle.
function deployRelay(
    IRelay.RelayInitialConfig memory config,
    address signingPolicySetter,
    IRelay oldRelay
) returns (Relay) {
    return deployRelayWithGovernance(config, signingPolicySetter, oldRelay, RELAY_TEST_GOVERNANCE);
}

function deployRelayWithGovernance(
    IRelay.RelayInitialConfig memory config,
    address signingPolicySetter,
    IRelay oldRelay,
    address initialGovernance
) returns (Relay) {
    Relay implementation = new Relay();
    return Relay(
        address(new RelayProxy(address(implementation), config, signingPolicySetter, oldRelay, initialGovernance))
    );
}
