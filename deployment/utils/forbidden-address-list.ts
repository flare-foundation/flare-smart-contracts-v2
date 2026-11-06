import fs from "fs";
import { ForbiddenAddressListInstance } from "../../typechain-truffle";
import { ChainParameters } from "../chain-config/chain-parameters";

/** The data file of OFAC's addresses, which update-forbidden-addresses.ts regenerates whole. */
export const FORBIDDEN_ADDRESSES_FILE = "deployment/chain-config/forbidden-addresses.json";

/** The data file of the addresses added by hand, each group naming its `source`; nothing rewrites it. */
export const MANUAL_FORBIDDEN_ADDRESSES_FILE = "deployment/chain-config/forbidden-addresses-manual.json";

/** Both data files, which every network loads. */
export const FORBIDDEN_ADDRESSES_FILES = [FORBIDDEN_ADDRESSES_FILE, MANUAL_FORBIDDEN_ADDRESSES_FILE];

/** The addresses one transaction adds, as DeployForbiddenAddressList.s.sol's `BATCH_SIZE`. */
export const FORBIDDEN_ADDRESS_BATCH_SIZE = 100;

/** A group of addresses and the sources it applies to, so an address forbidden on several chains is written once. */
interface ForbiddenAddressGroup {
  source?: string;
  sourceIds: string[];
  addresses: string[];
}

/** A group of EVM addresses of the manual file, naming its `source`. */
interface ForbiddenEvmAddressGroup {
  source: string;
  addresses: string[];
}

export type ForbiddenAddressListProfile = Pick<
  ChainParameters,
  "forbiddenAddressListMaintainers" | "forbiddenAddressListSources" | "forbiddenAddressListPersonalAccountProviders"
>;

interface ForbiddenAddressesData {
  lists?: ForbiddenAddressGroup[];
  evmAddresses?: string[];
  evmLists?: ForbiddenEvmAddressGroup[];
}

function readData(file: string): ForbiddenAddressesData {
  return JSON.parse(fs.readFileSync(file, "utf-8")) as ForbiddenAddressesData;
}

/** Every address the data files list for `sourceId`, in the files' order. */
export function forbiddenAddressesOf(sourceId: string, files: string[] = FORBIDDEN_ADDRESSES_FILES): string[] {
  return files.flatMap((file) =>
    (readData(file).lists ?? [])
      .filter((group) => group.sourceIds.includes(sourceId))
      .flatMap((group) => group.addresses)
  );
}

/**
 * The data files' EVM addresses, lowercased: they are `address` values with no spelling, written as OFAC writes them,
 * and web3 refuses a mixed-case address whose checksum is wrong.
 */
export function forbiddenEvmAddressesOf(files: string[] = FORBIDDEN_ADDRESSES_FILES): string[] {
  return files.flatMap((file) => {
    const data = readData(file);
    return [...(data.evmAddresses ?? []), ...(data.evmLists ?? []).flatMap((group) => group.addresses)].map((address) =>
      address.toLowerCase()
    );
  });
}

/** An FDC source id as the list's `bytes32`. */
export function sourceIdHex(sourceId: string): string {
  return "0x" + Buffer.from(sourceId, "utf-8").toString("hex").padEnd(64, "0");
}

/**
 * Loads a profile's maintainers and Personal Account providers, the forbidden addresses of its sources and the EVM
 * list into a freshly deployed list,
 * in batches of `FORBIDDEN_ADDRESS_BATCH_SIZE` — what DeployForbiddenAddressList.s.sol does on a real network. `from` must be the list's
 * governance outside production mode, so the additions execute at once.
 */
export async function loadForbiddenAddressList(
  list: ForbiddenAddressListInstance,
  profile: ForbiddenAddressListProfile,
  from: string,
  files: string[] = FORBIDDEN_ADDRESSES_FILES
): Promise<void> {
  if (profile.forbiddenAddressListMaintainers.length > 0) {
    await list.addMaintainers(profile.forbiddenAddressListMaintainers, { from });
  }
  for (const { sourceId, provider } of profile.forbiddenAddressListPersonalAccountProviders) {
    await list.setPersonalAccountProvider(sourceIdHex(sourceId), provider, { from });
  }
  for (const source of profile.forbiddenAddressListSources) {
    const addresses = forbiddenAddressesOf(source, files);
    for (let start = 0; start < addresses.length; start += FORBIDDEN_ADDRESS_BATCH_SIZE) {
      const batch = addresses.slice(start, start + FORBIDDEN_ADDRESS_BATCH_SIZE);
      await list.addForbiddenAddresses(sourceIdHex(source), batch, { from });
    }
  }
  const evmAddresses = forbiddenEvmAddressesOf(files);
  for (let start = 0; start < evmAddresses.length; start += FORBIDDEN_ADDRESS_BATCH_SIZE) {
    await list.addForbiddenEvmAddresses(evmAddresses.slice(start, start + FORBIDDEN_ADDRESS_BATCH_SIZE), { from });
  }
}
