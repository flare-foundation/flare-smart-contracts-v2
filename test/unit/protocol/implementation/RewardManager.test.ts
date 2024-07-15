
import { expectRevert } from '@openzeppelin/test-helpers';
import { getTestFile } from "../../../utils/constants";
import { encodeContractNames } from '../../../utils/test-helpers';
import { Contracts } from '../../../../deployment/scripts/Contracts';
import { RelayContract } from '../../../../typechain-truffle/contracts/protocol/implementation/Relay';
import { MockContractContract, MockContractInstance } from '../../../../typechain-truffle/@gnosis.pm/mock-contract/contracts/MockContract.sol/MockContract';
import { RewardManagerContract } from '../../../../typechain-truffle';
import { RewardManagerInstance } from '../../../../typechain-truffle/contracts/protocol/implementation/RewardManager';

const RewardManager: RewardManagerContract = artifacts.require("RewardManager");
const MockContract: MockContractContract = artifacts.require("MockContract");

contract(`RewardManager.sol; ${getTestFile(__filename)}`, async accounts => {

  let rewardManager: RewardManagerInstance;
  let flareSystemsManager: MockContractInstance;
  const ADDRESS_UPDATER = accounts[16];

  beforeEach(async () => {
    rewardManager = await RewardManager.new(accounts[0], accounts[0], ADDRESS_UPDATER, "0x0000000000000000000000000000000000000000", 0);
    flareSystemsManager = await MockContract.new();
    await rewardManager.updateContractAddresses(
      encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.VOTER_REGISTRY, Contracts.CLAIM_SETUP_MANAGER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.FLARE_SYSTEMS_CALCULATOR, Contracts.P_CHAIN_STAKE_MIRROR, Contracts.WNAT, Contracts.FTSO_REWARD_MANAGER_PROXY]),
      [ADDRESS_UPDATER, accounts[2], accounts[2], flareSystemsManager.address, accounts[2], accounts[2], accounts[2], accounts[2]], { from: ADDRESS_UPDATER });
    await rewardManager.enableClaims();
    await rewardManager.activate();
  });

  it("Should revert for invalid claim type", async () => {
    const GET_CURRENT_REWARD_EPOCH_ID_SELECTOR = web3.utils.sha3("getCurrentRewardEpochId()")!.slice(0, 10); // first 4 bytes is function selector
    await flareSystemsManager.givenMethodReturnUint(GET_CURRENT_REWARD_EPOCH_ID_SELECTOR, 3);
    await expectRevert.unspecified(rewardManager.claim(accounts[1], accounts[2], 1, true, [{merkleProof: [], body: {rewardEpochId: 0, beneficiary: accounts[1], amount: 100, claimType: 5}}], { from: accounts[1] }));
  });

});
