import { bn254 } from "@noble/curves/bn254";
import { expect } from "chai";

import { g1compress, randomInt } from "../../../utils/sortition";

import { getTestFile } from "../../../utils/constants";
import { Bn256MockContract, Bn256MockInstance } from "../../../../typechain-truffle";

const Bn256Mock = artifacts.require("Bn256Mock") as Bn256MockContract;

contract(`Bn256.sol; ${getTestFile(__filename)}`, accounts => {
  let bn256Instance: Bn256MockInstance;
  before(async () => {
    const governance = accounts[0];
    if (!governance) throw new Error("No governance account");
    bn256Instance = await Bn256Mock.new();
  });

  it("should add two points", async () => {
    const r1 = randomInt(bn254.CURVE.n);
    const r2 = randomInt(bn254.CURVE.n);
    const a = bn254.ProjectivePoint.BASE.multiply(r1);
    const b = bn254.ProjectivePoint.BASE.multiply(r2);

    const c = await bn256Instance.publicG1Add(
      {
        x: a.x.toString(),
        y: a.y.toString(),
      },
      {
        x: b.x.toString(),
        y: b.y.toString(),
      }
    );

    const cCheck = a.add(b);
    expect(c.x.toString()).to.equal(cCheck.x.toString());
    expect(c.y.toString()).to.equal(cCheck.y.toString());
  });

  it("should multiply a point with a scalar", async () => {
    const r1 = randomInt(bn254.CURVE.n);
    const r2 = randomInt(bn254.CURVE.n);
    const a = bn254.ProjectivePoint.BASE.multiply(r1);

    const c = await bn256Instance.publicG1ScalarMultiply({ x: a.x.toString(), y: a.y.toString() }, r2.toString());

    const cCheck = a.multiply(r2);
    expect(c.x.toString()).to.equal(cCheck.x.toString());
    expect(c.y.toString()).to.equal(cCheck.y.toString());
  });
});
