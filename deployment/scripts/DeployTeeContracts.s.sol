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
import {IIFlareTeeManager} from
    "../../contracts/tee/interface/IIFlareTeeManager.sol";
import {FlareTeeManager} from
    "../../contracts/tee/diamond/FlareTeeManager.sol";
// Diamond init contracts
import {FlareTeeManagerInit} from
    "../../contracts/tee/facets/FlareTeeManagerInit.sol";
// Facets
import {DiamondGovernanceFacet} from
    "../../contracts/tee/facets/DiamondGovernanceFacet.sol";
import {DiamondLoupeFacet} from
    "../../contracts/diamond/facets/DiamondLoupeFacet.sol";
import {ExtensionManagerFacet} from
    "../../contracts/tee/facets/ExtensionManagerFacet.sol";
import {InstructionsFacet} from
    "../../contracts/tee/facets/InstructionsFacet.sol";
import {MachineManagerFacet} from
    "../../contracts/tee/facets/MachineManagerFacet.sol";
import {VerificationFacet} from
    "../../contracts/tee/facets/VerificationFacet.sol";
import {OperationFeesFacet} from
    "../../contracts/tee/facets/OperationFeesFacet.sol";
import {OwnerAllowlistFacet} from
    "../../contracts/tee/facets/OwnerAllowlistFacet.sol";
import {WalletManagerFacet} from
    "../../contracts/tee/facets/WalletManagerFacet.sol";
import {WalletKeyManagerFacet} from
    "../../contracts/tee/facets/WalletKeyManagerFacet.sol";
import {WalletProjectManagerFacet} from
    "../../contracts/tee/facets/WalletProjectManagerFacet.sol";
import {WalletBackupManagerFacet} from
    "../../contracts/tee/facets/WalletBackupManagerFacet.sol";
import {VrfFacet} from "../../contracts/tee/facets/VrfFacet.sol";
import {ExternalAddressesFacet} from
    "../../contracts/tee/facets/ExternalAddressesFacet.sol";
import {ExtensionGovernanceFacet} from
    "../../contracts/tee/facets/ExtensionGovernanceFacet.sol";
import {MachinePathManagerFacet} from
    "../../contracts/tee/facets/MachinePathManagerFacet.sol";
import {WalletProjectPauseFacet} from
    "../../contracts/tee/facets/WalletProjectPauseFacet.sol";
import {MachineEmergencyPauseFacet} from
    "../../contracts/tee/facets/MachineEmergencyPauseFacet.sol";
// FDC2 contracts
import {Fdc2Hub} from "../../contracts/fdc2/implementation/Fdc2Hub.sol";
import {Fdc2HubProxy} from "../../contracts/fdc2/proxy/Fdc2HubProxy.sol";
import {Fdc2InflationConfigurations} from
    "../../contracts/fdc2/implementation/Fdc2InflationConfigurations.sol";
import {Fdc2InflationConfigurationsProxy} from
    "../../contracts/fdc2/proxy/Fdc2InflationConfigurationsProxy.sol";
import {IFdc2InflationConfigurations} from
    "../../contracts/userInterfaces/fdc2/IFdc2InflationConfigurations.sol";
import {Fdc2RequestFeeConfigurations} from
    "../../contracts/fdc2/implementation/Fdc2RequestFeeConfigurations.sol";
import {Fdc2RequestFeeConfigurationsProxy} from
    "../../contracts/fdc2/proxy/Fdc2RequestFeeConfigurationsProxy.sol";
import {Fdc2RewardOffersManager} from
    "../../contracts/fdc2/implementation/Fdc2RewardOffersManager.sol";
import {Fdc2RewardOffersManagerProxy} from
    "../../contracts/fdc2/proxy/Fdc2RewardOffersManagerProxy.sol";
import {Fdc2Verification} from
    "../../contracts/fdc2/implementation/Fdc2Verification.sol";
import {Fdc2VerificationProxy} from
    "../../contracts/fdc2/proxy/Fdc2VerificationProxy.sol";
// TEE UUPS contracts
import {TeePayments} from "../../contracts/tee/implementation/TeePayments.sol";
import {TeePaymentsUtxo} from
    "../../contracts/tee/implementation/TeePaymentsUtxo.sol";
import {TeePaymentsProxy} from "../../contracts/tee/proxy/TeePaymentsProxy.sol";
import {TeePaymentsConfigVerifier} from
    "../../contracts/tee/implementation/TeePaymentsConfigVerifier.sol";
import {TeePaymentsConfigVerifierProxy} from
    "../../contracts/tee/proxy/TeePaymentsConfigVerifierProxy.sol";
