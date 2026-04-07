// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
// solhint-disable no-console

import {Script, console2} from "forge-std/Script.sol";
import {IDiamond} from "../../contracts/diamond/interfaces/IDiamond.sol";
import {IDiamondCut} from "../../contracts/diamond/interfaces/IDiamondCut.sol";
import {IIFlareTeeManager} from "../../contracts/tee/interface/IIFlareTeeManager.sol";
import {FlareTeeManager} from "../../contracts/tee/diamond/FlareTeeManager.sol";
import {IGovernanceSettings} from
    "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
// init contracts
import {FlareTeeManagerInit} from "../../contracts/tee/facets/FlareTeeManagerInit.sol";
import {TeeReplicationInit} from "../../contracts/tee/facets/TeeReplicationInit.sol";
// day-1 facets
import {FlareTeeManagerDiamondCutFacet} from
    "../../contracts/tee/facets/FlareTeeManagerDiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../contracts/diamond/facets/DiamondLoupeFacet.sol";
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
// later facets
import {TeeReplicationFacet} from
    "../../contracts/tee/facets/TeeReplicationFacet.sol";
import {TeeGovernanceFacet} from
    "../../contracts/tee/facets/TeeGovernanceFacet.sol";
import {TeeVersionManagerFacet} from
    "../../contracts/tee/facets/TeeVersionManagerFacet.sol";

// solhint-disable no-console
// solhint-disable-next-line max-line-length
// forge script deployment/scripts/DeployFlareTeeManager.s.sol:DeployFlareTeeManager --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast --sig "run(bool)" true

