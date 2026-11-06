#!/usr/bin/env node
import { readFileSync, writeFileSync } from "node:fs";
import { FORBIDDEN_ADDRESSES_FILE } from "../utils/forbidden-address-list";

// Regenerates deployment/chain-config/forbidden-addresses.json from OFAC's SDN list
// (https://sanctionslist.ofac.treas.gov/Home/SdnList), whose entries carry their digital currency addresses as
// `Digital Currency Address - <currency>` ids:
// - BTC: the `XBT` addresses, and the `USDT` ones that are Bitcoin addresses (USDT issued on Bitcoin through Omni);
// - XRP: the `XRP` addresses, for `testXRP` too — an XRPL classic address names no network, so the same strings are
//   canonical on the test networks, where the costons load them (Bitcoin's name theirs, so `BTC` is mainnet only);
// - the EVM list (`evmAddresses`, one for every EVM chain): every `0x` address, whatever currency OFAC files it under
//   (ETH, USDT, USDC, ETC, BSC, ARB, …) — an EVM address is the same holder on every EVM chain.
// BTC and XRP addresses are written in the form the FDC hashes (lowercase Bech32, Base58 as written); EVM addresses as
// OFAC writes them, since they are loaded as `address` values, which have no spelling. An address that does not have
// its list's shape is reported and left out. Pass `--file <SDN.XML>` to read a downloaded copy.
//
//   pnpm update_forbidden_addresses [--file <SDN.XML>]

const SDN_XML_URL = "https://sanctionslistservice.ofac.treas.gov/api/PublicationPreview/exports/SDN.XML";

const BITCOIN_BASE58 = /^[13][1-9A-HJ-NP-Za-km-z]{25,34}$/;
const BITCOIN_BECH32 = /^bc1[02-9ac-hj-np-z]{11,71}$/;
const XRP_BASE58 = /^r[1-9A-HJ-NP-Za-km-z]{24,34}$/;
const EVM_HEX = /^0x[0-9a-fA-F]{40}$/;

interface CurrencyAddress {
  currency: string;
  address: string;
}

async function readSdnXml(file: string | undefined): Promise<string> {
  if (file !== undefined) {
    return readFileSync(file, "utf-8");
  }
  const response = await fetch(SDN_XML_URL);
  if (!response.ok) {
    throw new Error(`${SDN_XML_URL}: HTTP ${response.status}`);
  }
  return response.text();
}

/** Every `<id>` of the list whose type is a digital currency address. */
function currencyAddresses(xml: string): CurrencyAddress[] {
  const found: CurrencyAddress[] = [];
  for (const id of xml.matchAll(/<id>([\s\S]*?)<\/id>/g)) {
    const type = /<idType>Digital Currency Address - ([^<]+)<\/idType>/.exec(id[1]);
    const address = /<idNumber>([^<]+)<\/idNumber>/.exec(id[1]);
    if (type && address) {
      found.push({ currency: type[1].trim(), address: address[1].trim() });
    }
  }
  return found;
}

/** The distinct addresses, sorted, after `canonical`; `undefined` from it rejects an address. */
function collect(
  entries: CurrencyAddress[],
  canonical: (address: string) => string | undefined,
  label: string
): string[] {
  const addresses = new Set<string>();
  for (const entry of entries) {
    const address = canonical(entry.address);
    if (address === undefined) {
      console.warn(`${label}: left out ${entry.currency} ${entry.address} (not a ${label} address)`);
    } else {
      addresses.add(address);
    }
  }
  return [...addresses].sort();
}

function bitcoin(address: string): string | undefined {
  if (BITCOIN_BASE58.test(address)) {
    return address;
  }
  const lower = address.toLowerCase();
  return BITCOIN_BECH32.test(lower) ? lower : undefined;
}

function xrp(address: string): string | undefined {
  return XRP_BASE58.test(address) ? address : undefined;
}

/** The distinct EVM addresses as OFAC writes them (the first spelling of each), sorted case-insensitively. */
function collectEvm(entries: CurrencyAddress[]): string[] {
  const addresses = new Map<string, string>();
  for (const entry of entries) {
    if (!EVM_HEX.test(entry.address)) {
      console.warn(`EVM: left out ${entry.currency} ${entry.address} (not an EVM address)`);
    } else if (!addresses.has(entry.address.toLowerCase())) {
      addresses.set(entry.address.toLowerCase(), entry.address);
    }
  }
  return [...addresses.keys()].sort().map((key) => addresses.get(key) as string);
}

async function main(): Promise<void> {
  const fileIndex = process.argv.indexOf("--file");
  const xml = await readSdnXml(fileIndex >= 0 ? process.argv[fileIndex + 1] : undefined);
  const publishDate = /<Publish_Date>([^<]+)<\/Publish_Date>/.exec(xml)?.[1];
  if (publishDate === undefined) {
    throw new Error("not an SDN list: no Publish_Date");
  }
  const entries = currencyAddresses(xml);
  const lists = [
    {
      sourceIds: ["BTC"],
      addresses: collect(
        entries.filter((entry) => entry.currency === "XBT" || (entry.currency === "USDT" && bitcoin(entry.address))),
        bitcoin,
        "BTC"
      ),
    },
    {
      sourceIds: ["XRP", "testXRP"],
      addresses: collect(
        entries.filter((entry) => entry.currency === "XRP"),
        xrp,
        "XRP"
      ),
    },
  ];
  const evmAddresses = collectEvm(entries.filter((entry) => entry.address.startsWith("0x")));
  writeFileSync(
    FORBIDDEN_ADDRESSES_FILE,
    JSON.stringify({ source: SDN_XML_URL, publishDate, lists, evmAddresses }, null, 2) + "\n"
  );
  for (const list of lists) {
    console.log(`${list.sourceIds.join(", ")}: ${list.addresses.length} addresses`);
  }
  console.log(`EVM: ${evmAddresses.length} addresses`);
  console.log(`Wrote ${FORBIDDEN_ADDRESSES_FILE} (SDN list of ${publishDate}).`);
}

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});
