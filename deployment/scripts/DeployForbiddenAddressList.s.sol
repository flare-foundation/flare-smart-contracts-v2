// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;
// solhint-disable no-console

import {Script, console2} from "forge-std/Script.sol";
import {IGovernanceSettings} from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import {IFlareContractRegistry} from "@flarenetwork/flare-periphery-contracts/flare/IFlareContractRegistry.sol";
import {IIAddressUpdater} from
    "@flarenetwork/flare-periphery-contracts/flare/addressUpdater/interfaces/IIAddressUpdater.sol";
import {ForbiddenAddressList} from "../../contracts/compliance/implementation/ForbiddenAddressList.sol";
import {ForbiddenAddressListProxy} from "../../contracts/compliance/proxy/ForbiddenAddressListProxy.sol";
import {IIFlareGovernance} from "../../contracts/governance/interface/IIFlareGovernance.sol";
import {IPersonalAccountProvider} from "../../contracts/userInterfaces/IPersonalAccountProvider.sol";
import {IExternalNetwork} from "../../contracts/userInterfaces/IExternalNetwork.sol";
import {AddressUpdatable} from "../../contracts/utils/implementation/AddressUpdatable.sol";
import {DeployNetwork} from "./lib/DeployNetwork.sol";

// solhint-disable-next-line max-line-length
// forge script deployment/scripts/DeployForbiddenAddressList.s.sol:DeployForbiddenAddressList --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast --sig "run()"

/**
 * Deploys the ForbiddenAddressList (one UUPS proxy per network) and loads its initial contents:
 * - the maintainers from the chain profile (`forbiddenAddressListMaintainers`);
 * - the Personal Account providers from the chain profile (`forbiddenAddressListPersonalAccountProviders`), set before
 *   anything is loaded, so the initial contents list the Personal Accounts of the sources' addresses too;
 * - for each source the profile names (`forbiddenAddressListSources`), every address the shared
 *   deployment/chain-config/forbidden-addresses.json lists for it, in batches of `BATCH_SIZE` —
 *   one transaction per batch — and, where the source has a provider, the Personal Account of each on the EVM list.
 *   The file is one for every network: each group of addresses names the sources it applies to, so an address
 *   forbidden on several chains is written once;
 * - on every network, the file's `evmAddresses` into the EVM list, which covers every EVM chain, in batches of
 *   `BATCH_SIZE` too.
 * The list is initialised with the network of the chains it screens (`_externalChainEnvironment`: flare and songbird
 * mainnet, the costons testnet, scdev local, where Bitcoin is regtest), so each profile names source ids of that kind
 * (`forbiddenAddressListSources`) and the data file's addresses must be of that network.
 * The deployer is the list's initial governance, so outside production mode its additions execute at once. The script
 * then hands the address updater role to the AddressUpdater and publishes the name `ForbiddenAddressList` on it —
 * directly when the deployer governs the AddressUpdater, printed as governance calldata otherwise. Switching the list
 * to production mode is the separate `switchToProduction()` step; from then on removals go through governance with its
 * timelock, and additions through a maintainer.
 */
