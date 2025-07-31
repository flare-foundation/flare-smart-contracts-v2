import { constants, expectEvent, expectRevert, time } from '@openzeppelin/test-helpers';
import { toChecksumAddress } from 'ethereumjs-util';
import { Contracts } from '../../deployment/scripts/Contracts';
import privateKeys from "../../deployment/test-1020-accounts.json";
import { RelayInitialConfig } from '../../deployment/utils/RelayInitialConfig';
import { ECDSASignatureWithIndex } from "../../scripts/libs/protocol/ECDSASignatureWithIndex";
import { FtsoConfigurations } from '../../scripts/libs/protocol/FtsoConfigurations';
import { IProtocolMessageMerkleRoot, ProtocolMessageMerkleRoot } from "../../scripts/libs/protocol/ProtocolMessageMerkleRoot";
import { RelayMessage } from '../../scripts/libs/protocol/RelayMessage';
import { ISigningPolicy, SigningPolicy } from "../../scripts/libs/protocol/SigningPolicy";
import { AddressBinderInstance, EntityManagerInstance, FtsoFeedIdConverterContract, FtsoFeedIdConverterInstance, FtsoFeedPublisherContract, FtsoFeedPublisherInstance, FtsoInflationConfigurationsInstance, GovernanceSettingsInstance, GovernanceVotePowerInstance, MockContractInstance, PChainStakeMirrorInstance, PChainStakeMirrorVerifierInstance, RewardManagerContract, TeeExtensionRegistryContract, TeeGovernanceProxyContract, TeeInstructionsProxyContract, TeePaymentsProxyContract, TeeMachineRegistryProxyContract, TeeVersionManagerProxyContract, TeeWalletBackupManagerProxyContract, TeeWalletKeyManagerProxyContract, TeeWalletManagerProxyContract, TeeWalletProjectManagerProxyContract, WNatInstance } from '../../typechain-truffle';
import { MockContractContract } from '../../typechain-truffle/@gnosis.pm/mock-contract/contracts/MockContract.sol/MockContract';
import { FtsoFeedDecimalsContract, FtsoFeedDecimalsInstance } from '../../typechain-truffle/contracts/ftso/implementation/FtsoFeedDecimals';
import { FtsoInflationConfigurationsContract } from '../../typechain-truffle/contracts/ftso/implementation/FtsoInflationConfigurations';
import { FtsoRewardOffersManagerContract, FtsoRewardOffersManagerInstance } from '../../typechain-truffle/contracts/ftso/implementation/FtsoRewardOffersManager';
import { PollingFoundationContract, PollingFoundationInstance } from '../../typechain-truffle/contracts/governance/implementation/PollingFoundation';
import { PollingManagementGroupContract, PollingManagementGroupInstance } from '../../typechain-truffle/contracts/governance/implementation/PollingManagementGroup';
import { CChainStakeContract, CChainStakeInstance } from '../../typechain-truffle/contracts/mock/CChainStake';
import { GovernanceVotePowerContract } from '../../typechain-truffle/contracts/mock/GovernanceVotePower';
import { PChainStakeMirrorContract } from '../../typechain-truffle/flattened/FlareSmartContracts.sol/PChainStakeMirror';
import { EntityManagerContract } from '../../typechain-truffle/contracts/protocol/implementation/EntityManager';
import { FlareSystemsCalculatorContract, FlareSystemsCalculatorInstance } from '../../typechain-truffle/contracts/protocol/implementation/FlareSystemsCalculator';
import { FlareSystemsManagerContract, FlareSystemsManagerInstance } from '../../typechain-truffle/contracts/protocol/implementation/FlareSystemsManager';
import { PChainStakeMirrorVerifierContract } from '../../typechain-truffle/contracts/staking/implementation/PChainStakeMirrorVerifier';
import { RelayContract, RelayInstance } from '../../typechain-truffle/contracts/protocol/implementation/Relay';
import { RewardManagerInstance } from '../../typechain-truffle/contracts/protocol/implementation/RewardManager';
import { SubmissionContract, SubmissionInstance } from '../../typechain-truffle/contracts/protocol/implementation/Submission';
import { VoterRegistryContract, VoterRegistryInstance } from '../../typechain-truffle/contracts/protocol/implementation/VoterRegistry';
import { WNatDelegationFeeContract, WNatDelegationFeeInstance } from '../../typechain-truffle/contracts/protocol/implementation/WNatDelegationFee';
import { ValidatorRewardOffersManagerContract, ValidatorRewardOffersManagerInstance } from '../../typechain-truffle/contracts/staking/implementation/ValidatorRewardOffersManager';
import { AddressBinderContract } from '../../typechain-truffle/flattened/FlareSmartContracts.sol/AddressBinder';
import { CleanupBlockNumberManagerContract, CleanupBlockNumberManagerInstance } from '../../typechain-truffle/flattened/FlareSmartContracts.sol/CleanupBlockNumberManager';
import { VPContractContract } from '../../typechain-truffle/flattened/FlareSmartContracts.sol/VPContract';
import { WNatContract } from '../../typechain-truffle/flattened/FlareSmartContracts.sol/WNat';
import { generateSignatures } from '../unit/protocol/coding/coding-helpers';
import { getTestFile } from "../utils/constants";
import { executeTimelockedGovernanceCall, testDeployGovernanceSettings } from '../utils/contract-test-helpers';
import * as util from "../utils/key-to-address";
import { encodeContractNames, findRequiredEvent, toBN } from '../utils/test-helpers';
import { TeeGovernanceContract, TeeGovernanceInstance } from '../../typechain-truffle/contracts/tee/implementation/TeeGovernance';
import { TeeVersionManagerContract, TeeVersionManagerInstance } from '../../typechain-truffle/contracts/tee/implementation/TeeVersionManager';
import { TeeMachineRegistryContract, TeeMachineRegistryInstance } from '../../typechain-truffle/contracts/tee/implementation/TeeMachineRegistry';
import { TeeWalletProjectManagerContract, TeeWalletProjectManagerInstance } from '../../typechain-truffle/contracts/tee/implementation/TeeWalletProjectManager';
import { TeeWalletManagerContract, TeeWalletManagerInstance } from '../../typechain-truffle/contracts/tee/implementation/TeeWalletManager';
import { TeeWalletKeyManagerContract, TeeWalletKeyManagerInstance } from '../../typechain-truffle/contracts/tee/implementation/TeeWalletKeyManager';
import { TeeWalletBackupManagerContract, TeeWalletBackupManagerInstance } from '../../typechain-truffle/contracts/tee/implementation/TeeWalletBackupManager';
import { TeeFeeCalculatorContract, TeeFeeCalculatorInstance } from '../../typechain-truffle/contracts/tee/implementation/TeeFeeCalculator';
import { TeeInstructionsContract, TeeInstructionsInstance } from '../../typechain-truffle/contracts/tee/implementation/TeeInstructions';
import { TeeRewardOffersManagerContract, TeeRewardOffersManagerInstance } from '../../typechain-truffle/contracts/tee/implementation/TeeRewardOffersManager';
import { TeePaymentsContract, TeePaymentsInstance } from '../../typechain-truffle/contracts/tee/implementation/TeePayments';
import { TeePaymentsEVMContract, TeePaymentsEVMInstance } from '../../typechain-truffle/contracts/tee/implementation/TeePaymentsEVM';
import { TEE_OPERATION_FEES, TEE_SOURCE_ID } from '../../deployment/tasks/run-simulation';
import { requiredEventArgsFrom } from '../utils/Web3EventDecoder';
import { AddressUpdater, TeeInstructions } from '../../typechain';
import { FtdcHubContract, FtdcHubInstance } from '../../typechain-truffle/contracts/ftdc/implementation/FtdcHub';
import { FtdcRequestFeeConfigurationsContract, FtdcRequestFeeConfigurationsInstance } from '../../typechain-truffle/contracts/ftdc/implementation/FtdcRequestFeeConfigurations';
import { FtdcVerificationMockContract, FtdcVerificationMockInstance } from '../../typechain-truffle/contracts/ftdc/mock/FtdcVerificationMock';
import { TeeVerificationContract, TeeVerificationInstance } from '../../typechain-truffle/contracts/tee/implementation/TeeVerification';
import { TeeVerificationProxyContract } from '../../typechain-truffle/contracts/tee/proxy/TeeVerificationProxy';
import { ECDSASignature } from '../../scripts/libs/protocol/ECDSASignature';
import { TeeOwnerAllowlistContract, TeeOwnerAllowlistInstance } from "../../typechain-truffle/contracts/tee/implementation/TeeOwnerAllowlist";
import { TeeSystemStateVerifierContract, TeeSystemStateVerifierInstance } from '../../typechain-truffle/contracts/tee/implementation/TeeSystemStateVerifier';
import { TeeSystemStateVerifierProxyContract } from '../../typechain-truffle/contracts/tee/proxy/TeeSystemStateVerifierProxy';
import { TeeOwnerAllowlistProxyContract } from '../../typechain-truffle/contracts/tee/proxy/TeeOwnerAllowlistProxy';
import { TeeExtensionRegistryProxyContract } from '../../typechain-truffle/contracts/tee/proxy/TeeExtensionRegistryProxy';
import { TeeExtensionRegistryInstance } from '../../typechain-truffle/contracts/tee/implementation/TeeExtensionRegistry';
import { TeeReplicationContract, TeeReplicationInstance } from '../../typechain-truffle/contracts/tee/implementation/TeeReplication';
import { TeeReplicationProxyContract } from '../../typechain-truffle/contracts/tee/proxy/TeeReplicationProxy';
import { AddressUpdaterContract, AddressUpdaterInstance } from '../../typechain-truffle/flattened/FlareSmartContracts.sol/AddressUpdater';

const MockContract: MockContractContract = artifacts.require("MockContract");
const AddressUpdater: AddressUpdaterContract = artifacts.require("AddressUpdater");
const WNat: WNatContract = artifacts.require("WNat");
const VPContract: VPContractContract = artifacts.require("VPContract");
const PChainStakeMirror: PChainStakeMirrorContract = artifacts.require("PChainStakeMirror");
const GovernanceVotePower: GovernanceVotePowerContract = artifacts.require("GovernanceVotePower");
const AddressBinder: AddressBinderContract = artifacts.require("AddressBinder");
const PChainStakeMirrorVerifier: PChainStakeMirrorVerifierContract = artifacts.require("PChainStakeMirrorVerifier");
const EntityManager: EntityManagerContract = artifacts.require("EntityManager");
const VoterRegistry: VoterRegistryContract = artifacts.require("VoterRegistry");
const FlareSystemsCalculator: FlareSystemsCalculatorContract = artifacts.require("FlareSystemsCalculator");
const FlareSystemsManager: FlareSystemsManagerContract = artifacts.require("FlareSystemsManager");
const RewardManager: RewardManagerContract = artifacts.require("RewardManager");
const Submission: SubmissionContract = artifacts.require("Submission");
const Relay: RelayContract = artifacts.require("Relay");
const CChainStake: CChainStakeContract = artifacts.require("CChainStake");
const WNatDelegationFee: WNatDelegationFeeContract = artifacts.require("WNatDelegationFee");
const FtsoInflationConfigurations: FtsoInflationConfigurationsContract = artifacts.require("FtsoInflationConfigurations");
const FtsoRewardOffersManager: FtsoRewardOffersManagerContract = artifacts.require("FtsoRewardOffersManager");
const FtsoFeedDecimals: FtsoFeedDecimalsContract = artifacts.require("FtsoFeedDecimals");
const FtsoFeedPublisher: FtsoFeedPublisherContract = artifacts.require("FtsoFeedPublisher");
const FtsoFeedIdConverter: FtsoFeedIdConverterContract = artifacts.require("FtsoFeedIdConverter");
const CleanupBlockNumberManager: CleanupBlockNumberManagerContract = artifacts.require("CleanupBlockNumberManager");
const ValidatorRewardOffersManager: ValidatorRewardOffersManagerContract = artifacts.require("ValidatorRewardOffersManager");
const PollingFoundation: PollingFoundationContract = artifacts.require("PollingFoundation");
const PollingManagementGroup: PollingManagementGroupContract = artifacts.require("PollingManagementGroup");
const TeeExtensionRegistry: TeeExtensionRegistryContract = artifacts.require("TeeExtensionRegistry");
const TeeExtensionRegistryProxy: TeeExtensionRegistryProxyContract = artifacts.require("TeeExtensionRegistryProxy");
const TeeOwnerAllowlist: TeeOwnerAllowlistContract = artifacts.require("TeeOwnerAllowlist");
const TeeOwnerAllowlistProxy: TeeOwnerAllowlistProxyContract = artifacts.require("TeeOwnerAllowlistProxy");
const TeeGovernance: TeeGovernanceContract = artifacts.require("TeeGovernance");
const TeeGovernanceProxy: TeeGovernanceProxyContract = artifacts.require("TeeGovernanceProxy");
const TeeVersionManager: TeeVersionManagerContract = artifacts.require("TeeVersionManager");
const TeeVersionManagerProxy: TeeVersionManagerProxyContract = artifacts.require("TeeVersionManagerProxy");
const TeeVerification: TeeVerificationContract = artifacts.require("TeeVerification");
const TeeVerificationProxy: TeeVerificationProxyContract = artifacts.require("TeeVerificationProxy");
const TeeSystemStateVerifier: TeeSystemStateVerifierContract = artifacts.require("TeeSystemStateVerifier");
const TeeSystemStateVerifierProxy: TeeSystemStateVerifierProxyContract = artifacts.require("TeeSystemStateVerifierProxy");
const TeeMachineRegistry: TeeMachineRegistryContract = artifacts.require("TeeMachineRegistry");
const TeeMachineRegistryProxy: TeeMachineRegistryProxyContract = artifacts.require("TeeMachineRegistryProxy");
const TeeWalletProjectManager: TeeWalletProjectManagerContract = artifacts.require("TeeWalletProjectManager");
const TeeWalletProjectManagerProxy: TeeWalletProjectManagerProxyContract = artifacts.require("TeeWalletProjectManagerProxy");
const TeeWalletManager: TeeWalletManagerContract = artifacts.require("TeeWalletManager");
const TeeWalletManagerProxy: TeeWalletManagerProxyContract = artifacts.require("TeeWalletManagerProxy");
const TeeWalletKeyManager: TeeWalletKeyManagerContract = artifacts.require("TeeWalletKeyManager");
const TeeWalletKeyManagerProxy: TeeWalletKeyManagerProxyContract = artifacts.require("TeeWalletKeyManagerProxy");
const TeeWalletBackupManager: TeeWalletBackupManagerContract = artifacts.require("TeeWalletBackupManager");
const TeeWalletBackupManagerProxy: TeeWalletBackupManagerProxyContract = artifacts.require("TeeWalletBackupManagerProxy");
const TeeFeeCalculator: TeeFeeCalculatorContract = artifacts.require("TeeFeeCalculator");
const TeeInstructions: TeeInstructionsContract = artifacts.require("TeeInstructions");
const TeeInstructionsProxy: TeeInstructionsProxyContract = artifacts.require("TeeInstructionsProxy");
const TeeReplication: TeeReplicationContract = artifacts.require("TeeReplication");
const TeeReplicationProxy: TeeReplicationProxyContract = artifacts.require("TeeReplicationProxy");
const TeeRewardOffersManager: TeeRewardOffersManagerContract = artifacts.require("TeeRewardOffersManager");
const TeePayments: TeePaymentsContract = artifacts.require("TeePayments");
const TeePaymentsProxy: TeePaymentsProxyContract = artifacts.require("TeePaymentsProxy");
const TeePaymentsEVM: TeePaymentsEVMContract = artifacts.require("TeePaymentsEVM");
const FtdcHub: FtdcHubContract = artifacts.require("FtdcHub");
const FtdcRequestFeeConfigurations: FtdcRequestFeeConfigurationsContract = artifacts.require("FtdcRequestFeeConfigurations");
const FtdcVerification: FtdcVerificationMockContract = artifacts.require("FtdcVerificationMock");

