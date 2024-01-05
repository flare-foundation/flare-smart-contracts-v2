import Web3 from "web3";
import { retry } from "../retry";
import { TransactionReceipt, Transaction, Log } from "web3-core/types";
import { BlockData } from "./MockDBIndexer";

export interface TxData {
  readonly tx: Transaction;
  readonly status: boolean;
  readonly logs?: Log[];
}
/**
 * Retrieves block for a given {@link blockNumber} and returns {@link BlockData} containing only transactions to the specified {@link contractAddresses}.
 */
export async function getFilteredBlock(
  web3: Web3,
  blockNumber: number,
  contractAddresses: string[]
): Promise<BlockData> {
  const rawBlock = await web3.eth.getBlock(blockNumber, true);
  // console.log(`Block ${blockNumber} retrieved: ${JSON.stringify(rawBlock, null, 2)}}`);
  if (rawBlock === null) throw new Error(`Block ${blockNumber} not found`);
  if (rawBlock.number === null) throw new Error(`Block ${blockNumber} is still pending.`);

  const relevantContracts = new Set(contractAddresses);
  const relevantTransactions = rawBlock.transactions.filter(tx => tx.to != null && relevantContracts.has(tx.to));
  const receiptPromises = relevantTransactions.map(async tx => {
    let receipt: TransactionReceipt;
    try {
      receipt = await retry(async () => web3.eth.getTransactionReceipt(tx.hash));
    } catch (e) {
      throw new Error(`Error getting receipt for block ${blockNumber} tx ${JSON.stringify(tx, null, 2)}`, { cause: e });
    }
    if (receipt === null) {
      throw new Error(`Receipt for transaction ${tx.hash} is null, transaction: ${JSON.stringify(tx, null, 2)}`);
    }
    return receipt;
  });

  const receipts = await Promise.all(receiptPromises);

  const blockData: BlockData = {
    number: rawBlock.number,
    hash: rawBlock.hash,
    timestamp: parseInt("" + rawBlock.timestamp, 10),
    transactions: relevantTransactions.map((tx, i) => {
      const txData: TxData = {
        tx: tx,
        status: receipts[i].status,
        logs: receipts[i].logs,
      };
      return txData;
    }),
  };
  return blockData;
}
