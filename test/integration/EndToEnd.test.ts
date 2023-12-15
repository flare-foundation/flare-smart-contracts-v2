
import { expectEvent, expectRevert, time } from '@openzeppelin/test-helpers';
import { getTestFile } from "../utils/constants";
import { AddressBinderInstance, EntityManagerInstance, GovernanceSettingsInstance, GovernanceVotePowerInstance, MockContractInstance, PChainStakeMirrorInstance, PChainStakeMirrorVerifierInstance, WNatInstance } from '../../typechain-truffle';
import { Contracts } from '../../deployment/scripts/Contracts';
import { encodeContractNames, findRequiredEvent, toBN } from '../utils/test-helpers';
import privateKeys from "../../deployment/test-1020-accounts.json"
import * as util from "../utils/key-to-address";
import { toChecksumAddress } from 'ethereumjs-util';
import { VoterWhitelisterInstance } from '../../typechain-truffle/contracts/protocol/implementation/VoterWhitelister';
import { FinalisationInstance } from '../../typechain-truffle/contracts/protocol/implementation/Finalisation';
import { SubmissionInstance } from '../../typechain-truffle/contracts/protocol/implementation/Submission';
import { executeTimelockedGovernanceCall, testDeployGovernanceSettings } from '../utils/contract-test-helpers';
import { RelayInstance } from '../../typechain-truffle/contracts/protocol/implementation/Relay';
import { ProtocolMessageMerkleRoot, SigningPolicy, encodeProtocolMessageMerkleRoot, encodeSigningPolicy, signingPolicyHash } from '../../scripts/libs/protocol/protocol-coder';
import { generateSignatures } from '../unit/protocol/coding/coding-helpers';

const MockContract = artifacts.require("MockContract");
const WNat = artifacts.require("WNat");
const VPContract = artifacts.require("VPContract");
const PChainStakeMirror = artifacts.require("PChainStakeMirror");
const GovernanceVotePower = artifacts.require("flattened/FlareSmartContracts.sol:GovernanceVotePower" as any);
const AddressBinder = artifacts.require("AddressBinder");
const PChainVerifier = artifacts.require("PChainStakeMirrorVerifier");
const EntityManager = artifacts.require("EntityManager");
const VoterWhitelister = artifacts.require("VoterWhitelister");
const Finalisation = artifacts.require("Finalisation");
const Submission = artifacts.require("Submission");
const Relay = artifacts.require("Relay");


type PChainStake = {
    txId: string,
    stakingType: number,
    inputAddress: string,
    nodeId: string,
    startTime: number,
    endTime: number,
    weight: number,
}

async function setMockStakingData(verifierMock: MockContractInstance, pChainVerifier: PChainStakeMirrorVerifierInstance, txId: string, stakingType: number, inputAddress: string, nodeId: string, startTime: BN, endTime: BN, weight: number, stakingProved: boolean = true): Promise<PChainStake> {
    let data = {
        txId: txId,
        stakingType: stakingType,
        inputAddress: inputAddress,
        nodeId: nodeId,
        startTime: startTime.toNumber(),
        endTime: endTime.toNumber(),
        weight: weight
    };

    const verifyPChainStakingMethod = pChainVerifier.contract.methods.verifyStake(data, []).encodeABI();
    await verifierMock.givenCalldataReturnBool(verifyPChainStakingMethod, stakingProved);
    return data;
}

function getSigningPolicyHash(signingPolicy: SigningPolicy): string {
    return signingPolicyHash(encodeSigningPolicy(signingPolicy));
}

