// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {DeployForbiddenAddressList} from "../../../deployment/scripts/DeployForbiddenAddressList.s.sol";
import {ForbiddenAddressList} from "../../../contracts/compliance/implementation/ForbiddenAddressList.sol";
import {IFlareGovernance} from "../../../contracts/userInterfaces/IFlareGovernance.sol";
import {AddressUpdatable} from "../../../contracts/utils/implementation/AddressUpdatable.sol";
import {ForbiddenAddressListProxy} from "../../../contracts/compliance/proxy/ForbiddenAddressListProxy.sol";
import {IExternalNetwork} from "../../../contracts/userInterfaces/IExternalNetwork.sol";
import {IGovernanceSettings} from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import {DerivingProvider} from "../compliance/implementation/ForbiddenAddressList.t.sol";

/// The deployment record the steps share in place of deployment/deploys/<network>.json.
contract DeployRecord {
    DeployForbiddenAddressList.DeployedContract[] private entries;

    function add(
        string calldata _name,
        string calldata _contractName,
        address _addr
    )
        external
    {
        for (uint256 i = 0; i < entries.length; i++) {
            if (keccak256(bytes(entries[i].name)) == keccak256(bytes(_name))) {
                entries[i].addr = _addr;
                entries[i].contractName = _contractName;
                return;
            }
        }
        entries.push(
            DeployForbiddenAddressList.DeployedContract({addr: _addr, contractName: _contractName, name: _name})
        );
    }

    function all()
        external view
        returns (DeployForbiddenAddressList.DeployedContract[] memory)
    {
        return entries;
    }

    function addressOf(
        string calldata _name
    )
        external view
        returns (address)
    {
        for (uint256 i = 0; i < entries.length; i++) {
            if (keccak256(bytes(entries[i].name)) == keccak256(bytes(_name))) {
                return entries[i].addr;
            }
        }
        return address(0);
    }
}

contract ForbiddenAddressListStep is DeployForbiddenAddressList {
    DeployRecord private record;

    function setRecord(DeployRecord _record) external {
        record = _record;
    }

    function _logDeployed(string memory _name, string memory _contractName, address _addr) internal override {
        super._logDeployed(_name, _contractName, _addr);
        record.add(_name, _contractName, _addr);
    }

    function _readDeploysFile(string memory) internal view override returns (DeployedContract[] memory) {
        return record.all();
    }

    function _forbiddenAddressesFile() internal pure override returns (string memory) {
        return "test-forge/fixtures/forbidden-addresses.json";
    }

    /// The fixture's regtest Bitcoin, which the local profile does not load from the shared (mainnet) file.
    function _sources() internal pure override returns (string[] memory _names) {
        _names = new string[](2);
        _names[0] = "BTC";
        _names[1] = "XRP";
    }
}

/// The fixture step with a Personal Account provider for BTC, which the local profile does not name.
contract ProviderStep is ForbiddenAddressListStep {
    address private provider;

    function setProvider(address _provider) external {
        provider = _provider;
    }

    function _personalAccountProviders()
        internal view override
        returns (PersonalAccountProvider[] memory _providers)
    {
        _providers = new PersonalAccountProvider[](1);
        _providers[0] = PersonalAccountProvider({ sourceId: bytes32("BTC"), provider: provider });
    }
}

/// The same step reading the shared deployment/chain-config/forbidden-addresses.json.
contract SharedFileStep is DeployForbiddenAddressList {
    DeployRecord private record;

    function setRecord(DeployRecord _record) external {
        record = _record;
    }

    function _logDeployed(string memory _name, string memory _contractName, address _addr) internal override {
        super._logDeployed(_name, _contractName, _addr);
        record.add(_name, _contractName, _addr);
    }

    function _readDeploysFile(string memory) internal view override returns (DeployedContract[] memory) {
        return record.all();
    }
}

/**
 * DeployForbiddenAddressList on the local (scdev) profile, a Local deployment — sources BTC and XRP, batches of 100 —
 * against test-forge/fixtures/forbidden-addresses.json: 205 regtest Bitcoin addresses and a second BTC group repeating
 * one of them, two XRP addresses, and 104 EVM addresses in mixed spellings with one repeated in another spelling.
 */
