import { GovernedBaseInstance } from "../../typechain-truffle";
import { toBN } from "web3-utils";
import { time } from "@nomicfoundation/hardhat-network-helpers";

const ZERO_BYTES32 = "0x0000000000000000000000000000000000000000000000000000000000000000";

export async function transferWithSuicide(amount: BN, from: string, to: string, web3: any) {
    const SuicidalMock = artifacts.require("SuicidalMock");
    if (amount.lten(0)) throw new Error("Amount must be positive");
    const suicidalMock = await SuicidalMock.new(to);
    await web3.eth.sendTransaction({ from: from, to: suicidalMock.address, value: amount });
    await suicidalMock.die();
}

export async function impersonateContract(contractAddress: string, gasBalance: BN, gasSource: string, network:any, web3: any) {
    // allow us to impersonate calls from contract address
    await network.provider.request({ method: "hardhat_impersonateAccount", params: [contractAddress] });
    // provide some balance for gas
    await transferWithSuicide(gasBalance, gasSource, contractAddress, web3);
}

export async function stopImpersonatingContract(contractAddress: string, network: any) {
    await network.provider.request({ method: "hardhat_stopImpersonatingAccount", params: [contractAddress] });
}

export async function emptyAddressBalance(address: string, toAccount: string, network: any, web3: any) {
    const gasPrice = toBN(100_000_000_000);
    const gasAmount = 21000;
    await impersonateContract(address, gasPrice.muln(gasAmount), toAccount, network, web3);
    const addressBalance = toBN(await web3.eth.getBalance(address));
    const amount = addressBalance.sub(gasPrice.muln(gasAmount));
    await web3.eth.sendTransaction({ from: address, to: toAccount, value: amount, gas: gasAmount, gasPrice: gasPrice });
    await stopImpersonatingContract(address, network);
}

export async function executeTimelockedGovernanceCall(artifacts: any, contract: Truffle.ContractInstance, methodCall: (governance: string) => Promise<Truffle.TransactionResponse<any>>) {
    const GovernanceSettings = artifacts.require("GovernanceSettings");

    const contractGoverned = contract as GovernedBaseInstance;
    const governanceSettings = await GovernanceSettings.at(await contractGoverned.governanceSettings());
    const governance = await governanceSettings.getGovernanceAddress();
    const executor = (await governanceSettings.getExecutors())[0];
    const response = await methodCall(governance);
    const timelockArgs = findRequiredEvent(response, "GovernanceCallTimelocked").args;
    await time.increaseTo(timelockArgs.allowedAfterTimestamp.toNumber() + 1);
    await contractGoverned.executeGovernanceCall(timelockArgs.selector, { from: executor });
}

const GOVERNANCE_SETTINGS_ADDRESS = "0x1000000000000000000000000000000000000007";
const GENESIS_GOVERNANCE_ADDRESS = "0xfffEc6C83c8BF5c3F4AE0cCF8c45CE20E4560BD7";

export async function testDeployGovernanceSettings(artifacts: any, governance: string, timelock: number, executors: string[], network: any) {
    const GovernanceSettings = artifacts.require("GovernanceSettings");

    const tempGovSettings = await GovernanceSettings.new();
    const governanceSettingsCode = await web3.eth.getCode(tempGovSettings.address);   // get deployed code
    await network.provider.send("hardhat_setCode", [GOVERNANCE_SETTINGS_ADDRESS, governanceSettingsCode]);
    await network.provider.send("hardhat_setStorageAt", [GOVERNANCE_SETTINGS_ADDRESS, "0x0", ZERO_BYTES32]);  // clear initialisation
    const governanceSettings = await GovernanceSettings.at(GOVERNANCE_SETTINGS_ADDRESS);
    await governanceSettings.initialise(governance, timelock, executors, { from: GENESIS_GOVERNANCE_ADDRESS });
    return governanceSettings;
}


export function findRequiredEvent<E extends Truffle.AnyEvent, N extends E['name']>(res: Truffle.TransactionResponse<E>, name: N): Truffle.TransactionLog<Extract<E, { name: N }>> {
    const event = res.logs.find(e => e.event === name) as any;
    assert.isTrue(event != null);
    return event;
}
