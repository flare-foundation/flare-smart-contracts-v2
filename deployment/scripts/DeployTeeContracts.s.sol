// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
// solhint-disable no-console

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {IGovernanceSettings} from
    "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import {IFlareContractRegistry} from
    "@flarenetwork/flare-periphery-contracts/flare/IFlareContractRegistry.sol";
import {IDiamond} from "../../contracts/diamond/interfaces/IDiamond.sol";
import {IDiamondCut} from "../../contracts/diamond/interfaces/IDiamondCut.sol";
import {IIFlareTeeManager} from
    "../../contracts/tee/interface/IIFlareTeeManager.sol";
import {FlareTeeManager} from
    "../../contracts/tee/diamond/FlareTeeManager.sol";
// Diamond init contracts
import {FlareTeeManagerInit} from
    "../../contracts/tee/facets/FlareTeeManagerInit.sol";
import {TeeReplicationInit} from
    "../../contracts/tee/facets/TeeReplicationInit.sol";
// Day-1 facets
import {FlareTeeManagerDiamondCutFacet} from
    "../../contracts/tee/facets/FlareTeeManagerDiamondCutFacet.sol";
import {DiamondLoupeFacet} from
    "../../contracts/diamond/facets/DiamondLoupeFacet.sol";
import {TeeExtensionRegistryFacet} from
    "../../contracts/tee/facets/TeeExtensionRegistryFacet.sol";
import {TeeMachineRegistryFacet} from
    "../../contracts/tee/facets/TeeMachineRegistryFacet.sol";
import {TeeVerificationFacet} from
    "../../contracts/tee/facets/TeeVerificationFacet.sol";
import {TeeWalletVerificationFacet} from
    "../../contracts/tee/facets/TeeWalletVerificationFacet.sol";
import {TeeFeeCalculatorFacet} from
    "../../contracts/tee/facets/TeeFeeCalculatorFacet.sol";
import {TeeOwnerAllowlistFacet} from
    "../../contracts/tee/facets/TeeOwnerAllowlistFacet.sol";
import {TeeSystemStateVerifierFacet} from
    "../../contracts/tee/facets/TeeSystemStateVerifierFacet.sol";
import {TeeWalletManagerFacet} from
    "../../contracts/tee/facets/TeeWalletManagerFacet.sol";
import {TeeWalletKeyManagerFacet} from
    "../../contracts/tee/facets/TeeWalletKeyManagerFacet.sol";
import {TeeWalletProjectManagerFacet} from
    "../../contracts/tee/facets/TeeWalletProjectManagerFacet.sol";
import {TeeWalletBackupManagerFacet} from
    "../../contracts/tee/facets/TeeWalletBackupManagerFacet.sol";
import {TeeVrfFacet} from "../../contracts/tee/facets/TeeVrfFacet.sol";
import {TeeAddressUpdatableFacet} from
    "../../contracts/tee/facets/TeeAddressUpdatableFacet.sol";
// Later facets
import {TeeReplicationFacet} from
    "../../contracts/tee/facets/TeeReplicationFacet.sol";
import {TeeGovernanceFacet} from
    "../../contracts/tee/facets/TeeGovernanceFacet.sol";
import {TeeVersionManagerFacet} from
    "../../contracts/tee/facets/TeeVersionManagerFacet.sol";
// FDC2 contracts
import {Fdc2Hub} from "../../contracts/fdc2/implementation/Fdc2Hub.sol";
import {Fdc2HubProxy} from "../../contracts/fdc2/proxy/Fdc2HubProxy.sol";
import {Fdc2RequestFeeConfigurations} from
    "../../contracts/fdc2/implementation/Fdc2RequestFeeConfigurations.sol";
import {Fdc2RequestFeeConfigurationsProxy} from
    "../../contracts/fdc2/proxy/Fdc2RequestFeeConfigurationsProxy.sol";
import {Fdc2Verification} from
    "../../contracts/fdc2/implementation/Fdc2Verification.sol";
import {Fdc2VerificationProxy} from
    "../../contracts/fdc2/proxy/Fdc2VerificationProxy.sol";
// TEE UUPS contracts
import {TeePayments} from "../../contracts/tee/implementation/TeePayments.sol";
import {TeePaymentsProxy} from "../../contracts/tee/proxy/TeePaymentsProxy.sol";
import {TeeRewardOffersManager} from
    "../../contracts/tee/implementation/TeeRewardOffersManager.sol";
import {VrfVerifier} from "../../contracts/tee/lib/VrfVerifier.sol";

