import { sleep } from "../../tasks/run-simulation";
import { getDataSource } from "./data-source";
import { DataSource } from "typeorm";
import { errorString } from "../error";
import { TLPEvents, TLPState, TLPTransaction } from "./Entity";
import { TxData, getFilteredBlock } from "./web3";
import { retry } from "../retry";

export interface ContractAddresses {
  submission: string;
  flareSystemManager: string;
}

export interface BlockData {
  readonly number: number;
  readonly timestamp: number;
  readonly hash: string;
  readonly transactions: readonly TxData[];
}

export class MockDBIndexer {
  private lastProcessedBlockNumber = 0;
  private dataSource!: DataSource;

  constructor(private readonly web3: Web3, private readonly contractAddresses: ContractAddresses) {}

  async run(startBlock: number | undefined = undefined) {
    this.dataSource = await getDataSource();

    if (startBlock) {
      this.lastProcessedBlockNumber = startBlock - 1;
    } else {
      this.lastProcessedBlockNumber = (await this.web3.eth.getBlockNumber()) - 1;
    }

    const state = new TLPState();
    state.id = 3;
    state.name = "last_chain_block";
    state.index = this.lastProcessedBlockNumber;
    state.block_timestamp = 0;
    state.updated = new Date();

    while (true) {
      await this.processNewBlocks(state);
      await sleep(500);
    }
  }

  async processNewBlocks(state: TLPState) {
    try {
      const currentBlockNumber = await this.web3.eth.getBlockNumber();
      while (this.lastProcessedBlockNumber < currentBlockNumber) {
        const block = await retry(
          async () => {
            return await getFilteredBlock(this.web3, this.lastProcessedBlockNumber + 1, [
              this.contractAddresses.submission,
              this.contractAddresses.flareSystemManager,
            ]);
          },
          3,
          3000
        );
        for (const tx of block.transactions) {
          await this.processTx(tx, block.timestamp, block.hash);
        }
        state.index = block.number;
        state.block_timestamp = block.timestamp;
        await this.dataSource.getRepository(TLPState).save(state);
        this.lastProcessedBlockNumber++;
      }
    } catch (e: unknown) {
      console.error(`Error processing new blocks ${this.lastProcessedBlockNumber}: ${errorString(e)}`);
      throw e;
    }
  }

  async processTx(tx: TxData, timestamp: number, blockHash: string) {
    try {
      const ftx = new TLPTransaction();
      ftx.hash = tx.tx.hash.slice(2);
      ftx.function_sig = tx.tx.input.slice(2, 10);
      ftx.input = tx.tx.input.slice(2);
      ftx.block_number = tx.tx.blockNumber!;
      ftx.block_hash = blockHash;
      ftx.status = tx.status ? 1 : 0;
      ftx.from_address = tx.tx.from.slice(2);
      ftx.transaction_index = tx.tx.transactionIndex ?? -1;
      ftx.to_address = tx.tx.to?.slice(2) ?? "";
      ftx.timestamp = timestamp;
      ftx.value = tx.tx.value;
      ftx.gas_price = tx.tx.gasPrice;
      ftx.gas = tx.tx.gas;

      await this.dataSource.getRepository(TLPTransaction).save(ftx);

      if (tx.logs) {
        for (const log of tx.logs) {
          const event = new TLPEvents();
          event.transaction_id = ftx;
          event.data = log.data.slice(2);
          event.topic0 = log.topics[0];
          event.topic1 = log.topics[1] ?? "";
          event.topic2 = log.topics[2] ?? "";
          event.topic3 = log.topics[3] ?? "";
          event.address = log.address.slice(2);
          event.log_index = log.logIndex;
          event.timestamp = timestamp;

          await this.dataSource.getRepository(TLPEvents).save(event);
        }
      }
    } catch (e) {
      console.error(`Tx: ${JSON.stringify(tx, null, 2)}`);
    }
  }
}
