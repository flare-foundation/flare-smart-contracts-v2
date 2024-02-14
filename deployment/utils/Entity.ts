interface Account {
  address: string;
  privateKey: string;
}

export interface Entity {
  readonly identity: Account;
  readonly submit: Account;
  readonly submitSignatures: Account;
  readonly signingPolicy: Account;
  readonly delegation: Account;
  readonly wrapped: string;
}

export function readEntities(filePath: string): Entity[] {
  const fs = require("fs");
  if (!fs.existsSync(filePath)) throw new Error(`File not found: ${filePath}`);
  const contractsJson = fs.readFileSync(filePath);
  if (contractsJson.length == 0) return [];
  return JSON.parse(contractsJson);
}
