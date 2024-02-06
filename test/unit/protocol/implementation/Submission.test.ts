
import { expectRevert } from '@openzeppelin/test-helpers';
import { getTestFile } from "../../../utils/constants";
import { SubmissionContract, SubmissionInstance } from '../../../../typechain-truffle/contracts/protocol/implementation/Submission';
import { encodeContractNames } from '../../../utils/test-helpers';
import { Contracts } from '../../../../deployment/scripts/Contracts';
import { RelayContract } from '../../../../typechain-truffle/contracts/protocol/implementation/Relay';
import { MockContractContract } from '../../../../typechain-truffle/@gnosis.pm/mock-contract/contracts/MockContract.sol/MockContract';

const Submission: SubmissionContract = artifacts.require("Submission");
const Relay: RelayContract = artifacts.require("Relay");
const MockContract: MockContractContract = artifacts.require("MockContract");

contract(`Submission.sol; ${getTestFile(__filename)}`, async accounts => {

  let submission: SubmissionInstance;
  const ADDRESS_UPDATER = accounts[16];

  beforeEach(async () => {
    submission = await Submission.new(accounts[0], accounts[0], ADDRESS_UPDATER, false);
    await submission.updateContractAddresses(
      encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.RELAY]),
      [ADDRESS_UPDATER, accounts[2], accounts[3]], { from: ADDRESS_UPDATER });

  });

  it("Should revert 1", async () => {
    const relay = await Relay.new(accounts[1], 0, 0, web3.utils.keccak256("test"), 1, 242, 90, 0, 23, 12000);
    await submission.setSubmitAndPassData(relay.address, web3.utils.keccak256("relay()").slice(0, 10)); // first 4 bytes is function selector
    let startBalance = BigInt(await web3.eth.getBalance(accounts[0]));
    await expectRevert(submission.submitAndPass(web3.utils.keccak256("some data")), "Invalid sign policy length");
    console.log(`tx fee (wei): ${startBalance - BigInt(await web3.eth.getBalance(accounts[0]))}`);
  });

  it("Should revert 2", async () => {
    const methodSignature = web3.utils.sha3("test()")!.slice(0, 10); // first 4 bytes is function selector
    const mockContract = await MockContract.new();
    await mockContract.givenMethodRunOutOfGas(methodSignature);
    await submission.setSubmitAndPassData(mockContract.address, methodSignature);
    let startBalance = BigInt(await web3.eth.getBalance(accounts[0]));
    await expectRevert(submission.submitAndPass(web3.utils.keccak256("some data")), "Transaction reverted silently");
    console.log(`tx fee (wei): ${startBalance - BigInt(await web3.eth.getBalance(accounts[0]))}`);
  });

  it("Should revert 3", async () => {
    const methodSignature = web3.utils.sha3("test()")!.slice(0, 10); // first 4 bytes is function selector
    const revertMessage = "Revert message test";
    const mockContract = await MockContract.new();
    await mockContract.givenMethodRevertWithMessage(methodSignature, revertMessage);
    await submission.setSubmitAndPassData(mockContract.address, methodSignature);
    let startBalance = BigInt(await web3.eth.getBalance(accounts[0]));
    await expectRevert(submission.submitAndPass(web3.utils.keccak256("some data")), revertMessage);
    console.log(`tx fee (wei): ${startBalance - BigInt(await web3.eth.getBalance(accounts[0]))}`);
  });

});
