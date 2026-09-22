// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;
// solhint-disable no-console

import {Script, console2} from "forge-std/Script.sol";
// FDC2 implementations
import {Fdc2Hub} from "../../contracts/fdc2/implementation/Fdc2Hub.sol";
import {Fdc2Verification} from "../../contracts/fdc2/implementation/Fdc2Verification.sol";
import {Fdc2RequestFeeConfigurations} from
    "../../contracts/fdc2/implementation/Fdc2RequestFeeConfigurations.sol";
import {Fdc2InflationConfigurations} from
    "../../contracts/fdc2/implementation/Fdc2InflationConfigurations.sol";
import {Fdc2RewardOffersManager} from
    "../../contracts/fdc2/implementation/Fdc2RewardOffersManager.sol";
// TEE implementations
import {TeePayments} from "../../contracts/tee/implementation/TeePayments.sol";
import {TeePaymentsRegistry} from "../../contracts/tee/implementation/TeePaymentsRegistry.sol";
import {TeePaymentsConfigVerifier} from
    "../../contracts/tee/implementation/TeePaymentsConfigVerifier.sol";
import {TeePaymentsFeeScheduleManager} from
    "../../contracts/tee/implementation/TeePaymentsFeeScheduleManager.sol";
import {TeeRewardOffersManager} from
    "../../contracts/tee/implementation/TeeRewardOffersManager.sol";
import {VrfVerifier} from "../../contracts/tee/implementation/VrfVerifier.sol";

/// The FlareUpgradeableBase surface the upgrade needs: UUPS upgrade entry (an
/// `onlyGovernance` method — pre-production it executes immediately when called by the
/// governance address) plus the views the preflight checks read.
interface IUpgradeableGoverned {
    function upgradeToAndCall(
        address _newImplementation,
        bytes memory _data
    )
        external payable;

    function implementation()
        external view
        returns (address);

    function productionMode()
        external view
        returns (bool);

    function governance()
        external view
        returns (address);
}

