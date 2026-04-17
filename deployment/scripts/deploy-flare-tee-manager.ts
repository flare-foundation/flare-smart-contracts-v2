/**
 * This script deploys the FlareTeeManager Diamond proxy and its facets.
 * Replaces the individual UUPS proxy deployments for TEE contracts that are now Diamond facets.
 *
 * Exports shared diamond deployment helpers used by both production deploy and test deploy.
 */

import { HardhatRuntimeEnvironment } from "hardhat/types";
import "@nomiclabs/hardhat-truffle5";
import "@nomiclabs/hardhat-web3";
import { Interface } from "ethers";
import { AbiItem } from "web3-utils";
import { Contracts } from "./Contracts";
import { spewNewContractInfo } from "./deploy-utils";
import { ChainParameters, TeeKeyTypeWithSigningAlgos, TeePaymentConfiguration } from "../chain-config/chain-parameters";

// Day-1 facets (deployed in initial diamond cut)
export const DAY1_FACETS = [
  "DiamondGovernanceFacet",
  "DiamondLoupeFacet",
  "ExtensionManagerFacet",
  "InstructionsFacet",
  "MachineManagerFacet",
  "VerificationFacet",
  "OperationFeesFacet",
  "OwnerAllowlistFacet",
  "SystemStateVerifierFacet",
  "WalletManagerFacet",
  "WalletKeyManagerFacet",
  "WalletProjectManagerFacet",
  "WalletBackupManagerFacet",
  "VrfFacet",
  "ExternalAddressesFacet",
];

// Deploy-later facets (added via diamondCut after initial deployment)
export const LATER_FACETS = ["ReplicationFacet", "ExtensionGovernanceFacet", "UpgradeManagerFacet"];

export enum FacetCutAction {
  Add = 0,
  Replace = 1,
  Remove = 2,
}

export interface FacetCut {
  facetAddress: string;
  action: FacetCutAction;
  functionSelectors: string[];
}

/**
 * Extracts function selectors from a contract's ABI.
 * Returns all function selectors excluding constructor, fallback, and receive.
 */
export function getSelectors(abi: AbiItem[]): string[] {
  const jsonAbi = abi.filter((item: AbiItem) => item.type === "function");
  const iface = new Interface(JSON.parse(JSON.stringify(jsonAbi)) as string[]);
  const selectors: string[] = [];
  iface.forEachFunction((fn) => selectors.push(fn.selector));
  return selectors;
}

/**
 * Deploys facet contracts and builds FacetCut array for diamondCut.
 * Throws if any selector appears in more than one facet.
 */
export async function deployFacetsAndBuildCuts(
  hre: HardhatRuntimeEnvironment,
  facetNames: string[]
): Promise<{
  facetCuts: FacetCut[];
  facetAddresses: Record<string, string>;
}> {
  const seen = new Map<string, string>(); // selector → facet name
  const facetCuts: FacetCut[] = [];
  const facetAddresses: Record<string, string> = {};

  for (const facetName of facetNames) {
    const FacetArtifact = hre.artifacts.require(facetName);
    const facetInstance = await FacetArtifact.new();
    facetAddresses[facetName] = facetInstance.address;

    const selectors = getSelectors(FacetArtifact.abi as AbiItem[]);
    for (const s of selectors) {
      const existing = seen.get(s);
      if (existing) {
        throw new Error(`Duplicate selector ${s} in ${facetName} (already in ${existing})`);
      }
      seen.set(s, facetName);
    }

    facetCuts.push({
      facetAddress: facetInstance.address,
      action: FacetCutAction.Add,
      functionSelectors: selectors,
    });
  }

  return { facetCuts, facetAddresses };
}

/**
 * Deploys later facets and adds them to an existing FlareTeeManager Diamond via diamondCut.
 */
export async function addLaterFacetsToDiamond(
  hre: HardhatRuntimeEnvironment,
  flareTeeManagerAddress: string,
  pauseBeforeUpgradeMinDurationSeconds: string
): Promise<void> {
  const { facetCuts } = await deployFacetsAndBuildCuts(hre, LATER_FACETS);

  // Deploy ReplicationInit for the replication facet init
  const ReplicationInit = hre.artifacts.require("ReplicationInit");
  const teeReplicationInit = await ReplicationInit.new();

  const initCalldata = hre.web3.eth.abi.encodeFunctionCall(
    (ReplicationInit.abi as AbiItem[]).find((item: AbiItem) => item.name === "init")!,
    [pauseBeforeUpgradeMinDurationSeconds]
  );

  // Execute diamondCut on FlareTeeManager
  const IDiamondCut = hre.artifacts.require("IDiamondCut");
  const flareTeeManager = await IDiamondCut.at(flareTeeManagerAddress);
  await flareTeeManager.diamondCut(facetCuts, teeReplicationInit.address, initCalldata);
}