contract DeployFlareTeeManager is Script {

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

    IIFlareTeeManager private flareTeeManager;
    address private flareTeeManagerAddress;

    // day-1 facets
    IDiamond.FacetCut[] private day1Facets;
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

    // later facets
    IDiamond.FacetCut[] private laterFacets;
    TeeReplicationFacet private teeReplicationFacet;
    TeeGovernanceFacet private teeGovernanceFacet;
    TeeVersionManagerFacet private teeVersionManagerFacet;

    function run(bool _fullDeploy) external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        string memory configFile = "deployment/chain-config/";
        string memory deploysFile = "deployment/deploys/";
        string memory network;
        uint256 chainId = block.chainid;

        if (chainId == 14) {
            network = "flare";
        } else if (chainId == 19) {
            network = "songbird";
        } else if (chainId == 16) {
            network = "coston";
        } else if (chainId == 114) {
            network = "coston2";
        } else {
            network = "scdev";
        }
        configFile = string.concat(configFile, network, ".json");
        deploysFile = string.concat(deploysFile, network, ".json");
        console2.log(string.concat("NETWORK: ", network));

        // read chain config (TEE params)
        string memory config = vm.readFile(configFile);
        uint64 availabilityCheckValidityDurationSeconds =
            uint64(vm.parseJsonUint(config, ".teeAvailabilityCheckValidityDurationSeconds"));
        uint64 signingPolicyValidityDurationInRewardEpochs =
            uint64(vm.parseJsonUint(config, ".teeSigningPolicyValidityDurationInRewardEpochs"));
        uint64 challengeValidityDurationSeconds =
            uint64(vm.parseJsonUint(config, ".teeChallengeValidityDurationSeconds"));
        uint256 defaultFeeWei = vm.parseJsonUint(config, ".teeDefaultFeeWei");
        uint256 pauseBeforeUpgradeMinDurationSeconds =
            vm.parseJsonUint(config, ".teePauseBeforeUpgradeMinDurationSeconds");

        // read deployed addresses
        string memory deploys = vm.readFile(deploysFile);
        address governanceSettings = _findDeployedAddress(deploys, "GovernanceSettings");
        address addressUpdater = _findDeployedAddress(deploys, "AddressUpdater");
        require(governanceSettings != address(0), "GovernanceSettings not found in deploys");
        require(addressUpdater != address(0), "AddressUpdater not found in deploys");

        vm.startBroadcast();

        // Phase 1: Deploy day-1 facets
        _deployDay1Facets();
        _logDay1FacetAddresses();

        // Phase 2: Deploy FlareTeeManagerInit and create diamond
        FlareTeeManagerInit flareTeeManagerInit = new FlareTeeManagerInit();

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

        FlareTeeManager flareTeeManagerDiamond = new FlareTeeManager(
            day1Facets,
            FlareTeeManager.DiamondArgs({
                init: address(flareTeeManagerInit),
                initCalldata: initCalldata
            })
        );
        flareTeeManagerAddress = address(flareTeeManagerDiamond);
        flareTeeManager = IIFlareTeeManager(flareTeeManagerAddress);

        // Phase 3: Post-init configuration
        _configureOperationFees(config);
        _configureSystemPlatforms(config);
        _configureKeyTypesAndSigningAlgos(config);
        _configureExtensionKeyTypes(config);

        if (_fullDeploy) {
            // Phase 4: Deploy later facets and add via diamondCut
            _deployLaterFacets();
            TeeReplicationInit teeReplicationInit = new TeeReplicationInit();
            IDiamondCut(flareTeeManagerAddress).diamondCut(
                laterFacets,
                address(teeReplicationInit),
                abi.encodeWithSelector(
                    TeeReplicationInit.init.selector,
                    pauseBeforeUpgradeMinDurationSeconds
                )
            );

            console2.log(
                string.concat(
                    "DEPLOYED: TeeReplicationInit, ",
                    "TeeReplicationInit.sol: ",
                    vm.toString(address(teeReplicationInit))
                )
            );
            _logLaterFacetAddresses();
        } else {
            console2.log("Skipping later facets as per input flag");
        }

        console2.log(
            string.concat(
                "DEPLOYED: FlareTeeManagerInit, ",
                "FlareTeeManagerInit.sol: ",
                vm.toString(address(flareTeeManagerInit))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: FlareTeeManager, ",
                "FlareTeeManager.sol: ",
                vm.toString(flareTeeManagerAddress)
            )
        );

        vm.stopBroadcast();
    }

    // =========================================================================
    // Facet deployment helpers
    // =========================================================================

    function _addFacet(
        address facetAddr,
        string memory facetName
    )
        internal
        returns (IDiamond.FacetCut memory)
    {
        string[] memory cmds = new string[](3);
        cmds[0] = "node";
        cmds[1] = "scripts/flare-tee-manager-selectors.js";
        cmds[2] = facetName;
        bytes memory out = vm.ffi(cmds);
        bytes4[] memory selectors = abi.decode(out, (bytes4[]));
        return IDiamond.FacetCut({
            facetAddress: facetAddr,
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

        day1Facets.push(_addFacet(address(diamondCutFacet), "FlareTeeManagerDiamondCutFacet"));
        day1Facets.push(_addFacet(address(diamondLoupeFacet), "DiamondLoupeFacet"));
        day1Facets.push(_addFacet(address(teeExtensionRegistryFacet), "TeeExtensionRegistryFacet"));
        day1Facets.push(_addFacet(address(teeMachineRegistryFacet), "TeeMachineRegistryFacet"));
        day1Facets.push(_addFacet(address(teeVerificationFacet), "TeeVerificationFacet"));
        day1Facets.push(
            _addFacet(address(teeWalletVerificationFacet), "TeeWalletVerificationFacet")
        );
        day1Facets.push(_addFacet(address(teeFeeCalculatorFacet), "TeeFeeCalculatorFacet"));
        day1Facets.push(_addFacet(address(teeOwnerAllowlistFacet), "TeeOwnerAllowlistFacet"));
        day1Facets.push(
            _addFacet(address(teeSystemStateVerifierFacet), "TeeSystemStateVerifierFacet")
        );
        day1Facets.push(_addFacet(address(teeWalletManagerFacet), "TeeWalletManagerFacet"));
        day1Facets.push(
            _addFacet(address(teeWalletKeyManagerFacet), "TeeWalletKeyManagerFacet")
        );
        day1Facets.push(
            _addFacet(address(teeWalletProjectManagerFacet), "TeeWalletProjectManagerFacet")
        );
        day1Facets.push(
            _addFacet(address(teeWalletBackupManagerFacet), "TeeWalletBackupManagerFacet")
        );
        day1Facets.push(_addFacet(address(teeVrfFacet), "TeeVrfFacet"));
        day1Facets.push(
            _addFacet(address(teeAddressUpdatableFacet), "TeeAddressUpdatableFacet")
        );
    }

    function _deployLaterFacets() internal {
        teeReplicationFacet = new TeeReplicationFacet();
        teeGovernanceFacet = new TeeGovernanceFacet();
        teeVersionManagerFacet = new TeeVersionManagerFacet();

        laterFacets.push(_addFacet(address(teeReplicationFacet), "TeeReplicationFacet"));
        laterFacets.push(_addFacet(address(teeGovernanceFacet), "TeeGovernanceFacet"));
        laterFacets.push(_addFacet(address(teeVersionManagerFacet), "TeeVersionManagerFacet"));
    }

    // =========================================================================
    // Post-init configuration
    // =========================================================================

    function _configureOperationFees(string memory _config) internal {
        OperationFeeConfig[] memory fees =
            abi.decode(vm.parseJson(_config, ".teeOperationFees"), (OperationFeeConfig[]));
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

    function _configureSystemPlatforms(string memory _config) internal {
        string[] memory platforms =
            abi.decode(vm.parseJson(_config, ".teeSupportedPlatforms"), (string[]));
        if (platforms.length == 0) return;

        bytes32[] memory platformBytes = new bytes32[](platforms.length);
        for (uint256 i = 0; i < platforms.length; i++) {
            platformBytes[i] = bytes32(bytes(platforms[i]));
        }

        console2.log("Adding system supported platforms, count:", platforms.length);
        flareTeeManager.addSystemSupportedPlatforms(platformBytes);
    }

    function _configureKeyTypesAndSigningAlgos(string memory _config) internal {
        KeyTypeWithSigningAlgos[] memory keyTypes = abi.decode(
            vm.parseJson(_config, ".teeSupportedKeyTypesWithSigningAlgos"),
            (KeyTypeWithSigningAlgos[])
        );
        if (keyTypes.length == 0) return;

        bytes32[] memory keyTypeBytes = new bytes32[](keyTypes.length);
        bytes32[][] memory signingAlgosBytes = new bytes32[][](keyTypes.length);

        for (uint256 i = 0; i < keyTypes.length; i++) {
            keyTypeBytes[i] = bytes32(bytes(keyTypes[i].keyType));
            signingAlgosBytes[i] = new bytes32[](keyTypes[i].signingAlgos.length);
            for (uint256 j = 0; j < keyTypes[i].signingAlgos.length; j++) {
                signingAlgosBytes[i][j] = bytes32(bytes(keyTypes[i].signingAlgos[j]));
            }
        }

        console2.log("Adding system supported key types, count:", keyTypes.length);
        flareTeeManager.addSystemSupportedKeyTypesAndSigningAlgos(keyTypeBytes, signingAlgosBytes);
    }

    function _configureExtensionKeyTypes(string memory _config) internal {
        PaymentConfiguration[] memory paymentConfigs = abi.decode(
            vm.parseJson(_config, ".teePaymentConfigurations"),
            (PaymentConfiguration[])
        );
        if (paymentConfigs.length == 0) return;

        // collect unique key types
        bytes32[] memory tempKeyTypes = new bytes32[](paymentConfigs.length);
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

        console2.log("Adding extension supported key types (system ext 0), count:", uniqueCount);
        flareTeeManager.addSupportedKeyTypes(0, uniqueKeyTypes);
    }

    // =========================================================================
    // Deploys file reader
    // =========================================================================

    function _findDeployedAddress(
        string memory _json,
        string memory _name
    )
        internal
        returns (address)
    {
        // deployed addresses JSON is an array of {name, contractName, address} objects
        // iterate until we find the matching name
        for (uint256 i = 0; ; i++) {
            string memory namePath = string.concat("[", vm.toString(i), "].name");
            bytes memory rawName;
            // solhint-disable-next-line no-inline-assembly
            try this._parseJsonString(_json, namePath) returns (string memory aName) {
                rawName = bytes(aName);
                if (keccak256(rawName) == keccak256(bytes(_name))) {
                    string memory addrPath = string.concat("[", vm.toString(i), "].address");
                    return this._parseJsonAddress(_json, addrPath);
                }
            } catch {
                break;
            }
        }
        return address(0);
    }

    // External helpers to allow try/catch on vm calls
    function _parseJsonString(
        string calldata _json,
        string calldata _path
    )
        external view
        returns (string memory)
    {
        return vm.parseJsonString(_json, _path);
    }

    function _parseJsonAddress(
        string calldata _json,
        string calldata _path
    )
        external view
        returns (address)
    {
        return vm.parseJsonAddress(_json, _path);
    }

    // =========================================================================
    // Logging
    // =========================================================================

    function _logDay1FacetAddresses() internal view {
        console2.log(
            string.concat(
                "DEPLOYED: FlareTeeManagerDiamondCutFacet, ",
                "FlareTeeManagerDiamondCutFacet.sol: ",
                vm.toString(address(diamondCutFacet))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: DiamondLoupeFacet, ",
                "DiamondLoupeFacet.sol: ",
                vm.toString(address(diamondLoupeFacet))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: TeeExtensionRegistryFacet, ",
                "TeeExtensionRegistryFacet.sol: ",
                vm.toString(address(teeExtensionRegistryFacet))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: TeeMachineRegistryFacet, ",
                "TeeMachineRegistryFacet.sol: ",
                vm.toString(address(teeMachineRegistryFacet))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: TeeVerificationFacet, ",
                "TeeVerificationFacet.sol: ",
                vm.toString(address(teeVerificationFacet))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: TeeWalletVerificationFacet, ",
                "TeeWalletVerificationFacet.sol: ",
                vm.toString(address(teeWalletVerificationFacet))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: TeeFeeCalculatorFacet, ",
                "TeeFeeCalculatorFacet.sol: ",
                vm.toString(address(teeFeeCalculatorFacet))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: TeeOwnerAllowlistFacet, ",
                "TeeOwnerAllowlistFacet.sol: ",
                vm.toString(address(teeOwnerAllowlistFacet))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: TeeSystemStateVerifierFacet, ",
                "TeeSystemStateVerifierFacet.sol: ",
                vm.toString(address(teeSystemStateVerifierFacet))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: TeeWalletManagerFacet, ",
                "TeeWalletManagerFacet.sol: ",
                vm.toString(address(teeWalletManagerFacet))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: TeeWalletKeyManagerFacet, ",
                "TeeWalletKeyManagerFacet.sol: ",
                vm.toString(address(teeWalletKeyManagerFacet))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: TeeWalletProjectManagerFacet, ",
                "TeeWalletProjectManagerFacet.sol: ",
                vm.toString(address(teeWalletProjectManagerFacet))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: TeeWalletBackupManagerFacet, ",
                "TeeWalletBackupManagerFacet.sol: ",
                vm.toString(address(teeWalletBackupManagerFacet))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: TeeVrfFacet, ",
                "TeeVrfFacet.sol: ",
                vm.toString(address(teeVrfFacet))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: TeeAddressUpdatableFacet, ",
                "TeeAddressUpdatableFacet.sol: ",
                vm.toString(address(teeAddressUpdatableFacet))
            )
        );
    }

    function _logLaterFacetAddresses() internal view {
        console2.log(
            string.concat(
                "DEPLOYED: TeeReplicationFacet, ",
                "TeeReplicationFacet.sol: ",
                vm.toString(address(teeReplicationFacet))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: TeeGovernanceFacet, ",
                "TeeGovernanceFacet.sol: ",
                vm.toString(address(teeGovernanceFacet))
            )
        );
        console2.log(
            string.concat(
                "DEPLOYED: TeeVersionManagerFacet, ",
                "TeeVersionManagerFacet.sol: ",
                vm.toString(address(teeVersionManagerFacet))
            )
        );
    }
}
