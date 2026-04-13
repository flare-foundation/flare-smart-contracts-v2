import BN from "bn.js";
import Web3 from "web3";

export declare type RawEvent = import("web3-core").Log;

// eslint-disable-next-line @typescript-eslint/no-redundant-type-constituents
export type TruffleExtractEvent<E extends Truffle.AnyEvent, N extends E["name"]> = Truffle.TransactionLog<
  Extract<E, { name: N }>
>;

export type ContractWithEvents<C extends Truffle.ContractInstance, E extends Truffle.AnyEvent> = C & {
  "~eventMarker"?: E;
};

/**
 * Helper wrapper to convert number to BN
 * @param x number expressed in any reasonable type
 * @returns same number as BN
 */
export function toBN(x: BN | number | string): BN {
  if (BN.isBN(x)) return x;
  return Web3.utils.toBN(x);
}

/**
 * Check if value is non-null.
 * Useful in array.filter, to return array of non-nullable types.
 */
export function isNotNull<T>(x: T): x is NonNullable<T> {
  return x != null;
}

export interface EvmEvent {
  address: string;
  event: string;
  args: any;
  blockHash: string;
  blockNumber: number;
  logIndex: number;
  transactionHash: string;
  transactionIndex: number;
  type: string;
  signature: string;
}

class Web3EventDecoder {
  public eventTypes = new Map<string, AbiItem>(); // signature (topic[0]) => type

  constructor(contract: Truffle.ContractInstance, filter?: string[]) {
    for (const item of contract.abi) {
      // eslint-disable-next-line @typescript-eslint/no-unnecessary-type-assertion
      if (item.type === "event" && (filter == null || filter.includes(item.name!))) {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        this.eventTypes.set((item as any).signature as string, item);
      }
    }
  }

  decodeEvent(event: RawEvent): EvmEvent | null {
    const signature = event.topics[0];
    const evtType = this.eventTypes.get(signature);
    if (evtType == null) return null;
    // based on web3 docs, first topic has to be removed for non-anonymous events
    const topics = evtType.anonymous ? event.topics : event.topics.slice(1);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    // eslint-disable-next-line @typescript-eslint/no-unnecessary-type-assertion
    const decodedArgs: any = web3.eth.abi.decodeLog(evtType.inputs!, event.data, topics);
    // convert parameters based on type (BN for now)
    evtType.inputs!.forEach((arg, i) => {
      if (/^u?int\d*$/.test(arg.type)) {
        decodedArgs[i] = decodedArgs[arg.name] = toBN(decodedArgs[i]);
      } else if (/^u?int\d*\[\]$/.test(arg.type)) {
        decodedArgs[i] = decodedArgs[arg.name] = decodedArgs[i].map(toBN);
      }
    });
    return {
      address: event.address,
      type: evtType.type,
      signature: signature,
      event: evtType.name ?? "<unknown>",
      args: decodedArgs,
      blockHash: event.blockHash,
      blockNumber: event.blockNumber,
      logIndex: event.logIndex,
      transactionHash: event.transactionHash,
      transactionIndex: event.transactionIndex,
    };
  }

  // eslint-disable-next-line @typescript-eslint/no-redundant-type-constituents
  decodeEvents(tx: Truffle.TransactionResponse<any> | TransactionReceipt): EvmEvent[] {
    // for truffle, must decode tx.receipt.rawLogs to also obtain logs from indirectly called contracts
    // for plain web3, just decode receipt.logs
    const receipt: TransactionReceipt = "receipt" in tx ? tx.receipt : tx;
    const rawLogs: RawEvent[] = "rawLogs" in receipt ? (receipt as any).rawLogs : receipt.logs;
    // decode all events
    return rawLogs.map((raw) => this.decodeEvent(raw)).filter(isNotNull);
  }

  findEvent<E extends Truffle.AnyEvent, N extends E["name"]>(
    response: Truffle.TransactionResponse<E>,
    name: N
  ): // eslint-disable-next-line @typescript-eslint/no-redundant-type-constituents
  TruffleExtractEvent<E, N> | undefined {
    const logs = this.decodeEvents(response);
    return logs.find((e) => e.event === name) as any;
  }
}

export function findRequiredEventFrom<
  C extends Truffle.ContractInstance,
  E extends Truffle.AnyEvent,
  N extends E["name"],
>(response: Truffle.TransactionResponse<any>, contract: ContractWithEvents<C, E>, name: N): TruffleExtractEvent<E, N> {
  const eventDecoder = new Web3EventDecoder(contract);
  const event = eventDecoder.findEvent(response, name);
  if (event == null) {
    throw new Error(`Missing event ${name}`);
  }
  return event;
}

export function requiredEventArgsFrom<
  C extends Truffle.ContractInstance,
  E extends Truffle.AnyEvent,
  N extends E["name"],
>(
  response: Truffle.TransactionResponse<any>,
  contract: ContractWithEvents<C, E>,
  name: N
): TruffleExtractEvent<E, N>["args"] {
  return findRequiredEventFrom(response, contract, name).args;
}
