
import { expectRevert } from '@openzeppelin/test-helpers';
import { getTestFile } from "../../utils/constants";
import { TestCustomErrorContract, TestCustomErrorInstance } from '../../../typechain-truffle/contracts/mock/TestCustomError';
import { TestCustomErrorInterface } from '../../../typechain/contracts/mock/TestCustomError';

const TestCustomError = artifacts.require("TestCustomError");

contract(`CustomError.sol; ${getTestFile(__filename)}`, async accounts => {

  let testCustomError: TestCustomErrorInstance;

  beforeEach(async () => {
    testCustomError = await TestCustomError.new();
  });

  it("Should revert with message", async () => {
    await expectRevert(testCustomError.testError(true), `CustomErrorMessage(\"some error message\")`);
    await expectRevert(testCustomError.testError(true), "some error message");
  });

  it("Should revert without message", async () => {
    await expectRevert(testCustomError.testError(false), "CustomError");
  });

  it("Should revert message string and uint", async () => {
    // this works
    await expectRevert(testCustomError.testErrorUint(123), `CustomErrorUint(\"error message\", 123)`);
    // but also this
    await expectRevert(testCustomError.testErrorUint(123), "CustomErrorUint");
    // and this
    await expectRevert(testCustomError.testErrorUint(123), "CustomError");
  });

});