type PChainStake = {
    txId: string,
    stakingType: number,
    inputAddress: string,
    nodeId: string,
    startTime: number,
    endTime: number,
    weight: number,
}

async function setMockStakingData(verifierMock: MockContractInstance, pChainStakeMirrorVerifierInterface: PChainStakeMirrorVerifierInstance, txId: string, stakingType: number, inputAddress: string, nodeId: string, startTime: BN, endTime: BN, weight: number, stakingProved: boolean = true): Promise<PChainStake> {
    const data = {
        txId: txId,
        stakingType: stakingType,
        inputAddress: inputAddress,
        nodeId: nodeId,
        startTime: startTime.toNumber(),
        endTime: endTime.toNumber(),
        weight: weight
    };

    // eslint-disable-next-line @typescript-eslint/no-unsafe-call, @typescript-eslint/no-unsafe-member-access
    const verifyPChainStakingMethod = pChainStakeMirrorVerifierInterface.contract.methods.verifyStake(data, []).encodeABI();
    // eslint-disable-next-line @typescript-eslint/no-unsafe-argument
    await verifierMock.givenCalldataReturnBool(verifyPChainStakingMethod, stakingProved);
    return data;
}

function getSigningPolicyHash(signingPolicy: ISigningPolicy): string {
    return SigningPolicy.hash(signingPolicy);
}

