// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { Relay } from "../../contracts/protocol/implementation/Relay.sol";
import { RelayProxy } from "../../contracts/protocol/implementation/RelayProxy.sol";
import { IRelay } from "../../contracts/userInterfaces/IRelay.sol";

// Per-chain owner placeholder (Relay's owner-timelock governance and upgrade authority)
// used by tests that do not exercise owner actions.
address constant RELAY_TEST_GOVERNANCE = address(uint160(uint256(keccak256("relay.test.governance"))));

// Drop-in replacement for the pre-proxy `new Relay(config, setter, oldRelay)`:
// deploys an implementation + RelayProxy and returns the proxied handle.
function deployRelay(
    IRelay.RelayInitialConfig memory config,
    address signingPolicySetter,
    IRelay oldRelay
) returns (Relay) {
    return deployRelayWithOwner(config, signingPolicySetter, oldRelay, RELAY_TEST_GOVERNANCE);
}

function deployRelayWithOwner(
    IRelay.RelayInitialConfig memory config,
    address signingPolicySetter,
    IRelay oldRelay,
    address initialOwner
) returns (Relay) {
    Relay implementation = new Relay();
    return Relay(
        address(new RelayProxy(address(implementation), config, signingPolicySetter, oldRelay, initialOwner))
    );
}