contract DeployForbiddenAddressListTest is Test {
    uint256 private constant DEPLOYER_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address private constant GOVERNANCE_SETTINGS = address(0x1000000000000000000000000000000000000007);
    address private constant ADDRESS_UPDATER = address(0xA1);

    DeployRecord private record;
    address private deployer;

    function setUp() public {
        vm.setEnv("DEPLOYER_PRIVATE_KEY", vm.toString(bytes32(DEPLOYER_KEY)));
        vm.setEnv("DEPLOY_NETWORK", "scdev");
        // the record's system contracts must have code on the chain
        vm.etch(GOVERNANCE_SETTINGS, hex"00");
        vm.etch(ADDRESS_UPDATER, hex"00");
        deployer = vm.addr(DEPLOYER_KEY);
        record = new DeployRecord();
        record.add("GovernanceSettings", "GovernanceSettings.sol", GOVERNANCE_SETTINGS);
        record.add("AddressUpdater", "AddressUpdater.sol", ADDRESS_UPDATER);
    }

    function testDeploysAndLoadsTheListPerSource() public {
        _step().run();
        ForbiddenAddressList list = ForbiddenAddressList(record.addressOf("ForbiddenAddressList"));
        assertTrue(address(list).code.length > 0, "recorded and deployed");
        assertTrue(record.addressOf("ForbiddenAddressListImplementation") != address(0));

        (, uint256 btcTotal, uint64 btcVersion) = list.getForbiddenAddressHashes(bytes32("BTC"), 0, 0);
        assertEq(btcTotal, 206, "205 + the second group's new one; its repeat is skipped");
        assertEq(btcVersion, 3, "three batches of at most 100");
        assertTrue(list.isForbidden(bytes32("BTC"), "miVvPZUZqGn91tCrcR5CnvPtyGmL9piYV2"), "the first group's last");
        assertTrue(list.isForbidden(bytes32("BTC"), "2N95GDiZFt7F2rBUTFXYi1BRMrxibToBauw"), "the second group's");
        assertEq(uint256(list.getNetwork()), uint256(IExternalNetwork.Network.Local), "scdev is a Local deployment");
        (, uint256 xrpTotal, ) = list.getForbiddenAddressHashes(bytes32("XRP"), 0, 0);
        assertEq(xrpTotal, 2);
        (, uint256 evmTotal, uint64 evmVersion) = list.getForbiddenEvmAddresses(0, 0);
        assertEq(evmTotal, 104, "an address in two spellings is one address");
        assertEq(evmVersion, 2, "two batches of at most 100");
        assertTrue(list.isForbiddenEvmAddress(address(0xF001)));
        assertTrue(list.isForbiddenEvmAddress(address(0xF068)));
        assertFalse(list.isForbiddenEvmAddress(address(0xF069)));
        assertEq(list.getMaintainers().length, 0, "the local profile names no maintainer");
        assertEq(list.getPersonalAccountProvider(bytes32("XRP")), address(0), "the local profile names no provider");

        assertEq(IFlareGovernance(address(list)).governance(), deployer, "governance stays the deployer's");
        assertFalse(IFlareGovernance(address(list)).productionMode(), "production is a separate step");
        assertEq(AddressUpdatable(address(list)).getAddressUpdater(), ADDRESS_UPDATER, "updater role handed over");
    }

    /// A provider is set before the sources load, so the initial contents list the Personal Account of every address
    /// of its source (the script checks each); a source without a provider derives none.
    function testTheProvidersAreSetBeforeLoading() public {
        DerivingProvider provider = new DerivingProvider();
        ProviderStep step = new ProviderStep();
        step.setRecord(record);
        step.setProvider(address(provider));
        step.run();
        ForbiddenAddressList list = ForbiddenAddressList(record.addressOf("ForbiddenAddressList"));
        assertEq(list.getPersonalAccountProvider(bytes32("BTC")), address(provider));
        assertTrue(list.isForbiddenEvmAddress(provider.getPersonalAccount("miVvPZUZqGn91tCrcR5CnvPtyGmL9piYV2")));
        assertTrue(list.isForbiddenEvmAddress(provider.getPersonalAccount("2N95GDiZFt7F2rBUTFXYi1BRMrxibToBauw")));
        (, uint256 evmTotal, uint64 evmVersion) = list.getForbiddenEvmAddresses(0, 0);
        assertEq(evmTotal, 104 + 206, "the EVM file's and one Personal Account per Bitcoin address");
        assertEq(evmVersion, 3 + 2, "each Bitcoin batch moved the EVM list, then the EVM batches");
    }

    /// A record naming system contracts this chain does not run (a stale local record) stops the run at its start.
    function testRevertSystemAddressWithoutCode() public {
        vm.etch(GOVERNANCE_SETTINGS, "");
        ForbiddenAddressListStep step = _step();
        vm.expectRevert(
            bytes("GovernanceSettings or AddressUpdater has no code on scdev: check the deployment record")
        );
        step.run();
    }

    /// The separate step hands governance to GovernanceSettings; a second run leaves the list alone.
    function testSwitchToProduction() public {
        _step().run();
        address list = record.addressOf("ForbiddenAddressList");
        address governance = makeAddr("governance");
        vm.mockCall(
            GOVERNANCE_SETTINGS,
            abi.encodeWithSelector(IGovernanceSettings.getGovernanceAddress.selector),
            abi.encode(governance)
        );
        _step().switchToProduction();
        assertTrue(IFlareGovernance(list).productionMode());
        assertEq(IFlareGovernance(list).governance(), governance);
        _step().switchToProduction();
        assertTrue(IFlareGovernance(list).productionMode(), "already in production: left alone");
    }

    function testRevertSwitchToProductionNotDeployed() public {
        ForbiddenAddressListStep step = _step();
        vm.expectRevert(bytes("ForbiddenAddressList is not deployed on scdev"));
        step.switchToProduction();
    }

    /// Only the list's governance can switch it; a deployer that does not govern it stops the run.
    function testRevertSwitchToProductionNotGovernance() public {
        _step().run();
        address list = record.addressOf("ForbiddenAddressList");
        address other = makeAddr("other");
        vm.mockCall(list, abi.encodeWithSelector(IFlareGovernance.governance.selector), abi.encode(other));
        ForbiddenAddressListStep step = _step();
        vm.expectRevert(bytes(string.concat(
            "ForbiddenAddressList is governed by ", vm.toString(other), ", not the deployer; only it can switch"
        )));
        step.switchToProduction();
    }

    function testASecondRunIsRefused() public {
        _step().run();
        ForbiddenAddressListStep again = _step();
        vm.expectRevert();
        again.run();
    }

    /// The shared file loads on mainnet, the network its Bitcoin addresses are of: the list refuses an address not in
    /// its chain's canonical form, so a regeneration that wrote another form fails here, before a real deploy.
    function testTheSharedFileLoadsOnMainnet() public {
        string memory data = vm.readFile("deployment/chain-config/forbidden-addresses.json");
        address implementation = address(new ForbiddenAddressList());
        ForbiddenAddressList mainnetList = ForbiddenAddressList(address(new ForbiddenAddressListProxy(
            IGovernanceSettings(GOVERNANCE_SETTINGS), address(this), ADDRESS_UPDATER, IExternalNetwork.Network.Mainnet,
            implementation
        )));
        string[2] memory sources = ["BTC", "XRP"];
        for (uint256 g = 0; vm.keyExistsJson(data, string.concat(".lists[", vm.toString(g), "]")); g++) {
            string memory base = string.concat(".lists[", vm.toString(g), "]");
            string[] memory sourceIds = vm.parseJsonStringArray(data, string.concat(base, ".sourceIds"));
            string[] memory addresses = vm.parseJsonStringArray(data, string.concat(base, ".addresses"));
            for (uint256 s = 0; s < sourceIds.length; s++) {
                bool known = keccak256(bytes(sourceIds[s])) == keccak256(bytes(sources[0]))
                    || keccak256(bytes(sourceIds[s])) == keccak256(bytes(sources[1]));
                assertTrue(known, string.concat("a source this test does not load: ", sourceIds[s]));
                for (uint256 start = 0; start < addresses.length; start += 100) {
                    uint256 end = start + 100 < addresses.length ? start + 100 : addresses.length;
                    string[] memory batch = new string[](end - start);
                    for (uint256 i = start; i < end; i++) {
                        batch[i - start] = addresses[i];
                    }
                    mainnetList.addForbiddenAddresses(bytes32(bytes(sourceIds[s])), batch);
                }
            }
        }
        mainnetList.addForbiddenEvmAddresses(vm.parseJsonAddressArray(data, ".evmAddresses"));
        (, uint256 btcTotal, ) = mainnetList.getForbiddenAddressHashes(bytes32("BTC"), 0, 0);
        assertGt(btcTotal, 0);
    }

    /// The shared file deploys through the script on the local profile: XRP and the EVM list (its Bitcoin is mainnet).
    function testTheSharedFileDeploys() public {
        SharedFileStep shared = new SharedFileStep();
        shared.setRecord(record);
        shared.run();
        assertTrue(record.addressOf("ForbiddenAddressList").code.length > 0);
    }

    function _step() private returns (ForbiddenAddressListStep _deployStep) {
        _deployStep = new ForbiddenAddressListStep();
        _deployStep.setRecord(record);
    }
}
