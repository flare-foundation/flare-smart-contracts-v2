
import Web3 from "web3";

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
  const logs: any[] = response.receipt.rawLogs;

  let abi: any[];
  let address: string | null;
  abi = emitter.abi;
  try {
    address = emitter.address;
  } catch (e) {
    address = null;
  }
  let eventABIs = abi.filter(x => x.type === "event" && x.name === eventName);
  if (eventABIs.length === 0) {
    throw new Error(`No ABI entry for event '${eventName}'`);
  } else if (eventABIs.length > 1) {
    throw new Error(`Multiple ABI entries for event '${eventName}', only uniquely named events are supported`);
  }

  const eventABI = eventABIs[0];
  const eventSignature = `${eventName}(${eventABI.inputs.map((input: any) => input.type).join(",")})`;
  const eventTopic = Web3.utils.sha3(eventSignature);

  return logs
    .filter(log => log.topics.length > 0 && log.topics[0] === eventTopic && (!address || log.address === address))
    .map(log => web3.eth.abi.decodeLog(eventABI.inputs, log.data, log.topics.slice(1)))
    .map(decoded => ({ event: eventName, args: decoded })) as any;
}
