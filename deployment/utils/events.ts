
import Web3 from "web3";
import type { AbiInput } from "web3-utils";

/**
 * Can be used to decode events that were emitted indirectly.
 *
 * I.e. if we call contract A, which calls contract B, which emits an event, the event won't be
 * decoded by Truffle in the response. So we have to decode it manually, specifying the contract
 * where it's defined.
 */
export function decodeLogs(
  response: Truffle.TransactionResponse<Truffle.AnyEvent>,
  emitter: Truffle.ContractInstance,
  eventName: string
): Truffle.TransactionLog<never>[] {
  const receipt = response.receipt as { rawLogs: Array<{ topics: string[]; data: string; address: string; logIndex?: number }> };
  const logs = receipt.rawLogs;

  const abi = emitter.abi;
  let address: string | null;
  try {
    address = emitter.address;
  } catch {
    address = null;
  }
  const eventABIs = abi.filter(x => x.type === "event" && x.name === eventName);
  if (eventABIs.length === 0) {
    throw new Error(`No ABI entry for event '${eventName}'`);
  } else if (eventABIs.length > 1) {
    throw new Error(`Multiple ABI entries for event '${eventName}', only uniquely named events are supported`);
  }

  const eventABI = eventABIs[0];
  const inputs: AbiInput[] = eventABI.inputs ?? [];
  const eventSignature = `${eventName}(${inputs.map(input => input.type).join(",")})`;
  const eventTopic = Web3.utils.sha3(eventSignature);

  return logs
    .filter(log => log.topics.length > 0 && log.topics[0] === eventTopic && (!address || log.address === address))
    .map(log => web3.eth.abi.decodeLog(inputs, log.data, log.topics.slice(1)))
    .map(decoded => ({ event: eventName, args: decoded })) as Truffle.TransactionLog<never>[];
}
