// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
// solhint-disable no-console

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {IGovernanceSettings} from
    "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import {IFlareContractRegistry} from
    "@flarenetwork/flare-periphery-contracts/flare/IFlareContractRegistry.sol";
import {TeeOracleInstructionsSender} from
    "../../contracts/tee/extensions/oracle/implementation/TeeOracleInstructionsSender.sol";
import {TeeOracleInstructionsSenderProxy} from
    "../../contracts/tee/extensions/oracle/proxy/TeeOracleInstructionsSenderProxy.sol";
import {TeeOracleFeedStore} from
    "../../contracts/tee/extensions/oracle/implementation/TeeOracleFeedStore.sol";
import {TeeOracleFeedStoreProxy} from
    "../../contracts/tee/extensions/oracle/proxy/TeeOracleFeedStoreProxy.sol";
import {ITeeOracleInstructionsSender} from
    "../../contracts/userInterfaces/tee/ITeeOracleInstructionsSender.sol";

// solhint-disable-next-line max-line-length
// forge script deployment/scripts/DeployTeeOracle.s.sol:DeployTeeOracle --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast --sig "run()"

/**
 * Deploys the TEE oracle extension: one TeeOracleInstructionsSender UUPS proxy for the
 * extension plus one TeeOracleFeedStore UUPS proxy per configured feed (all reading the
 * same sender, so one machine fleet serves every feed), wired via the AddressUpdater and
 * switched to production mode.
 *
 * Steps that CANNOT be scripted here (governance / extension owner, see docs/specs/FCC/TeeOracle.md):
 * - FlareTeeManager.registerReserved(extensionId, owner)          - Flare governance (timelocked)
 * - FlareTeeManager.setExtensionContracts(extensionId, 0, sender) - extension owner (direct)
 * - addTeeVersion / addAllowedTeeMachineOwners / setNewTeeGovernance - extension owner (direct)
 * - OperationFeesFacet.setOperationFees TEE_ORACLE rows           - Flare governance (timelocked)
 *   NOTE: until the fee rows are executed, the default fee applies
 * - FtsoV2.addCustomFeeds([feed stores])                          - Flare governance (timelocked)
 * - sender.setEndpoints / setAdmins per feed and machine          - Flare governance (timelocked)
 *   NOTE: the executor attaches the instruction fee to executeGovernanceCall
 */
