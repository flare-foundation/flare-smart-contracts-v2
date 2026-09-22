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
import {AddressUpdatable} from "../../contracts/utils/implementation/AddressUpdatable.sol";
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
import {AddressValidator} from
    "../../contracts/tee/implementation/AddressValidator.sol";
import {AddressValidatorProxy} from
    "../../contracts/tee/proxy/AddressValidatorProxy.sol";
import {IAddressValidator} from
    "../../contracts/userInterfaces/tee/IAddressValidator.sol";
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

    struct KeyTypeWithSigningAlgos {
        string keyType;
        string[] signingAlgos;
    }

    // NOTE: stdJson parses struct fields in alphabetical order of JSON keys.
    // Keep field names alphabetical: maxFeeDelaySeconds, maxFeeSchedules, sourceId.
    struct TeePaymentsSourceConfig {
        uint256 maxFeeDelaySeconds;
        uint256 maxFeeSchedules;
        string sourceId;
    }

    // NOTE: stdJson parses struct fields in alphabetical order of JSON keys.
    // Keep field names alphabetical: keyType, opType, sourceConfigs.
    struct TeePaymentsConfiguration {
        string keyType;
        string opType;
        TeePaymentsSourceConfig[] sourceConfigs;
    }

    struct TeePaymentsUtxoSourceConfig {
        string sourceId;
    }

    // NOTE: stdJson parses struct fields in alphabetical order of JSON keys.
    // Keep field names alphabetical: anchorReuseDelaySeconds, keyType,
    // maxBatchDurationSeconds, maxBatchSize, opType, sourceConfigs.
    struct TeePaymentsUtxoConfiguration {
        uint256 anchorReuseDelaySeconds;
        string keyType;
        uint256 maxBatchDurationSeconds;
        uint256 maxBatchSize;
        string opType;
        TeePaymentsUtxoSourceConfig[] sourceConfigs;
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
    address private addressValidatorAddr;

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
        _deployAddressValidator();
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
        _configureAddressValidatorSources();
        _configureUtxoBatchSettings();
        _configureUtxoAnchorReuseDelay();
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
        uint256 count = _jsonArrayLength(".teeOperationFees");
        if (count == 0) return;

        bytes32[] memory opTypes = new bytes32[](count);
        bytes32[] memory opCommands = new bytes32[](count);
        uint256[] memory feeValues = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            string memory key = string.concat(".teeOperationFees[", vm.toString(i), "]");
            opTypes[i] = bytes32(bytes(vm.parseJsonString(config, string.concat(key, ".opType"))));
            opCommands[i] = bytes32(bytes(vm.parseJsonString(config, string.concat(key, ".opCommand"))));
            feeValues[i] = vm.parseJsonUint(config, string.concat(key, ".feeWei"));
        }

        console2.log("Setting operation fees, count:", count);
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
        TeePaymentsConfiguration[] memory accountConfigs = abi.decode(
            vm.parseJson(config, ".teePaymentsConfigurations"),
            (TeePaymentsConfiguration[])
        );
        TeePaymentsUtxoConfiguration[] memory utxoConfigs = abi.decode(
            vm.parseJson(config, ".teePaymentsUtxoConfigurations"),
            (TeePaymentsUtxoConfiguration[])
        );

        // A single account proxy serves every account source and a single UTXO proxy serves every UTXO
        // source — each source carries its own keyType/opType in the registry, so one proxy per payment
        // model is enough. Implementations are deployed only when used by this network.
        if (accountConfigs.length > 0) {
            address accountImpl = address(new TeePayments());
            _logDeployed(
                "TeePaymentsImplementation",
                "TeePayments.sol",
                accountImpl
            );
            address accountProxy = _deployTeePaymentsProxy(accountImpl);
            teePaymentsAddresses.push(accountProxy);
            _logDeployed("TeePayments", "TeePaymentsProxy.sol", accountProxy);

            // Track sourceId -> TeePayments bindings for the registry (all sources share the proxy).
            for (uint256 i = 0; i < accountConfigs.length; i++) {
                for (uint256 j = 0; j < accountConfigs[i].sourceConfigs.length; j++) {
                    sourceRegistrations.push(
                        ITeePaymentsRegistry.SourceRegistration({
                            keyType: bytes32(bytes(accountConfigs[i].keyType)),
                            opType: bytes32(bytes(accountConfigs[i].opType)),
                            paymentModel: PaymentModel.ACCOUNT,
                            sourceId: bytes32(
                                bytes(accountConfigs[i].sourceConfigs[j].sourceId)
                            ),
                            teePayments: accountProxy
                        })
                    );
                }
            }
        }

        if (utxoConfigs.length > 0) {
            address utxoImpl = address(new TeePaymentsUtxo());
            _logDeployed(
                "TeePaymentsUtxoImplementation",
                "TeePaymentsUtxo.sol",
                utxoImpl
            );
            address utxoProxy = _deployTeePaymentsProxy(utxoImpl);
            teePaymentsAddresses.push(utxoProxy);
            _logDeployed("TeePaymentsUtxo", "TeePaymentsProxy.sol", utxoProxy);

            // Track sourceId -> TeePayments bindings for the registry (all sources share the proxy).
            for (uint256 i = 0; i < utxoConfigs.length; i++) {
                for (uint256 j = 0; j < utxoConfigs[i].sourceConfigs.length; j++) {
                    sourceRegistrations.push(
                        ITeePaymentsRegistry.SourceRegistration({
                            keyType: bytes32(bytes(utxoConfigs[i].keyType)),
                            opType: bytes32(bytes(utxoConfigs[i].opType)),
                            paymentModel: PaymentModel.UTXO,
                            sourceId: bytes32(
                                bytes(utxoConfigs[i].sourceConfigs[j].sourceId)
                            ),
                            teePayments: utxoProxy
                        })
                    );
                }
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
    // Deploy AddressValidator (always deployed, before TeePayments)
    // =========================================================================

    function _deployAddressValidator() internal {
        AddressValidator impl = new AddressValidator();
        _logDeployed(
            "AddressValidatorImplementation",
            "AddressValidator.sol",
            address(impl)
        );

        AddressValidatorProxy proxy =
            new AddressValidatorProxy(
                IGovernanceSettings(governanceSettings),
                deployer,
                deployer,
                address(impl)
            );
        addressValidatorAddr = address(proxy);
        _logDeployed(
            "AddressValidator",
            "AddressValidatorProxy.sol",
            addressValidatorAddr
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
        _wireFdc2RequestFeeConfigurations();
        _wireFdc2InflationConfigurations();
        _wireFdc2RewardOffersManager();
        _wireTeePaymentsConfigVerifier();
        _wireAddressValidator();
        _wireTeePayments();
        _wireTeeRewardOffersManager();
        _wireTeePaymentsFeeScheduleManager();
        _wireTeePaymentsRegistry();
        _verifyAddressUpdaterHandover();
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

    function _wireFdc2RequestFeeConfigurations() internal {
        // No upstream dependencies; the call only hands the address updater over from the
        // deployer to the real AddressUpdater (see _verifyAddressUpdaterHandover).
        bytes32[] memory names = new bytes32[](1);
        names[0] = _encodeContractName("AddressUpdater");
        address[] memory addrs = new address[](1);
        addrs[0] = addressUpdater;
        Fdc2RequestFeeConfigurations(fdc2FeeAddr)
            .updateContractAddresses(names, addrs);
    }

    function _wireTeePayments() internal {
        bytes32[] memory names = new bytes32[](7);
        names[0] = _encodeContractName("AddressUpdater");
        names[1] = _encodeContractName("FlareTeeManager");
        names[2] = _encodeContractName("FlareSystemsManager");
        names[3] = _encodeContractName("TeePaymentsFeeScheduleManager");
        names[4] = _encodeContractName("TeePaymentsRegistry");
        names[5] = _encodeContractName("TeePaymentsConfigVerifier");
        names[6] = _encodeContractName("AddressValidator");
        address[] memory addrs = new address[](7);
        addrs[0] = addressUpdater;
        addrs[1] = flareTeeManagerAddress;
        addrs[2] = flareSystemsManager;
        addrs[3] = teePaymentsFeeScheduleManagerAddr;
        addrs[4] = teePaymentsRegistryAddr;
        addrs[5] = teePaymentsConfigVerifierAddr;
        addrs[6] = addressValidatorAddr;
        for (uint256 i = 0; i < teePaymentsAddresses.length; i++) {
            TeePayments(teePaymentsAddresses[i])
                .updateContractAddresses(names, addrs);
        }
    }

    function _wireAddressValidator() internal {
        // AddressValidator has no upstream dependencies; still needs AddressUpdater wired for consistency.
        bytes32[] memory names = new bytes32[](1);
        names[0] = _encodeContractName("AddressUpdater");
        address[] memory addrs = new address[](1);
        addrs[0] = addressUpdater;
        AddressValidator(addressValidatorAddr)
            .updateContractAddresses(names, addrs);
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
        TeePaymentsUtxoConfiguration[] memory utxoConfigs = abi.decode(
            vm.parseJson(config, ".teePaymentsUtxoConfigurations"),
            (TeePaymentsUtxoConfiguration[])
        );

        for (uint256 i = 0; i < utxoConfigs.length; i++) {
            for (uint256 j = 0; j < utxoConfigs[i].sourceConfigs.length; j++) {
                bytes32 sourceId =
                    bytes32(bytes(utxoConfigs[i].sourceConfigs[j].sourceId));
                address teePayments =
                    TeePaymentsRegistry(teePaymentsRegistryAddr)
                        .getTeePaymentsForSource(sourceId);
                TeePaymentsUtxo(teePayments).setMaxBatchSettings(
                    sourceId,
                    uint64(utxoConfigs[i].maxBatchSize),
                    uint64(utxoConfigs[i].maxBatchDurationSeconds)
                );
            }
        }
    }

    function _configureUtxoAnchorReuseDelay() internal {
        TeePaymentsUtxoConfiguration[] memory utxoConfigs = abi.decode(
            vm.parseJson(config, ".teePaymentsUtxoConfigurations"),
            (TeePaymentsUtxoConfiguration[])
        );

        for (uint256 i = 0; i < utxoConfigs.length; i++) {
            for (uint256 j = 0; j < utxoConfigs[i].sourceConfigs.length; j++) {
                bytes32 sourceId =
                    bytes32(bytes(utxoConfigs[i].sourceConfigs[j].sourceId));
                address teePayments =
                    TeePaymentsRegistry(teePaymentsRegistryAddr)
                        .getTeePaymentsForSource(sourceId);
                TeePaymentsUtxo(teePayments).setAnchorReuseDelay(
                    sourceId,
                    uint64(utxoConfigs[i].anchorReuseDelaySeconds)
                );
            }
        }
    }

    function _configureFeeScheduleSourceLimits() internal {
        TeePaymentsConfiguration[] memory accountConfigs = abi.decode(
            vm.parseJson(config, ".teePaymentsConfigurations"),
            (TeePaymentsConfiguration[])
        );

        uint256 totalSources;
        for (uint256 i = 0; i < accountConfigs.length; i++) {
            totalSources += accountConfigs[i].sourceConfigs.length;
        }
        if (totalSources == 0) return;

        ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[] memory inputs =
            new ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[](
                totalSources
        );
        uint256 k;
        for (uint256 i = 0; i < accountConfigs.length; i++) {
            for (uint256 j = 0; j < accountConfigs[i].sourceConfigs.length; j++) {
                TeePaymentsSourceConfig memory src = accountConfigs[i].sourceConfigs[j];
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
    // Configure AddressValidator per-source {chainKind, network} profiles
    // =========================================================================

    function _configureAddressValidatorSources() internal {
        TeePaymentsConfiguration[] memory accountConfigs = abi.decode(
            vm.parseJson(config, ".teePaymentsConfigurations"),
            (TeePaymentsConfiguration[])
        );
        TeePaymentsUtxoConfiguration[] memory utxoConfigs = abi.decode(
            vm.parseJson(config, ".teePaymentsUtxoConfigurations"),
            (TeePaymentsUtxoConfiguration[])
        );

        uint256 total;
        for (uint256 i = 0; i < accountConfigs.length; i++) {
            total += accountConfigs[i].sourceConfigs.length;
        }
        for (uint256 i = 0; i < utxoConfigs.length; i++) {
            total += utxoConfigs[i].sourceConfigs.length;
        }
        if (total == 0) return;

        // chainKind is derived from the config's keyType; network from the deploy target
        // (flare/songbird -> mainnet, every other network -> testnet).
        IAddressValidator.Network network = _addressValidatorNetwork();
        IAddressValidator.SourceConfig[] memory inputs =
            new IAddressValidator.SourceConfig[](total);
        uint256 k;
        for (uint256 i = 0; i < accountConfigs.length; i++) {
            IAddressValidator.ChainKind kind =
                _chainKindForKeyType(bytes32(bytes(accountConfigs[i].keyType)));
            for (uint256 j = 0; j < accountConfigs[i].sourceConfigs.length; j++) {
                inputs[k++] = IAddressValidator.SourceConfig({
                    sourceId: bytes32(bytes(accountConfigs[i].sourceConfigs[j].sourceId)),
                    chainKind: kind,
                    network: network
                });
            }
        }
        for (uint256 i = 0; i < utxoConfigs.length; i++) {
            IAddressValidator.ChainKind kind =
                _chainKindForKeyType(bytes32(bytes(utxoConfigs[i].keyType)));
            for (uint256 j = 0; j < utxoConfigs[i].sourceConfigs.length; j++) {
                inputs[k++] = IAddressValidator.SourceConfig({
                    sourceId: bytes32(bytes(utxoConfigs[i].sourceConfigs[j].sourceId)),
                    chainKind: kind,
                    network: network
                });
            }
        }

        console2.log(
            "Configuring AddressValidator sources, count:", total
        );
        AddressValidator(addressValidatorAddr).setSourceConfigs(inputs);
    }

    // =========================================================================
    // Set FDC2 request fee configurations
    // =========================================================================

    function _configureFdc2RequestFees() internal {
        uint256 count = _jsonArrayLength(".fdc2RequestFees");
        console2.log(
            "Setting FDC2 request fees, count:",
            count
        );
        for (uint256 i = 0; i < count; i++) {
            string memory key = string.concat(".fdc2RequestFees[", vm.toString(i), "]");
            Fdc2RequestFeeConfigurations(fdc2FeeAddr).setTypeAndSourceFee(
                bytes32(bytes(vm.parseJsonString(config, string.concat(key, ".attestationType")))),
                bytes32(bytes(vm.parseJsonString(config, string.concat(key, ".source")))),
                vm.parseJsonUint(config, string.concat(key, ".feeWei"))
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
        // AddressValidator (always deployed)
        AddressValidator(addressValidatorAddr)
            .switchToProductionMode();
    }

    // =========================================================================
    // Post-wiring guard
    // =========================================================================
    /**
     * Every proxy is deployed with the deployer as its address updater so the deployer can push
     * the initial addresses directly; the `AddressUpdater` name in each wiring call then hands
     * the role over to the real AddressUpdater. A contract missing from _wireUpContractAddresses
     * would keep the deployer as its updater forever, so the run fails here instead.
     */
    function _verifyAddressUpdaterHandover()
        internal view
    {
        address[11] memory fixedUpdatables = [
            flareTeeManagerAddress,
            fdc2HubAddr,
            fdc2FeeAddr,
            fdc2VerificationAddr,
            fdc2InflationConfigurationsAddr,
            fdc2RewardOffersManagerAddr,
            teeRewardOffersManagerAddr,
            teePaymentsFeeScheduleManagerAddr,
            teePaymentsRegistryAddr,
            teePaymentsConfigVerifierAddr,
            addressValidatorAddr
        ];
        for (uint256 i = 0; i < fixedUpdatables.length; i++) {
            _requireAddressUpdaterHandedOver(fixedUpdatables[i]);
        }
        for (uint256 i = 0; i < teePaymentsAddresses.length; i++) {
            _requireAddressUpdaterHandedOver(teePaymentsAddresses[i]);
        }
    }

    function _requireAddressUpdaterHandedOver(
        address _updatable
    )
        internal view
    {
        require(
            AddressUpdatable(_updatable).getAddressUpdater() == addressUpdater,
            string.concat("address updater not handed over: ", vm.toString(_updatable))
        );
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

    // The AddressValidator network for this deploy target (flare/songbird -> mainnet, else testnet).
    // Only Bitcoin/Dogecoin enforce network; EVM and XRPL addresses are network-agnostic by format.
    function _addressValidatorNetwork()
        internal view
        returns (IAddressValidator.Network)
    {
        uint256 chainId = block.chainid;
        if (chainId == 14 || chainId == 19) {
            return IAddressValidator.Network.Mainnet; // flare / songbird
        }
        return IAddressValidator.Network.Testnet;
    }

    // =========================================================================
    // JSON array helpers
    // =========================================================================

    // NOTE: vm.parseJson coerces string values that parse as numbers wider than
    // 64 bits into uint256 while smaller numeric strings stay strings, so
    // abi.decode of object arrays with numeric string fields (e.g. feeWei) is
    // unreliable. Such arrays must be parsed element by element with the typed
    // cheatcodes (vm.parseJsonString / vm.parseJsonUint).
    function _jsonArrayLength(
        string memory _key
    )
        internal view
        returns (uint256 _length)
    {
        while (vm.keyExistsJson(config, string.concat(_key, "[", vm.toString(_length), "]"))) {
            _length++;
        }
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

    // Maps a config keyType to the AddressValidator chain kind (keyType is the chain family).
    function _chainKindForKeyType(
        bytes32 _keyType
    )
        internal pure
        returns (IAddressValidator.ChainKind)
    {
        if (_keyType == bytes32("XRP")) return IAddressValidator.ChainKind.Xrpl;
        if (_keyType == bytes32("EVM")) return IAddressValidator.ChainKind.Evm;
        if (_keyType == bytes32("BTC")) return IAddressValidator.ChainKind.Bitcoin;
        if (_keyType == bytes32("DOGE")) return IAddressValidator.ChainKind.Dogecoin;
        revert("AddressValidator: unknown keyType");
    }
}