contract(`End to end test; ${getTestFile(__filename)}`, async accounts => {

    const FTSO_PROTOCOL_ID = 100;

    let wNat: WNatInstance;
    let pChainStakeMirror: PChainStakeMirrorInstance;
    let governanceVotePower: GovernanceVotePowerInstance;
    let addressBinder: AddressBinderInstance;
    let pChainVerifier: PChainStakeMirrorVerifierInstance;
    let verifierMock: MockContractInstance;

    let governanceSettings: GovernanceSettingsInstance;
    let entityManager: EntityManagerInstance;
    let voterWhitelister: VoterWhitelisterInstance;
    let finalisation: FinalisationInstance;
    let submission: SubmissionInstance;
    let relay: RelayInstance;

    let initialSigningPolicy: SigningPolicy;
    let newSigningPolicy: SigningPolicy;

    let registeredPAddresses: string[] = [];
    let registeredCAddresses: string[] = [];
    let now: BN;
    let nodeIds: string[] = [];
    let weightsGwei: number[] = [];
    let stakeIds: string[] = [];

    const RANDOM_ROOT = web3.utils.keccak256("root");
    const RANDOM_ROOT2 = web3.utils.keccak256("root2");

    // same as in relay contract
    const REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS = 3360; // 3.5 days
    const FIRST_REWARD_EPOCH_VOTING_ROUND_ID = 1000;
    const RELAY_SELECTOR = web3.utils.sha3("relay()")!.slice(0, 10); // first 4 bytes is function selector

    const GWEI = 1e9;
    const VOTING_EPOCH_DURATION_SEC = 90;
    const REWARD_EPOCH_DURATION_IN_SEC = REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS * VOTING_EPOCH_DURATION_SEC;

    const ADDRESS_UPDATER = accounts[16];
    const CLEANER_CONTRACT = accounts[100];
    const CLEANUP_BLOCK_NUMBER_MANAGER = accounts[17];
    const PRICE_SUBMITTER = accounts[18];

    before(async () => {
        pChainStakeMirror = await PChainStakeMirror.new(
            accounts[0],
            accounts[0],
            ADDRESS_UPDATER,
            2
        );

        governanceSettings = await testDeployGovernanceSettings(accounts[0], 3600, [accounts[0]]);
        wNat = await WNat.new(accounts[0], "Wrapped NAT", "WNAT");
        await wNat.switchToProductionMode({ from: accounts[0] });
        let switchToProdModeTime = await time.latest();
        const vpContract = await VPContract.new(wNat.address, false);
        await wNat.setWriteVpContract(vpContract.address);
        await wNat.setReadVpContract(vpContract.address);
        governanceVotePower = await GovernanceVotePower.new(wNat.address, pChainStakeMirror.address);
        await wNat.setGovernanceVotePower(governanceVotePower.address);

        await time.increaseTo(switchToProdModeTime.addn(3600)); // 2 hours before new reward epoch
        await executeTimelockedGovernanceCall(wNat, (governance) =>
            wNat.setWriteVpContract(vpContract.address, { from: governance }));
        await executeTimelockedGovernanceCall(wNat, (governance) =>
            wNat.setReadVpContract(vpContract.address, { from: governance }));
        await executeTimelockedGovernanceCall(wNat, (governance) =>
            wNat.setGovernanceVotePower(governanceVotePower.address, { from: governance }));

        addressBinder = await AddressBinder.new();
        pChainVerifier = await PChainVerifier.new(ADDRESS_UPDATER, 10, 1000, 5, 5000);
        verifierMock = await MockContract.new();

        await pChainStakeMirror.updateContractAddresses(
            encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.ADDRESS_BINDER, Contracts.GOVERNANCE_VOTE_POWER, Contracts.CLEANUP_BLOCK_NUMBER_MANAGER, Contracts.P_CHAIN_STAKE_MIRROR_VERIFIER]),
            [ADDRESS_UPDATER, addressBinder.address, governanceVotePower.address, CLEANUP_BLOCK_NUMBER_MANAGER, verifierMock.address], { from: ADDRESS_UPDATER });

        await pChainStakeMirror.setCleanerContract(CLEANER_CONTRACT);

        // activate contract
        await pChainStakeMirror.activate();

        // set values
        weightsGwei = [1000, 500, 100, 50];
        nodeIds = ["0x0123456789012345678901234567890123456789", "0x0123456789012345678901234567890123456788", "0x0123456789012345678901234567890123456787", "0x0123456789012345678901234567890123456786"];
        stakeIds = [web3.utils.keccak256("stake1"), web3.utils.keccak256("stake2"), web3.utils.keccak256("stake3"), web3.utils.keccak256("stake4")];
        now = await time.latest();

        entityManager = await EntityManager.new(governanceSettings.address, accounts[0], 4);
        voterWhitelister = await VoterWhitelister.new(governanceSettings.address, accounts[0], ADDRESS_UPDATER, 100, 0, [accounts[0]]);

        initialSigningPolicy = {rewardEpochId: 0, startVotingRoundId: FIRST_REWARD_EPOCH_VOTING_ROUND_ID, threshold: 65500 / 2, seed: "0x" + (123).toString(16).padStart(64, "0"), voters: accounts.slice(0, 100), weights: Array(100).fill(655)};

        const finalisationSettings = {
            votingEpochsStartTs: now.toNumber() - FIRST_REWARD_EPOCH_VOTING_ROUND_ID * VOTING_EPOCH_DURATION_SEC,
            votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
            rewardEpochsStartTs: now.toNumber(),
            rewardEpochDurationSeconds: REWARD_EPOCH_DURATION_IN_SEC,
            newSigningPolicyInitializationStartSeconds: 3600 * 2,
            nonPunishableRandomAcquisitionMinDurationSeconds: 75 * 60,
            nonPunishableRandomAcquisitionMinDurationBlocks: 2250,
            voterRegistrationMinDurationSeconds: 30 * 60,
            voterRegistrationMinDurationBlocks: 20, // default 900,
            nonPunishableSigningPolicySignMinDurationSeconds: 20 * 60,
            nonPunishableSigningPolicySignMinDurationBlocks: 600,
            signingPolicyThresholdPPM: 500000,
            signingPolicyMinNumberOfVoters: 2
        };

        finalisation = await Finalisation.new(
            governanceSettings.address,
            accounts[0],
            ADDRESS_UPDATER,
            accounts[0],
            finalisationSettings,
            1,
            0
        );

        relay = await Relay.new(finalisation.address, 0, getSigningPolicyHash(initialSigningPolicy), FTSO_PROTOCOL_ID);

        submission = await Submission.new(governanceSettings.address, accounts[0], ADDRESS_UPDATER, false);

        await voterWhitelister.updateContractAddresses(
            encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FINALISATION, Contracts.ENTITY_MANAGER, Contracts.WNAT, Contracts.P_CHAIN_STAKE_MIRROR]),
            [ADDRESS_UPDATER, finalisation.address, entityManager.address, wNat.address, pChainStakeMirror.address], { from: ADDRESS_UPDATER });

        await finalisation.updateContractAddresses(
            encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.VOTER_WHITELISTER, Contracts.SUBMISSION, Contracts.RELAY, Contracts.PRICE_SUBMITTER]),
            [ADDRESS_UPDATER, voterWhitelister.address, submission.address, relay.address, PRICE_SUBMITTER], { from: ADDRESS_UPDATER });

        await submission.updateContractAddresses(
            encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FINALISATION, Contracts.RELAY]),
            [ADDRESS_UPDATER, finalisation.address, relay.address], { from: ADDRESS_UPDATER });
    });

    it("Should register addresses", async () => {
        for (let i = 0; i < 4; i++) {
            let prvKey = privateKeys[i].privateKey.slice(2);
            let prvkeyBuffer = Buffer.from(prvKey, 'hex');
            let [x, y] = util.privateKeyToPublicKeyPair(prvkeyBuffer);
            let pubKey = "0x" + util.encodePublicKey(x, y, false).toString('hex');
            let pAddr = "0x" + util.publicKeyToAvalancheAddress(x, y).toString('hex');
            let cAddr = toChecksumAddress("0x" + util.publicKeyToEthereumAddress(x, y).toString('hex'));
            await addressBinder.registerAddresses(pubKey, pAddr, cAddr);
            registeredPAddresses.push(pAddr);
            registeredCAddresses.push(cAddr)
        }
    });

    it("Should verify stakes", async () => {
        for (let i = 0; i < 4; i++) {
            const data = await setMockStakingData(verifierMock, pChainVerifier, stakeIds[i], 0, registeredPAddresses[i], nodeIds[i], now.subn(10), now.addn(10000), weightsGwei[i]);
            await pChainStakeMirror.mirrorStake(data, []);
        }
    });

    it("Should wrap some funds", async () => {
        for (let i = 0; i < 4; i++) {
            await wNat.deposit({ value: weightsGwei[i] * GWEI, from: registeredCAddresses[i] });
        }
    });

    it("Should register nodes", async () => {
        for (let i = 0; i < 4; i++) {
            await entityManager.registerNodeId(nodeIds[i], { from: registeredCAddresses[i] });
        }
    });

    it("Should register and confirm data provider addresses", async () => {
        for (let i = 0; i < 4; i++) {
            await entityManager.registerDataProviderAddress(accounts[10 + i], { from: registeredCAddresses[i] });
            await entityManager.confirmDataProviderAddressRegistration(registeredCAddresses[i], { from: accounts[10 + i] });
        }
    });

    it("Should register and confirm signing addresses", async () => {
        for (let i = 0; i < 4; i++) {
            await entityManager.registerSigningAddress(accounts[20 + i], { from: registeredCAddresses[i] });
            await entityManager.confirmSigningAddressRegistration(registeredCAddresses[i], { from: accounts[20 + i] });
        }
    });

    it("Should start random acquisition", async () => {
        await time.increaseTo(now.addn(REWARD_EPOCH_DURATION_IN_SEC - 3600 * 2)); // 2 hours before new reward epoch
        expectEvent(await finalisation.daemonize(), "RandomAcquisitionStarted", { rewardEpochId: toBN(1) });
    });

    it("Should get good random", async () => {
        const votingRoundId = (REWARD_EPOCH_DURATION_IN_SEC - 3600 * 2) / VOTING_EPOCH_DURATION_SEC + 1;
        const quality = true;

        const messageData: ProtocolMessageMerkleRoot = {protocolId: FTSO_PROTOCOL_ID, votingRoundId: votingRoundId, randomQualityScore: quality, merkleRoot: RANDOM_ROOT};
        const fullMessage = encodeProtocolMessageMerkleRoot(messageData).slice(2);
        const messageHash = web3.utils.keccak256("0x" + fullMessage);
        const signatures = await generateSignatures(privateKeys.map(x => x.privateKey), messageHash, 51);
        const signingPolicy = encodeSigningPolicy(initialSigningPolicy).slice(2);
        const fullData = RELAY_SELECTOR + signingPolicy + fullMessage + signatures;

        const tx = await submission.finalise(fullData);
        console.log(tx.receipt.gasUsed);
        // const tx = await web3.eth.sendTransaction({
        //     from: accounts[0],
        //     to: relay.address,
        //     data: fullData,
        // });
        // console.log(tx.gasUsed);
        expect((await finalisation.getCurrentRandomWithQuality())[1]).to.be.true;
    });

    it("Should select vote power block", async () => {
        expectEvent(await finalisation.daemonize(), "VotePowerBlockSelected", { rewardEpochId: toBN(1) });
    });

    it("Should register a few voters", async () => {
        for (let i = 0; i < 4; i++) {
            expectEvent(await voterWhitelister.requestWhitelisting(registeredCAddresses[i], { from: accounts[20 + i]}),
                "VoterWhitelisted", {voter : registeredCAddresses[i], rewardEpochId: toBN(1), signingAddress: accounts[20 + i], dataProviderAddress: accounts[10 + i]});
        }
    });

    it("Should initialise new signing policy", async () => {
        for (let i = 0; i < 20; i++) {
            await time.advanceBlock(); // create required number of blocks to proceed
        }
        await time.increaseTo(now.addn(REWARD_EPOCH_DURATION_IN_SEC - 3600 )); // at least 30 minutes from the vote power block selection
        const startVotingRoundId = FIRST_REWARD_EPOCH_VOTING_ROUND_ID + REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS;
        newSigningPolicy = {
            rewardEpochId: 1,
            startVotingRoundId: startVotingRoundId,
            threshold: Math.floor(65535 / 2),
            seed: RANDOM_ROOT,
            voters: accounts.slice(20, 24),
            weights: [39718, 19859, 3971, 1985]
        };
        expectEvent(await finalisation.daemonize(), "SigningPolicyInitialized",
            { rewardEpochId: toBN(1), startVotingRoundId: toBN(startVotingRoundId), voters: newSigningPolicy.voters,
                seed: toBN(RANDOM_ROOT), threshold: toBN(32767), weights: newSigningPolicy.weights.map(x => toBN(x)) });
        expect(await relay.toSigningPolicyHash(1)).to.be.equal(getSigningPolicyHash(newSigningPolicy));
    });

    it("Should sign new signing policy", async () => {
        const rewardEpochId = 1;
        const newSigningPolicyHash = await relay.toSigningPolicyHash(rewardEpochId);
        const hash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
            ["uint64", "bytes32"],
            [rewardEpochId, newSigningPolicyHash]));

        const signature = web3.eth.accounts.sign(hash, privateKeys[0].privateKey);
        expectEvent(await finalisation.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature, { from: accounts[0] }), "SigningPolicySigned",
            { rewardEpochId: toBN(1), signingAddress: accounts[0], voter: accounts[0], thresholdReached: true });
    });

    it("Should start new reward epoch and initiate new voting round", async () => {
        await time.increaseTo(now.addn(REWARD_EPOCH_DURATION_IN_SEC));
        expect((await finalisation.getCurrentRewardEpochId()).toNumber()).to.be.equal(1);
        const tx = await finalisation.daemonize();
        await expectEvent.inTransaction(tx.tx, submission, "NewVotingRoundInitiated");
    });

    it("Should commit", async () => {
        for (let i = 0; i < 4; i++) {
            expect(await submission.commit.call( { from: accounts[10 + i]})).to.be.true;
            await submission.commit( { from: accounts[10 + i]});
            expect(await submission.commit.call( { from: accounts[10 + i]})).to.be.false;
        }
    });

    it("Should initiate new voting round", async () => {
        await time.increaseTo(now.addn(REWARD_EPOCH_DURATION_IN_SEC + VOTING_EPOCH_DURATION_SEC));
        const tx = await finalisation.daemonize();
        await expectEvent.inTransaction(tx.tx, submission, "NewVotingRoundInitiated");
    });

    it("Should reveal", async () => {
        for (let i = 0; i < 4; i++) {
            expect(await submission.reveal.call( { from: accounts[10 + i]})).to.be.true;
        }
    });

    it("Should sign", async () => {
        for (let i = 0; i < 4; i++) {
            expect(await submission.sign.call( { from: accounts[20 + i]})).to.be.true;
        }
    });

    it("Should finalise", async () => {
        const votingRoundId = FIRST_REWARD_EPOCH_VOTING_ROUND_ID + REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS;
        const quality = true;
        const root = web3.utils.keccak256("root1");

        const messageData: ProtocolMessageMerkleRoot = {protocolId: FTSO_PROTOCOL_ID, votingRoundId: votingRoundId, randomQualityScore: quality, merkleRoot: root};
        const fullMessage = encodeProtocolMessageMerkleRoot(messageData).slice(2);
        const messageHash = web3.utils.keccak256("0x" + fullMessage);
        const signatures = await generateSignatures(privateKeys.slice(20, 24).map(x => x.privateKey), messageHash, 4);
        const signingPolicy = encodeSigningPolicy(newSigningPolicy).slice(2);
        const fullData = RELAY_SELECTOR + signingPolicy + fullMessage + signatures;

        await submission.finalise(fullData);
        expect(await relay.merkleRoots(FTSO_PROTOCOL_ID, votingRoundId)).to.be.equal(root);
        expect((await finalisation.getCurrentRandom()).eq(toBN(root))).to.be.true;
        expect((await finalisation.getCurrentRandomWithQuality())[1]).to.be.true;
    });

    it("Should commit 2", async () => {
        for (let i = 0; i < 4; i++) {
            expect(await submission.commit.call( { from: accounts[10 + i]})).to.be.true;
        }
    });

    it("Should start random acquisition for reward epoch 2", async () => {
        await time.increaseTo(now.addn(2 * REWARD_EPOCH_DURATION_IN_SEC - 3600 * 2)); // 2 hours before new reward epoch
        expectEvent(await finalisation.daemonize(), "RandomAcquisitionStarted", { rewardEpochId: toBN(2) });
    });

    it("Should get good random for reward epoch 2", async () => {
        const votingRoundId = FIRST_REWARD_EPOCH_VOTING_ROUND_ID + 2 * REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS;
        const quality = true;

        const messageData: ProtocolMessageMerkleRoot = {protocolId: FTSO_PROTOCOL_ID, votingRoundId: votingRoundId, randomQualityScore: quality, merkleRoot: RANDOM_ROOT2};
        const fullMessage = encodeProtocolMessageMerkleRoot(messageData).slice(2);
        const messageHash = web3.utils.keccak256("0x" + fullMessage);
        const signatures = await generateSignatures(privateKeys.slice(20, 24).map(x => x.privateKey), messageHash, 4);
        const signingPolicy = encodeSigningPolicy(newSigningPolicy).slice(2);
        const fullData = RELAY_SELECTOR + signingPolicy + fullMessage + signatures;

        await submission.finalise(fullData);
        expect((await finalisation.getCurrentRandomWithQuality())[1]).to.be.true;
    });

    it("Should select vote power block for reward epoch 2", async () => {
        expectEvent(await finalisation.daemonize(), "VotePowerBlockSelected", { rewardEpochId: toBN(2) });
    });

    it("Should register a few voters for reward epoch 2", async () => {
        for (let i = 0; i < 4; i++) {
            expectEvent(await voterWhitelister.requestWhitelisting(registeredCAddresses[i], { from: accounts[20 + i]}),
                "VoterWhitelisted", {voter : registeredCAddresses[i], rewardEpochId: toBN(2), signingAddress: accounts[20 + i], dataProviderAddress: accounts[10 + i]});
        }
    });

    it("Should initialise new signing policy for reward epoch 2", async () => {
        for (let i = 0; i < 20; i++) {
            await time.advanceBlock(); // create required number of blocks to proceed
        }
        await time.increaseTo(now.addn(2 * REWARD_EPOCH_DURATION_IN_SEC - 3600)); // at least 30 minutes from the vote power block selection
        const votingRoundId = FIRST_REWARD_EPOCH_VOTING_ROUND_ID + 2 * REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS;
        expectEvent(await finalisation.daemonize(), "SigningPolicyInitialized",
            { rewardEpochId: toBN(2), startVotingRoundId: toBN(votingRoundId), voters: accounts.slice(20, 24),
                seed: toBN(RANDOM_ROOT2), threshold: toBN(32767), weights: [toBN(39718), toBN(19859), toBN(3971), toBN(1985)] });
    });

    it("Should sign new signing policy for reward epoch 2", async () => {
        const rewardEpochId = 2;
        const newSigningPolicyHash = await relay.toSigningPolicyHash(rewardEpochId);
        const hash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
            ["uint64", "bytes32"],
            [rewardEpochId, newSigningPolicyHash]));

        const signature = web3.eth.accounts.sign(hash, privateKeys[21].privateKey);
        expectEvent(await finalisation.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature, { from: accounts[21] }), "SigningPolicySigned",
            { rewardEpochId: toBN(2), signingAddress: accounts[21], voter: registeredCAddresses[1], thresholdReached: false });
        const signature2 = web3.eth.accounts.sign(hash, privateKeys[20].privateKey);
        expectEvent(await finalisation.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature2, { from: accounts[20] }), "SigningPolicySigned",
            { rewardEpochId: toBN(2), signingAddress: accounts[20], voter: registeredCAddresses[0], thresholdReached: true });
        const signature3 = web3.eth.accounts.sign(hash, privateKeys[22].privateKey);
        await expectRevert(finalisation.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature3, { from: accounts[22] }), "new signing policy already signed");

    });

    it("Should start new reward epoch (2) and initiate new voting round", async () => {
        await time.increaseTo(now.addn(2 * REWARD_EPOCH_DURATION_IN_SEC));
        expect((await finalisation.getCurrentRewardEpochId()).toNumber()).to.be.equal(2);
        const tx = await finalisation.daemonize();
        await expectEvent.inTransaction(tx.tx, submission, "NewVotingRoundInitiated");
    });

    it("Should sign uptime vote for reward epoch 1", async () => {
        const rewardEpochId = 1;
        const uptimeVoteHash = web3.utils.keccak256("uptime");
        const hash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
            ["uint64", "bytes32"],
            [rewardEpochId, uptimeVoteHash]));

        const signature = web3.eth.accounts.sign(hash, privateKeys[21].privateKey);
        expectEvent(await finalisation.signUptimeVote(rewardEpochId, uptimeVoteHash, signature, { from: accounts[21] }), "UptimeVoteSigned",
            { rewardEpochId: toBN(1), signingAddress: accounts[21], voter: registeredCAddresses[1], thresholdReached: false });
        const signature2 = web3.eth.accounts.sign(hash, privateKeys[20].privateKey);
        expectEvent(await finalisation.signUptimeVote(rewardEpochId, uptimeVoteHash, signature2, { from: accounts[20] }), "UptimeVoteSigned",
            { rewardEpochId: toBN(1), signingAddress: accounts[20], voter: registeredCAddresses[0], thresholdReached: true });
        const signature3 = web3.eth.accounts.sign(hash, privateKeys[22].privateKey);
        await expectRevert(finalisation.signUptimeVote(rewardEpochId, uptimeVoteHash, signature3, { from: accounts[22] }), "uptime vote hash already signed");
        expect(await finalisation.uptimeVoteHash(rewardEpochId)).to.be.equal(uptimeVoteHash);
    });

    it("Should sign rewards for reward epoch 1", async () => {
        const rewardEpochId = 1;
        const noOfWeightBasedClaims = 5;
        const rewardsVoteHash = web3.utils.keccak256("rewards");
        const hash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
            ["uint64", "uint64", "bytes32"],
            [rewardEpochId, noOfWeightBasedClaims, rewardsVoteHash]));

        const signature = web3.eth.accounts.sign(hash, privateKeys[21].privateKey);
        expectEvent(await finalisation.signRewards(rewardEpochId, noOfWeightBasedClaims, rewardsVoteHash, signature, { from: accounts[21] }), "RewardsSigned",
            { rewardEpochId: toBN(1), signingAddress: accounts[21], voter: registeredCAddresses[1], noOfWeightBasedClaims: toBN(noOfWeightBasedClaims), thresholdReached: false });
        const signature2 = web3.eth.accounts.sign(hash, privateKeys[20].privateKey);
        expectEvent(await finalisation.signRewards(rewardEpochId, noOfWeightBasedClaims, rewardsVoteHash, signature2, { from: accounts[20] }), "RewardsSigned",
            { rewardEpochId: toBN(1), signingAddress: accounts[20], voter: registeredCAddresses[0], noOfWeightBasedClaims: toBN(noOfWeightBasedClaims), thresholdReached: true });
        const signature3 = web3.eth.accounts.sign(hash, privateKeys[22].privateKey);
        await expectRevert(finalisation.signRewards(rewardEpochId, noOfWeightBasedClaims, rewardsVoteHash, signature3, { from: accounts[22] }), "rewards hash already signed");
        expect(await finalisation.rewardsHash(rewardEpochId)).to.be.equal(rewardsVoteHash);
        expect((await finalisation.noOfWeightBasedClaims(rewardEpochId)).toNumber()).to.be.equal(noOfWeightBasedClaims);
    });
});