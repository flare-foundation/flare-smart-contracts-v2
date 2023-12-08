
import { expectRevert } from '@openzeppelin/test-helpers';
import { getTestFile } from "../../utils/constants";
import { CustomErrorRevertInstance } from '../../../typechain-truffle';


const CustomErrorRevert = artifacts.require("CustomErrorRevert");

contract(`CustomErrorRevert.sol; ${getTestFile(__filename)}`, async accounts => {

  let customErrorRevert: CustomErrorRevertInstance;

  beforeEach(async () => {
    customErrorRevert = await CustomErrorRevert.new();
  });

  it("Should revert with message", async () => {
    await expectRevert(customErrorRevert.errorRevert(true), `CustomErrorMessage(\"some error message\")`);
    await expectRevert(customErrorRevert.errorRevert(true), "some error message");
  });

  it("Should revert without message", async () => {
    await expectRevert(customErrorRevert.errorRevert(false), "CustomError");
  });

  it("Should revert message string and uint", async () => {
    // this works
    await expectRevert(customErrorRevert.errorRevertUint(123), `CustomErrorUint(\"error message\", 123)`);
    // but also this
    await expectRevert(customErrorRevert.errorRevertUint(123), "CustomErrorUint");
    // and this
    await expectRevert(customErrorRevert.errorRevertUint(123), "CustomError");
    // or this...
    await expectRevert(customErrorRevert.errorRevertUint(123), "123");
  });

});
