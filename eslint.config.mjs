// @ts-check
import { includeIgnoreFile } from "@eslint/compat";
import { defaultConfig } from "@flarenetwork/eslint-config-flare";
import prettier from "eslint-config-prettier";
import path from "node:path";
import { fileURLToPath } from "node:url";

const gitignorePath = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  ".gitignore",
);

export default [
  includeIgnoreFile(gitignorePath),
  ...defaultConfig,
  {
    ignores: [
      "eslint.config.mjs",
      ".solcover.js",
      "scripts/forge-lcov-prune.js",
      "scripts/slither-parse.js",
      "scripts/flare-tee-manager-selectors.js",
    ],
  },
  {
    rules: {
      // Hardhat/Truffle APIs return `any` (artifacts.require, web3, etc.)
      // causing ~2000 false positives. Warn until Hardhat is fully migrated to Forge.
      "@typescript-eslint/no-unsafe-assignment": "warn",
      "@typescript-eslint/no-unsafe-argument": "warn",
      "@typescript-eslint/no-unsafe-call": "warn",
      "@typescript-eslint/no-unsafe-member-access": "warn",
      "@typescript-eslint/no-unsafe-return": "warn",
    },
  },
  prettier,
];
