// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;
// solhint-disable no-console

import {console2} from "forge-std/Script.sol";
import {RelayDeployBase} from "./RelayDeployBase.s.sol";

// Idempotent deployment of the canonical Create3Factory on the current chain.
//
// The factory is deployed through the keyless CREATE2 deployer (Arachnid) from the FROZEN
// initcode committed at deployment/create3/Create3Factory.initcode.hex — never from a fresh
// compile — so it lands at the same address on every chain, present and future. Safe to run
// by anyone at any time: if the factory already has code the script is a no-op, and a
// front-run deployment is harmless (byte-identical, stateless, permissionless).
//
// Usage (per target chain):
//   forge script deployment/scripts/relay/DeployCreate3Factory.s.sol:DeployCreate3Factory \
//     --rpc-url $TARGET_RPC --broadcast
//
// Signs with whatever forge is given (any signer flag, or the wrapper's DEPLOYER_PRIVATE_KEY
// fallback). Any funded account works: the factory address is deployer-independent, so — unlike
// home/mirror — no expectedDeployer or address-pin check applies to the sender here; the frozen
// initcode and the codehash pins carry all the guarantees instead.
contract DeployCreate3Factory is RelayDeployBase {

    function run() external {
        bytes memory initCode = _frozenFactoryInitCode();
        address factory = _factoryAddress();
        // Exact "NETWORK: <label>" line consumed by save-deployed-addresses.ts.
        console2.log(string.concat("NETWORK: ", _configLabel()));
        console2.log("Canonical Create3Factory address:", factory);

        if (factory.code.length > 0) {
            // Someone (us or a third party) already deployed it — accept only the exact runtime
            // code the frozen initcode produces.
            require(
                factory.codehash == FACTORY_RUNTIME_CODEHASH,
                "code at the canonical Create3Factory address does not match the pinned runtime codehash"
            );
            console2.log("Create3Factory already deployed - nothing to do");
            return;
        }
        require(
            ARACHNID_CREATE2_DEPLOYER.code.length > 0,
            "canonical CREATE2 deployer missing on this chain; broadcast its presigned deployment first"
        );
        // A chain carrying DIFFERENT code at the well-known Arachnid address is not a genuine
        // keyless deployment — it could deploy anything (or nothing) at the predicted address.
        require(
            ARACHNID_CREATE2_DEPLOYER.codehash == ARACHNID_DEPLOYER_CODEHASH,
            "no genuine keyless CREATE2 deployer on this chain (runtime codehash mismatch)"
        );

        vm.startBroadcast(msg.sender);
        // Raw Arachnid call: salt || initcode. Reverts if another party deployed in between,
        // which is fine — the code check below is the source of truth.
        (bool success, ) = ARACHNID_CREATE2_DEPLOYER.call(abi.encodePacked(FACTORY_CREATE2_SALT, initCode));
        vm.stopBroadcast();

        require(success, "Create3Factory deployment through the CREATE2 deployer failed");
        require(factory.code.length > 0, "Create3Factory has no code after deployment");
        require(
            factory.codehash == FACTORY_RUNTIME_CODEHASH,
            "deployed Create3Factory runtime code does not match the pinned runtime codehash"
        );
        _logDeployed("Create3Factory", "Create3Factory.sol", factory);
    }
}
