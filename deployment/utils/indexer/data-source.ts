import { DataSource } from "typeorm";
import { retry } from "../retry";
import { TLPEvents, TLPState, TLPTransaction } from "./Entity";
import fs from "fs";

export const sqliteDatabase = `./db/indexer.db`;

export async function getDataSource(readOnly = false) {
  if (fs.existsSync(sqliteDatabase)) {
    fs.unlinkSync(sqliteDatabase);
  }

  // TODO: Load params from config
  const dataSource = new DataSource({
    type: "sqlite",
    database: sqliteDatabase,
    entities: [TLPTransaction, TLPEvents, TLPState],
    synchronize: !readOnly,
    flags: readOnly ? 1 : undefined,
  });
  await retry(async () => {
    await dataSource.initialize();
  });

  return dataSource;
}