import {TeePaymentsFeeScheduleManager} from
    "../../contracts/tee/implementation/TeePaymentsFeeScheduleManager.sol";
import {TeePaymentsFeeScheduleManagerProxy} from
    "../../contracts/tee/proxy/TeePaymentsFeeScheduleManagerProxy.sol";
import {ITeePaymentsFeeScheduleManager} from
    "../../contracts/userInterfaces/tee/ITeePaymentsFeeScheduleManager.sol";
import {TeePaymentsRegistry} from
    "../../contracts/tee/implementation/TeePaymentsRegistry.sol";
import {TeePaymentsRegistryProxy} from
    "../../contracts/tee/proxy/TeePaymentsRegistryProxy.sol";
import {ITeePaymentsRegistry} from
    "../../contracts/userInterfaces/tee/ITeePaymentsRegistry.sol";
import {PaymentModel} from
    "../../contracts/userInterfaces/tee/ITeePaymentsModel.sol";
import {TeeRewardOffersManager} from
    "../../contracts/tee/implementation/TeeRewardOffersManager.sol";
import {TeeRewardOffersManagerProxy} from
    "../../contracts/tee/proxy/TeeRewardOffersManagerProxy.sol";
import {VrfVerifier} from "../../contracts/tee/implementation/VrfVerifier.sol";

// solhint-disable no-console
// solhint-disable-next-line max-line-length
// forge script deployment/scripts/DeployTeeContracts.s.sol:DeployTeeContracts --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast --sig "run()"

