// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IRelay } from "../../userInterfaces/IRelay.sol";
import { Relay } from "./Relay.sol";

/**
 * The Relay UUPS proxy. `initialize` runs inside this constructor, so deploy + full
 * configuration (including the per-chain owner) is one atomic transaction — deployed
 * through the Create3Factory the proxy address is chain-invariant and never observable in
 * an uninitialized state.
 */
contract RelayProxy is ERC1967Proxy {
    constructor(
        address _implementationAddress,
        IRelay.RelayInitialConfig memory _initialConfig,
        address _signingPolicySetter,
        IRelay _oldRelay,
        address _initialOwner
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                Relay.initialize,
                (_initialConfig, _signingPolicySetter, _oldRelay, _initialOwner)
            )
        )
    { }
}
