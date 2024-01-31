import { sleep } from "../../tasks/run-simulation";
import { getDataSource } from "./data-source";
import { DataSource } from "typeorm";
import { errorString } from "../error";
import { TLPEvents, TLPState, TLPTransaction } from "./Entity";
import { TxData, getFilteredBlock } from "./web3";
import { retry } from "../retry";
import { FIRST_DATABASE_INDEX_STATE, LAST_CHAIN_INDEX_STATE, LAST_DATABASE_INDEX_STATE } from "../constants";

export interface ContractAddresses {
  submission: string;
  flareSystemsManager: string;
  voterRegistry: string;
  ftsoRewardOffersManager: string;
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


    const firstDatabaseIndexState = new TLPState();
    firstDatabaseIndexState.id = 1;
    firstDatabaseIndexState.name = FIRST_DATABASE_INDEX_STATE;
    firstDatabaseIndexState.index = this.lastProcessedBlockNumber;
    firstDatabaseIndexState.block_timestamp = 0;
    firstDatabaseIndexState.updated = new Date();


    const lastDatabaseIndexState = new TLPState();
    lastDatabaseIndexState.id = 2;
    lastDatabaseIndexState.name = LAST_DATABASE_INDEX_STATE;
    lastDatabaseIndexState.index = this.lastProcessedBlockNumber;
    lastDatabaseIndexState.block_timestamp = 0;
    lastDatabaseIndexState.updated = new Date();


    const lastChainIndexState = new TLPState();
    lastChainIndexState.id = 3;
    lastChainIndexState.name = LAST_CHAIN_INDEX_STATE;
    lastChainIndexState.index = this.lastProcessedBlockNumber;
    lastChainIndexState.block_timestamp = 0;
    lastChainIndexState.updated = new Date();

    while (true) {
      await this.processNewBlocks(firstDatabaseIndexState, lastDatabaseIndexState, lastChainIndexState);
      await sleep(500);
    }
  }


  async processNewBlocks(firstDatabaseIndexState: TLPState, lastDatabaseIndexState: TLPState, lastChainIndexState: TLPState) {
    try {
      const currentBlockNumber = await this.web3.eth.getBlockNumber();
      while (this.lastProcessedBlockNumber < currentBlockNumber) {
        const block = await retry(
          async () => {
            return await getFilteredBlock(this.web3, this.lastProcessedBlockNumber + 1, [
              this.contractAddresses.submission,
              this.contractAddresses.flareSystemsManager,
              this.contractAddresses.voterRegistry,
              this.contractAddresses.ftsoRewardOffersManager,
            ]);
          },
          3,
          3000
        );
        for (const tx of block.transactions) {
          await this.processTx(tx, block.timestamp, block.hash);
        }
        await this.dataSource.transaction(async (manager) => {
          if (firstDatabaseIndexState.block_timestamp === 0) {
            firstDatabaseIndexState.index = block.number;
            firstDatabaseIndexState.block_timestamp = block.timestamp;
            firstDatabaseIndexState.updated = new Date();
          }  

          lastDatabaseIndexState.index = block.number;
          lastDatabaseIndexState.block_timestamp = block.timestamp;
          lastDatabaseIndexState.updated = new Date();
          lastChainIndexState.index = block.number;
          lastChainIndexState.block_timestamp = block.timestamp;
          lastChainIndexState.updated = new Date();
          await manager.getRepository(TLPState).save(firstDatabaseIndexState);
          await manager.getRepository(TLPState).save(lastDatabaseIndexState);
          await manager.getRepository(TLPState).save(lastChainIndexState);
        });
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
      ftx.hash = tx.tx.hash.slice(2).toLowerCase();
      ftx.function_sig = tx.tx.input.slice(2, 10).toLowerCase();
      ftx.input = tx.tx.input.slice(2).toLowerCase();
      ftx.block_number = tx.tx.blockNumber!;
      ftx.block_hash = blockHash.startsWith("0x") ? blockHash.slice(2).toLowerCase() : blockHash.toLowerCase();
      ftx.status = tx.status ? 1 : 0;
      ftx.from_address = tx.tx.from.slice(2)?.toLowerCase() ?? "";
      ftx.transaction_index = tx.tx.transactionIndex ?? -1;
      ftx.to_address = tx.tx.to?.slice(2)?.toLowerCase() ?? "";
      ftx.timestamp = timestamp;
      ftx.value = tx.tx.value;
      ftx.gas_price = tx.tx.gasPrice;
      ftx.gas = tx.tx.gas;

      await this.dataSource.getRepository(TLPTransaction).save(ftx);

      if (tx.logs) {
        for (const log of tx.logs) {
          const event = new TLPEvents();
          event.transaction_id = ftx;
          event.data = log.data.slice(2).toLowerCase();
          event.topic0 = log.topics[0]?.slice(2)?.toLowerCase() ?? "";
          event.topic1 = log.topics[1]?.slice(2)?.toLowerCase() ?? "";
          event.topic2 = log.topics[2]?.slice(2)?.toLowerCase() ?? "";
          event.topic3 = log.topics[3]?.slice(2)?.toLowerCase() ?? "";
          event.address = log.address.slice(2).toLowerCase();
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