export async function deployFlareTeeManager(
  hre: HardhatRuntimeEnvironment,
  oldContracts: Contracts,
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false
): Promise<string> {
  const governanceSettings = oldContracts.getContractAddress(Contracts.GOVERNANCE_SETTINGS);

  // 1. Deploy all day-1 facet contracts
  const { facetCuts, facetAddresses } = await deployFacetsAndBuildCuts(hre, DAY1_FACETS);

  for (const facetName of DAY1_FACETS) {
    spewNewContractInfo(contracts, null, facetName, `${facetName}.sol`, facetAddresses[facetName], quiet);
  }

  // 2. Deploy FlareTeeManagerInit (init contract, not a facet)
  const FlareTeeManagerInit = hre.artifacts.require("FlareTeeManagerInit");
  const flareTeeManagerInit = await FlareTeeManagerInit.new();
  spewNewContractInfo(
    contracts,
    null,
    "FlareTeeManagerInit",
    "FlareTeeManagerInit.sol",
    flareTeeManagerInit.address,
    quiet
  );

  // 3. Encode init calldata
  const initCalldata = hre.web3.eth.abi.encodeFunctionCall(
    (FlareTeeManagerInit.abi as AbiItem[]).find((item: AbiItem) => item.name === "init")!,
    [
      governanceSettings,
      hre.web3.eth.defaultAccount!, // initial governance
      hre.web3.eth.defaultAccount!, // tmp address updater
      parameters.teeAvailabilityCheckValidityDurationSeconds.toString(),
      parameters.teeSigningPolicyValidityDurationInRewardEpochs.toString(),
      parameters.teeChallengeValidityDurationSeconds.toString(),
      parameters.teeDefaultFeeWei.toString(),
    ]
  );

  // 4. Deploy FlareTeeManager Diamond
  const FlareTeeManager = hre.artifacts.require("FlareTeeManager");
  const flareTeeManager = await FlareTeeManager.new(facetCuts, { init: flareTeeManagerInit.address, initCalldata });
  spewNewContractInfo(contracts, null, "FlareTeeManager", "FlareTeeManager.sol", flareTeeManager.address, quiet);

  // 5. Post-init configuration (governance calls are immediate before production mode)
  // Access facets through the diamond address
  const ExtensionManagerFacet = hre.artifacts.require("ExtensionManagerFacet");
  const extensionManager = await ExtensionManagerFacet.at(flareTeeManager.address);

  const OperationFeesFacet = hre.artifacts.require("OperationFeesFacet");
  const operationFeesFacet = await OperationFeesFacet.at(flareTeeManager.address);

  // Set operation fees
  const operationTypes: string[] = [];
  const operationCommands: string[] = [];
  const operationFees: string[] = [];
  for (const teeOperationFee of parameters.teeOperationFees) {
    operationTypes.push(hre.web3.utils.utf8ToHex(teeOperationFee.opType).padEnd(66, "0"));
    operationCommands.push(hre.web3.utils.utf8ToHex(teeOperationFee.opCommand).padEnd(66, "0"));
    operationFees.push(teeOperationFee.feeWei);
  }
  await operationFeesFacet.setOperationFees(operationTypes, operationCommands, operationFees);

  // Add system supported platforms
  await extensionManager.addSystemSupportedPlatforms(
    parameters.teeSupportedPlatforms.map((platform: string) => hre.web3.utils.utf8ToHex(platform).padEnd(66, "0"))
  );

  // Add system supported key types and signing algorithms
  await extensionManager.addSystemSupportedKeyTypesAndSigningAlgos(
    parameters.teeSupportedKeyTypesWithSigningAlgos.map((cfg: TeeKeyTypeWithSigningAlgos) =>
      hre.web3.utils.utf8ToHex(cfg.keyType).padEnd(66, "0")
    ),
    parameters.teeSupportedKeyTypesWithSigningAlgos.map((cfg: TeeKeyTypeWithSigningAlgos) =>
      cfg.signingAlgos.map((alg: string) => hre.web3.utils.utf8ToHex(alg).padEnd(66, "0"))
    )
  );

  // Add system extension supported key types
  await extensionManager.addSupportedKeyTypes(
    0, // system extension id
    [
      ...new Set(
        parameters.teePaymentConfigurations.map((cfg: TeePaymentConfiguration) =>
          hre.web3.utils.utf8ToHex(cfg.keyType).padEnd(66, "0")
        )
      ),
    ]
  );

  return flareTeeManager.address;
}

/**
 * Deploys later facets (replication, governance, version manager)
 * and adds them to the existing FlareTeeManager Diamond via diamondCut.
 */
export async function addLaterFacets(
  hre: HardhatRuntimeEnvironment,
  flareTeeManagerAddress: string,
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false
): Promise<void> {
  const { facetCuts, facetAddresses } = await deployFacetsAndBuildCuts(hre, LATER_FACETS);

  for (const facetName of LATER_FACETS) {
    spewNewContractInfo(contracts, null, facetName, `${facetName}.sol`, facetAddresses[facetName], quiet);
  }

  // Deploy ReplicationInit for the replication facet init
  const ReplicationInit = hre.artifacts.require("ReplicationInit");
  const teeReplicationInit = await ReplicationInit.new();
  spewNewContractInfo(
    contracts,
    null,
    "ReplicationInit",
    "ReplicationInit.sol",
    teeReplicationInit.address,
    quiet
  );

  const initCalldata = hre.web3.eth.abi.encodeFunctionCall(
    (ReplicationInit.abi as AbiItem[]).find((item: AbiItem) => item.name === "init")!,
    [parameters.teePauseBeforeUpgradeMinDurationSeconds.toString()]
  );

  // Execute diamondCut on FlareTeeManager
  const IDiamondCut = hre.artifacts.require("IDiamondCut");
  const flareTeeManager = await IDiamondCut.at(flareTeeManagerAddress);
  await flareTeeManager.diamondCut(facetCuts, teeReplicationInit.address, initCalldata);
}
