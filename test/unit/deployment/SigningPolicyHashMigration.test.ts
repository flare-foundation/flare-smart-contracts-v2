import { expect } from "chai";
import { ethers } from "ethers";
import { chainBoundHash } from "../../../scripts/libs/protocol/ChainDomain";
import {
  signingPolicyHashForMigration
} from "../../../deployment/utils/SigningPolicyHashMigration";

describe("SigningPolicyHashMigration", () => {
  const chainId = 14;
  const contentHash = ethers.keccak256(ethers.toUtf8Bytes("policy"));

  it("wraps a legacy content hash exactly once", () => {
    expect(signingPolicyHashForMigration(contentHash, chainId, "legacy"))
      .to.equal(chainBoundHash(contentHash, chainId));
  });

  it("preserves an already chain-bound hash", () => {
    const bound = chainBoundHash(contentHash, chainId);
    expect(signingPolicyHashForMigration(bound, chainId, "chain-bound"))
      .to.equal(bound);
  });

  it("rejects zero, malformed, and ambiguous schemes", () => {
    expect(() => signingPolicyHashForMigration(ethers.ZeroHash, chainId, "legacy"))
      .to.throw("Invalid old Relay signing policy hash");
    expect(() => signingPolicyHashForMigration("0x12", chainId, "legacy"))
      .to.throw("Invalid old Relay signing policy hash");
    expect(() => signingPolicyHashForMigration(contentHash, chainId, "auto"))
      .to.throw("expected 'legacy' or 'chain-bound'");
  });
});