contract(`End to end test; ${getTestFile(__filename)}`, accounts => {

    const FTSO_PROTOCOL_ID = 100;
    const REWARD_MANAGER_ID = 0;
    const TEE_CODE_HASH = "0x194844cf417dde867073e5ab7199fa4d21fd82b5dbe2bdea8b3d7fc18d10fdc2";
    const TEE_PLATFORMS = ["GCP_INTEL_TDX", "GCP_AMD_SEV"];
    const TEE_OWNERS = [accounts[101], accounts[102]];
    const TEE_IDS = [accounts[20], accounts[21]];
    const TEE_PROXY_IDS = [accounts[22], accounts[23]];
    const TEE_URLS = ["127.0.0.1:1234", "127.0.0.1:1235"];
    const TEE_WALLET_OWNERS = [accounts[103], accounts[104]];
    const TEE_WALLET_SUBMIT_ADDRESSES = [accounts[105], accounts[106]];

    const PROJECT1_ID = web3.utils.keccak256(web3.eth.abi.encodeParameters(
        ["string", "address", "uint256"],
        ["PROJECT", TEE_WALLET_OWNERS[0], 1]));
    const WALLET1_ID = web3.utils.keccak256(web3.eth.abi.encodeParameters(
        ["string", "address", "uint256"],
        ["WALLET", TEE_WALLET_OWNERS[0], 1]));
    const PROJECT2_ID = web3.utils.keccak256(web3.eth.abi.encodeParameters(
        ["string", "address", "uint256"],
        ["PROJECT", TEE_WALLET_OWNERS[1], 2]));
    const WALLET2_ID = web3.utils.keccak256(web3.eth.abi.encodeParameters(
        ["string", "address", "uint256"],
        ["WALLET", TEE_WALLET_OWNERS[1], 2]));

    let addressUpdater: AddressUpdaterInstance;
    let wNat: WNatInstance;
    let pChainStakeMirror: PChainStakeMirrorInstance;
    let governanceVotePower: GovernanceVotePowerInstance;
    let addressBinder: AddressBinderInstance;
    let pChainStakeMirrorVerifierInterface: PChainStakeMirrorVerifierInstance;
    let verifierMock: MockContractInstance;

    let governanceSettings: GovernanceSettingsInstance;
    let entityManager: EntityManagerInstance;
    let voterRegistry: VoterRegistryInstance;
    let flareSystemsCalculator: FlareSystemsCalculatorInstance;
    let flareSystemsManager: FlareSystemsManagerInstance;
    let rewardManager: RewardManagerInstance;
    let submission: SubmissionInstance;
    let relay: RelayInstance;
    let relay2: RelayInstance;
    let cChainStake: CChainStakeInstance;
    let wNatDelegationFee: WNatDelegationFeeInstance;
    let ftsoInflationConfigurations: FtsoInflationConfigurationsInstance;
    let ftsoRewardOffersManager: FtsoRewardOffersManagerInstance;
    let ftsoFeedDecimals: FtsoFeedDecimalsInstance;
    let ftsoFeedPublisher: FtsoFeedPublisherInstance;
    let ftsoFeedIdConverter: FtsoFeedIdConverterInstance;
    let validatorRewardOffersManager: ValidatorRewardOffersManagerInstance
    let cleanupBlockNumberManager: CleanupBlockNumberManagerInstance;
    let pollingFoundation: PollingFoundationInstance;
    let supplyMock: MockContractInstance;
    let pollingManagementGroup: PollingManagementGroupInstance;
    let teeExtensionRegistry: TeeExtensionRegistryInstance;
    let teeOwnerAllowlist: TeeOwnerAllowlistInstance;
    let teeGovernance: TeeGovernanceInstance;
    let teeVersionManager: TeeVersionManagerInstance;
    let teeVerification: TeeVerificationInstance;
    let teeSystemStateVerifier: TeeSystemStateVerifierInstance;
    let teeMachineRegistry: TeeMachineRegistryInstance;
    let teeWalletProjectManager: TeeWalletProjectManagerInstance;
    let teeWalletManager: TeeWalletManagerInstance;
    let teeWalletKeyManager: TeeWalletKeyManagerInstance;
    let teeWalletBackupManager: TeeWalletBackupManagerInstance;
    let teeFeeCalculator: TeeFeeCalculatorInstance;
    let teeInstructions: TeeInstructionsInstance;
    let teeReplication: TeeReplicationInstance;
    let teeRewardOffersManager: TeeRewardOffersManagerInstance;
    let teePayments: TeePaymentsInstance;
    let teePaymentsEVM: TeePaymentsEVMInstance;
    let ftdcHub: FtdcHubInstance;
    let ftdcRequestFeeConfigurations: FtdcRequestFeeConfigurationsInstance;
    let ftdcVerification: FtdcVerificationMockInstance;

    let teeGovernanceSigners: string[] = [accounts[50], accounts[51], accounts[52], accounts[53], accounts[54], accounts[55]];
    let teeGovernanceSignersThreshold = 3;

    let initialSigningPolicy: ISigningPolicy;
    let newSigningPolicy: ISigningPolicy;

    const registeredPAddresses: string[] = [];
    const registeredCAddresses: string[] = [];
    let now: BN;
    let nodeIds: string[] = [];
    let weightsGwei: number[] = [];
    let stakeIds: string[] = [];
    let rewardClaim: {
        rewardEpochId: number;
        beneficiary: string;
        amount: number;
        claimType: number;
    };
    let feed: {
        votingRoundId: number;
        id: string;
        value: number;
        turnoutBIPS: number;
        decimals: number;
    };
    let challenges: string[] = [];

    let [x1, y1] = util.privateKeyToPublicKeyPairString(privateKeys[10].privateKey.slice(2));
    let [x2, y2] = util.privateKeyToPublicKeyPairString(privateKeys[11].privateKey.slice(2));
    const adminsPublicKeys1 = [{x : x1, y : y1}, {x : x2, y : y2}];
    [x1, y1] = util.privateKeyToPublicKeyPairString(privateKeys[12].privateKey.slice(2));
    [x2, y2] = util.privateKeyToPublicKeyPairString(privateKeys[13].privateKey.slice(2));
    const adminsPublicKeys2 = [{x : x1, y : y1}, {x : x2, y : y2}];

    const RANDOM_ROOT = web3.utils.keccak256("root");
    const RANDOM_ROOT2 = web3.utils.keccak256("root2");

    // same as in relay and Flare system manager contracts
    const REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS = 3360; // 3.5 days
    const FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID = 1000;
    const NEW_SIGNING_POLICY_INITIALIZATION_START_SEC = 3600 * 2; // 2 hours
    const RELAY_SELECTOR = web3.utils.sha3("relay()")!.slice(0, 10); // first 4 bytes is function selector

    const MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS = 100;
    const GWEI = 1e9;
    const VOTING_EPOCH_DURATION_SEC = 90;
    const REWARD_EPOCH_DURATION_IN_SEC = REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS * VOTING_EPOCH_DURATION_SEC;

    const CLAIM_SETUP_MANAGER = accounts[17];
    const FTSO_REWARD_MANAGER = accounts[18];
    const INFLATION = accounts[19];

    const INITIAL_NUMBER_OF_VOTERS = 100;

    before(async () => {
        const addressUpdatableContracts = [];
        addressUpdater = await AddressUpdater.new(accounts[0]);
        pChainStakeMirror = await PChainStakeMirror.new(
            accounts[0],
            accounts[0],
            addressUpdater.address,
            50
        );
        addressUpdatableContracts.push(pChainStakeMirror.address);

        cChainStake = await CChainStake.new(accounts[0], accounts[0], addressUpdater.address, 0, 100, 1e10, 50);
        addressUpdatableContracts.push(cChainStake.address);

        governanceSettings = await testDeployGovernanceSettings(accounts[0], 3600, [accounts[0]]);
        wNat = await WNat.new(accounts[0], "Wrapped NAT", "WNAT");
        await wNat.switchToProductionMode({ from: accounts[0] });
        const switchToProdModeTime = await time.latest();
        const vpContract = await VPContract.new(wNat.address, false);
        await wNat.setWriteVpContract(vpContract.address);
        await wNat.setReadVpContract(vpContract.address);
        governanceVotePower = await GovernanceVotePower.new(wNat.address, pChainStakeMirror.address, cChainStake.address);
        await wNat.setGovernanceVotePower(governanceVotePower.address);

        await time.increaseTo(switchToProdModeTime.addn(3600)); // 1 hour after switching to production mode
        await executeTimelockedGovernanceCall(wNat, (governance) =>
            wNat.setWriteVpContract(vpContract.address, { from: governance }));
        await executeTimelockedGovernanceCall(wNat, (governance) =>
            wNat.setReadVpContract(vpContract.address, { from: governance }));
        await executeTimelockedGovernanceCall(wNat, (governance) =>
            wNat.setGovernanceVotePower(governanceVotePower.address, { from: governance }));

        addressBinder = await AddressBinder.new();
        pChainStakeMirrorVerifierInterface = await PChainStakeMirrorVerifier.new(accounts[5], accounts[6], 10, 1000, 5, 5000);
        verifierMock = await MockContract.new();

        // set values
        weightsGwei = [1000, 500, 100, 50];
        nodeIds = ["0x0123456789012345678901234567890123456789", "0x0123456789012345678901234567890123456788", "0x0123456789012345678901234567890123456787", "0x0123456789012345678901234567890123456786"];
        stakeIds = [web3.utils.keccak256("stake1"), web3.utils.keccak256("stake2"), web3.utils.keccak256("stake3"), web3.utils.keccak256("stake4")];
        now = await time.latest();

        const initialThreshold = 65500 / 2;
        const initialVoters = accounts.slice(0, INITIAL_NUMBER_OF_VOTERS);
        const initialSigningPolicyVoters = accounts.slice(INITIAL_NUMBER_OF_VOTERS, INITIAL_NUMBER_OF_VOTERS + INITIAL_NUMBER_OF_VOTERS);
        const initialWeights: number[] = Array(100).fill(655);

        entityManager = await EntityManager.new(governanceSettings.address, accounts[0], 4);
        await entityManager.setNodePossessionVerifier(verifierMock.address); // mock verifier

        for (let i = 0; i < INITIAL_NUMBER_OF_VOTERS; i++) {
            await entityManager.proposeSigningPolicyAddress(accounts[INITIAL_NUMBER_OF_VOTERS + i], { from: initialVoters[i] });
            await entityManager.confirmSigningPolicyAddressRegistration(initialVoters[i], { from: accounts[INITIAL_NUMBER_OF_VOTERS + i] });
        }

        await time.advanceBlock();

        voterRegistry = await VoterRegistry.new(governanceSettings.address, accounts[0], addressUpdater.address, 100, 0, (await time.latestBlock()).toNumber() - 1, 0, initialVoters, initialWeights);
        addressUpdatableContracts.push(voterRegistry.address);
        flareSystemsCalculator = await FlareSystemsCalculator.new(governanceSettings.address, accounts[0], addressUpdater.address, 2500, 20 * 60, 600, 600);
        addressUpdatableContracts.push(flareSystemsCalculator.address);

        initialSigningPolicy = {
            rewardEpochId: 0,
            startVotingRoundId: FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID,
            threshold: initialThreshold,
            seed: web3.utils.keccak256("123"),
            voters: initialSigningPolicyVoters,
            weights: initialWeights
        };

        const settings = {
            newSigningPolicyInitializationStartSeconds: NEW_SIGNING_POLICY_INITIALIZATION_START_SEC,
            randomAcquisitionMaxDurationSeconds: 8 * 3600,
            randomAcquisitionMaxDurationBlocks: 15000,
            newSigningPolicyMinNumberOfVotingRoundsDelay: 1,
            voterRegistrationMinDurationSeconds: 30 * 60,
            voterRegistrationMinDurationBlocks: 20, // default 900,
            submitUptimeVoteMinDurationSeconds: 10 * 60,
            submitUptimeVoteMinDurationBlocks: 20, // default 300,
            signingPolicyThresholdPPM: 500000,
            signingPolicyMinNumberOfVoters: 2,
            rewardExpiryOffsetSeconds: 90 * 24 * 3600
        };

        const initialSettings = {
            initialRandomVotePowerBlockSelectionSize: 1,
            initialRewardEpochId: 0,
            initialRewardEpochThreshold: initialThreshold
        }

        const firstVotingRoundStartTs = now.toNumber() - FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID * VOTING_EPOCH_DURATION_SEC;

        flareSystemsManager = await FlareSystemsManager.new(
            governanceSettings.address,
            accounts[0],
            addressUpdater.address,
            accounts[0],
            settings,
            firstVotingRoundStartTs,
            VOTING_EPOCH_DURATION_SEC,
            FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            initialSettings
        );
        addressUpdatableContracts.push(flareSystemsManager.address);

        rewardManager = await RewardManager.new(
            governanceSettings.address,
            accounts[0],
            addressUpdater.address,
            constants.ZERO_ADDRESS,
            REWARD_MANAGER_ID
        );
        addressUpdatableContracts.push(rewardManager.address);

        const relayInitialConfig: RelayInitialConfig = {
            initialRewardEpochId: initialSigningPolicy.rewardEpochId,
            startingVotingRoundIdForInitialRewardEpochId: initialSigningPolicy.startVotingRoundId,
            initialSigningPolicyHash: getSigningPolicyHash(initialSigningPolicy),
            randomNumberProtocolId: FTSO_PROTOCOL_ID,
            firstVotingRoundStartTs: firstVotingRoundStartTs,
            votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
            firstRewardEpochStartVotingRoundId: FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID,
            rewardEpochDurationInVotingEpochs: REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            thresholdIncreaseBIPS: 12000,
            messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
            feeCollectionAddress: constants.ZERO_ADDRESS,
            feeConfigs: []
        }

        relay = await Relay.new(
            relayInitialConfig,
            flareSystemsManager.address,
            constants.ZERO_ADDRESS
        );

        const relayInitialConfig2: RelayInitialConfig = {
            initialRewardEpochId: initialSigningPolicy.rewardEpochId,
            startingVotingRoundIdForInitialRewardEpochId: initialSigningPolicy.startVotingRoundId,
            initialSigningPolicyHash: getSigningPolicyHash(initialSigningPolicy),
            randomNumberProtocolId: FTSO_PROTOCOL_ID,
            firstVotingRoundStartTs: firstVotingRoundStartTs,
            votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
            firstRewardEpochStartVotingRoundId: FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID,
            rewardEpochDurationInVotingEpochs: REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            thresholdIncreaseBIPS: 12000,
            messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
            feeCollectionAddress: constants.ZERO_ADDRESS,
            feeConfigs: []
        }

        relay2 = await Relay.new(
            relayInitialConfig2,
            constants.ZERO_ADDRESS,
            constants.ZERO_ADDRESS
        );

        submission = await Submission.new(governanceSettings.address, accounts[0], addressUpdater.address, false);
        addressUpdatableContracts.push(submission.address);

        wNatDelegationFee = await WNatDelegationFee.new(addressUpdater.address, 2, 2000);
        addressUpdatableContracts.push(wNatDelegationFee.address);

        ftsoInflationConfigurations = await FtsoInflationConfigurations.new(governanceSettings.address, accounts[0]);

        ftsoRewardOffersManager = await FtsoRewardOffersManager.new(governanceSettings.address, accounts[0], addressUpdater.address, 100);
        addressUpdatableContracts.push(ftsoRewardOffersManager.address);

        ftsoFeedDecimals = await FtsoFeedDecimals.new(
            governanceSettings.address,
            accounts[0],
            addressUpdater.address,
            2,
            5,
            0,
            [
                { feedId: FtsoConfigurations.encodeFeedId({ category: 1, name: "BTC/USD" }), decimals: 2 },
                { feedId: FtsoConfigurations.encodeFeedId({ category: 1, name: "ETH/USD" }), decimals: 3 }
            ]
        );
        addressUpdatableContracts.push(ftsoFeedDecimals.address);

        ftsoFeedPublisher = await FtsoFeedPublisher.new(
            governanceSettings.address,
            accounts[0],
            addressUpdater.address,
            FTSO_PROTOCOL_ID,
            200
        );
        addressUpdatableContracts.push(ftsoFeedPublisher.address);

        ftsoFeedIdConverter = await FtsoFeedIdConverter.new();

        validatorRewardOffersManager = await ValidatorRewardOffersManager.new(governanceSettings.address, accounts[0], addressUpdater.address);
        addressUpdatableContracts.push(validatorRewardOffersManager.address);

        cleanupBlockNumberManager = await CleanupBlockNumberManager.new(accounts[0], addressUpdater.address, "FlareSystemsManager");
        addressUpdatableContracts.push(cleanupBlockNumberManager.address);

        pollingFoundation = await PollingFoundation.new(governanceSettings.address, accounts[0], addressUpdater.address, [accounts[10], accounts[11]]);
        addressUpdatableContracts.push(pollingFoundation.address);
        supplyMock = await MockContract.new();

        pollingManagementGroup = await PollingManagementGroup.new(governanceSettings.address, accounts[0], addressUpdater.address);
        addressUpdatableContracts.push(pollingManagementGroup.address);

        const teeOwnerAllowlistImpl: TeeOwnerAllowlistInstance = await TeeOwnerAllowlist.new();
        const teeOwnerAllowlistProxy = await TeeOwnerAllowlistProxy.new(governanceSettings.address, accounts[0], addressUpdater.address, teeOwnerAllowlistImpl.address);
        teeOwnerAllowlist = await TeeOwnerAllowlist.at(teeOwnerAllowlistProxy.address);
        addressUpdatableContracts.push(teeOwnerAllowlist.address);

        const teeGovernanceImpl: TeeGovernanceInstance = await TeeGovernance.new();
        const teeGovernanceProxy = await TeeGovernanceProxy.new(governanceSettings.address, accounts[0], addressUpdater.address, teeGovernanceImpl.address);
        teeGovernance = await TeeGovernance.at(teeGovernanceProxy.address);
        addressUpdatableContracts.push(teeGovernance.address);

        const teeVersionManagerImpl: TeeVersionManagerInstance = await TeeVersionManager.new();
        const teeVersionManagerProxy = await TeeVersionManagerProxy.new(governanceSettings.address, accounts[0], addressUpdater.address, teeVersionManagerImpl.address);
        teeVersionManager = await TeeVersionManager.at(teeVersionManagerProxy.address);
        addressUpdatableContracts.push(teeVersionManager.address);

        const teeVerificationImpl = await TeeVerification.new();
        const teeVerificationProxy = await TeeVerificationProxy.new(governanceSettings.address, accounts[0], addressUpdater.address, 3600, 10, 600, teeVerificationImpl.address);
        teeVerification = await TeeVerification.at(teeVerificationProxy.address);
        addressUpdatableContracts.push(teeVerification.address);

        const teeSystemStateVerifierImpl = await TeeSystemStateVerifier.new();
        const teeSystemStateVerifierProxy = await TeeSystemStateVerifierProxy.new(governanceSettings.address, accounts[0], addressUpdater.address, teeSystemStateVerifierImpl.address);
        teeSystemStateVerifier = await TeeSystemStateVerifier.at(teeSystemStateVerifierProxy.address);
        addressUpdatableContracts.push(teeSystemStateVerifier.address);

        const teeMachineRegistryImpl: TeeMachineRegistryInstance = await TeeMachineRegistry.new();
        const teeMachineRegistryProxy = await TeeMachineRegistryProxy.new(governanceSettings.address, accounts[0], addressUpdater.address, teeMachineRegistryImpl.address);
        teeMachineRegistry = await TeeMachineRegistry.at(teeMachineRegistryProxy.address);
        addressUpdatableContracts.push(teeMachineRegistry.address);

        const teeWalletProjectManagerImpl: TeeWalletProjectManagerInstance = await TeeWalletProjectManager.new();
        const teeWalletProjectManagerProxy = await TeeWalletProjectManagerProxy.new(governanceSettings.address, accounts[0], addressUpdater.address, teeWalletProjectManagerImpl.address);
        teeWalletProjectManager = await TeeWalletProjectManager.at(teeWalletProjectManagerProxy.address);
        addressUpdatableContracts.push(teeWalletProjectManager.address);

        const teeWalletManagerImpl: TeeWalletManagerInstance = await TeeWalletManager.new();
        const teeWalletManagerProxy = await TeeWalletManagerProxy.new(governanceSettings.address, accounts[0], addressUpdater.address, teeWalletManagerImpl.address);
        teeWalletManager = await TeeWalletManager.at(teeWalletManagerProxy.address);
        addressUpdatableContracts.push(teeWalletManager.address);

        const teeWalletKeyManagerImpl: TeeWalletKeyManagerInstance = await TeeWalletKeyManager.new();
        const teeWalletKeyManagerProxy = await TeeWalletKeyManagerProxy.new(governanceSettings.address, accounts[0], addressUpdater.address, teeWalletKeyManagerImpl.address);
        teeWalletKeyManager = await TeeWalletKeyManager.at(teeWalletKeyManagerProxy.address);
        addressUpdatableContracts.push(teeWalletKeyManager.address);

        const teeWalletBackupManagerImpl: TeeWalletBackupManagerInstance = await TeeWalletBackupManager.new();
        const teeWalletBackupManagerProxy = await TeeWalletBackupManagerProxy.new(governanceSettings.address, accounts[0], addressUpdater.address, teeWalletBackupManagerImpl.address);
        teeWalletBackupManager = await TeeWalletBackupManager.at(teeWalletBackupManagerProxy.address);
        addressUpdatableContracts.push(teeWalletBackupManager.address);

        teeFeeCalculator = await TeeFeeCalculator.new(governanceSettings.address, accounts[0], 1);

        teeRewardOffersManager = await TeeRewardOffersManager.new(governanceSettings.address, accounts[0], addressUpdater.address, 100000); // 10%
        addressUpdatableContracts.push(teeRewardOffersManager.address);

        const teeInstructionsImpl: TeeInstructionsInstance = await TeeInstructions.new();
        const teeInstructionsProxy = await TeeInstructionsProxy.new(governanceSettings.address, accounts[0], addressUpdater.address, teeInstructionsImpl.address);
        teeInstructions = await TeeInstructions.at(teeInstructionsProxy.address);
        addressUpdatableContracts.push(teeInstructions.address);

        const teeReplicationImpl: TeeReplicationInstance = await TeeReplication.new();
        const teeReplicationProxy = await TeeReplicationProxy.new(governanceSettings.address, accounts[0], addressUpdater.address, 60, teeReplicationImpl.address);
        teeReplication = await TeeReplication.at(teeReplicationProxy.address);
        addressUpdatableContracts.push(teeReplication.address);

        const teeExtensionRegistryImpl: TeeExtensionRegistryInstance = await TeeExtensionRegistry.new();
        const teeExtensionRegistryProxy = await TeeExtensionRegistryProxy.new(governanceSettings.address, accounts[0], addressUpdater.address, teeExtensionRegistryImpl.address);
        teeExtensionRegistry = await TeeExtensionRegistry.at(teeExtensionRegistryProxy.address);
        addressUpdatableContracts.push(teeExtensionRegistry.address);

        const operationTypes = [];
        const operationCommands = [];
        const operationFees = [];
        for (const teeOperationFee of TEE_OPERATION_FEES) {
            operationTypes.push(web3.utils.utf8ToHex(teeOperationFee.opType).padEnd(66, "0"));
            operationCommands.push(web3.utils.utf8ToHex(teeOperationFee.opCommand).padEnd(66, "0"));
            operationFees.push(teeOperationFee.feeWei);
        }
        await teeFeeCalculator.setOperationFees(operationTypes, operationCommands, operationFees);

        const teePaymentsImpl: TeePaymentsInstance = await TeePayments.new();
        let teePaymentsProxy = await TeePaymentsProxy.new(governanceSettings.address, accounts[0], addressUpdater.address, 1, 0, web3.utils.utf8ToHex("F_XRP").padEnd(66, "0"),  teePaymentsImpl.address);
        teePayments = await TeePayments.at(teePaymentsProxy.address);
        addressUpdatableContracts.push(teePayments.address);

        const teePaymentsEVMImpl: TeePaymentsEVMInstance = await TeePaymentsEVM.new();
        teePaymentsProxy = await TeePaymentsProxy.new(governanceSettings.address, accounts[0], addressUpdater.address, 1, 0, web3.utils.utf8ToHex("F_EVM").padEnd(66, "0"), teePaymentsEVMImpl.address);
        teePaymentsEVM = await TeePaymentsEVM.at(teePaymentsProxy.address);
        addressUpdatableContracts.push(teePaymentsEVM.address);

        ftdcHub = await FtdcHub.new(governanceSettings.address, accounts[0], addressUpdater.address, 3000, 1);
        addressUpdatableContracts.push(ftdcHub.address);
        ftdcRequestFeeConfigurations = await FtdcRequestFeeConfigurations.new(governanceSettings.address, accounts[0]);
        ftdcVerification = await FtdcVerification.new(addressUpdater.address);
        addressUpdatableContracts.push(ftdcVerification.address);
        // Set the FTDC request fee configurations
        const ftdc_attestationTypes = ["TeeAvailabilityCheck", "PMWPaymentStatus"];
        for (const attestationType of ftdc_attestationTypes) {
            await ftdcRequestFeeConfigurations.setTypeAndSourceFee(
                web3.utils.utf8ToHex(attestationType).padEnd(66, "0"),
                web3.utils.utf8ToHex(TEE_SOURCE_ID).padEnd(66, "0"),
                "1"
            );
        }

        await flareSystemsCalculator.enablePChainStakeMirror();
        await rewardManager.enablePChainStakeMirror();

        // update contract addresses
        await addressUpdater.update(
            [
                Contracts.ADDRESS_UPDATER,
                Contracts.INFLATION,
                Contracts.ADDRESS_BINDER,
                Contracts.GOVERNANCE_VOTE_POWER,
                Contracts.CLEANUP_BLOCK_NUMBER_MANAGER,
                Contracts.P_CHAIN_STAKE_MIRROR_VERIFIER,
                Contracts.FLARE_SYSTEMS_MANAGER,
                Contracts.ENTITY_MANAGER,
                Contracts.FLARE_SYSTEMS_CALCULATOR,
                Contracts.WNAT_DELEGATION_FEE,
                Contracts.VOTER_REGISTRY,
                Contracts.P_CHAIN_STAKE_MIRROR,
                Contracts.WNAT,
                Contracts.SUBMISSION,
                Contracts.SUPPLY,
                Contracts.RELAY,
                Contracts.REWARD_MANAGER,
                Contracts.CLAIM_SETUP_MANAGER,
                Contracts.FTSO_REWARD_MANAGER,
                Contracts.FTSO_INFLATION_CONFIGURATIONS,
                Contracts.FTSO_FEED_DECIMALS,
                Contracts.TEE_GOVERNANCE,
                Contracts.TEE_VERSION_MANAGER,
                Contracts.TEE_EXTENSION_REGISTRY,
                Contracts.TEE_MACHINE_REGISTRY,
                Contracts.TEE_FEE_CALCULATOR,
                Contracts.TEE_SYSTEM_STATE_VERIFIER,
                Contracts.TEE_INSTRUCTIONS,
                Contracts.FTDC_HUB,
                Contracts.FTDC_VERIFICATION,
                Contracts.FTDC_REQUEST_FEE_CONFIGURATIONS,
                Contracts.TEE_REWARD_OFFERS_MANAGER,
                Contracts.TEE_VERIFICATION,
                Contracts.TEE_OWNER_ALLOWLIST,
                Contracts.TEE_WALLET_MANAGER,
                Contracts.TEE_WALLET_PROJECT_MANAGER,
                Contracts.TEE_WALLET_KEY_MANAGER,
                Contracts.TEE_WALLET_BACKUP_MANAGER,
                Contracts.TEE_REPLICATION
            ],
            [
                addressUpdater.address,
                INFLATION,
                addressBinder.address,
                governanceVotePower.address,
                cleanupBlockNumberManager.address,
                verifierMock.address,
                flareSystemsManager.address,
                entityManager.address,
                flareSystemsCalculator.address,
                wNatDelegationFee.address,
                voterRegistry.address,
                pChainStakeMirror.address,
                wNat.address,
                submission.address,
                supplyMock.address,
                relay.address,
                rewardManager.address,
                CLAIM_SETUP_MANAGER,
                FTSO_REWARD_MANAGER,
                ftsoInflationConfigurations.address,
                ftsoFeedDecimals.address,
                teeGovernance.address,
                teeVersionManager.address,
                teeExtensionRegistry.address,
                teeMachineRegistry.address,
                teeFeeCalculator.address,
                teeSystemStateVerifier.address,
                teeInstructions.address,
                ftdcHub.address,
                ftdcVerification.address,
                ftdcRequestFeeConfigurations.address,
                teeRewardOffersManager.address,
                teeVerification.address,
                teeOwnerAllowlist.address,
                teeWalletManager.address,
                teeWalletProjectManager.address,
                teeWalletKeyManager.address,
                teeWalletBackupManager.address,
                teeReplication.address
            ],
            addressUpdatableContracts,
            { from: accounts[0] }
        );
        // set extension contracts
        await teeExtensionRegistry.setExtensionContracts(0, constants.ZERO_ADDRESS, teeInstructions.address);
        // set supported operation types
        await teeExtensionRegistry.addOrUpdateSupportedWalletProjectOpTypes(0, [teePayments.address, teePaymentsEVM.address]);
        // set supported platforms
        await teeExtensionRegistry.addSupportedPlatforms(TEE_PLATFORMS.map(platform => web3.utils.utf8ToHex(platform).padEnd(66, "0")));
        // register system instruction initiators
        await teeExtensionRegistry.registerSystemInstructionInitiators([teeVerification.address, teeWalletManager.address, teeWalletKeyManager.address, teeWalletBackupManager.address, teeReplication.address]);
        // register instructions initiators
        await teeInstructions.registerInstructionInitiators([teePayments.address, teePaymentsEVM.address, ftdcHub.address]);
        await teeOwnerAllowlist.allowAllTeeMachineOwners(0);
        await teeOwnerAllowlist.allowAllTeeWalletProjectOwners(0);
        // set reward offers manager list
        await rewardManager.setRewardOffersManagerList([ftsoRewardOffersManager.address, validatorRewardOffersManager.address, teeRewardOffersManager.address, teeExtensionRegistry.address, ftdcHub.address]);

        // set initial reward data
        await rewardManager.setInitialRewardData();

        // send some inflation funds
        const inflationFunds = web3.utils.toWei("200000");
        await ftsoRewardOffersManager.setDailyAuthorizedInflation(inflationFunds, { from: INFLATION });
        await ftsoRewardOffersManager.receiveInflation({ value: inflationFunds, from: INFLATION });

        await validatorRewardOffersManager.setDailyAuthorizedInflation(inflationFunds, { from: INFLATION });
        await validatorRewardOffersManager.receiveInflation({ value: inflationFunds, from: INFLATION });

        await teeRewardOffersManager.setDailyAuthorizedInflation(inflationFunds, { from: INFLATION });
        await teeRewardOffersManager.receiveInflation({ value: inflationFunds, from: INFLATION });

        // set reward epoch switchover trigger contracts
        await flareSystemsManager.setRewardEpochSwitchoverTriggerContracts([ftsoRewardOffersManager.address, validatorRewardOffersManager.address, teeRewardOffersManager.address]);

        // set ftso configurations
        await ftsoInflationConfigurations.addFtsoConfiguration(
            {
                feedIds: FtsoConfigurations.encodeFeedIds([{ category: 1, name: "BTC/USD" }, { category: 1, name: "XRP/USD" }, { category: 1, name: "FLR/USD" }, { category: 1, name: "ETH/USD" }]),
                inflationShare: 200,
                minRewardedTurnoutBIPS: 5000,
                mode: 0,
                primaryBandRewardSharePPM: 700000,
                secondaryBandWidthPPMs: FtsoConfigurations.encodeSecondaryBandWidthPPMs([400, 800, 100, 250])
            }
        );
        await ftsoInflationConfigurations.addFtsoConfiguration(
            {
                feedIds: FtsoConfigurations.encodeFeedIds([{ category: 1, name: "BTC/USD" }, { category: 1, name: "LTC/USD" }]),
                inflationShare: 100,
                minRewardedTurnoutBIPS: 5000,
                mode: 0,
                primaryBandRewardSharePPM: 600000,
                secondaryBandWidthPPMs: FtsoConfigurations.encodeSecondaryBandWidthPPMs([200, 1000])
            }
        );

        // set polling management group maintainer and parameters
        await pollingManagementGroup.setMaintainer(accounts[10]);
        await pollingManagementGroup.setParameters(3600, 3600, 5000, 5000, 100, 20, 20, 2, 4, 2, 7, { from: accounts[10] });

        // offer some rewards
        await ftsoRewardOffersManager.offerRewards(1, [
            {
                amount: 25000000,
                feedId: FtsoConfigurations.encodeFeedId({ category: 1, name: "BTC/USD" }),
                minRewardedTurnoutBIPS: 5000,
                primaryBandRewardSharePPM: 450000,
                secondaryBandWidthPPM: 50000,
                claimBackAddress: constants.ZERO_ADDRESS
            }],
            { value: "25000000" }
        );

        // enable claims
        await rewardManager.enableClaims();

        // activate contracts
        await pChainStakeMirror.activate();
        await cChainStake.activate();
        await rewardManager.activate();
    });

    it("Should register addresses", async () => {
        for (let i = 0; i < 4; i++) {
            const prvKey = privateKeys[i].privateKey.slice(2);
            const prvkeyBuffer = Buffer.from(prvKey, 'hex');
            const [x, y] = util.privateKeyToPublicKeyPair(prvkeyBuffer);
            const pubKey = "0x" + util.encodePublicKey(x, y, false).toString('hex');
            const pAddr = "0x" + util.publicKeyToAvalancheAddress(x, y).toString('hex');
            const cAddr = toChecksumAddress("0x" + util.publicKeyToEthereumAddress(x, y).toString('hex'));
            await addressBinder.registerAddresses(pubKey, pAddr, cAddr);
            registeredPAddresses.push(pAddr);
            registeredCAddresses.push(cAddr)
        }
    });

    it("Should verify stakes", async () => {
        for (let i = 0; i < 4; i++) {
            const data = await setMockStakingData(verifierMock, pChainStakeMirrorVerifierInterface, stakeIds[i], 0, registeredPAddresses[i], nodeIds[i], now.subn(10), now.addn(10000), weightsGwei[i]);
            await pChainStakeMirror.mirrorStake(data, []);
        }
    });

    it("Should register and confirm delegation addresses", async () => {
        for (let i = 0; i < 4; i++) {
            await entityManager.proposeDelegationAddress(accounts[50 + i], { from: registeredCAddresses[i] });
            await entityManager.confirmDelegationAddressRegistration(registeredCAddresses[i], { from: accounts[50 + i] });
        }
    });

    it("Should wrap some funds", async () => {
        for (let i = 0; i < 4; i++) {
            await wNat.deposit({ value: toBN(weightsGwei[i] * GWEI), from: accounts[50 + i] });
        }
    });

    it("Should register nodes", async () => {
        for (let i = 0; i < 4; i++) {
            await entityManager.registerNodeId(nodeIds[i], "0x", "0x", { from: registeredCAddresses[i] });
        }
    });

    it("Should register and confirm data provider addresses", async () => {
        for (let i = 0; i < 4; i++) {
            await entityManager.proposeSubmitAddress(accounts[10 + i], { from: registeredCAddresses[i] });
            await entityManager.confirmSubmitAddressRegistration(registeredCAddresses[i], { from: accounts[10 + i] });
        }
    });

    it("Should register and confirm deposit signatures addresses", async () => {
        for (let i = 0; i < 4; i++) {
            await entityManager.proposeSubmitSignaturesAddress(accounts[20 + i], { from: registeredCAddresses[i] });
            await entityManager.confirmSubmitSignaturesAddressRegistration(registeredCAddresses[i], { from: accounts[20 + i] });
        }
    });

    it("Should register and confirm signing policy addresses", async () => {
        for (let i = 0; i < 4; i++) {
            await entityManager.proposeSigningPolicyAddress(accounts[30 + i], { from: registeredCAddresses[i] });
            await entityManager.confirmSigningPolicyAddressRegistration(registeredCAddresses[i], { from: accounts[30 + i] });
        }
    });

    it("Should start random acquisition", async () => {
        await time.increaseTo(now.addn(REWARD_EPOCH_DURATION_IN_SEC - NEW_SIGNING_POLICY_INITIALIZATION_START_SEC)); // 2 hours before new reward epoch
        expectEvent(await flareSystemsManager.daemonize(), "RandomAcquisitionStarted", { rewardEpochId: toBN(1) });
    });

    it("Should get good random", async () => {
        const votingRoundId = FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS -
            NEW_SIGNING_POLICY_INITIALIZATION_START_SEC / VOTING_EPOCH_DURATION_SEC + 1;
        const quality = true;

        const messageData: IProtocolMessageMerkleRoot = { protocolId: FTSO_PROTOCOL_ID, votingRoundId: votingRoundId, isSecureRandom: quality, merkleRoot: RANDOM_ROOT };
        const messageHash = ProtocolMessageMerkleRoot.hash(messageData);
        const signatures = await generateSignatures(privateKeys.slice(INITIAL_NUMBER_OF_VOTERS, INITIAL_NUMBER_OF_VOTERS + 51).map(x => x.privateKey), messageHash, 51);

        const relayMessage = {
            signingPolicy: initialSigningPolicy,
            signatures,
            protocolMessageMerkleRoot: messageData,
        };

        const fullData = RelayMessage.encode(relayMessage);

        const tx = await web3.eth.sendTransaction({
            from: accounts[0],
            to: relay.address,
            data: RELAY_SELECTOR + fullData.slice(2),
        });
        console.log(tx.gasUsed);
        expect((await submission.getCurrentRandomWithQuality())[1]).to.be.true;
    });

    it("Should select vote power block", async () => {
        await time.increase(1); // new random is later than random acquisition start
        expectEvent(await flareSystemsManager.daemonize(), "VotePowerBlockSelected", { rewardEpochId: toBN(1) });
    });

    it("Should register a few voters", async () => {
        const rewardEpochId = 1;
        for (let i = 0; i < 4; i++) {
            const chainId = await web3.eth.getChainId();
            const hash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
                ["uint256", "uint32", "address"],
                [chainId, rewardEpochId, registeredCAddresses[i]]));

            const signature = web3.eth.accounts.sign(hash, privateKeys[30 + i].privateKey);
            expectEvent(await voterRegistry.registerVoter(registeredCAddresses[i], signature),
                "VoterRegistered", { voter: registeredCAddresses[i], rewardEpochId: toBN(1), signingPolicyAddress: accounts[30 + i], submitAddress: accounts[10 + i], submitSignaturesAddress: accounts[20 + i] });
        }
    });

    it("Should initialise new signing policy", async () => {
        for (let i = 0; i < 20; i++) {
            await time.advanceBlock(); // create required number of blocks to proceed
        }
        await time.increaseTo(now.addn(REWARD_EPOCH_DURATION_IN_SEC - 3600)); // at least 30 minutes from the vote power block selection
        const startVotingRoundId = FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS;
        newSigningPolicy = {
            rewardEpochId: 1,
            startVotingRoundId: startVotingRoundId,
            threshold: Math.floor(65535 / 2),
            seed: web3.utils.keccak256(RANDOM_ROOT),
            voters: accounts.slice(30, 34),
            weights: [34664, 20660, 6334, 3875]
        };

        const receipt = await flareSystemsManager.daemonize();
        await expectEvent.inTransaction(receipt.tx, relay, "SigningPolicyInitialized",
            {
                rewardEpochId: toBN(1), startVotingRoundId: toBN(startVotingRoundId), voters: newSigningPolicy.voters,
                seed: toBN(web3.utils.keccak256(RANDOM_ROOT)), threshold: toBN(32767), weights: newSigningPolicy.weights.map(x => toBN(x))
            });
        const result = await relay.lastInitializedRewardEpochData();
        const _lastInitializedRewardEpoch = result[0];
        const _startingVotingRoundIdForLastInitializedRewardEpoch = result[1];
        expect(_lastInitializedRewardEpoch.toString()).to.equal("1");
        expect(_startingVotingRoundIdForLastInitializedRewardEpoch.toString()).to.equal(startVotingRoundId.toString());
        expect(await relay.toSigningPolicyHash(1)).to.be.equal(getSigningPolicyHash(newSigningPolicy));
    });

    it("Should sign new signing policy and relay it", async () => {
        const rewardEpochId = 1;
        // const newSigningPolicyHash = getSigningPolicyHash(newSigningPolicy)
        const newSigningPolicyHash = await relay.toSigningPolicyHash(rewardEpochId);

        let signatures = (51).toString(16).padStart(4, "0");
        for (let i = 0; i < 50; i++) {
            const signature = web3.eth.accounts.sign(newSigningPolicyHash, privateKeys[INITIAL_NUMBER_OF_VOTERS + i].privateKey);
            expectEvent(await flareSystemsManager.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature), "SigningPolicySigned",
                { rewardEpochId: toBN(rewardEpochId), signingPolicyAddress: accounts[INITIAL_NUMBER_OF_VOTERS + i], voter: accounts[i], thresholdReached: false });
            signatures += ECDSASignatureWithIndex.encode({
                v: parseInt(signature.v.slice(2), 16),
                r: signature.r,
                s: signature.s,
                index: i
            }).slice(2);
        }
        const signature = web3.eth.accounts.sign(newSigningPolicyHash, privateKeys[INITIAL_NUMBER_OF_VOTERS + 50].privateKey);
        expectEvent(await flareSystemsManager.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature), "SigningPolicySigned",
            { rewardEpochId: toBN(rewardEpochId), signingPolicyAddress: accounts[INITIAL_NUMBER_OF_VOTERS + 50], voter: accounts[50], thresholdReached: true });
        signatures += ECDSASignatureWithIndex.encode({
            v: parseInt(signature.v.slice(2), 16),
            r: signature.r,
            s: signature.s,
            index: 50
        }).slice(2);

        const signingPolicyEncoded = SigningPolicy.encode(initialSigningPolicy).slice(2);
        const newSigningPolicyEncoded = SigningPolicy.encode(newSigningPolicy).slice(2);
        const fullData = RELAY_SELECTOR + signingPolicyEncoded + "00" + newSigningPolicyEncoded + signatures;


        let result = await relay2.lastInitializedRewardEpochData();
        let _lastInitializedRewardEpoch = result[0];
        expect(_lastInitializedRewardEpoch.toString()).to.equal("0");

        const txReceipt = await web3.eth.sendTransaction({
            from: accounts[0],
            to: relay2.address,
            data: fullData,
        });

        await expectEvent.inTransaction(txReceipt.transactionHash, relay2, "SigningPolicyRelayed", { rewardEpochId: toBN(rewardEpochId) });
        result = (await relay2.lastInitializedRewardEpochData());
        _lastInitializedRewardEpoch = result[0];
        expect(_lastInitializedRewardEpoch.toString()).to.equal(rewardEpochId.toString());
    });

    it("Should start new reward epoch, initiate new voting round and offer rewards for the next reward epoch", async () => {
        await time.increaseTo(now.addn(REWARD_EPOCH_DURATION_IN_SEC));
        expect((await flareSystemsManager.getCurrentRewardEpochId()).toNumber()).to.be.equal(0);
        const tx = await flareSystemsManager.daemonize();
        expectEvent(tx, "RewardEpochStarted");
        await expectEvent.inTransaction(tx.tx, submission, "NewVotingRoundInitiated");
        await expectEvent.inTransaction(tx.tx, ftsoRewardOffersManager, "InflationRewardsOffered", { rewardEpochId: toBN(2), amount: toBN("133333333333333333333333") });
        await expectEvent.inTransaction(tx.tx, ftsoRewardOffersManager, "InflationRewardsOffered", { rewardEpochId: toBN(2), amount: toBN("66666666666666666666667") });
        await expectEvent.inTransaction(tx.tx, validatorRewardOffersManager, "InflationRewardsOffered", { rewardEpochId: toBN(2), amount: toBN("200000000000000000000000") });
        expect((await flareSystemsManager.getCurrentRewardEpochId()).toNumber()).to.be.equal(1);
    });

    it("Should commit", async () => {
        for (let i = 0; i < 4; i++) {
            expect(await submission.submit1.call({ from: accounts[10 + i] })).to.be.true;
            await submission.submit1({ from: accounts[10 + i] });
            expect(await submission.submit1.call({ from: accounts[10 + i] })).to.be.false;
        }
    });

    it("Should initiate new voting round", async () => {
        await time.increaseTo(now.addn(REWARD_EPOCH_DURATION_IN_SEC + VOTING_EPOCH_DURATION_SEC));
        const tx = await flareSystemsManager.daemonize();
        await expectEvent.inTransaction(tx.tx, submission, "NewVotingRoundInitiated");
    });

    it("Should reveal", async () => {
        for (let i = 0; i < 4; i++) {
            expect(await submission.submit2.call({ from: accounts[10 + i] })).to.be.true;
        }
    });

    it("Should deposit signature", async () => {
        for (let i = 0; i < 4; i++) {
            expect(await submission.submitSignatures.call({ from: accounts[20 + i] })).to.be.true;
        }
    });

    it("Should finalise and relay", async () => {
        const votingRoundId = FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS;
        const quality = true;

        feed = {
            votingRoundId: votingRoundId,
            id: FtsoConfigurations.encodeFeedId({ category: 1, name: "BTC/USD" }),
            value: 12345,
            turnoutBIPS: 6500,
            decimals: 1
        };

        const root = web3.utils.keccak256(web3.eth.abi.encodeParameters(
            ["uint32", "bytes21", "int32", "uint16", "int8"],
            [feed.votingRoundId, feed.id, feed.value, feed.turnoutBIPS, feed.decimals]));

        const messageData: IProtocolMessageMerkleRoot = { protocolId: FTSO_PROTOCOL_ID, votingRoundId: votingRoundId, isSecureRandom: quality, merkleRoot: root };
        const messageHash = ProtocolMessageMerkleRoot.hash(messageData);

        const signatures = await generateSignatures(privateKeys.slice(30, 34).map(x => x.privateKey), messageHash, 4);

        const relayMessage = {
            signingPolicy: newSigningPolicy,
            signatures,
            protocolMessageMerkleRoot: messageData,
        };

        const fullData = RelayMessage.encode(relayMessage);

        await web3.eth.sendTransaction({
            from: accounts[0],
            to: relay.address,
            data: RELAY_SELECTOR + fullData.slice(2),
        });
        expect(await relay.merkleRoots(FTSO_PROTOCOL_ID, votingRoundId)).to.be.equal(root);
        expect((await submission.getCurrentRandom()).eq(toBN(web3.utils.keccak256(root)))).to.be.true;
        expect((await submission.getCurrentRandomWithQuality())[1]).to.be.true;

        expect(await relay2.isFinalized(FTSO_PROTOCOL_ID, votingRoundId)).to.be.false;
        await web3.eth.sendTransaction({
            from: accounts[0],
            to: relay2.address,
            data: RELAY_SELECTOR + fullData.slice(2),
        });
        expect(await relay2.isFinalized(FTSO_PROTOCOL_ID, votingRoundId)).to.be.true;
    });

    it("Should publish ftso feed", async () => {
        const feedWithProof = { body: feed, merkleProof: [] };
        const tx = await ftsoFeedPublisher.publish([feedWithProof]);
        expectEvent(tx, "FtsoFeedPublished", { votingRoundId: toBN(feed.votingRoundId), id: feed.id.padEnd(66, "0"), value: toBN(feed.value), turnoutBIPS: toBN(feed.turnoutBIPS), decimals: toBN(feed.decimals) });
        const feedReturn = await ftsoFeedPublisher.getCurrentFeed(feed.id);
        expect(feedReturn.votingRoundId).to.be.equal(feed.votingRoundId.toString());
        expect(feedReturn.id).to.be.equal(feed.id);
        expect(feedReturn.value).to.be.equal(feed.value.toString());
        expect(feedReturn.turnoutBIPS).to.be.equal(feed.turnoutBIPS.toString());
        expect(feedReturn.decimals).to.be.equal(feed.decimals.toString());
    });

    it("Should convert feed id", async () => {
        const category = 1;
        const name = "BTC/USD";
        const encodedFeedId = FtsoConfigurations.encodeFeedId({ category, name });
        const feedId = FtsoConfigurations.decodeFeedIds(encodedFeedId)[0];
        const encodedFeedId2 = await ftsoFeedIdConverter.getFeedId(category, name);
        expect(encodedFeedId2).to.be.equal(encodedFeedId);
        const feedId2 = await ftsoFeedIdConverter.getFeedCategoryAndName(encodedFeedId);
        expect(category).to.be.equal(feedId.category);
        expect(name).to.be.equal(feedId.name);
        expect(category).to.be.equal(feedId2[0]);
        expect(name).to.be.equal(feedId2[1]);
    });

    it("Should commit 2", async () => {
        for (let i = 0; i < 4; i++) {
            expect(await submission.submit1.call({ from: accounts[10 + i] })).to.be.true;
        }
    });

    it("Should start random acquisition for reward epoch 2", async () => {
        await time.increaseTo(now.addn(2 * REWARD_EPOCH_DURATION_IN_SEC - NEW_SIGNING_POLICY_INITIALIZATION_START_SEC)); // 2 hours before new reward epoch
        expectEvent(await flareSystemsManager.daemonize(), "RandomAcquisitionStarted", { rewardEpochId: toBN(2) });
    });

    it("Should get good random for reward epoch 2", async () => {
        const votingRoundId = FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID + 2 * REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS -
            NEW_SIGNING_POLICY_INITIALIZATION_START_SEC / VOTING_EPOCH_DURATION_SEC + 1;
        const quality = true;

        const messageData: IProtocolMessageMerkleRoot = { protocolId: FTSO_PROTOCOL_ID, votingRoundId: votingRoundId, isSecureRandom: quality, merkleRoot: RANDOM_ROOT2 };
        const messageHash = ProtocolMessageMerkleRoot.hash(messageData);

        const signatures = await generateSignatures(privateKeys.slice(30, 34).map(x => x.privateKey), messageHash, 4);

        const relayMessage = {
            signingPolicy: newSigningPolicy,
            signatures,
            protocolMessageMerkleRoot: messageData,
        };

        const fullData = RelayMessage.encode(relayMessage);

        await web3.eth.sendTransaction({
            from: accounts[0],
            to: relay.address,
            data: RELAY_SELECTOR + fullData.slice(2),
        });
        expect((await submission.getCurrentRandomWithQuality())[1]).to.be.true;
    });

    it("Should select vote power block for reward epoch 2", async () => {
        expectEvent(await flareSystemsManager.daemonize(), "VotePowerBlockSelected", { rewardEpochId: toBN(2) });
    });

    it("Should register a few voters for reward epoch 2", async () => {
        const rewardEpochId = 2;
        for (let i = 0; i < 4; i++) {
            const chainId = await web3.eth.getChainId();
            const hash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
                ["uint256", "uint32", "address"],
                [chainId, rewardEpochId, registeredCAddresses[i]]));

            const signature = web3.eth.accounts.sign(hash, privateKeys[30 + i].privateKey);
            expectEvent(await voterRegistry.registerVoter(registeredCAddresses[i], signature),
                "VoterRegistered", { voter: registeredCAddresses[i], rewardEpochId: toBN(2), signingPolicyAddress: accounts[30 + i], submitAddress: accounts[10 + i], submitSignaturesAddress: accounts[20 + i] });
        }
    });

    it("Should initialise new signing policy for reward epoch 2", async () => {
        for (let i = 0; i < 20; i++) {
            await time.advanceBlock(); // create required number of blocks to proceed
        }
        await time.increaseTo(now.addn(2 * REWARD_EPOCH_DURATION_IN_SEC - 3600)); // at least 30 minutes from the vote power block selection
        const votingRoundId = FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID + 2 * REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS;
        const receipt = await flareSystemsManager.daemonize()
        await expectEvent.inTransaction(receipt.tx, relay, "SigningPolicyInitialized",
            {
                rewardEpochId: toBN(2), startVotingRoundId: toBN(votingRoundId), voters: accounts.slice(30, 34),
                seed: toBN(web3.utils.keccak256(RANDOM_ROOT2)), threshold: toBN(32767), weights: [toBN(34664), toBN(20660), toBN(6334), toBN(3875)]
            });
        // tempSigningPolicyEncoded = SigningPolicy.encode({
        //     rewardEpochId: 2,
        //     startVotingRoundId: votingRoundId,
        //     voters: accounts.slice(30, 34),
        //     seed: web3.utils.keccak256(RANDOM_ROOT2),
        //     threshold: 32767,
        //     weights: [34664, 20660, 6334, 3875]
        // })

    });

    it("Should sign new signing policy for reward epoch 2", async () => {
        const rewardEpochId = 2;
        // const newSigningPolicyHash = SigningPolicy.hashEncoded(tempSigningPolicyEncoded)
        const newSigningPolicyHash = await relay.toSigningPolicyHash(rewardEpochId);

        const signature = web3.eth.accounts.sign(newSigningPolicyHash, privateKeys[31].privateKey);
        expectEvent(await flareSystemsManager.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature), "SigningPolicySigned",
            { rewardEpochId: toBN(rewardEpochId), signingPolicyAddress: accounts[31], voter: registeredCAddresses[1], thresholdReached: false });
        const signature2 = web3.eth.accounts.sign(newSigningPolicyHash, privateKeys[30].privateKey);
        expectEvent(await flareSystemsManager.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature2), "SigningPolicySigned",
            { rewardEpochId: toBN(rewardEpochId), signingPolicyAddress: accounts[30], voter: registeredCAddresses[0], thresholdReached: true });
        const signature3 = web3.eth.accounts.sign(newSigningPolicyHash, privateKeys[32].privateKey);
        await expectRevert(flareSystemsManager.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature3), "new signing policy already signed");

    });

    it("Should start new reward epoch (2) and initiate new voting round", async () => {
        await time.increaseTo(now.addn(2 * REWARD_EPOCH_DURATION_IN_SEC));
        expect((await flareSystemsManager.getCurrentRewardEpochId()).toNumber()).to.be.equal(1);
        const tx = await flareSystemsManager.daemonize();
        expectEvent(tx, "RewardEpochStarted");
        await expectEvent.inTransaction(tx.tx, submission, "NewVotingRoundInitiated");
        expect((await flareSystemsManager.getCurrentRewardEpochId()).toNumber()).to.be.equal(2);
    });

    it("Should submit some uptime votes for reward epoch 1", async () => {
        const rewardEpochId = 1;
        for (let i = 0; i < 4; i++) {
            const hash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
                ["uint24", "bytes20[]"],
                [rewardEpochId, nodeIds]));

            const signature = web3.eth.accounts.sign(hash, privateKeys[30 + i].privateKey);
            expectEvent(await flareSystemsManager.submitUptimeVote(rewardEpochId, nodeIds, signature),
                "UptimeVoteSubmitted", { voter: registeredCAddresses[i], rewardEpochId: toBN(1), signingPolicyAddress: accounts[30 + i], nodeIds: nodeIds });
        }
    });

    it("Should sign uptime vote for reward epoch 1", async () => {
        for (let i = 0; i < 20; i++) {
            await time.advanceBlock(); // create required number of blocks to proceed
        }
        await time.increaseTo(now.addn(2 * REWARD_EPOCH_DURATION_IN_SEC + 3600)); // at least 10 minutes from the new reward epoch start
        const tx = await flareSystemsManager.daemonize();
        expectEvent(tx, "SignUptimeVoteEnabled", { rewardEpochId: toBN(1) });
        const rewardEpochId = 1;
        const uptimeVoteHash = web3.utils.keccak256("uptime");
        const hash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
            ["uint24", "bytes32"],
            [rewardEpochId, uptimeVoteHash]));

        const signature = web3.eth.accounts.sign(hash, privateKeys[31].privateKey);
        expectEvent(await flareSystemsManager.signUptimeVote(rewardEpochId, uptimeVoteHash, signature), "UptimeVoteSigned",
            { rewardEpochId: toBN(1), signingPolicyAddress: accounts[31], voter: registeredCAddresses[1], thresholdReached: false });
        const signature2 = web3.eth.accounts.sign(hash, privateKeys[30].privateKey);
        expectEvent(await flareSystemsManager.signUptimeVote(rewardEpochId, uptimeVoteHash, signature2), "UptimeVoteSigned",
            { rewardEpochId: toBN(1), signingPolicyAddress: accounts[30], voter: registeredCAddresses[0], thresholdReached: true });
        const signature3 = web3.eth.accounts.sign(hash, privateKeys[32].privateKey);
        await expectRevert(flareSystemsManager.signUptimeVote(rewardEpochId, uptimeVoteHash, signature3), "uptime vote hash already signed");
        expect(await flareSystemsManager.uptimeVoteHash(rewardEpochId)).to.be.equal(uptimeVoteHash);
    });

    it("Should sign rewards for reward epoch 1", async () => {
        const rewardEpochId = 1;
        const noOfWeightBasedClaims = [{ rewardManagerId: REWARD_MANAGER_ID, noOfWeightBasedClaims: 1 }];

        rewardClaim = {
            rewardEpochId: 1,
            beneficiary: accounts[50],
            amount: 500,
            claimType: 2 //RewardsV2Interface.ClaimType.WNAT
        }

        const rewardsVoteHash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
            ["uint24", "bytes20", "uint120", "uint8"],
            [rewardClaim.rewardEpochId, rewardClaim.beneficiary, rewardClaim.amount, rewardClaim.claimType]));
        const noOfWeightBasedClaimsHash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
            ["tuple(uint256,uint256)[]"],
            [noOfWeightBasedClaims.map(value => [value.rewardManagerId, value.noOfWeightBasedClaims])]));
        const hash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
            ["uint24", "bytes32", "bytes32"],
            [rewardEpochId, noOfWeightBasedClaimsHash, rewardsVoteHash]));

        const signature = web3.eth.accounts.sign(hash, privateKeys[31].privateKey);
        expectEvent(await flareSystemsManager.signRewards(rewardEpochId, noOfWeightBasedClaims, rewardsVoteHash, signature), "RewardsSigned",
            { rewardEpochId: toBN(1), signingPolicyAddress: accounts[31], voter: registeredCAddresses[1], thresholdReached: false });
        const signature2 = web3.eth.accounts.sign(hash, privateKeys[30].privateKey);
        expectEvent(await flareSystemsManager.signRewards(rewardEpochId, noOfWeightBasedClaims, rewardsVoteHash, signature2), "RewardsSigned",
            { rewardEpochId: toBN(1), signingPolicyAddress: accounts[30], voter: registeredCAddresses[0], thresholdReached: true });
        const signature3 = web3.eth.accounts.sign(hash, privateKeys[32].privateKey);
        await expectRevert(flareSystemsManager.signRewards(rewardEpochId, noOfWeightBasedClaims, rewardsVoteHash, signature3), "rewards hash already signed");
        expect(await flareSystemsManager.rewardsHash(rewardEpochId)).to.be.equal(rewardsVoteHash);
        expect((await flareSystemsManager.noOfWeightBasedClaims(rewardEpochId, REWARD_MANAGER_ID)).toNumber()).to.be.equal(noOfWeightBasedClaims[0].noOfWeightBasedClaims);
    });

    it("Should claim the reward for reward epoch 1", async () => {
        const balanceBefore = await wNat.balanceOf(accounts[200]);
        const tx = await rewardManager.claim(accounts[50],
            accounts[200],
            1,
            true,
            [{ body: rewardClaim, merkleProof: [] }],
            { from: accounts[50] }
        );
        const balanceAfter = await wNat.balanceOf(accounts[200]);

        expectEvent(tx, "RewardClaimed", { beneficiary: accounts[50], rewardOwner: accounts[50], recipient: accounts[200], rewardEpochId: toBN(1), claimType: toBN(2), amount: toBN(500) });
        expect(balanceAfter.sub(balanceBefore).toNumber()).to.be.equal(500);
    });

    it("Should create new PollingFoundation proposal and vote on it", async () => {
        type ProposalCreatedEvent = { name: "ProposalCreated"; args: { proposalId: string } };

        const tx = await pollingFoundation.methods["propose(string,(bool,uint256,uint256,uint256,uint256,uint256))"].sendTransaction("Proposal",
            {
                accept: false,
                votingStartTs: (await time.latest()).addn(3600).toNumber(),
                votingPeriodSeconds: 7200,
                vpBlockPeriodSeconds: 259200,
                thresholdConditionBIPS: 7500,
                majorityConditionBIPS: 5000
            }, { from: accounts[10] }) as unknown as Truffle.TransactionResponse<ProposalCreatedEvent>;
        const event = findRequiredEvent(tx, "ProposalCreated");
        const eventArgs = event.args;
        const proposalId: string = eventArgs.proposalId.toString();

        // advance one hour to the voting period
        await time.increase(3600);

        // voting
        await pollingFoundation.castVote(proposalId, 0, { from: registeredCAddresses[0] });
        await pollingFoundation.castVote(proposalId, 1, { from: registeredCAddresses[1] });
        await pollingFoundation.castVote(proposalId, 0, { from: registeredCAddresses[2] });

        // advance to the end of the voting period
        await time.increase(7200);

        const state = await pollingFoundation.state(proposalId);
        expect(state.toString()).to.equals("2");
    });

    it("Should create new PollingManagementGroup proposal and vote on it", async () => {
        // change management group members
        await pollingManagementGroup.changeManagementGroupMembers(registeredCAddresses, [], { from: accounts[10] });
        const proposalId = toBN(1);
        const tx = await pollingManagementGroup.propose("Proposal", { value: toBN(100), from: registeredCAddresses[0] });
        expectEvent(tx, "ManagementGroupProposalCreated", { proposalId: proposalId, proposer: registeredCAddresses[0] });

        // advance one hour to the voting period
        await time.increase(3600);

        // voting
        await pollingManagementGroup.castVote(proposalId, 1, { from: registeredCAddresses[0] });
        await pollingManagementGroup.castVote(proposalId, 1, { from: registeredCAddresses[1] });
        await pollingManagementGroup.castVote(proposalId, 0, { from: registeredCAddresses[2] });

        // advance to the end of the voting period
        await time.increase(3600);

        const state = await pollingManagementGroup.state(proposalId);
        expect(state.toString()).to.equals("4");
    });

    it("Should set new TEE governance", async () => {
        await teeGovernance.setNewTeeGovernance(0,teeGovernanceSigners, teeGovernanceSignersThreshold);

        const governanceHash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
            ["address[]", "uint256"],
            [teeGovernanceSigners, teeGovernanceSignersThreshold]));

        expect(await teeGovernance.getLatestTeeGovernanceHash(0)).to.be.equal(governanceHash);
        const governance = await teeGovernance.getTeeGovernance(0, governanceHash);
        expect(governance[0]).to.be.deep.equal(teeGovernanceSigners);
        expect(governance[1].toNumber()).to.be.equal(teeGovernanceSignersThreshold);
        expect(await teeGovernance.getTeeGovernanceThreshold(0, governanceHash)).to.be.equal(teeGovernanceSignersThreshold);
    });

    it("Should add new TEE node version", async () => {
        const governanceHash = await teeGovernance.getLatestTeeGovernanceHash(0);
        const supportedPlatforms = TEE_PLATFORMS.map(platform => web3.utils.utf8ToHex(platform).padEnd(66, "0"));
        await teeExtensionRegistry.addTeeVersion(0, "v0.1.0", TEE_CODE_HASH, supportedPlatforms, governanceHash);

        const codeHashInfo = await teeExtensionRegistry.getCodeHashInfo(0, TEE_CODE_HASH);
        expect(codeHashInfo[0]).to.be.equal(governanceHash);
        expect(codeHashInfo[1]).to.be.equal("v0.1.0");
        expect(codeHashInfo[2]).to.be.deep.equal(supportedPlatforms);
    });

    it("Should register new TEE machines", async () => {
        assert(TEE_URLS.length === TEE_IDS.length && TEE_URLS.length === TEE_PROXY_IDS.length && TEE_URLS.length === TEE_PLATFORMS.length && TEE_URLS.length === TEE_OWNERS.length, "Arrays must be of the same length");
        for (let i = 0; i < TEE_URLS.length; i++) {
            const tx = await teeMachineRegistry.register(
                0,
                TEE_IDS[i],
                TEE_PROXY_IDS[i],
                TEE_URLS[i],
                TEE_CODE_HASH,
                web3.utils.utf8ToHex(TEE_PLATFORMS[i]).padEnd(66, "0"),
                { value: "2", from: TEE_OWNERS[i] }
            );
            expectEvent(tx, "TeeMachineRegistered", {
                teeId: TEE_IDS[i],
                teeProxyId: TEE_PROXY_IDS[i],
                extensionId: "0",
                owner: TEE_OWNERS[i],
                url: TEE_URLS[i],
                codeHash: TEE_CODE_HASH,
                platform: web3.utils.utf8ToHex(TEE_PLATFORMS[i]).padEnd(66, "0")
            });

            const event = requiredEventArgsFrom(tx, teeExtensionRegistry, "TeeInstructionsSent") as any;
            expect(event.rewardEpochId).to.be.equal("2");
            expect(event.opType).to.be.equal(web3.utils.utf8ToHex("F_REG").padEnd(66, "0"));
            expect(event.opCommand).to.be.equal(web3.utils.utf8ToHex("TEE_ATTESTATION").padEnd(66, "0"));
            // TODO check why expectEvent.inTransaction is not working
            // await expectEvent.inTransaction(response.tx, teeExtensionRegistry, 'TeeInstructionsSent', {
            //     rewardEpochId: "2",
            //     opType: web3.utils.utf8ToHex("F_FTDC").padEnd(66, "0"),
            //     opCommand: web3.utils.utf8ToHex("PROVE").padEnd(66, "0")
            // });
            const event2 = requiredEventArgsFrom(tx, teeVerification, "TeeAttestationRequested") as any;
            expect(event2.teeId).to.be.equal(TEE_IDS[i]);
            challenges.push(event2.challenge);
        }
    });

    it("Should put new TEE machines in production", async () => {
        const governanceHash = await teeGovernance.getLatestTeeGovernanceHash(0);
        const rewardEpochId = 2;
        assert(TEE_URLS.length === challenges.length && TEE_URLS.length === TEE_IDS.length && TEE_URLS.length === TEE_PLATFORMS.length && TEE_URLS.length === TEE_OWNERS.length, "Arrays must be of the same length");
        for (let i = 0; i < TEE_URLS.length; i++) {
            const teeState = {
                systemState: "0x",
                systemStateVersion: constants.ZERO_BYTES32,
                state: "0x",
                stateVersion: constants.ZERO_BYTES32
            };
            const proof = {
                signatures: {
                    signingPolicySignatures: "0x", // TODO
                    teeSignatures: [],
                    cosignerSignatures: [],
                },
                header: {
                    attestationType: web3.utils.utf8ToHex("TeeAvailabilityCheck").padEnd(66, "0"),
                    sourceId: web3.utils.utf8ToHex(TEE_SOURCE_ID).padEnd(66, "0"),
                    thresholdBIPS: "0",
                    timestamp: (await time.latest()).toString(),
                    cosigners: [],
                    cosignersThreshold: "0",
                },
                requestBody: {
                    teeId: TEE_IDS[i],
                    url: TEE_URLS[i],
                    challenge: challenges[i].toString()
                },
                responseBody: {
                    status: "0",
                    teeTimestamp: (await time.latest()).toString(),
                    initialTeeId: TEE_IDS[i],
                    codeHash: TEE_CODE_HASH,
                    platform: web3.utils.utf8ToHex(TEE_PLATFORMS[i]).padEnd(66, "0"),
                    initialSigningPolicyId: rewardEpochId,
                    lastSigningPolicyId: rewardEpochId,
                    state: teeState
                },
            }
            await time.increase(1);
            let tx = await teeMachineRegistry.toProduction(proof, { from: TEE_OWNERS[i] });
            expectEvent(tx, "TeeMachinePutIntoProduction", {
                teeId: TEE_IDS[i]
            });
        }
    });

    it("Should create new TEE projects", async () => {
        assert(TEE_WALLET_SUBMIT_ADDRESSES.length >= 2 && TEE_WALLET_OWNERS.length >= 2, "At least 2 owners and submit addresses are required");

        let tx = await teeWalletProjectManager.createProject(
            0,
            web3.utils.utf8ToHex("F_XRP").padEnd(66, "0"),
            TEE_WALLET_SUBMIT_ADDRESSES[0],
            { from: TEE_WALLET_OWNERS[0] }
        );
        expectEvent(tx, "ProjectCreated", {
            extensionId: "0",
            projectId: PROJECT1_ID,
            opType: web3.utils.utf8ToHex("F_XRP").padEnd(66, "0"),
            owner: TEE_WALLET_OWNERS[0],
            submitAddress: TEE_WALLET_SUBMIT_ADDRESSES[0]
        });

        tx = await teeWalletProjectManager.createProject(
            0,
            web3.utils.utf8ToHex("F_EVM").padEnd(66, "0"),
            TEE_WALLET_SUBMIT_ADDRESSES[1],
            { from: TEE_WALLET_OWNERS[1] }
        );
        expectEvent(tx, "ProjectCreated", {
            extensionId: "0",
            projectId: PROJECT2_ID,
            opType: web3.utils.utf8ToHex("F_EVM").padEnd(66, "0"),
            owner: TEE_WALLET_OWNERS[1],
            submitAddress: TEE_WALLET_SUBMIT_ADDRESSES[1]
        });
    });

    it("Should create TEE wallets and initialize them", async () => {
        // create wallet for project 1
        let tx = await teeWalletManager.createWallet(PROJECT1_ID, { from: TEE_WALLET_OWNERS[0] });
        expectEvent(tx, "WalletCreated", {
            walletId: WALLET1_ID,
            projectId: PROJECT1_ID
        });

        tx = await teeWalletManager.setAdmins(WALLET1_ID, adminsPublicKeys1, 2, { from: TEE_WALLET_OWNERS[0] });
        expectEvent(tx, "WalletAdminsSet", {
            walletId: WALLET1_ID,
            adminsThreshold: "2"
        });
        expectEvent(await teeWalletManager.confirmAdmin(WALLET1_ID, { from: accounts[10] }), "WalletAdminConfirmed", {
            walletId: WALLET1_ID,
            admin: accounts[10]
        });
        expectEvent(await teeWalletManager.confirmAdmin(WALLET1_ID, { from: accounts[11] }), "WalletAdminConfirmed", {
            walletId: WALLET1_ID,
            admin: accounts[11]
        });
        tx = await teeWalletManager.closeWalletInitialization(WALLET1_ID, { from: TEE_WALLET_OWNERS[0] });
        expectEvent(tx, "WalletInitialized", {
            walletId: WALLET1_ID
        });

        // create wallet for project 2
        expectEvent(await teePaymentsEVM.setChainId(PROJECT2_ID, 14, { from: TEE_WALLET_OWNERS[1] }), "ChainIdSet", {
            projectId: PROJECT2_ID,
            chainId: "14"
        });
        tx = await teeWalletManager.createWallet(PROJECT2_ID, { from: TEE_WALLET_OWNERS[1] });
        expectEvent(tx, "WalletCreated", {
            walletId: WALLET2_ID,
            projectId: PROJECT2_ID
        });

        tx = await teeWalletManager.setAdmins(WALLET2_ID, adminsPublicKeys2, 1, { from: TEE_WALLET_OWNERS[1] });
        expectEvent(tx, "WalletAdminsSet", {
            walletId: WALLET2_ID,
            adminsThreshold: "1"
        });
        expectEvent(await teeWalletManager.confirmAdmin(WALLET2_ID, { from: accounts[12] }), "WalletAdminConfirmed", {
            walletId: WALLET2_ID,
            admin: accounts[12]
        });
        expectEvent(await teeWalletManager.confirmAdmin(WALLET2_ID, { from: accounts[13] }), "WalletAdminConfirmed", {
            walletId: WALLET2_ID,
            admin: accounts[13]
        });
        tx = await teeWalletManager.setCosigners(WALLET2_ID, [accounts[14]], 1, { from: TEE_WALLET_OWNERS[1] });
        expectEvent(tx, "WalletCosignersSet", {
            walletId: WALLET2_ID,
            cosignersThreshold: "1"
        });
        expectEvent(await teeWalletManager.confirmCosigner(WALLET2_ID, { from: accounts[14] }), "WalletCosignerConfirmed", {
            walletId: WALLET2_ID,
            cosigner: accounts[14]
        });
        tx = await teeWalletManager.closeWalletInitialization(WALLET2_ID, { from: TEE_WALLET_OWNERS[1] });
        expectEvent(tx, "WalletInitialized", {
            walletId: WALLET2_ID
        });
    });

    it("Should set wallet multisig threshold", async () => {
        let tx = await teeWalletKeyManager.setMultisigThreshold(WALLET1_ID, 2, { from: TEE_WALLET_OWNERS[0] });
        expectEvent(tx, "WalletMultisigThresholdSet", {
            walletId: WALLET1_ID,
            multisigThreshold: "2"
        });
        tx = await teeWalletKeyManager.setMultisigThreshold(WALLET2_ID, 1, { from: TEE_WALLET_OWNERS[1] });
        expectEvent(tx, "WalletMultisigThresholdSet", {
            walletId: WALLET2_ID,
            multisigThreshold: "1"
        });
    });

    it("Should add keys to TEE wallets and confirm them", async () => {
        const xrpPublicKeys = ["0x03D11FBF992FCC3C7326E323687C234866E400229EA81C73EE4D0DBC1AB5DB22D3", "0x03FE12E21F5B2298FFC9A260A95F5031071E9E0778257276E47BB9A0C27CF6C5AD", "0x03353D8A544503E0F4D6686379B82D64ED1537CB2961FA1193F57B3E8E17F82980"];
        const xrpAddresses = ["rE5KBHjE7cHFUfHazonUcX9cKv7R519uyR", "rDagTyzXeYLZPe2fLbKYG9n7rCTQd3D2No", "r3uuriD2ARqLqZnEbk5sWzvjuD3zyVQEU1"];

        for (let i = 0; i < xrpPublicKeys.length; i++) {
            let tx = await teeWalletKeyManager.addKey(TEE_IDS[i%2], WALLET1_ID, { value: "10", from: TEE_WALLET_OWNERS[0] });
            const event = requiredEventArgsFrom(tx, teeExtensionRegistry, "TeeInstructionsSent") as any;
            expect(event.rewardEpochId).to.be.equal("2");
            expect(event.opType).to.be.equal(web3.utils.utf8ToHex("F_WALLET").padEnd(66, "0"));
            expect(event.opCommand).to.be.equal(web3.utils.utf8ToHex("KEY_GENERATE").padEnd(66, "0"));

            const proof = {
                teeId: TEE_IDS[i%2],
                walletId: WALLET1_ID,
                keyId: i.toString(),
                opType: web3.utils.utf8ToHex("F_XRP").padEnd(66, "0"),
                publicKey: xrpPublicKeys[i],
                proofOfPossession: "0x",
                nonce: "0",
                pauseNonce: "0",
                status: "0",
                restored: false,
                addressStr: xrpAddresses[i],
                configConstants: {
                    adminsPublicKeys: adminsPublicKeys1,
                    adminsThreshold: "2",
                    cosigners: [],
                    cosignersThreshold: "0",
                    opTypeConstants: "0x",
                },
                configSettings: {
                    pausingAddresses: [],
                    opTypeSettings: "0x"
                }
            };

            const msg = web3.utils.keccak256(web3.eth.abi.encodeParameters(
                [KeyExistanceStruct],
                [proof]
            ));
            const signature = await ECDSASignature.signMessageHash(
                msg,
                privateKeys[20 + i%2].privateKey
            );


            await time.increase(1);
            tx = await teeWalletKeyManager.confirmKey(proof, signature, { from: TEE_WALLET_OWNERS[0] });
            expectEvent(tx, "WalletKeyConfirmed", {
                teeId: TEE_IDS[i%2],
                walletId: WALLET1_ID,
                keyId: i.toString(),
                publicKey: xrpPublicKeys[i],
                addressStr: xrpAddresses[i]
            });
        }

        const opTypeConstants = web3.eth.abi.encodeParameters(["uint256"], [14]);

        for (let i = 0; i < 4; i++) {
            let tx = await teeWalletKeyManager.addKey(TEE_IDS[i%2], WALLET2_ID, { value: "10", from: TEE_WALLET_OWNERS[1] });
            const event = requiredEventArgsFrom(tx, teeExtensionRegistry, "TeeInstructionsSent") as any;
            expect(event.rewardEpochId).to.be.equal("2");
            expect(event.opType).to.be.equal(web3.utils.utf8ToHex("F_WALLET").padEnd(66, "0"));
            expect(event.opCommand).to.be.equal(web3.utils.utf8ToHex("KEY_GENERATE").padEnd(66, "0"));

            let prvKey = privateKeys[50+i].privateKey.slice(2);
            let prvkeyBuffer = Buffer.from(prvKey, 'hex');
            let [x, y] = util.privateKeyToPublicKeyPair(prvkeyBuffer);
            let publicKey = "0x" + util.encodePublicKey(x, y, false).toString('hex');
            let addressStr = toChecksumAddress("0x" + util.publicKeyToEthereumAddress(x, y).toString('hex'));

            const proof = {
                teeId: TEE_IDS[i%2],
                walletId: WALLET2_ID,
                keyId: i.toString(),
                opType: web3.utils.utf8ToHex("F_EVM").padEnd(66, "0"),
                publicKey: publicKey,
                proofOfPossession: "0x",
                nonce: "0",
                pauseNonce: "0",
                status: "0",
                restored: false,
                addressStr: addressStr,
                configConstants: {
                    adminsPublicKeys: adminsPublicKeys2,
                    adminsThreshold: "1",
                    cosigners: [accounts[14]],
                    cosignersThreshold: "1",
                    opTypeConstants: opTypeConstants,
                },
                configSettings: {
                    pausingAddresses: [],
                    opTypeSettings: "0x"
                }
            };

            const msg = web3.utils.keccak256(web3.eth.abi.encodeParameters(
                [KeyExistanceStruct],
                [proof]
            ));
            console.log("msg", msg);
            const signature = await ECDSASignature.signMessageHash(
                msg,
                privateKeys[20 + i%2].privateKey
            );

            // mock
            await ftdcVerification.setSigningTeeIds([TEE_IDS[i%2]]);
            await time.increase(1);
            tx = await teeWalletKeyManager.confirmKey(proof, signature, { from: TEE_WALLET_OWNERS[1] });
            expectEvent(tx, "WalletKeyConfirmed", {
                teeId: TEE_IDS[i%2],
                walletId: WALLET2_ID,
                keyId: i.toString(),
                publicKey: publicKey,
                addressStr: addressStr
            });
        }
    });

    it("Should enable TEE wallets", async () => {
        let tx = await teeWalletManager.enableWallet(WALLET1_ID, { from: TEE_WALLET_OWNERS[0] });
        expectEvent(tx, "WalletEnabled", {
            walletId: WALLET1_ID
        });

        tx = await teeWalletManager.enableWallet(WALLET2_ID, { from: TEE_WALLET_OWNERS[1] });
        expectEvent(tx, "WalletEnabled", {
            walletId: WALLET2_ID
        });
    });

    it("Should set default TEE wallets", async () => {
        let tx = await teeWalletProjectManager.setDefaultWallet(PROJECT1_ID, WALLET1_ID, { from: TEE_WALLET_OWNERS[0] });
        expectEvent(tx, "DefaultWalletSet", {
            projectId: PROJECT1_ID,
            walletId: WALLET1_ID
        });

        tx = await teeWalletProjectManager.setDefaultWallet(PROJECT2_ID, WALLET2_ID, { from: TEE_WALLET_OWNERS[1] });
        expectEvent(tx, "DefaultWalletSet", {
            projectId: PROJECT2_ID,
            walletId: WALLET2_ID
        });
    });

    it("Should set TEE payment wallet settings", async () => {
        // set wallet 1 settings
        let tx = await teePayments.setBatchSettings(WALLET1_ID, 1, 0, { from: TEE_WALLET_OWNERS[0] });
        expectEvent(tx, "BatchSettingsSet", {
            walletId: WALLET1_ID,
            batchSize: "1",
            batchDurationSeconds: "0"
        });

        tx = await teePayments.setMinFee(WALLET1_ID, 100, { from: TEE_WALLET_OWNERS[0] });
        expectEvent(tx, "MinFeeSet", {
            walletId: WALLET1_ID,
            minFee: "100"
        });

        tx = await teePayments.setSenderAddressAndInitialNonce(WALLET1_ID, "rUzM4ovjNkjSZ2jVJfZQ9321ikeNM6ASzh", 2, { from: TEE_WALLET_OWNERS[0] });
        expectEvent(tx, "SenderAddressSet", {
            walletId: WALLET1_ID,
            senderAddress: "rUzM4ovjNkjSZ2jVJfZQ9321ikeNM6ASzh",
            initialNonce: "2"
        });

        // set wallet 2 settings
        let tx2 = await teePaymentsEVM.setBatchSettings(WALLET2_ID, 1, 0, { from: TEE_WALLET_OWNERS[1] });
        expectEvent(tx2, "BatchSettingsSet", {
            walletId: WALLET2_ID,
            batchSize: "1",
            batchDurationSeconds: "0"
        });
        tx2 = await teePaymentsEVM.setMinFee(WALLET2_ID, 1000, { from: TEE_WALLET_OWNERS[1] });
        expectEvent(tx2, "MinFeeSet", {
            walletId: WALLET2_ID,
            minFee: "1000"
        });
        tx2 = await teePaymentsEVM.setSenderAddressAndInitialNonce(WALLET2_ID, accounts[200], 1, { from: TEE_WALLET_OWNERS[1] });
        expectEvent(tx2, "SenderAddressSet", {
            walletId: WALLET2_ID,
            senderAddress: accounts[200],
            initialNonce: "1"
        });
    });

    it("Should trigger TEE wallet payments", async () => {
        let tx = await teePayments.pay(PROJECT1_ID, constants.ZERO_BYTES32,
            { recipientAddress: "rJcBbUCtPg7b4Pfou23SgF18yMihWueK5B", amount: "500", fee: 150, paymentReference: "0xa586ed066db13d66ebe984e1898a2c5fdd74927b21fe92d3b9913725cdaee75a" },
            { value: "10", from: TEE_WALLET_SUBMIT_ADDRESSES[0] });
        const event = requiredEventArgsFrom(tx, teeExtensionRegistry, "TeeInstructionsSent") as any;
        expect(event.rewardEpochId).to.be.equal("2");
        expect(event.opType).to.be.equal(web3.utils.utf8ToHex("F_XRP").padEnd(66, "0"));
        expect(event.opCommand).to.be.equal(web3.utils.utf8ToHex("PAY").padEnd(66, "0"));

        let tx2 = await teePaymentsEVM.pay(PROJECT2_ID, constants.ZERO_BYTES32,
            { recipientAddress: accounts[150], amount: "1500", fee: 1000, paymentReference: "0xa7ed203289b636afb50dfc134afdcf844e495ec686cda5fb958e5a0ddd039797" },
            { value: "10", from: TEE_WALLET_SUBMIT_ADDRESSES[1] });
        const event2 = requiredEventArgsFrom(tx2, teeExtensionRegistry, "TeeInstructionsSent") as any;
        expect(event2.rewardEpochId).to.be.equal("2");
        expect(event2.opType).to.be.equal(web3.utils.utf8ToHex("F_EVM").padEnd(66, "0"));
        expect(event2.opCommand).to.be.equal(web3.utils.utf8ToHex("PAY").padEnd(66, "0"));
    });

    it("Should trigger TEE wallet reissue payments", async () => {
        await time.increase(1);
        let tx = await teePayments.reissue(WALLET1_ID, 2, 2,
            [{ recipientAddress: "rJcBbUCtPg7b4Pfou23SgF18yMihWueK5B", amount: "500", fee: 150, paymentReference: "0xa586ed066db13d66ebe984e1898a2c5fdd74927b21fe92d3b9913725cdaee75a" }],
            [10000], [false],
            { value: "10", from: TEE_WALLET_SUBMIT_ADDRESSES[0] });
        const event = requiredEventArgsFrom(tx, teeExtensionRegistry, "TeeInstructionsSent") as any;
        expect(event.rewardEpochId).to.be.equal("2");
        expect(event.opType).to.be.equal(web3.utils.utf8ToHex("F_XRP").padEnd(66, "0"));
        expect(event.opCommand).to.be.equal(web3.utils.utf8ToHex("REISSUE").padEnd(66, "0"));

        let tx2 = await teePaymentsEVM.reissue(WALLET2_ID, 1, 1,
            [{ recipientAddress: accounts[150], amount: "1500", fee: 1000, paymentReference: "0xa7ed203289b636afb50dfc134afdcf844e495ec686cda5fb958e5a0ddd039797" }],
            [5000000], [false],
            { value: "10", from: TEE_WALLET_SUBMIT_ADDRESSES[1] });
        const event2 = requiredEventArgsFrom(tx2, teeExtensionRegistry, "TeeInstructionsSent") as any;
        expect(event2.rewardEpochId).to.be.equal("2");
        expect(event2.opType).to.be.equal(web3.utils.utf8ToHex("F_EVM").padEnd(66, "0"));
        expect(event2.opCommand).to.be.equal(web3.utils.utf8ToHex("REISSUE").padEnd(66, "0"));
    });
});