// Upgrades every non-diamond TEE / FDC2 UUPS proxy to a freshly deployed implementation and
// redeploys the standalone VrfVerifier, in one run. The diamond facets are NOT handled here —
// they have their own cut mechanism (build-cut / ExecuteTeeManagerDiamondCut).
//
// Proxy addresses are read from deployment/deploys/<network>.json by registry name; the new
// implementation addresses are emitted as the standard "DEPLOYED: <Name>Implementation, ..."
// log lines, so piping the broadcast output through save-deployed-addresses.ts REPLACES the
// old implementation entries in deploys/<network>.json (and appends to deploys/all/).
//
// PRE-PRODUCTION ONLY: every proxy must still be in non-production mode with the broadcast
// key as its governance — both are checked before anything signs. Once a network switches to
// production mode, upgrades go through the governance timelock instead and this script
// refuses to run.
//
// Usage — prefer the wrapper (dry run unless --broadcast):
//   deployment/scripts/upgrade-tee-implementations.sh coston [--broadcast]
contract UpgradeTeeImplementations is Script {

    // stdJson parses struct fields in alphabetical order of JSON keys: address, contractName, name.
    struct DeployedContract {
        address addr;
        string contractName;
        string name;
    }

    uint256 internal constant N_PROXIES = 10;

    address internal deployer;

    string[N_PROXIES] internal proxyNames = [
        "Fdc2Hub",
        "Fdc2Verification",
        "Fdc2RequestFeeConfigurations",
        "Fdc2InflationConfigurations",
        "Fdc2RewardOffersManager",
        "TeePayments",
        "TeePaymentsRegistry",
        "TeePaymentsConfigVerifier",
        "TeePaymentsFeeScheduleManager",
        "TeeRewardOffersManager"
    ];

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        string memory network = _resolveNetwork();
        // Exact "NETWORK: <label>" line consumed by save-deployed-addresses.ts.
        console2.log(string.concat("NETWORK: ", network));
        console2.log("TEE/FDC2 implementation upgrade; deployer:", deployer);

        DeployedContract[] memory deployed = _readDeploysFile(network);
        address[N_PROXIES] memory proxies;
        for (uint256 i = 0; i < N_PROXIES; i++) {
            proxies[i] = _findDeployedAddress(deployed, proxyNames[i]);
            _preflight(proxyNames[i], proxies[i]);
        }

        vm.startBroadcast();

        address[N_PROXIES] memory impls;
        impls[0] = address(new Fdc2Hub());
        impls[1] = address(new Fdc2Verification());
        impls[2] = address(new Fdc2RequestFeeConfigurations());
        impls[3] = address(new Fdc2InflationConfigurations());
        impls[4] = address(new Fdc2RewardOffersManager());
        impls[5] = address(new TeePayments());
        impls[6] = address(new TeePaymentsRegistry());
        impls[7] = address(new TeePaymentsConfigVerifier());
        impls[8] = address(new TeePaymentsFeeScheduleManager());
        impls[9] = address(new TeeRewardOffersManager());

        for (uint256 i = 0; i < N_PROXIES; i++) {
            _upgrade(proxyNames[i], proxies[i], impls[i]);
        }

        // Standalone (non-proxy) contract: fresh deployment replaces the registry entry;
        // nothing on-chain points at it, so no re-wiring call is needed.
        VrfVerifier vrfVerifier = new VrfVerifier();
        _logDeployed("VrfVerifier", "VrfVerifier.sol", address(vrfVerifier));

        vm.stopBroadcast();

        for (uint256 i = 0; i < N_PROXIES; i++) {
            require(
                IUpgradeableGoverned(proxies[i]).implementation() == impls[i],
                string.concat("verify: implementation not switched on ", proxyNames[i])
            );
        }
        console2.log("All proxies upgraded and verified.");
    }

    function _upgrade(
        string memory _name,
        address _proxy,
        address _newImplementation
    )
        internal
    {
        address oldImplementation = IUpgradeableGoverned(_proxy).implementation();
        IUpgradeableGoverned(_proxy).upgradeToAndCall(_newImplementation, "");
        console2.log(string.concat("Upgraded ", _name, ":"));
        console2.log("  old implementation:", oldImplementation);
        console2.log("  new implementation:", _newImplementation);
        _logDeployed(
            string.concat(_name, "Implementation"),
            string.concat(_name, ".sol"),
            _newImplementation
        );
    }

    /**
     * Deploy-time invariants, checked BEFORE anything signs: the proxy is still in
     * non-production mode (otherwise `upgradeToAndCall` would be recorded as a timelocked
     * governance call instead of executing) and the broadcast key is its governance.
     */
    function _preflight(
        string memory _name,
        address _proxy
    )
        internal view
    {
        require(_proxy.code.length > 0, string.concat("no code at proxy ", _name));
        IUpgradeableGoverned proxy = IUpgradeableGoverned(_proxy);
        require(
            !proxy.productionMode(),
            string.concat(_name, " is in production mode - upgrades must go through the timelock")
        );
        require(
            proxy.governance() == deployer,
            string.concat(_name, ": deployer is not the governance address")
        );
    }

    function _readDeploysFile(
        string memory _network
    )
        internal view
        returns (DeployedContract[] memory)
    {
        string memory deploysFile = string.concat("deployment/deploys/", _network, ".json");
        return abi.decode(vm.parseJson(vm.readFile(deploysFile)), (DeployedContract[]));
    }

    function _resolveNetwork()
        internal view
        returns (string memory)
    {
        uint256 chainId = block.chainid;
        if (chainId == 14) return "flare";
        if (chainId == 19) return "songbird";
        if (chainId == 16) return "coston";
        if (chainId == 114) return "coston2";
        return "scdev";
    }

    function _findDeployedAddress(
        DeployedContract[] memory _contracts,
        string memory _name
    )
        internal pure
        returns (address)
    {
        bytes32 nameHash = keccak256(bytes(_name));
        for (uint256 i = 0; i < _contracts.length; i++) {
            if (keccak256(bytes(_contracts[i].name)) == nameHash) {
                return _contracts[i].addr;
            }
        }
        revert(string.concat("contract not found in deploys file: ", _name));
    }

    function _logDeployed(
        string memory _name,
        string memory _contractName,
        address _addr
    )
        internal pure
    {
        console2.log(
            string.concat("DEPLOYED: ", _name, ", ", _contractName, ": ", vm.toString(_addr))
        );
    }
}
