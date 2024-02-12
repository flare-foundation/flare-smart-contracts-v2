import { HardhatRuntimeEnvironment } from "hardhat/types";
import { pascalCase } from "pascal-case";
import {   } from "../../typechain-truffle";
import { ChainParameters } from "../chain-config/chain-parameters";
import { Contract, Contracts } from "./Contracts";
import { readFileSync } from "fs";

export interface AssetDefinition {
  name?: string;
  symbol: string;
  wSymbol?: string;
  decimals?: number;
  ftsoDecimals: number;
  maxMintRequestTwei?: number;
  initialPriceUSDDec5: number;
}

const Ajv = require('ajv');
const ajv = new Ajv();
const validateParamaterSchema = ajv.compile(require('../chain-config/chain-parameters.json'));

// Load parameters with validation against schema chain-parameters.json
export function loadParameters(filename: string): ChainParameters {
  const jsonText = readFileSync(filename).toString();
  const parameters = JSON.parse(jsonText);
  return validateParameters(parameters);
}

// Validate already decoded parameters; to be used with require
export function validateParameters(parameters: any): ChainParameters {
  if (!validateParamaterSchema(parameters)) {
    throw new Error(`Invalid format of parameter file`);
  }
  return parameters;
}

// Here we should add certain verifications of parameters
export function verifyParameters(parameters: ChainParameters) {
  if (parameters.initialVoters.length !== parameters.initialNormalisedWeights.length) {
    throw new Error(`Mismatch between initialVoters and initialNormalisedWeights`);
  }
  let totalInitialNormalisedWeight = 0;
  for (const initialNormalisedWeight of parameters.initialNormalisedWeights) {
    if (initialNormalisedWeight <= 0 || initialNormalisedWeight >= 2**16) {
      throw new Error(`Invalid initialNormalisedWeight: ${initialNormalisedWeight}`);
    }
    totalInitialNormalisedWeight += initialNormalisedWeight;
  }
  if (totalInitialNormalisedWeight === 0) {
    throw new Error(`Total initialNormalisedWeight is zero`);
  }
  if (totalInitialNormalisedWeight >= 2**16) {
    throw new Error(`Total initialNormalisedWeight is too large`);
  }
  if (totalInitialNormalisedWeight <= parameters.initialThreshold) {
    throw new Error(`Total initialThreshold is too large`);
  }
}

export function spewNewContractInfo(contracts: Contracts, addressUpdaterContracts: string[] | null, name: string, contractName: string, address: string, quiet = false, pascal = true) {
  if (!quiet) {
    console.error(`${name} contract: `, address);
  }
  if (pascal) {
    contracts.add(new Contract(pascalCase(name), contractName, address));
  }
  else {
    contracts.add(new Contract(name.replace(/\s/g, ""), contractName, address));
  }
  if (addressUpdaterContracts) {
    addressUpdaterContracts.push(name);
  }
}

// waitFinalize3 and setDefaultVPContract are duplicated from test helper library because imports contain hardhat runtime.
// Because this procedure now runs as a hardhat task, the hardhat runtime cannot be imported, as this procedure
// is now considered a part of the HH configuration.

/**
 * Finalization wrapper for web3/truffle. Needed on Flare network since account nonce has to increase
 * to have the transaction confirmed.
 * @param address
 * @param func
 * @returns
 */
 export async function waitFinalize3(hre: HardhatRuntimeEnvironment, address: string, func: () => any) {
  const web3 = hre.web3;
  let nonce = await web3.eth.getTransactionCount(address);
  let res = await func();
  while ((await web3.eth.getTransactionCount(address)) == nonce) {
    await new Promise((resolve: any) => { setTimeout(() => { resolve() }, 1000) })
    // console.log("Waiting...")
  }
  return res;
}