const KeyExistanceStruct = {
    "components": [
        {
            "internalType": "address",
            "name": "teeId",
            "type": "address"
        },
        {
            "internalType": "bytes32",
            "name": "walletId",
            "type": "bytes32"
        },
        {
            "internalType": "uint64",
            "name": "keyId",
            "type": "uint64"
        },
        {
            "internalType": "bytes32",
            "name": "opType",
            "type": "bytes32"
        },
        {
            "internalType": "bytes",
            "name": "publicKey",
            "type": "bytes"
        },
        {
            "internalType": "bytes",
            "name": "proofOfPossession",
            "type": "bytes"
        },
        {
            "internalType": "uint256",
            "name": "nonce",
            "type": "uint256"
        },
        {
            "internalType": "uint256",
            "name": "pauseNonce",
            "type": "uint256"
        },
        {
            "internalType": "enum ITeeWalletKeyManager.TeeKeyStatus",
            "name": "status",
            "type": "uint8"
        },
        {
            "internalType": "bool",
            "name": "restored",
            "type": "bool"
        },
        {
            "internalType": "string",
            "name": "addressStr",
            "type": "string"
        },
        {
            "components": [
            {
                "components": [
                {
                    "internalType": "bytes32",
                    "name": "x",
                    "type": "bytes32"
                },
                {
                    "internalType": "bytes32",
                    "name": "y",
                    "type": "bytes32"
                }
                ],
                "internalType": "struct PublicKey[]",
                "name": "adminsPublicKeys",
                "type": "tuple[]"
            },
            {
                "internalType": "uint64",
                "name": "adminsThreshold",
                "type": "uint64"
            },
            {
                "internalType": "address[]",
                "name": "cosigners",
                "type": "address[]"
            },
            {
                "internalType": "uint64",
                "name": "cosignersThreshold",
                "type": "uint64"
            },
            {
                "internalType": "bytes",
                "name": "opTypeConstants",
                "type": "bytes"
            }
            ],
            "internalType": "struct ITeeWalletKeyManager.KeyConfigConstants",
            "name": "configConstants",
            "type": "tuple"
        },
        {
            "components": [
            {
                "internalType": "address[]",
                "name": "pausingAddresses",
                "type": "address[]"
            },
            {
                "internalType": "bytes",
                "name": "opTypeSettings",
                "type": "bytes"
            }
            ],
            "internalType": "struct ITeeWalletKeyManager.KeyConfigSettings",
            "name": "configSettings",
            "type": "tuple"
        }
    ],
    "internalType": "struct ITeeWalletKeyManager.KeyExistence",
    "name": "_proof",
    "type": "tuple"
};
