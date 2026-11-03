// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { Vm } from "forge-std/Vm.sol";

/**
 * The network a TEE deploy script runs on, one resolver for every script (TeeDeployBase and the scripts on it,
 * SwitchTeeToProduction, ExecuteDiamondCut, DeployTeeOracle). The operator names the network — the deploy wrappers
 * set `DEPLOY_NETWORK` from their `<network>` argument, a direct `forge script` call sets it by hand — and the RPC's
 * chain id must agree: flare (14), songbird (19), coston (16) and coston2 (114) are known by their ids, and any other
 * id is accepted only as `scdev`, a local node, whose id is not fixed. Everything a script reads by the network's
 * name — its chain profile, the deployment record, a WalletPayments diamond's permanent external network — therefore
 * follows the chain it really talks to, and a mistyped network or an RPC pointing at another chain stops the run
 * before anything is simulated.
 */
library DeployNetwork {

    string internal constant SCDEV = "scdev";

    Vm private constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /**
     * The network named by `DEPLOY_NETWORK`, checked against the RPC's chain id (`check`).
     */
    function resolve()
        internal view
        returns (string memory)
    {
        return check(VM.envOr("DEPLOY_NETWORK", string("")), block.chainid);
    }

    /**
     * `_requested` if it is the network chain id `_chainId` belongs to. Reverts when it is empty (the variable was
     * not set), when a known chain id names another network, and when an unknown chain id is named anything but
     * `scdev`.
     */
    function check(
        string memory _requested,
        uint256 _chainId
    )
        internal pure
        returns (string memory)
    {
        require(
            bytes(_requested).length > 0,
            string.concat(
                "DEPLOY_NETWORK is not set: run the deploy wrapper with the network, ",
                "or set it to the network the RPC serves"
            )
        );
        string memory known = knownNetwork(_chainId);
        if (bytes(known).length > 0) {
            require(
                _equal(_requested, known),
                string.concat("the RPC serves ", known, " (chain id ", VM.toString(_chainId), "), not ", _requested)
            );
        } else {
            require(
                _equal(_requested, SCDEV),
                string.concat(
                    "unknown chain id ", VM.toString(_chainId),
                    ": only scdev runs on a chain other than flare, songbird, coston or coston2, not ", _requested
                )
            );
        }
        return _requested;
    }

    /**
     * The network a chain id belongs to — flare, songbird, coston or coston2 — or empty for any other id.
     */
    function knownNetwork(
        uint256 _chainId
    )
        internal pure
        returns (string memory)
    {
        if (_chainId == 14) return "flare";
        if (_chainId == 19) return "songbird";
        if (_chainId == 16) return "coston";
        if (_chainId == 114) return "coston2";
        return "";
    }

    function _equal(
        string memory _a,
        string memory _b
    )
        private pure
        returns (bool)
    {
        return keccak256(bytes(_a)) == keccak256(bytes(_b));
    }
}
