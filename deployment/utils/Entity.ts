interface Account {
  address: string;
  privateKey: string;
}

interface PrivateKeyWithBalance {
  privateKey: string;
  balance: string;
}

export interface Entity {
  readonly identity: Account;
  readonly submit: Account;
  readonly submitSignatures: Account;
  readonly signingPolicy: Account;
  readonly delegation: Account;
  readonly sortition: Account;
  readonly wrapped: string;
}

export function readEntities(filePath: string): Entity[] {
  const fs = require("fs");
  if (!fs.existsSync(filePath)) throw new Error(`File not found: ${filePath}`);
  const entitiesJson = fs.readFileSync(filePath);
  if (entitiesJson.length == 0) return [];
  return JSON.parse(entitiesJson);
}

export function getEntityAccounts(filePath: string): PrivateKeyWithBalance[] {
  const result = [];
  const entities = readEntities(filePath);
  for (const entity of entities) {
    result.push({ privateKey: entity.identity.privateKey, balance: "0" });
    result.push({ privateKey: entity.submit.privateKey, balance: "0" });
    result.push({ privateKey: entity.submitSignatures.privateKey, balance: "0" });
    result.push({ privateKey: entity.signingPolicy.privateKey, balance: "0" });
    if (entity.delegation.privateKey) {
      result.push({ privateKey: entity.delegation.privateKey, balance: "0" });
    }
  }
  return result;
}