// solhint-disable no-console
// solhint-disable-next-line max-line-length
// forge script deployment/scripts/DeployTeeContracts.s.sol:DeployTeeContracts --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast --sig "run(bool)" true

contract DeployTeeContracts is Script {
    using stdJson for string;

    // =========================================================================
    // JSON deserialization structs
    // =========================================================================

    struct DeployedContract {
        address addr;
        string contractName;
        string name;
    }

    struct OperationFeeConfig {
        string feeWei;
        string opCommand;
        string opType;
    }

    struct KeyTypeWithSigningAlgos {
        string keyType;
        string[] signingAlgos;
    }

    struct PaymentConfiguration {
        string keyType;
        uint256 maxBatchDurationSeconds;
        uint256 maxBatchSize;
        string opType;
        string[] sourceIds;
    }

    struct Fdc2RequestFee {
        string attestationType;
        string feeWei;
        string source;
    }

    // =========================================================================
    // State variables (avoids stack-too-deep)
    // =========================================================================
    address private deployer;
    address private governanceSettings;
    address private addressUpdater;
    address private inflation;
    address private flareSystemsManager;
    address private relay;
    address private rewardManager;

    string private config;

    // FlareTeeManager diamond
    IIFlareTeeManager private flareTeeManager;
    address private flareTeeManagerAddress;
    IDiamond.FacetCut[] private day1Facets;
    IDiamond.FacetCut[] private laterFacets;

    // Day-1 facet instances (for logging)
    FlareTeeManagerDiamondCutFacet private diamondCutFacet;
    DiamondLoupeFacet private diamondLoupeFacet;
    TeeExtensionRegistryFacet private teeExtensionRegistryFacet;
    TeeMachineRegistryFacet private teeMachineRegistryFacet;
    TeeVerificationFacet private teeVerificationFacet;
    TeeWalletVerificationFacet private teeWalletVerificationFacet;
    TeeFeeCalculatorFacet private teeFeeCalculatorFacet;
    TeeOwnerAllowlistFacet private teeOwnerAllowlistFacet;
    TeeSystemStateVerifierFacet private teeSystemStateVerifierFacet;
    TeeWalletManagerFacet private teeWalletManagerFacet;
    TeeWalletKeyManagerFacet private teeWalletKeyManagerFacet;
    TeeWalletProjectManagerFacet private teeWalletProjectManagerFacet;
    TeeWalletBackupManagerFacet private teeWalletBackupManagerFacet;
    TeeVrfFacet private teeVrfFacet;
    TeeAddressUpdatableFacet private teeAddressUpdatableFacet;

    // Later facet instances (for logging)
    TeeReplicationFacet private teeReplicationFacet;
    TeeGovernanceFacet private teeGovernanceFacet;
    TeeVersionManagerFacet private teeVersionManagerFacet;

    // Deployed contract addresses
    address private fdc2HubAddr;
    address private fdc2FeeAddr;
    address private fdc2VerificationAddr;
    address[] private teePaymentsAddresses;
    address private teeRewardOffersManagerAddr;

    // Well-known FlareContractRegistry address (same on all Flare networks)
    IFlareContractRegistry private constant FLARE_CONTRACT_REGISTRY =
        IFlareContractRegistry(0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019);

    // =========================================================================
    // Entry point
    // =========================================================================

    function run(bool _fullDeploy) external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        string memory network = _resolveNetwork();
        string memory configFile =
            string.concat("deployment/chain-config/", network, ".json");
        console2.log(string.concat("NETWORK: ", network));

        config = vm.readFile(configFile);
        _readDeployedAddresses(network);

        vm.startBroadcast();

        // Phase 1: Deploy FlareTeeManager diamond
        _deployDay1Facets();
        _logDay1FacetAddresses();
        _createDiamond();
        _configureDiamond();

        if (_fullDeploy) {
            _deployLaterFacets();
            _addLaterFacetsToDiamond();
            _logLaterFacetAddresses();
        } else {
            console2.log("Skipping later facets as per input flag");
        }

        // Phase 2: Deploy remaining TEE contracts
        _deployFdc2Contracts();
        _deployTeePayments();
        _deployTeeRewardOffersManager();
        _deployVrfVerifier();

        // Phase 3: Wire up and configure
        _wireUpContractAddresses();
        _registerSystemInstructionsSenders();
        _configureFdc2RequestFees();

        vm.stopBroadcast();
    }

    // =========================================================================
    // Network resolution
    // =========================================================================

    function _resolveNetwork()
        internal
        view
        returns (string memory)
    {
        uint256 chainId = block.chainid;
        if (chainId == 14) return "flare";
        if (chainId == 19) return "songbird";
        if (chainId == 16) return "coston";
        if (chainId == 114) return "coston2";
        return "scdev";
    }

    // =========================================================================
    // Read pre-deployed addresses
    // =========================================================================

    function _readDeployedAddresses(string memory _network) internal {
        if (_isScdev(_network)) {
            _readDeployedAddressesFromJson(_network);
        } else {
            _readDeployedAddressesFromRegistry();
        }
    }

    function _readDeployedAddressesFromRegistry() internal {
        string[] memory names = new string[](6);
        names[0] = "GovernanceSettings";
        names[1] = "AddressUpdater";
        names[2] = "Inflation";
        names[3] = "FlareSystemsManager";
        names[4] = "Relay";
        names[5] = "RewardManager";
        address[] memory addrs =
            FLARE_CONTRACT_REGISTRY.getContractAddressesByName(names);

        governanceSettings = addrs[0];
        addressUpdater = addrs[1];
        inflation = addrs[2];
        flareSystemsManager = addrs[3];
        relay = addrs[4];
        rewardManager = addrs[5];
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
        addressUpdater =
            _findDeployedAddress(contracts, "AddressUpdater");
        inflation =
            _findDeployedAddress(contracts, "Inflation");
        flareSystemsManager =
            _findDeployedAddress(contracts, "FlareSystemsManager");
        relay =
            _findDeployedAddress(contracts, "Relay");
        rewardManager =
            _findDeployedAddress(contracts, "RewardManager");
    }

    function _isScdev(string memory _network)
        internal
        pure
        returns (bool)
    {
        return keccak256(bytes(_network)) == keccak256(bytes("scdev"));
    }

    // =========================================================================
    // FlareTeeManager Diamond deployment
    // =========================================================================

    function _addFacet(
        address _facetAddr,
        string memory _facetName
    )
        internal
        returns (IDiamond.FacetCut memory)
    {
        string[] memory cmds = new string[](3);
        cmds[0] = "node";
        cmds[1] = "scripts/flare-tee-manager-selectors.js";
        cmds[2] = _facetName;
        bytes memory out = vm.ffi(cmds);
        bytes4[] memory selectors = abi.decode(out, (bytes4[]));
        return IDiamond.FacetCut({
            facetAddress: _facetAddr,
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }

    function _deployDay1Facets() internal {
        diamondCutFacet = new FlareTeeManagerDiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        teeExtensionRegistryFacet = new TeeExtensionRegistryFacet();
        teeMachineRegistryFacet = new TeeMachineRegistryFacet();
        teeVerificationFacet = new TeeVerificationFacet();
        teeWalletVerificationFacet = new TeeWalletVerificationFacet();
        teeFeeCalculatorFacet = new TeeFeeCalculatorFacet();
        teeOwnerAllowlistFacet = new TeeOwnerAllowlistFacet();
        teeSystemStateVerifierFacet = new TeeSystemStateVerifierFacet();
        teeWalletManagerFacet = new TeeWalletManagerFacet();
        teeWalletKeyManagerFacet = new TeeWalletKeyManagerFacet();
        teeWalletProjectManagerFacet = new TeeWalletProjectManagerFacet();
        teeWalletBackupManagerFacet = new TeeWalletBackupManagerFacet();
        teeVrfFacet = new TeeVrfFacet();
        teeAddressUpdatableFacet = new TeeAddressUpdatableFacet();

        day1Facets.push(_addFacet(
            address(diamondCutFacet), "FlareTeeManagerDiamondCutFacet"
        ));
        day1Facets.push(_addFacet(
            address(diamondLoupeFacet), "DiamondLoupeFacet"
        ));
        day1Facets.push(_addFacet(
            address(teeExtensionRegistryFacet), "TeeExtensionRegistryFacet"
        ));
        day1Facets.push(_addFacet(
            address(teeMachineRegistryFacet), "TeeMachineRegistryFacet"
        ));
        day1Facets.push(_addFacet(
            address(teeVerificationFacet), "TeeVerificationFacet"
        ));
        day1Facets.push(_addFacet(
            address(teeWalletVerificationFacet),
            "TeeWalletVerificationFacet"
        ));
        day1Facets.push(_addFacet(
            address(teeFeeCalculatorFacet), "TeeFeeCalculatorFacet"
        ));
        day1Facets.push(_addFacet(
            address(teeOwnerAllowlistFacet), "TeeOwnerAllowlistFacet"
        ));
        day1Facets.push(_addFacet(
            address(teeSystemStateVerifierFacet),
            "TeeSystemStateVerifierFacet"
        ));
        day1Facets.push(_addFacet(
            address(teeWalletManagerFacet), "TeeWalletManagerFacet"
        ));
        day1Facets.push(_addFacet(
            address(teeWalletKeyManagerFacet), "TeeWalletKeyManagerFacet"
        ));
        day1Facets.push(_addFacet(
            address(teeWalletProjectManagerFacet),
            "TeeWalletProjectManagerFacet"
        ));
        day1Facets.push(_addFacet(
            address(teeWalletBackupManagerFacet),
            "TeeWalletBackupManagerFacet"
        ));
        day1Facets.push(_addFacet(
            address(teeVrfFacet), "TeeVrfFacet"
        ));
        day1Facets.push(_addFacet(
            address(teeAddressUpdatableFacet), "TeeAddressUpdatableFacet"
        ));
    }

    function _createDiamond() internal {
        uint64 availabilityCheckValidityDurationSeconds = uint64(
            vm.parseJsonUint(
                config,
                ".teeAvailabilityCheckValidityDurationSeconds"
            )
        );
        uint64 signingPolicyValidityDurationInRewardEpochs = uint64(
            vm.parseJsonUint(
                config,
                ".teeSigningPolicyValidityDurationInRewardEpochs"
            )
        );
        uint64 challengeValidityDurationSeconds = uint64(
            vm.parseJsonUint(
                config, ".teeChallengeValidityDurationSeconds"
            )
        );
        uint256 defaultFeeWei =
            vm.parseJsonUint(config, ".teeDefaultFeeWei");

        FlareTeeManagerInit flareTeeManagerInit =
            new FlareTeeManagerInit();

        bytes memory initCalldata = abi.encodeWithSelector(
            FlareTeeManagerInit.init.selector,
            IGovernanceSettings(governanceSettings),
            deployer,
            deployer, // tmp address updater
            availabilityCheckValidityDurationSeconds,
            signingPolicyValidityDurationInRewardEpochs,
            challengeValidityDurationSeconds,
            defaultFeeWei
        );

        FlareTeeManager diamond = new FlareTeeManager(
            day1Facets,
            FlareTeeManager.DiamondArgs({
                init: address(flareTeeManagerInit),
                initCalldata: initCalldata
            })
        );
        flareTeeManagerAddress = address(diamond);
        flareTeeManager = IIFlareTeeManager(flareTeeManagerAddress);

        _logDeployed(
            "FlareTeeManagerInit",
            "FlareTeeManagerInit.sol",
            address(flareTeeManagerInit)
        );
        _logDeployed(
            "FlareTeeManager",
            "FlareTeeManager.sol",
            flareTeeManagerAddress
        );
    }

    function _configureDiamond() internal {
        _configureOperationFees();
        _configureSystemPlatforms();
        _configureKeyTypesAndSigningAlgos();
        _configureExtensionKeyTypes();
    }

    function _configureOperationFees() internal {
        OperationFeeConfig[] memory fees = abi.decode(
            vm.parseJson(config, ".teeOperationFees"),
            (OperationFeeConfig[])
        );
        if (fees.length == 0) return;

        bytes32[] memory opTypes = new bytes32[](fees.length);
        bytes32[] memory opCommands = new bytes32[](fees.length);
        uint256[] memory feeValues = new uint256[](fees.length);

        for (uint256 i = 0; i < fees.length; i++) {
            opTypes[i] = bytes32(bytes(fees[i].opType));
            opCommands[i] = bytes32(bytes(fees[i].opCommand));
            feeValues[i] = vm.parseUint(fees[i].feeWei);
        }

        console2.log("Setting operation fees, count:", fees.length);
        flareTeeManager.setOperationFees(opTypes, opCommands, feeValues);
    }

    function _configureSystemPlatforms() internal {
        string[] memory platforms = abi.decode(
            vm.parseJson(config, ".teeSupportedPlatforms"),
            (string[])
        );
        if (platforms.length == 0) return;

        bytes32[] memory platformBytes = new bytes32[](platforms.length);
        for (uint256 i = 0; i < platforms.length; i++) {
            platformBytes[i] = bytes32(bytes(platforms[i]));
        }

        console2.log(
            "Adding system supported platforms, count:",
            platforms.length
        );
        flareTeeManager.addSystemSupportedPlatforms(platformBytes);
    }

    function _configureKeyTypesAndSigningAlgos() internal {
        KeyTypeWithSigningAlgos[] memory keyTypes = abi.decode(
            vm.parseJson(
                config, ".teeSupportedKeyTypesWithSigningAlgos"
            ),
            (KeyTypeWithSigningAlgos[])
        );
        if (keyTypes.length == 0) return;

        bytes32[] memory keyTypeBytes = new bytes32[](keyTypes.length);
        bytes32[][] memory signingAlgosBytes =
            new bytes32[][](keyTypes.length);

        for (uint256 i = 0; i < keyTypes.length; i++) {
            keyTypeBytes[i] = bytes32(bytes(keyTypes[i].keyType));
            signingAlgosBytes[i] =
                new bytes32[](keyTypes[i].signingAlgos.length);
            for (uint256 j = 0; j < keyTypes[i].signingAlgos.length; j++) {
                signingAlgosBytes[i][j] =
                    bytes32(bytes(keyTypes[i].signingAlgos[j]));
            }
        }

        console2.log(
            "Adding system supported key types, count:",
            keyTypes.length
        );
        flareTeeManager.addSystemSupportedKeyTypesAndSigningAlgos(
            keyTypeBytes, signingAlgosBytes
        );
    }

    function _configureExtensionKeyTypes() internal {
        PaymentConfiguration[] memory paymentConfigs = abi.decode(
            vm.parseJson(config, ".teePaymentConfigurations"),
            (PaymentConfiguration[])
        );
        if (paymentConfigs.length == 0) return;

        // collect unique key types
        bytes32[] memory tempKeyTypes =
            new bytes32[](paymentConfigs.length);
        uint256 uniqueCount = 0;
        for (uint256 i = 0; i < paymentConfigs.length; i++) {
            bytes32 kt = bytes32(bytes(paymentConfigs[i].keyType));
            bool found = false;
            for (uint256 j = 0; j < uniqueCount; j++) {
                if (tempKeyTypes[j] == kt) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                tempKeyTypes[uniqueCount] = kt;
                uniqueCount++;
            }
        }

        bytes32[] memory uniqueKeyTypes = new bytes32[](uniqueCount);
        for (uint256 i = 0; i < uniqueCount; i++) {
            uniqueKeyTypes[i] = tempKeyTypes[i];
        }

        console2.log(
            "Adding extension supported key types (system ext 0), count:",
            uniqueCount
        );
        flareTeeManager.addSupportedKeyTypes(0, uniqueKeyTypes);
    }

    // =========================================================================
    // Later facets (replication, governance, version manager)
    // =========================================================================

    function _deployLaterFacets() internal {
        teeReplicationFacet = new TeeReplicationFacet();
        teeGovernanceFacet = new TeeGovernanceFacet();
        teeVersionManagerFacet = new TeeVersionManagerFacet();

        laterFacets.push(_addFacet(
            address(teeReplicationFacet), "TeeReplicationFacet"
        ));
        laterFacets.push(_addFacet(
            address(teeGovernanceFacet), "TeeGovernanceFacet"
        ));
        laterFacets.push(_addFacet(
            address(teeVersionManagerFacet), "TeeVersionManagerFacet"
        ));
    }

    function _addLaterFacetsToDiamond() internal {
        uint256 pauseBeforeUpgradeMinDurationSeconds =
            vm.parseJsonUint(
                config, ".teePauseBeforeUpgradeMinDurationSeconds"
            );
        TeeReplicationInit teeReplicationInit = new TeeReplicationInit();
        IDiamondCut(flareTeeManagerAddress).diamondCut(
            laterFacets,
            address(teeReplicationInit),
            abi.encodeWithSelector(
                TeeReplicationInit.init.selector,
                pauseBeforeUpgradeMinDurationSeconds
            )
        );

        _logDeployed(
            "TeeReplicationInit",
            "TeeReplicationInit.sol",
            address(teeReplicationInit)
        );
    }

    // =========================================================================
    // Deploy FDC2 contracts
    // =========================================================================

    function _deployFdc2Contracts() internal {
        uint16 fdc2MinThresholdBIPS =
            uint16(vm.parseJsonUint(config, ".fdc2MinThresholdBIPS"));
        uint8 fdc2DefaultNumberOfTees =
            uint8(vm.parseJsonUint(config, ".fdc2DefaultNumberOfTees"));

        // Fdc2Hub
        Fdc2Hub fdc2HubImpl = new Fdc2Hub();
        _logDeployed(
            "Fdc2HubImplementation", "Fdc2Hub.sol", address(fdc2HubImpl)
        );
        Fdc2HubProxy fdc2HubProxy = new Fdc2HubProxy(
            IGovernanceSettings(governanceSettings),
            deployer,
            deployer,
            fdc2MinThresholdBIPS,
            fdc2DefaultNumberOfTees,
            address(fdc2HubImpl)
        );
        fdc2HubAddr = address(fdc2HubProxy);
        _logDeployed("Fdc2Hub", "Fdc2HubProxy.sol", fdc2HubAddr);

        // Fdc2RequestFeeConfigurations
        Fdc2RequestFeeConfigurations fdc2FeeImpl =
            new Fdc2RequestFeeConfigurations();
        _logDeployed(
            "Fdc2RequestFeeConfigurationsImplementation",
            "Fdc2RequestFeeConfigurations.sol",
            address(fdc2FeeImpl)
        );
        Fdc2RequestFeeConfigurationsProxy fdc2FeeProxy =
            new Fdc2RequestFeeConfigurationsProxy(
                IGovernanceSettings(governanceSettings),
                deployer,
                address(fdc2FeeImpl)
            );
        fdc2FeeAddr = address(fdc2FeeProxy);
        _logDeployed(
            "Fdc2RequestFeeConfigurations",
            "Fdc2RequestFeeConfigurationsProxy.sol",
            fdc2FeeAddr
        );

        // Fdc2Verification
        Fdc2Verification fdc2VerificationImpl = new Fdc2Verification();
        _logDeployed(
            "Fdc2VerificationImplementation",
            "Fdc2Verification.sol",
            address(fdc2VerificationImpl)
        );
        Fdc2VerificationProxy fdc2VerProxy = new Fdc2VerificationProxy(
            IGovernanceSettings(governanceSettings),
            deployer,
            deployer,
            address(fdc2VerificationImpl)
        );
        fdc2VerificationAddr = address(fdc2VerProxy);
        _logDeployed(
            "Fdc2Verification",
            "Fdc2VerificationProxy.sol",
            fdc2VerificationAddr
        );
    }

    // =========================================================================
    // Deploy TeePayments (one impl, N proxies from config)
    // =========================================================================

    function _deployTeePayments() internal {
        PaymentConfiguration[] memory paymentConfigs = abi.decode(
            vm.parseJson(config, ".teePaymentConfigurations"),
            (PaymentConfiguration[])
        );

        TeePayments teePaymentsImpl = new TeePayments();
        _logDeployed(
            "TeePaymentsImplementation",
            "TeePayments.sol",
            address(teePaymentsImpl)
        );

        for (uint256 i = 0; i < paymentConfigs.length; i++) {
            address proxyAddr = _deployTeePaymentsProxy(
                paymentConfigs[i], address(teePaymentsImpl)
            );
            teePaymentsAddresses.push(proxyAddr);
            _logDeployed(
                string.concat(
                    "TeePayments_", paymentConfigs[i].opType
                ),
                "TeePaymentsProxy.sol",
                proxyAddr
            );
        }
    }

    function _deployTeePaymentsProxy(
        PaymentConfiguration memory _pc,
        address _impl
    )
        internal
        returns (address)
    {
        bytes32 opType = bytes32(bytes(_pc.opType));
        bytes32 keyType = bytes32(bytes(_pc.keyType));
        bytes32[] memory sourceIds = new bytes32[](_pc.sourceIds.length);
        for (uint256 j = 0; j < _pc.sourceIds.length; j++) {
            sourceIds[j] = bytes32(bytes(_pc.sourceIds[j]));
        }

        TeePaymentsProxy proxy = new TeePaymentsProxy(
            IGovernanceSettings(governanceSettings),
            deployer,
            deployer,
            uint64(_pc.maxBatchSize),
            uint64(_pc.maxBatchDurationSeconds),
            opType,
            keyType,
            sourceIds,
            _impl
        );
        return address(proxy);
    }

    // =========================================================================
    // Deploy TeeRewardOffersManager
    // =========================================================================

    function _deployTeeRewardOffersManager() internal {
        uint24 teeOwnersPPM =
            uint24(vm.parseJsonUint(config, ".teeOwnersPPM"));

        TeeRewardOffersManager mgr = new TeeRewardOffersManager(
            IGovernanceSettings(governanceSettings),
            deployer,
            deployer,
            teeOwnersPPM
        );
        teeRewardOffersManagerAddr = address(mgr);
        _logDeployed(
            "TeeRewardOffersManager",
            "TeeRewardOffersManager.sol",
            teeRewardOffersManagerAddr
        );
    }

    // =========================================================================
    // Deploy VrfVerifier
    // =========================================================================

    function _deployVrfVerifier() internal {
        VrfVerifier vrfVerifier = new VrfVerifier();
        _logDeployed(
            "VrfVerifier", "VrfVerifier.sol", address(vrfVerifier)
        );
    }

    // =========================================================================
    // Wire up contract addresses
    // =========================================================================

    function _wireUpContractAddresses() internal {
        _wireFlareTeeManager();
        _wireFdc2Hub();
        _wireFdc2Verification();
        _wireTeePayments();
        _wireTeeRewardOffersManager();
    }

    function _wireFlareTeeManager() internal {
        bytes32[] memory names = new bytes32[](6);
        names[0] = _encodeContractName("AddressUpdater");
        names[1] = _encodeContractName("FlareSystemsManager");
        names[2] = _encodeContractName("RewardManager");
        names[3] = _encodeContractName("Relay");
        names[4] = _encodeContractName("Fdc2Hub");
        names[5] = _encodeContractName("Fdc2Verification");
        address[] memory addrs = new address[](6);
        addrs[0] = addressUpdater;
        addrs[1] = flareSystemsManager;
        addrs[2] = rewardManager;
        addrs[3] = relay;
        addrs[4] = fdc2HubAddr;
        addrs[5] = fdc2VerificationAddr;
        TeeAddressUpdatableFacet(flareTeeManagerAddress)
            .updateContractAddresses(names, addrs);
    }

    function _wireFdc2Hub() internal {
        bytes32[] memory names = new bytes32[](5);
        names[0] = _encodeContractName("AddressUpdater");
        names[1] = _encodeContractName("FlareTeeManager");
        names[2] = _encodeContractName("FlareSystemsManager");
        names[3] = _encodeContractName("RewardManager");
        names[4] = _encodeContractName("Fdc2RequestFeeConfigurations");
        address[] memory addrs = new address[](5);
        addrs[0] = addressUpdater;
        addrs[1] = flareTeeManagerAddress;
        addrs[2] = flareSystemsManager;
        addrs[3] = rewardManager;
        addrs[4] = fdc2FeeAddr;
        Fdc2Hub(fdc2HubAddr).updateContractAddresses(names, addrs);
    }

    function _wireFdc2Verification() internal {
        bytes32[] memory names = new bytes32[](3);
        names[0] = _encodeContractName("AddressUpdater");
        names[1] = _encodeContractName("FlareTeeManager");
        names[2] = _encodeContractName("Relay");
        address[] memory addrs = new address[](3);
        addrs[0] = addressUpdater;
        addrs[1] = flareTeeManagerAddress;
        addrs[2] = relay;
        Fdc2Verification(fdc2VerificationAddr)
            .updateContractAddresses(names, addrs);
    }

    function _wireTeePayments() internal {
        bytes32[] memory names = new bytes32[](3);
        names[0] = _encodeContractName("AddressUpdater");
        names[1] = _encodeContractName("FlareTeeManager");
        names[2] = _encodeContractName("FlareSystemsManager");
        address[] memory addrs = new address[](3);
        addrs[0] = addressUpdater;
        addrs[1] = flareTeeManagerAddress;
        addrs[2] = flareSystemsManager;
        for (uint256 i = 0; i < teePaymentsAddresses.length; i++) {
            TeePayments(teePaymentsAddresses[i])
                .updateContractAddresses(names, addrs);
        }
    }

    function _wireTeeRewardOffersManager() internal {
        bytes32[] memory names = new bytes32[](4);
        names[0] = _encodeContractName("AddressUpdater");
        names[1] = _encodeContractName("RewardManager");
        names[2] = _encodeContractName("FlareSystemsManager");
        names[3] = _encodeContractName("Inflation");
        address[] memory addrs = new address[](4);
        addrs[0] = addressUpdater;
        addrs[1] = rewardManager;
        addrs[2] = flareSystemsManager;
        addrs[3] = inflation;
        TeeRewardOffersManager(teeRewardOffersManagerAddr)
            .updateContractAddresses(names, addrs);
    }

    // =========================================================================
    // Register system instructions senders
    // =========================================================================

    function _registerSystemInstructionsSenders() internal {
        address[] memory senders =
            new address[](teePaymentsAddresses.length + 1);
        for (uint256 i = 0; i < teePaymentsAddresses.length; i++) {
            senders[i] = teePaymentsAddresses[i];
        }
        senders[teePaymentsAddresses.length] = fdc2HubAddr;
        TeeExtensionRegistryFacet(flareTeeManagerAddress)
            .registerSystemInstructionsSenders(senders);
    }

    // =========================================================================
    // Set FDC2 request fee configurations
    // =========================================================================

    function _configureFdc2RequestFees() internal {
        Fdc2RequestFee[] memory fees = abi.decode(
            vm.parseJson(config, ".fdc2RequestFees"),
            (Fdc2RequestFee[])
        );
        for (uint256 i = 0; i < fees.length; i++) {
            Fdc2RequestFeeConfigurations(fdc2FeeAddr).setTypeAndSourceFee(
                bytes32(bytes(fees[i].attestationType)),
                bytes32(bytes(fees[i].source)),
                vm.parseUint(fees[i].feeWei)
            );
        }
    }

    // =========================================================================
    // Contract name encoding (matches TS: keccak256(abi.encode(name)))
    // =========================================================================

    function _encodeContractName(
        string memory _name
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_name));
    }

    // =========================================================================
    // Logging (format matches save-deployed-addresses.ts parser)
    // =========================================================================

    function _logDeployed(
        string memory _name,
        string memory _contractName,
        address _addr
    )
        internal
        view
    {
        console2.log(
            string.concat(
                "DEPLOYED: ", _name, ", ", _contractName, ": ",
                vm.toString(_addr)
            )
        );
    }

    function _logDay1FacetAddresses() internal view {
        _logDeployed(
            "FlareTeeManagerDiamondCutFacet",
            "FlareTeeManagerDiamondCutFacet.sol",
            address(diamondCutFacet)
        );
        _logDeployed(
            "DiamondLoupeFacet",
            "DiamondLoupeFacet.sol",
            address(diamondLoupeFacet)
        );
        _logDeployed(
            "TeeExtensionRegistryFacet",
            "TeeExtensionRegistryFacet.sol",
            address(teeExtensionRegistryFacet)
        );
        _logDeployed(
            "TeeMachineRegistryFacet",
            "TeeMachineRegistryFacet.sol",
            address(teeMachineRegistryFacet)
        );
        _logDeployed(
            "TeeVerificationFacet",
            "TeeVerificationFacet.sol",
            address(teeVerificationFacet)
        );
        _logDeployed(
            "TeeWalletVerificationFacet",
            "TeeWalletVerificationFacet.sol",
            address(teeWalletVerificationFacet)
        );
        _logDeployed(
            "TeeFeeCalculatorFacet",
            "TeeFeeCalculatorFacet.sol",
            address(teeFeeCalculatorFacet)
        );
        _logDeployed(
            "TeeOwnerAllowlistFacet",
            "TeeOwnerAllowlistFacet.sol",
            address(teeOwnerAllowlistFacet)
        );
        _logDeployed(
            "TeeSystemStateVerifierFacet",
            "TeeSystemStateVerifierFacet.sol",
            address(teeSystemStateVerifierFacet)
        );
        _logDeployed(
            "TeeWalletManagerFacet",
            "TeeWalletManagerFacet.sol",
            address(teeWalletManagerFacet)
        );
        _logDeployed(
            "TeeWalletKeyManagerFacet",
            "TeeWalletKeyManagerFacet.sol",
            address(teeWalletKeyManagerFacet)
        );
        _logDeployed(
            "TeeWalletProjectManagerFacet",
            "TeeWalletProjectManagerFacet.sol",
            address(teeWalletProjectManagerFacet)
        );
        _logDeployed(
            "TeeWalletBackupManagerFacet",
            "TeeWalletBackupManagerFacet.sol",
            address(teeWalletBackupManagerFacet)
        );
        _logDeployed(
            "TeeVrfFacet",
            "TeeVrfFacet.sol",
            address(teeVrfFacet)
        );
        _logDeployed(
            "TeeAddressUpdatableFacet",
            "TeeAddressUpdatableFacet.sol",
            address(teeAddressUpdatableFacet)
        );
    }

    function _logLaterFacetAddresses() internal view {
        _logDeployed(
            "TeeReplicationFacet",
            "TeeReplicationFacet.sol",
            address(teeReplicationFacet)
        );
        _logDeployed(
            "TeeGovernanceFacet",
            "TeeGovernanceFacet.sol",
            address(teeGovernanceFacet)
        );
        _logDeployed(
            "TeeVersionManagerFacet",
            "TeeVersionManagerFacet.sol",
            address(teeVersionManagerFacet)
        );
    }

    // =========================================================================
    // Deploys file reader
    // =========================================================================

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
}