contract DeployForbiddenAddressList is Script {
    struct DeployedContract {
        address addr;
        string contractName;
        string name;
    }

    struct PersonalAccountProvider {
        bytes32 sourceId;
        address provider;
    }

    // Well-known FlareContractRegistry address (same on all Flare networks)
    IFlareContractRegistry internal constant FLARE_CONTRACT_REGISTRY =
        IFlareContractRegistry(0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019);
    string internal constant CONTRACT_NAME = "ForbiddenAddressList";
    string internal constant FORBIDDEN_ADDRESSES_FILE = "deployment/chain-config/forbidden-addresses.json";
    /// The addresses one transaction adds: about 14M gas for 100 of the longest Bitcoin addresses, half a Flare block
    /// (28M); about 20M with a Personal Account derived and listed for each.
    uint256 internal constant BATCH_SIZE = 100;
    // The AddressUpdater is a legacy Governed contract: its timelock keeps one pending call per function, so a second
    // call to the same function recorded before the first executes replaces it.
    string internal constant LEGACY_TIMELOCK_NOTE =
        "  the contract keeps ONE pending timelocked call per function: execute this call before another call to the "
        "same function is recorded (or merge both into one), else the later one silently replaces it";

    address internal deployer;
    address internal governanceSettings;
    address internal addressUpdater;
    string internal network;
    string internal config;

    ForbiddenAddressList internal list;

    function run() external {
        DeployedContract[] memory deployed = _setUp();
        address existing = _findDeployedAddress(deployed, CONTRACT_NAME);
        require(
            existing == address(0) || existing.code.length == 0,
            string.concat(CONTRACT_NAME, " already deployed at ", vm.toString(existing))
        );
        address[] memory maintainers = vm.parseJsonAddressArray(config, ".forbiddenAddressListMaintainers");
        string[] memory sources = _sources();
        PersonalAccountProvider[] memory providers = _personalAccountProviders();
        string memory data = vm.readFile(_forbiddenAddressesFile());

        vm.startBroadcast(deployer);
        ForbiddenAddressList implementation = new ForbiddenAddressList();
        // the deployer acts as initial governance and address updater; the wiring below hands the updater role to
        // the AddressUpdater, and the separate switchToProduction() step hands governance to GovernanceSettings
        list = ForbiddenAddressList(address(new ForbiddenAddressListProxy(
            IGovernanceSettings(governanceSettings), deployer, deployer, _externalChainEnvironment(),
            address(implementation)
        )));
        if (maintainers.length > 0) {
            list.addMaintainers(maintainers);
        }
        for (uint256 i = 0; i < providers.length; i++) {
            list.setPersonalAccountProvider(providers[i].sourceId, providers[i].provider);
        }
        for (uint256 i = 0; i < sources.length; i++) {
            _load(_toBytes32(sources[i]), sources[i], _addressesOf(data, sources[i]));
        }
        _loadEvm(
            vm.keyExistsJson(data, ".evmAddresses")
                ? vm.parseJsonAddressArray(data, ".evmAddresses")
                : new address[](0)
        );
        bytes32[] memory names = new bytes32[](1);
        names[0] = keccak256(abi.encode("AddressUpdater"));
        address[] memory addrs = new address[](1);
        addrs[0] = addressUpdater;
        list.updateContractAddresses(names, addrs);
        _publishAddressUpdaterName(CONTRACT_NAME, address(list));
        vm.stopBroadcast();

        require(
            AddressUpdatable(address(list)).getAddressUpdater() == addressUpdater,
            string.concat("address updater not handed over: ", vm.toString(address(list)))
        );
        _logDeployed("ForbiddenAddressListImplementation", "ForbiddenAddressList.sol", address(implementation));
        _logDeployed(CONTRACT_NAME, "ForbiddenAddressListProxy.sol", address(list));
        console2.log("Maintainers:", maintainers.length);
        console2.log("Personal Account providers:", providers.length);
        console2.log(
            "Switch to production mode with deploy-forbidden-address-list.sh <network> --switch-to-production."
        );
    }

    /// Switches the recorded list to production mode: from then on its governance is GovernanceSettings' and every
    /// governed call is timelocked. Kept separate from `run()`, so the contents can be checked while the deployer
    /// still governs. A list already in production is reported and left alone; one the deployer does not govern stops
    /// the run, since only its governance can switch it.
    function switchToProduction() external {
        address recorded = _findDeployedAddress(_setUp(), CONTRACT_NAME);
        require(recorded.code.length > 0, string.concat(CONTRACT_NAME, " is not deployed on ", network));
        IIFlareGovernance governed = IIFlareGovernance(recorded);
        if (governed.productionMode()) {
            console2.log(string.concat(CONTRACT_NAME, ": already in production mode"));
            return;
        }
        require(
            governed.governance() == deployer,
            string.concat(
                CONTRACT_NAME, " is governed by ", vm.toString(governed.governance()),
                ", not the deployer; only it can switch"
            )
        );
        vm.startBroadcast(deployer);
        governed.switchToProductionMode();
        vm.stopBroadcast();
        require(governed.productionMode(), string.concat(CONTRACT_NAME, ": still not in production mode"));
        console2.log(string.concat(CONTRACT_NAME, ": switched to production mode, governance now"),
            governed.governance());
    }

    /// The deployer, the network and its chain profile, the network's GovernanceSettings and AddressUpdater (from the
    /// deployment record on scdev, from the FlareContractRegistry elsewhere), and the network's deployment record.
    function _setUp()
        internal
        returns (DeployedContract[] memory _deployed)
    {
        deployer = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        network = DeployNetwork.resolve();
        console2.log(string.concat("NETWORK: ", network));
        config = vm.readFile(string.concat("deployment/chain-config/", network, ".json"));
        _deployed = _readDeploysFile(network);
        if (_isScdev()) {
            governanceSettings = _findDeployedAddress(_deployed, "GovernanceSettings");
            addressUpdater = _findDeployedAddress(_deployed, "AddressUpdater");
        } else {
            governanceSettings = FLARE_CONTRACT_REGISTRY.getContractAddressByName("GovernanceSettings");
            addressUpdater = FLARE_CONTRACT_REGISTRY.getContractAddressByName("AddressUpdater");
        }
        // a stale or foreign record (a local scdev.json, a wrong registry) names addresses this chain does not run
        require(
            governanceSettings.code.length > 0 && addressUpdater.code.length > 0,
            string.concat(
                "GovernanceSettings or AddressUpdater has no code on ", network, ": check the deployment record"
            )
        );
    }

    /// Publishes `_name` -> `_addr` on the AddressUpdater: directly (and read back) when the deployer governs it,
    /// printed as governance calldata otherwise. A name that already points at the address is skipped; one that points
    /// at ANOTHER address reverts — a deploy step never replaces a registry name, governance does, knowingly, on its
    /// own.
    function _publishAddressUpdaterName(
        string memory _name,
        address _addr
    )
        internal
    {
        address current = _addressUpdaterName(_name);
        if (current == _addr) {
            console2.log(string.concat("AddressUpdater name ", _name, " already points at"), _addr);
            return;
        }
        require(
            current == address(0),
            string.concat(
                "AddressUpdater name ", _name, " points at ", vm.toString(current), ", not ", vm.toString(_addr),
                ": a deploy step does not replace a registry name"
            )
        );
        string[] memory names = new string[](1);
        names[0] = _name;
        address[] memory addrs = new address[](1);
        addrs[0] = _addr;
        bytes memory updateCall = abi.encodeWithSignature(
            "update(string[],address[],address[])", names, addrs, new address[](0)
        );
        if (_deployerGoverns(addressUpdater)) {
            //solhint-disable-next-line avoid-low-level-calls
            (bool ok, ) = addressUpdater.call(updateCall);
            require(ok, "AddressUpdater.update failed");
            require(_addressUpdaterName(_name) == _addr, "AddressUpdater readback mismatch");
            console2.log(string.concat("AddressUpdater name ", _name, " published directly and verified"));
        } else {
            console2.log("AddressUpdater", addressUpdater);
            console2.log(string.concat("  ", _name, " ->"), _addr);
            console2.log(string.concat("  update(names, addresses, []): ", vm.toString(updateCall)));
            console2.log("AddressUpdater name PENDING governance");
            console2.log(LEGACY_TIMELOCK_NOTE);
        }
    }

    /// Logs a deployed contract in the format save-deployed-addresses.ts parses. Virtual so a test can capture what
    /// the script records.
    function _logDeployed(
        string memory _name,
        string memory _contractName,
        address _addr
    )
        internal virtual
    {
        console2.log(string.concat("DEPLOYED: ", _name, ", ", _contractName, ": ", vm.toString(_addr)));
    }

    /// Adds `_addresses` under `_sourceId`, `BATCH_SIZE` per call, and checks the list holds them all and, where the
    /// source has a Personal Account provider, the Personal Account of each.
    function _load(
        bytes32 _sourceId,
        string memory _source,
        string[] memory _addresses
    )
        internal
    {
        for (uint256 start = 0; start < _addresses.length; start += BATCH_SIZE) {
            uint256 end = start + BATCH_SIZE < _addresses.length ? start + BATCH_SIZE : _addresses.length;
            string[] memory batch = new string[](end - start);
            for (uint256 i = start; i < end; i++) {
                batch[i - start] = _addresses[i];
            }
            list.addForbiddenAddresses(_sourceId, batch);
        }
        (, uint256 total, uint64 version) = list.getForbiddenAddressHashes(_sourceId, 0, 0);
        address provider = list.getPersonalAccountProvider(_sourceId);
        for (uint256 i = 0; i < _addresses.length; i++) {
            require(
                list.isForbidden(_sourceId, _addresses[i]),
                string.concat(_source, ": not loaded: ", _addresses[i])
            );
            require(
                provider == address(0) || list.isForbiddenEvmAddress(
                    IPersonalAccountProvider(provider).getPersonalAccount(_addresses[i])
                ),
                string.concat(_source, ": Personal Account not listed: ", _addresses[i])
            );
        }
        console2.log(string.concat(
            _source, ": ", vm.toString(total), " forbidden addresses loaded, version ", vm.toString(uint256(version))
        ));
    }

    /// Adds `_addresses` to the EVM list, `BATCH_SIZE` per call, and checks the list holds them all.
    function _loadEvm(
        address[] memory _addresses
    )
        internal
    {
        for (uint256 start = 0; start < _addresses.length; start += BATCH_SIZE) {
            uint256 end = start + BATCH_SIZE < _addresses.length ? start + BATCH_SIZE : _addresses.length;
            address[] memory batch = new address[](end - start);
            for (uint256 i = start; i < end; i++) {
                batch[i - start] = _addresses[i];
            }
            list.addForbiddenEvmAddresses(batch);
        }
        for (uint256 i = 0; i < _addresses.length; i++) {
            require(
                list.isForbiddenEvmAddress(_addresses[i]),
                string.concat("EVM: not loaded: ", vm.toString(_addresses[i]))
            );
        }
        (, uint256 total, uint64 version) = list.getForbiddenEvmAddresses(0, 0);
        console2.log(string.concat(
            "EVM: ", vm.toString(total), " forbidden addresses loaded, version ", vm.toString(uint256(version))
        ));
    }

    /// The profile's `forbiddenAddressListSources`; virtual so a test can load sources its profile does not name.
    function _sources()
        internal view virtual
        returns (string[] memory)
    {
        return vm.parseJsonStringArray(config, ".forbiddenAddressListSources");
    }

    /// The profile's `forbiddenAddressListPersonalAccountProviders`; virtual so a test can set its own.
    function _personalAccountProviders()
        internal view virtual
        returns (PersonalAccountProvider[] memory _providers)
    {
        string memory key = ".forbiddenAddressListPersonalAccountProviders";
        uint256 count;
        while (vm.keyExistsJson(config, string.concat(key, "[", vm.toString(count), "]"))) {
            count++;
        }
        _providers = new PersonalAccountProvider[](count);
        for (uint256 i = 0; i < count; i++) {
            string memory item = string.concat(key, "[", vm.toString(i), "]");
            _providers[i].sourceId = _toBytes32(vm.parseJsonString(config, string.concat(item, ".sourceId")));
            _providers[i].provider = vm.parseJsonAddress(config, string.concat(item, ".provider"));
        }
    }

    /// The shared data file; virtual so a test can load its own.
    function _forbiddenAddressesFile()
        internal view virtual
        returns (string memory)
    {
        return FORBIDDEN_ADDRESSES_FILE;
    }

    /// The network's deployment record (empty for a network with none yet). Virtual so a test can supply its own.
    function _readDeploysFile(
        string memory _network
    )
        internal view virtual
        returns (DeployedContract[] memory)
    {
        string memory path = string.concat("deployment/deploys/", _network, ".json");
        if (!vm.exists(path)) {
            return new DeployedContract[](0);
        }
        return abi.decode(vm.parseJson(vm.readFile(path)), (DeployedContract[]));
    }

    /// Every address the data file lists for `_source`, in the file's order (an address in two groups for the same
    /// source appears twice; the list skips the repeat).
    function _addressesOf(
        string memory _data,
        string memory _source
    )
        internal view
        returns (string[] memory _addresses)
    {
        bytes32 sourceHash = keccak256(bytes(_source));
        uint256 count;
        uint256 groups;
        while (vm.keyExistsJson(_data, string.concat(".lists[", vm.toString(groups), "]"))) {
            groups++;
        }
        string[][] memory matched = new string[][](groups);
        for (uint256 g = 0; g < groups; g++) {
            string memory base = string.concat(".lists[", vm.toString(g), "]");
            string[] memory sourceIds = vm.parseJsonStringArray(_data, string.concat(base, ".sourceIds"));
            for (uint256 s = 0; s < sourceIds.length; s++) {
                if (keccak256(bytes(sourceIds[s])) == sourceHash) {
                    matched[g] = vm.parseJsonStringArray(_data, string.concat(base, ".addresses"));
                    count += matched[g].length;
                    break;
                }
            }
        }
        _addresses = new string[](count);
        uint256 next;
        for (uint256 g = 0; g < groups; g++) {
            for (uint256 i = 0; i < matched[g].length; i++) {
                _addresses[next++] = matched[g][i];
            }
        }
    }

    /// Whether the deployer can act on a governed contract directly: it is its governance and the contract is not yet
    /// in production mode (where a governance call only records a timelocked call).
    function _deployerGoverns(
        address _governed
    )
        internal view
        returns (bool)
    {
        (bool ok, bytes memory data) = _governed.staticcall(abi.encodeWithSignature("governance()"));
        if (!ok || data.length != 32 || abi.decode(data, (address)) != deployer) {
            return false;
        }
        (ok, data) = _governed.staticcall(abi.encodeWithSignature("productionMode()"));
        return ok && data.length == 32 && !abi.decode(data, (bool));
    }

    /// The AddressUpdater's current address for a name (zero if unset — the contract's own answer for an unknown
    /// name).
    function _addressUpdaterName(
        string memory _name
    )
        internal view
        returns (address)
    {
        (bool ok, bytes memory data) = addressUpdater.staticcall(
            abi.encodeWithSelector(IIAddressUpdater.getContractAddress.selector, _name)
        );
        if (!ok || data.length != 32) {
            return address(0);
        }
        return abi.decode(data, (address));
    }

    /// The network of the chains the list screens, for this deploy target: flare/songbird -> mainnet, scdev ->
    /// local (Bitcoin regtest), else public testnet.
    function _externalChainEnvironment()
        internal view
        returns (IExternalNetwork.Network)
    {
        bytes32 name = keccak256(bytes(network));
        if (name == keccak256("flare") || name == keccak256("songbird")) {
            return IExternalNetwork.Network.Mainnet;
        }
        if (_isScdev()) {
            return IExternalNetwork.Network.Local;
        }
        return IExternalNetwork.Network.Testnet;
    }

    function _isScdev()
        internal view
        returns (bool)
    {
        return keccak256(bytes(network)) == keccak256("scdev");
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
        return address(0);
    }

    /// A profile identifier as right-padded ASCII bytes32; 1..32 BYTES. A silent truncation would deploy a different
    /// identifier than the profile shows.
    function _toBytes32(
        string memory _value
    )
        internal pure
        returns (bytes32)
    {
        bytes memory raw = bytes(_value);
        require(raw.length > 0 && raw.length <= 32, string.concat("identifier not 1..32 bytes: ", _value));
        return bytes32(raw);
    }
}