// solhint-disable max-states-count
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

    // NOTE: stdJson parses struct fields in alphabetical order of JSON keys.
    // Keep field names alphabetical: maxFeeDelaySeconds, maxFeeSchedules, sourceId.
    struct PaymentSourceConfig {
        uint256 maxFeeDelaySeconds;
        uint256 maxFeeSchedules;
        string sourceId;
    }

    struct PaymentConfiguration {
        string keyType;
        uint256 maxBatchDurationSeconds;
        uint256 maxBatchSize;
        string opType;
        string paymentModel;
        PaymentSourceConfig[] sourceConfigs;
    }

    struct Fdc2RequestFee {
        string attestationType;
        string feeWei;
        string source;
    }

    // NOTE: stdJson parses struct fields in alphabetical order of JSON keys.
    // Keep field names alphabetical: attestationType, inflationShare, minRequestsThreshold, mode, source.
    struct Fdc2InflationConfig {
        string attestationType;
        uint256 inflationShare;
        uint256 minRequestsThreshold;
        uint256 mode;
        string source;
    }

    // Well-known FlareContractRegistry address (same on all Flare networks)
    IFlareContractRegistry private constant FLARE_CONTRACT_REGISTRY =
        IFlareContractRegistry(0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019);

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
    IDiamond.FacetCut[] private facets;

    // Facet instances (for logging)
    DiamondGovernanceFacet private diamondCutFacet;
    DiamondLoupeFacet private diamondLoupeFacet;
    ExtensionManagerFacet private extensionManagerFacet;
    InstructionsFacet private instructionsFacet;
    MachineManagerFacet private machineManagerFacet;
    VerificationFacet private verificationFacet;
    OperationFeesFacet private operationFeesFacet;
    OwnerAllowlistFacet private ownerAllowlistFacet;
    WalletManagerFacet private walletManagerFacet;
    WalletKeyManagerFacet private walletKeyManagerFacet;
    WalletProjectManagerFacet private walletProjectManagerFacet;
    WalletBackupManagerFacet private walletBackupManagerFacet;
    VrfFacet private vrfFacet;
    ExternalAddressesFacet private externalAddressesFacet;
    ExtensionGovernanceFacet private extensionGovernanceFacet;
    MachinePathManagerFacet private machinePathManagerFacet;
    WalletProjectPauseFacet private walletProjectPauseFacet;
    MachineEmergencyPauseFacet private machineEmergencyPauseFacet;

    // Deployed contract addresses
    address private fdc2HubAddr;
    address private fdc2FeeAddr;
    address private fdc2InflationConfigurationsAddr;
    address private fdc2RewardOffersManagerAddr;
    address private fdc2VerificationAddr;
    address[] private teePaymentsAddresses;
    address private teeRewardOffersManagerAddr;
    address private teePaymentsFeeScheduleManagerAddr;
    address private teePaymentsRegistryAddr;
    address private teePaymentsConfigVerifierAddr;

    // Registry entries — one entry per configured sourceId across all TeePayments proxies.
    ITeePaymentsRegistry.SourceRegistration[] private sourceRegistrations;

    // =========================================================================
    // Entry point
    // =========================================================================

    function run() external {
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
        _deployFacets();
        _logFacetAddresses();
        _createDiamond();
        _configureDiamond();

        // Phase 2: Deploy remaining TEE contracts
        _deployFdc2Contracts();
        _deployTeePaymentsRegistry();
        _deployTeePaymentsConfigVerifier();
        _deployTeePayments();
        _deployTeePaymentsFeeScheduleManager();
        _deployTeeRewardOffersManager();
        _deployFdc2InflationConfigurations();
        _deployFdc2RewardOffersManager();
        _deployVrfVerifier();

        // Phase 3: Wire up and configure
        _wireUpContractAddresses();
        _registerSystemInstructionsSenders();
        _configureFdc2RequestFees();
        _configureFdc2InflationConfigurations();
        _registerTeePaymentsSources();
        _configureUtxoBatchSettings();
        _configureFeeScheduleSourceLimits();

        // Phase 4: Switch all governed contracts to production mode
        _switchToProductionMode();

        vm.stopBroadcast();
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

    function _deployFacets() internal {
        diamondCutFacet = new DiamondGovernanceFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        extensionManagerFacet = new ExtensionManagerFacet();
        instructionsFacet = new InstructionsFacet();
        machineManagerFacet = new MachineManagerFacet();
        verificationFacet = new VerificationFacet();
        operationFeesFacet = new OperationFeesFacet();
        ownerAllowlistFacet = new OwnerAllowlistFacet();
        walletManagerFacet = new WalletManagerFacet();
        walletKeyManagerFacet = new WalletKeyManagerFacet();
        walletProjectManagerFacet = new WalletProjectManagerFacet();
        walletBackupManagerFacet = new WalletBackupManagerFacet();
        vrfFacet = new VrfFacet();
        externalAddressesFacet = new ExternalAddressesFacet();
        extensionGovernanceFacet = new ExtensionGovernanceFacet();
        machinePathManagerFacet = new MachinePathManagerFacet();
        walletProjectPauseFacet = new WalletProjectPauseFacet();
        machineEmergencyPauseFacet = new MachineEmergencyPauseFacet();

        facets.push(_addFacet(
            address(diamondCutFacet), "DiamondGovernanceFacet"
        ));
        facets.push(_addFacet(
            address(diamondLoupeFacet), "DiamondLoupeFacet"
        ));
        facets.push(_addFacet(
            address(extensionManagerFacet), "ExtensionManagerFacet"
        ));
        facets.push(_addFacet(
            address(instructionsFacet), "InstructionsFacet"
        ));
        facets.push(_addFacet(
            address(machineManagerFacet), "MachineManagerFacet"
        ));
        facets.push(_addFacet(
            address(verificationFacet), "VerificationFacet"
        ));
        facets.push(_addFacet(
            address(operationFeesFacet), "OperationFeesFacet"
        ));
        facets.push(_addFacet(
            address(ownerAllowlistFacet), "OwnerAllowlistFacet"
        ));
        facets.push(_addFacet(
            address(walletManagerFacet), "WalletManagerFacet"
        ));
        facets.push(_addFacet(
            address(walletKeyManagerFacet), "WalletKeyManagerFacet"
        ));
        facets.push(_addFacet(
            address(walletProjectManagerFacet),
            "WalletProjectManagerFacet"
        ));
        facets.push(_addFacet(
            address(walletBackupManagerFacet),
            "WalletBackupManagerFacet"
        ));
        facets.push(_addFacet(
            address(vrfFacet), "VrfFacet"
        ));
        facets.push(_addFacet(
            address(externalAddressesFacet), "ExternalAddressesFacet"
        ));
        facets.push(_addFacet(
            address(extensionGovernanceFacet), "ExtensionGovernanceFacet"
        ));
        facets.push(_addFacet(
            address(machinePathManagerFacet), "MachinePathManagerFacet"
        ));
        facets.push(_addFacet(
            address(walletProjectPauseFacet), "WalletProjectPauseFacet"
        ));
        facets.push(_addFacet(
            address(machineEmergencyPauseFacet), "MachineEmergencyPauseFacet"
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
        bool publicExtensionCreationEnabled =
            vm.parseJsonBool(config, ".teePublicExtensionCreationEnabled");
        uint256 emergencyUnpauseGracePeriodSeconds =
            vm.parseJsonUint(config, ".teeEmergencyUnpauseGracePeriodSeconds");

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
            defaultFeeWei,
            publicExtensionCreationEnabled,
            emergencyUnpauseGracePeriodSeconds
        );

        FlareTeeManager diamond = new FlareTeeManager(
            facets,
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

        console2.log(
            "Adding system extension (ext 0) supported key types, count:",
            keyTypes.length
        );
        flareTeeManager.addSupportedKeyTypes(0, keyTypeBytes);
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
        TeePaymentsUtxo teePaymentsUtxoImpl = new TeePaymentsUtxo();
        _logDeployed(
            "TeePaymentsImplementation",
            "TeePayments.sol",
            address(teePaymentsImpl)
        );
        _logDeployed(
            "TeePaymentsUtxoImplementation",
            "TeePaymentsUtxo.sol",
            address(teePaymentsUtxoImpl)
        );

        for (uint256 i = 0; i < paymentConfigs.length; i++) {
            PaymentModel model = _paymentModel(paymentConfigs[i].paymentModel);
            address implementation = model == PaymentModel.UTXO
                ? address(teePaymentsUtxoImpl)
                : address(teePaymentsImpl);
            address proxyAddr = _deployTeePaymentsProxy(
                implementation
            );
            teePaymentsAddresses.push(proxyAddr);
            _logDeployed(
                string.concat(
                    "TeePayments_", paymentConfigs[i].opType
                ),
                "TeePaymentsProxy.sol",
                proxyAddr
            );

            // Track sourceId -> TeePayments binding for the registry.
            for (
                uint256 j = 0;
                j < paymentConfigs[i].sourceConfigs.length;
                j++
            ) {
                sourceRegistrations.push(
                    ITeePaymentsRegistry.SourceRegistration({
                        keyType: bytes32(bytes(paymentConfigs[i].keyType)),
                        opType: bytes32(bytes(paymentConfigs[i].opType)),
                        paymentModel: model,
                        sourceId: bytes32(
                            bytes(paymentConfigs[i].sourceConfigs[j].sourceId)
                        ),
                        teePayments: proxyAddr
                    })
                );
            }
        }
    }

    function _deployTeePaymentsProxy(
        address _impl
    )
        internal
        returns (address)
    {
        TeePaymentsProxy proxy = new TeePaymentsProxy(
            IGovernanceSettings(governanceSettings),
            deployer,
            deployer,
            _impl
        );
        return address(proxy);
    }

    // =========================================================================
    // Deploy Fdc2InflationConfigurations
    // =========================================================================

    function _deployFdc2InflationConfigurations() internal {
        Fdc2InflationConfigurations impl = new Fdc2InflationConfigurations();
        _logDeployed(
            "Fdc2InflationConfigurationsImplementation",
            "Fdc2InflationConfigurations.sol",
            address(impl)
        );
        Fdc2InflationConfigurationsProxy proxy =
            new Fdc2InflationConfigurationsProxy(
                IGovernanceSettings(governanceSettings),
                deployer,
                deployer,
                address(impl)
            );
        fdc2InflationConfigurationsAddr = address(proxy);
        _logDeployed(
            "Fdc2InflationConfigurations",
            "Fdc2InflationConfigurationsProxy.sol",
            fdc2InflationConfigurationsAddr
        );
    }

    // =========================================================================
    // Deploy Fdc2RewardOffersManager
    // =========================================================================

    function _deployFdc2RewardOffersManager() internal {
        Fdc2RewardOffersManager impl = new Fdc2RewardOffersManager();
        _logDeployed(
            "Fdc2RewardOffersManagerImplementation",
            "Fdc2RewardOffersManager.sol",
            address(impl)
        );
        Fdc2RewardOffersManagerProxy proxy =
            new Fdc2RewardOffersManagerProxy(
                IGovernanceSettings(governanceSettings),
                deployer,
                deployer,
                address(impl)
            );
        fdc2RewardOffersManagerAddr = address(proxy);
        _logDeployed(
            "Fdc2RewardOffersManager",
            "Fdc2RewardOffersManagerProxy.sol",
            fdc2RewardOffersManagerAddr
        );
    }

    // =========================================================================
    // Deploy TeeRewardOffersManager
    // =========================================================================

    function _deployTeeRewardOffersManager() internal {
        uint24 teeOwnersPPM =
            uint24(vm.parseJsonUint(config, ".teeOwnersPPM"));

        TeeRewardOffersManager impl = new TeeRewardOffersManager();
        _logDeployed(
            "TeeRewardOffersManagerImplementation",
            "TeeRewardOffersManager.sol",
            address(impl)
        );
        TeeRewardOffersManagerProxy proxy = new TeeRewardOffersManagerProxy(
            IGovernanceSettings(governanceSettings),
            deployer,
            deployer,
            teeOwnersPPM,
            address(impl)
        );
        teeRewardOffersManagerAddr = address(proxy);
        _logDeployed(
            "TeeRewardOffersManager",
            "TeeRewardOffersManagerProxy.sol",
            teeRewardOffersManagerAddr
        );
    }

    // =========================================================================
    // Deploy TeePaymentsRegistry (always deployed, before TeePayments)
    // =========================================================================

    function _deployTeePaymentsRegistry() internal {
        TeePaymentsRegistry impl = new TeePaymentsRegistry();
        _logDeployed(
            "TeePaymentsRegistryImplementation",
            "TeePaymentsRegistry.sol",
            address(impl)
        );

        TeePaymentsRegistryProxy proxy = new TeePaymentsRegistryProxy(
            IGovernanceSettings(governanceSettings),
            deployer,
            deployer,
            address(impl)
        );
        teePaymentsRegistryAddr = address(proxy);
        _logDeployed(
            "TeePaymentsRegistry",
            "TeePaymentsRegistryProxy.sol",
            teePaymentsRegistryAddr
        );
    }

    // =========================================================================
    // Deploy TeePaymentsFeeScheduleManager (always deployed)
    // =========================================================================

    function _deployTeePaymentsFeeScheduleManager() internal {
        TeePaymentsFeeScheduleManager impl =
            new TeePaymentsFeeScheduleManager();
        _logDeployed(
            "TeePaymentsFeeScheduleManagerImplementation",
            "TeePaymentsFeeScheduleManager.sol",
            address(impl)
        );

        TeePaymentsFeeScheduleManagerProxy proxy =
            new TeePaymentsFeeScheduleManagerProxy(
                IGovernanceSettings(governanceSettings),
                deployer,
                deployer,
                address(impl)
            );
        teePaymentsFeeScheduleManagerAddr = address(proxy);
        _logDeployed(
            "TeePaymentsFeeScheduleManager",
            "TeePaymentsFeeScheduleManagerProxy.sol",
            teePaymentsFeeScheduleManagerAddr
        );
    }

    // =========================================================================
    // Deploy TeePaymentsConfigVerifier (always deployed, before TeePayments)
    // =========================================================================

    function _deployTeePaymentsConfigVerifier() internal {
        TeePaymentsConfigVerifier impl = new TeePaymentsConfigVerifier();
        _logDeployed(
            "TeePaymentsConfigVerifierImplementation",
            "TeePaymentsConfigVerifier.sol",
            address(impl)
        );

        TeePaymentsConfigVerifierProxy proxy =
            new TeePaymentsConfigVerifierProxy(
                IGovernanceSettings(governanceSettings),
                deployer,
                deployer,
                address(impl)
            );
        teePaymentsConfigVerifierAddr = address(proxy);
        _logDeployed(
            "TeePaymentsConfigVerifier",
            "TeePaymentsConfigVerifierProxy.sol",
            teePaymentsConfigVerifierAddr
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
        _wireFdc2InflationConfigurations();
        _wireFdc2RewardOffersManager();
        _wireTeePaymentsConfigVerifier();
        _wireTeePayments();
        _wireTeeRewardOffersManager();
        _wireTeePaymentsFeeScheduleManager();
        _wireTeePaymentsRegistry();
    }

    function _wireTeePaymentsRegistry() internal {
        // Registry has no upstream dependencies; still needs AddressUpdater wired for consistency.
        bytes32[] memory names = new bytes32[](1);
        names[0] = _encodeContractName("AddressUpdater");
        address[] memory addrs = new address[](1);
        addrs[0] = addressUpdater;
        TeePaymentsRegistry(teePaymentsRegistryAddr)
            .updateContractAddresses(names, addrs);
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
        ExternalAddressesFacet(flareTeeManagerAddress)
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
        bytes32[] memory names = new bytes32[](6);
        names[0] = _encodeContractName("AddressUpdater");
        names[1] = _encodeContractName("FlareTeeManager");
        names[2] = _encodeContractName("FlareSystemsManager");
        names[3] = _encodeContractName("TeePaymentsFeeScheduleManager");
        names[4] = _encodeContractName("TeePaymentsRegistry");
        names[5] = _encodeContractName("TeePaymentsConfigVerifier");
        address[] memory addrs = new address[](6);
        addrs[0] = addressUpdater;
        addrs[1] = flareTeeManagerAddress;
        addrs[2] = flareSystemsManager;
        addrs[3] = teePaymentsFeeScheduleManagerAddr;
        addrs[4] = teePaymentsRegistryAddr;
        addrs[5] = teePaymentsConfigVerifierAddr;
        for (uint256 i = 0; i < teePaymentsAddresses.length; i++) {
            TeePayments(teePaymentsAddresses[i])
                .updateContractAddresses(names, addrs);
        }
    }

    function _wireTeePaymentsConfigVerifier() internal {
        bytes32[] memory names = new bytes32[](6);
        names[0] = _encodeContractName("AddressUpdater");
        names[1] = _encodeContractName("FlareTeeManager");
        names[2] = _encodeContractName("FlareSystemsManager");
        names[3] = _encodeContractName("TeePaymentsRegistry");
        names[4] = _encodeContractName("Fdc2Verification");
        names[5] = _encodeContractName("Fdc2Hub");
        address[] memory addrs = new address[](6);
        addrs[0] = addressUpdater;
        addrs[1] = flareTeeManagerAddress;
        addrs[2] = flareSystemsManager;
        addrs[3] = teePaymentsRegistryAddr;
        addrs[4] = fdc2VerificationAddr;
        addrs[5] = fdc2HubAddr;
        TeePaymentsConfigVerifier(teePaymentsConfigVerifierAddr)
            .updateContractAddresses(names, addrs);
    }

    function _wireFdc2InflationConfigurations() internal {
        bytes32[] memory names = new bytes32[](2);
        names[0] = _encodeContractName("AddressUpdater");
        names[1] = _encodeContractName("Fdc2RequestFeeConfigurations");
        address[] memory addrs = new address[](2);
        addrs[0] = addressUpdater;
        addrs[1] = fdc2FeeAddr;
        Fdc2InflationConfigurations(fdc2InflationConfigurationsAddr)
            .updateContractAddresses(names, addrs);
    }

    function _wireFdc2RewardOffersManager() internal {
        bytes32[] memory names = new bytes32[](5);
        names[0] = _encodeContractName("AddressUpdater");
        names[1] = _encodeContractName("RewardManager");
        names[2] = _encodeContractName("FlareSystemsManager");
        names[3] = _encodeContractName("Inflation");
        names[4] = _encodeContractName("Fdc2InflationConfigurations");
        address[] memory addrs = new address[](5);
        addrs[0] = addressUpdater;
        addrs[1] = rewardManager;
        addrs[2] = flareSystemsManager;
        addrs[3] = inflation;
        addrs[4] = fdc2InflationConfigurationsAddr;
        Fdc2RewardOffersManager(fdc2RewardOffersManagerAddr)
            .updateContractAddresses(names, addrs);
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

    function _wireTeePaymentsFeeScheduleManager() internal {
        bytes32[] memory names = new bytes32[](3);
        names[0] = _encodeContractName("AddressUpdater");
        names[1] = _encodeContractName("FlareTeeManager");
        names[2] = _encodeContractName("TeePaymentsRegistry");
        address[] memory addrs = new address[](3);
        addrs[0] = addressUpdater;
        addrs[1] = flareTeeManagerAddress;
        addrs[2] = teePaymentsRegistryAddr;
        TeePaymentsFeeScheduleManager(teePaymentsFeeScheduleManagerAddr)
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
        console2.log(
            "Registering system instructions senders, count:",
            senders.length
        );
        InstructionsFacet(flareTeeManagerAddress)
            .registerSystemInstructionsSenders(senders);
    }

    // =========================================================================
    // Configure TeePaymentsFeeScheduleManager per-source limits
    // =========================================================================

    function _configureUtxoBatchSettings() internal {
        PaymentConfiguration[] memory paymentConfigs = abi.decode(
            vm.parseJson(config, ".teePaymentConfigurations"),
            (PaymentConfiguration[])
        );

        for (uint256 i = 0; i < paymentConfigs.length; i++) {
            if (_paymentModel(paymentConfigs[i].paymentModel) != PaymentModel.UTXO) {
                continue;
            }
            for (uint256 j = 0; j < paymentConfigs[i].sourceConfigs.length; j++) {
                PaymentSourceConfig memory src = paymentConfigs[i].sourceConfigs[j];
                bytes32 sourceId = bytes32(bytes(src.sourceId));
                address teePayments =
                    TeePaymentsRegistry(teePaymentsRegistryAddr)
                        .getTeePaymentsForSource(sourceId);
                TeePaymentsUtxo(teePayments).setMaxBatchSettings(
                    sourceId,
                    uint64(paymentConfigs[i].maxBatchSize),
                    uint64(paymentConfigs[i].maxBatchDurationSeconds)
                );
            }
        }
    }

    function _configureFeeScheduleSourceLimits() internal {
        PaymentConfiguration[] memory paymentConfigs = abi.decode(
            vm.parseJson(config, ".teePaymentConfigurations"),
            (PaymentConfiguration[])
        );

        uint256 totalSources;
        for (uint256 i = 0; i < paymentConfigs.length; i++) {
            if (_paymentModel(paymentConfigs[i].paymentModel) != PaymentModel.ACCOUNT) {
                continue;
            }
            totalSources += paymentConfigs[i].sourceConfigs.length;
        }
        if (totalSources == 0) return;

        ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[] memory inputs =
            new ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[](
                totalSources
        );
        uint256 k;
        for (uint256 i = 0; i < paymentConfigs.length; i++) {
            if (_paymentModel(paymentConfigs[i].paymentModel) != PaymentModel.ACCOUNT) {
                continue;
            }
            for (uint256 j = 0; j < paymentConfigs[i].sourceConfigs.length; j++) {
                PaymentSourceConfig memory src = paymentConfigs[i].sourceConfigs[j];
                inputs[k++] = ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput({
                    maxDelaySeconds: uint16(src.maxFeeDelaySeconds),
                    maxSchedules: uint8(src.maxFeeSchedules),
                    sourceId: bytes32(bytes(src.sourceId))
                });
            }
        }

        console2.log(
            "Setting fee schedule source config, count:", totalSources
        );
        TeePaymentsFeeScheduleManager(teePaymentsFeeScheduleManagerAddr)
            .setFeeScheduleConfigs(inputs);
    }

    // =========================================================================
    // Register sourceId -> TeePayments in the registry (single batch call)
    // =========================================================================

    function _registerTeePaymentsSources() internal {
        if (sourceRegistrations.length == 0) return;

        ITeePaymentsRegistry.SourceRegistration[] memory inputs =
            new ITeePaymentsRegistry.SourceRegistration[](
                sourceRegistrations.length
            );
        for (uint256 i = 0; i < sourceRegistrations.length; i++) {
            inputs[i] = sourceRegistrations[i];
        }

        console2.log(
            "Registering sourceIds in TeePaymentsRegistry, count:",
            sourceRegistrations.length
        );
        TeePaymentsRegistry(teePaymentsRegistryAddr)
            .registerSources(inputs);
    }

    // =========================================================================
    // Set FDC2 request fee configurations
    // =========================================================================

    function _configureFdc2RequestFees() internal {
        Fdc2RequestFee[] memory fees = abi.decode(
            vm.parseJson(config, ".fdc2RequestFees"),
            (Fdc2RequestFee[])
        );
        console2.log(
            "Setting FDC2 request fees, count:",
            fees.length
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
    // Set FDC2 inflation configurations
    // =========================================================================

    function _configureFdc2InflationConfigurations() internal {
        Fdc2InflationConfig[] memory inflationConfigs = abi.decode(
            vm.parseJson(config, ".fdc2InflationConfigurations"),
            (Fdc2InflationConfig[])
        );
        console2.log(
            "Setting FDC2 inflation configurations, count:",
            inflationConfigs.length
        );
        if (inflationConfigs.length == 0) return;

        IFdc2InflationConfigurations.Fdc2Configuration[] memory configs =
            new IFdc2InflationConfigurations.Fdc2Configuration[](
                inflationConfigs.length
            );
        for (uint256 i = 0; i < inflationConfigs.length; i++) {
            configs[i] = IFdc2InflationConfigurations.Fdc2Configuration({
                attestationType: bytes32(bytes(inflationConfigs[i].attestationType)),
                sourceId: bytes32(bytes(inflationConfigs[i].source)),
                inflationShare: uint24(inflationConfigs[i].inflationShare),
                minRequestsThreshold: uint8(inflationConfigs[i].minRequestsThreshold),
                mode: uint224(inflationConfigs[i].mode)
            });
        }
        Fdc2InflationConfigurations(fdc2InflationConfigurationsAddr)
            .addFdc2Configurations(configs);
    }

    // =========================================================================
    // Switch to production mode
    // =========================================================================

    function _switchToProductionMode() internal {
        console2.log(
            "Switching to production mode"
        );
        // FlareTeeManager diamond
        DiamondGovernanceFacet(flareTeeManagerAddress)
            .switchToProductionMode();
        // FDC2 contracts (proxies, called through implementation interface)
        Fdc2Hub(fdc2HubAddr).switchToProductionMode();
        Fdc2RequestFeeConfigurations(fdc2FeeAddr)
            .switchToProductionMode();
        Fdc2Verification(fdc2VerificationAddr).switchToProductionMode();
        // Fdc2InflationConfigurations and Fdc2RewardOffersManager
        Fdc2InflationConfigurations(fdc2InflationConfigurationsAddr)
            .switchToProductionMode();
        Fdc2RewardOffersManager(fdc2RewardOffersManagerAddr)
            .switchToProductionMode();
        // TeePayments proxies
        for (uint256 i = 0; i < teePaymentsAddresses.length; i++) {
            TeePayments(teePaymentsAddresses[i])
                .switchToProductionMode();
        }
        // TeeRewardOffersManager
        TeeRewardOffersManager(teeRewardOffersManagerAddr)
            .switchToProductionMode();
        // TeePaymentsFeeScheduleManager (always deployed)
        TeePaymentsFeeScheduleManager(teePaymentsFeeScheduleManagerAddr)
            .switchToProductionMode();
        // TeePaymentsRegistry (always deployed)
        TeePaymentsRegistry(teePaymentsRegistryAddr)
            .switchToProductionMode();
        // TeePaymentsConfigVerifier (always deployed)
        TeePaymentsConfigVerifier(teePaymentsConfigVerifierAddr)
            .switchToProductionMode();
    }

    // =========================================================================
    // Network resolution
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

    // =========================================================================
    // Logging (format matches save-deployed-addresses.ts parser)
    // =========================================================================
    function _logFacetAddresses() internal view {
        _logDeployed(
            "DiamondGovernanceFacet",
            "DiamondGovernanceFacet.sol",
            address(diamondCutFacet)
        );
        _logDeployed(
            "DiamondLoupeFacet",
            "DiamondLoupeFacet.sol",
            address(diamondLoupeFacet)
        );
        _logDeployed(
            "ExtensionManagerFacet",
            "ExtensionManagerFacet.sol",
            address(extensionManagerFacet)
        );
        _logDeployed(
            "InstructionsFacet",
            "InstructionsFacet.sol",
            address(instructionsFacet)
        );
        _logDeployed(
            "MachineManagerFacet",
            "MachineManagerFacet.sol",
            address(machineManagerFacet)
        );
        _logDeployed(
            "VerificationFacet",
            "VerificationFacet.sol",
            address(verificationFacet)
        );
        _logDeployed(
            "OperationFeesFacet",
            "OperationFeesFacet.sol",
            address(operationFeesFacet)
        );
        _logDeployed(
            "OwnerAllowlistFacet",
            "OwnerAllowlistFacet.sol",
            address(ownerAllowlistFacet)
        );
        _logDeployed(
            "WalletManagerFacet",
            "WalletManagerFacet.sol",
            address(walletManagerFacet)
        );
        _logDeployed(
            "WalletKeyManagerFacet",
            "WalletKeyManagerFacet.sol",
            address(walletKeyManagerFacet)
        );
        _logDeployed(
            "WalletProjectManagerFacet",
            "WalletProjectManagerFacet.sol",
            address(walletProjectManagerFacet)
        );
        _logDeployed(
            "WalletBackupManagerFacet",
            "WalletBackupManagerFacet.sol",
            address(walletBackupManagerFacet)
        );
        _logDeployed(
            "VrfFacet",
            "VrfFacet.sol",
            address(vrfFacet)
        );
        _logDeployed(
            "ExternalAddressesFacet",
            "ExternalAddressesFacet.sol",
            address(externalAddressesFacet)
        );
        _logDeployed(
            "ExtensionGovernanceFacet",
            "ExtensionGovernanceFacet.sol",
            address(extensionGovernanceFacet)
        );
        _logDeployed(
            "MachinePathManagerFacet",
            "MachinePathManagerFacet.sol",
            address(machinePathManagerFacet)
        );
        _logDeployed(
            "WalletProjectPauseFacet",
            "WalletProjectPauseFacet.sol",
            address(walletProjectPauseFacet)
        );
        _logDeployed(
            "MachineEmergencyPauseFacet",
            "MachineEmergencyPauseFacet.sol",
            address(machineEmergencyPauseFacet)
        );
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

    function _paymentModel(
        string memory _model
    )
        internal pure
        returns (PaymentModel)
    {
        bytes32 modelHash = keccak256(bytes(_model));
        if (modelHash == keccak256(bytes("ACCOUNT"))) {
            return PaymentModel.ACCOUNT;
        }
        if (modelHash == keccak256(bytes("UTXO"))) {
            return PaymentModel.UTXO;
        }
        revert("unknown payment model");
    }

    // =========================================================================
    // Contract name encoding (matches TS: keccak256(abi.encode(name)))
    // =========================================================================

    function _encodeContractName(
        string memory _name
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_name));
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

    // =========================================================================
    // Network check for scdev (used to determine where to read pre-deployed addresses from)
    // =========================================================================

    function _isScdev(string memory _network)
        internal pure
        returns (bool)
    {
        return keccak256(bytes(_network)) == keccak256(bytes("scdev"));
    }
}
