import { DataSource } from "typeorm";
import { retry } from "../retry";
import { TLPEvents, TLPState, TLPTransaction } from "./Entity";
import fs from "fs";
import { MEMORY_DATABASE_FILE } from "../../tasks/run-simulation";

export async function getDataSource(readOnly = false) {
  const sqliteDatabase = MEMORY_DATABASE_FILE
  if (!readOnly && fs.existsSync(sqliteDatabase)) {
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
