# Security policy

## Reporting a vulnerability

If you have found a possible vulnerability, please email
`security at flare dot network`.

## Bug bounties

We sincerely appreciate and encourage reports of suspected security
vulnerabilities. We currently run a bug bounty program through Immunefi, where
eligible researchers can earn rewards for responsibly disclosing valid security
issues. Please refer to our
[Immunefi](https://immunefi.com/bug-bounty/flarenetwork/information/) page for
scope, rules, and submission guidelines.

## Vulnerability disclosures

Critical vulnerabilities will be disclosed via GitHub's
[security advisory](https://github.com/flare-foundation/flare-smart-contracts-v2/security)
system.

## Review scope

### In scope
- `contracts/adapters/**/*`
- `contracts/customFeeds/**/*`
- `contracts/fastUpdates/**/*`
- `contracts/fdc/**/*`
- `contracts/fdc2/**/*`
- `contracts/fscV1/**/*`
- `contracts/ftso/**/*`
- `contracts/governance/**/*`
- `contracts/incentivePool/**/*`
- `contracts/inflation/**/*`
- `contracts/protocol/**/*`
- `contracts/rNat/**/*`
- `contracts/staking/**/*`
- `contracts/tee/**/*`
- `contracts/userInterfaces/**/*`
- `contracts/utils/**/*`

### Out of scope

- `contracts/diamond/**/*`
- `contracts/mock/**/*`

## Previous audits

| Auditor | Date | Scope | Report |
| ------- | ---- | ----- | ------ |
| Zellic | March 2026 | FSP V1 and V2 | [Smart Contract Security Assessment](./audit/2026-03-16-Zellic-FSP_V1_and_V2_Smart_Contract_Security_Assessment.pdf) |
| Zellic | June 2026 | FIP 16 | [Smart Contract Patch Review](./audit/2026-06-22-Zellic-FIP_16_Smart_Contract_Patch_Review.pdf) |