contract DeployTeeOracle is Script {
    using stdJson for string;

    struct DeployedContract {
        address addr;
        string contractName;
        string name;
    }

    struct FeedParams {
        string registryName;
        bytes21 feedId;
    }

    // Well-known FlareContractRegistry address (same on all Flare networks)
    IFlareContractRegistry private constant FLARE_CONTRACT_REGISTRY =
        IFlareContractRegistry(0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019);

    address private deployer;
    address private governanceSettings;
    address private addressUpdater;
    address private flareTeeManager;
    address private fdc2Verification;
    address private feeCalculator;

    string private config;

    uint256 private extensionId;
    address private feeDestination;
    FeedParams[] private feeds;

    TeeOracleInstructionsSender private sender;
    TeeOracleFeedStore[] private feedStores;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        string memory network = _resolveNetwork();
        console2.log(string.concat("NETWORK: ", network));
        config = vm.readFile(
            string.concat("deployment/chain-config/", network, ".json"));
        _readParams();
        _readDeployedAddresses(network);

        vm.startBroadcast();
        _deployInstructionsSender();
        _deployFeedStores();
        _wireInstructionsSender();
        _wireFeedStores();
        sender.switchToProductionMode();
        for (uint256 i = 0; i < feedStores.length; i++) {
            feedStores[i].switchToProductionMode();
        }
        vm.stopBroadcast();

        _logManualSteps();
    }

    // =========================================================================
    // Parameters
    // =========================================================================

    function _readParams() internal {
        extensionId = vm.parseJsonUint(config, ".teeOracleExtensionId");
        require(extensionId != 0, "extension id must not be zero");
        feeDestination =
            vm.parseJsonAddress(config, ".teeOracleFeeDestinationAddress");
        require(feeDestination != address(0), "fee destination not set");

        for (
            uint256 i = 0;
            vm.keyExistsJson(
                config,
                string.concat(".teeOracleFeeds[", vm.toString(i), "]")
            );
            i++
        ) {
            string memory base =
                string.concat(".teeOracleFeeds[", vm.toString(i), "]");
            string memory registryName =
                vm.parseJsonString(config, string.concat(base, ".registryName"));
            uint256 category =
                vm.parseJsonUint(config, string.concat(base, ".feedCategory"));
            string memory feedName =
                vm.parseJsonString(config, string.concat(base, ".feedName"));

            require(bytes(registryName).length > 0, "empty registry name");
            require(
                category >= 0x20 && category < 0x40, "invalid feed category"
            );
            bytes memory nameBytes = bytes(feedName);
            require(
                nameBytes.length > 0 && nameBytes.length <= 20,
                "invalid feed name length"
            );

            feeds.push(FeedParams({
                registryName: registryName,
                feedId: bytes21(
                    bytes.concat(bytes1(uint8(category)), nameBytes))
            }));
        }
        require(feeds.length > 0, "no feeds configured");
    }

    // =========================================================================
    // Pre-deployed addresses
    // =========================================================================

    function _readDeployedAddresses(string memory _network) internal {
        if (_isScdev(_network)) {
            _readDeployedAddressesFromJson(_network);
        } else {
            _readDeployedAddressesFromRegistry();
        }
    }

    function _readDeployedAddressesFromRegistry() internal {
        string[] memory names = new string[](5);
        names[0] = "GovernanceSettings";
        names[1] = "AddressUpdater";
        names[2] = "FlareTeeManager";
        names[3] = "Fdc2Verification";
        names[4] = "FeeCalculator";
        address[] memory addrs =
            FLARE_CONTRACT_REGISTRY.getContractAddressesByName(names);

        governanceSettings = addrs[0];
        addressUpdater = addrs[1];
        flareTeeManager = addrs[2];
        fdc2Verification = addrs[3];
        feeCalculator = addrs[4];
    }

    function _readDeployedAddressesFromJson(
        string memory _network
    )
        internal
    {
        string memory deploysFile =
            string.concat("deployment/deploys/", _network, ".json");
        string memory deploys = vm.readFile(deploysFile);
        DeployedContract[] memory contracts =
            abi.decode(vm.parseJson(deploys), (DeployedContract[]));

        governanceSettings =
            _findDeployedAddress(contracts, "GovernanceSettings");
        addressUpdater = _findDeployedAddress(contracts, "AddressUpdater");
        flareTeeManager = _findDeployedAddress(contracts, "FlareTeeManager");
        fdc2Verification =
            _findDeployedAddress(contracts, "Fdc2Verification");
        feeCalculator = _findDeployedAddress(contracts, "FeeCalculator");
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

    // =========================================================================
    // Deployment
    // =========================================================================

    function _deployInstructionsSender() internal {
        TeeOracleInstructionsSender impl = new TeeOracleInstructionsSender();
        _logDeployed(
            "TeeOracleInstructionsSenderImplementation",
            "TeeOracleInstructionsSender",
            address(impl)
        );
        // deployer acts as initial governance and address updater; the wiring call
        // below hands the updater role to the real AddressUpdater and
        // switchToProductionMode() hands governance to GovernanceSettings
        TeeOracleInstructionsSenderProxy proxy =
            new TeeOracleInstructionsSenderProxy(
                IGovernanceSettings(governanceSettings),
                deployer,
                deployer,
                extensionId,
                address(impl)
            );
        sender = TeeOracleInstructionsSender(address(proxy));
        _logDeployed(
            "TeeOracleInstructionsSender",
            "TeeOracleInstructionsSender",
            address(proxy)
        );
    }

    function _deployFeedStores() internal {
        // one implementation shared by all feed store proxies
        TeeOracleFeedStore impl = new TeeOracleFeedStore();
        _logDeployed(
            "TeeOracleFeedStoreImplementation",
            "TeeOracleFeedStore",
            address(impl)
        );

        for (uint256 i = 0; i < feeds.length; i++) {
            FeedParams memory feed = feeds[i];
            TeeOracleFeedStoreProxy proxy = new TeeOracleFeedStoreProxy(
                IGovernanceSettings(governanceSettings),
                deployer,
                deployer,
                ITeeOracleInstructionsSender(address(sender)),
                feed.feedId,
                feeDestination,
                address(impl)
            );
            feedStores.push(TeeOracleFeedStore(address(proxy)));
            _logDeployed(
                feed.registryName, "TeeOracleFeedStore", address(proxy)
            );
        }
    }

    // =========================================================================
    // Wiring
    // =========================================================================

    function _wireInstructionsSender() internal {
        bytes32[] memory names = new bytes32[](2);
        names[0] = _encodeContractName("AddressUpdater");
        names[1] = _encodeContractName("FlareTeeManager");
        address[] memory addrs = new address[](2);
        addrs[0] = addressUpdater;
        addrs[1] = flareTeeManager;
        sender.updateContractAddresses(names, addrs);
    }

    function _wireFeedStores() internal {
        bytes32[] memory names = new bytes32[](3);
        names[0] = _encodeContractName("AddressUpdater");
        names[1] = _encodeContractName("Fdc2Verification");
        names[2] = _encodeContractName("FeeCalculator");
        address[] memory addrs = new address[](3);
        addrs[0] = addressUpdater;
        addrs[1] = fdc2Verification;
        addrs[2] = feeCalculator;
        for (uint256 i = 0; i < feedStores.length; i++) {
            feedStores[i].updateContractAddresses(names, addrs);
        }
    }

    // =========================================================================
    // Helpers
    // =========================================================================

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

    function _isScdev(string memory _network)
        internal pure
        returns (bool)
    {
        return keccak256(bytes(_network)) == keccak256(bytes("scdev"));
    }

    function _encodeContractName(
        string memory _name
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_name));
    }

    function _logDeployed(
        string memory _name,
        string memory _contractName,
        address _addr
    )
        internal pure
    {
        console2.log(
            string.concat(
                "DEPLOYED: ", _name, ", ", _contractName, ": ",
                vm.toString(_addr)
            )
        );
    }

    function _logManualSteps() internal view {
        console2.log("");
        console2.log("Manual follow-up steps (governance / extension owner):");
        console2.log(string.concat(
            "1. governance: FlareTeeManager.registerReserved(",
            vm.toString(extensionId), ", <extension owner>)"
        ));
        console2.log(string.concat(
            "2. extension owner: FlareTeeManager.setExtensionContracts(",
            vm.toString(extensionId), ", 0x0, ",
            vm.toString(address(sender)), ")"
        ));
        console2.log(
            "3. extension owner: addTeeVersion / addAllowedTeeMachineOwners / setNewTeeGovernance"
        );
        for (uint256 i = 0; i < feedStores.length; i++) {
            console2.log(string.concat(
                "4. governance: FtsoV2.addCustomFeeds([",
                vm.toString(address(feedStores[i])), "]) // ",
                feeds[i].registryName
            ));
        }
        console2.log(
            "5. governance: sender.setEndpoints / setAdmins per feed and machine "
            "(executor attaches the fee)"
        );
    }
}
