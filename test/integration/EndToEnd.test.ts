
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

const MockContract = artifacts.require("MockContract");
const WNat = artifacts.require("WNat");
const VPContract = artifacts.require("VPContract");
const PChainStakeMirror = artifacts.require("PChainStakeMirror");
const GovernanceVotePower = artifacts.require("GovernanceVotePower");
const AddressBinder = artifacts.require("AddressBinder");
const PChainVerifier = artifacts.require("PChainStakeMirrorVerifier");
const EntityManager = artifacts.require("EntityManager");
const VoterWhitelister = artifacts.require("VoterWhitelister");
const Finalisation = artifacts.require("Finalisation");
const Submission = artifacts.require("Submission");


type PChainStake = {
    txId: string,
    stakingType: number,
    inputAddress: string,
    nodeId: string,
    startTime: number,
    endTime: number,
    weight: number,
}

type SigningPolicy = {
    rId: number                 // Reward epoch id.
    startVotingRoundId: number, // First voting round id of validity. Usually it is the first voting round of reward epoch rID.
                                // It can be later, if the confirmation of the signing policy on Flare blockchain gets delayed.
    threshold: number,          // Confirmation threshold in terms of PPM (parts per million). Usually more than 500,000.
    seed: string,               // Random seed.
    voters: string[],           // The list of eligible voters in the canonical order.
    weights: number[]           // The corresponding list of normalised signing weights of eligible voters.
                                // Normalisation is done by compressing the weights from 32-byte values to 2 bytes,
                                // while approximately keeping the weight relations.
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

function encodeSigningPolicy(signingPolicy: SigningPolicy): string {
    return web3.utils.keccak256(web3.eth.abi.encodeParameter("(uint64,uint64,uint64,uint256,address[],uint16[])",
        [signingPolicy.rId, signingPolicy.startVotingRoundId, signingPolicy.threshold, signingPolicy.seed, signingPolicy.voters, signingPolicy.weights]));
}

contract(`End to end test; ${getTestFile(__filename)}`, async accounts => {

    const NEW_SIGNING_POLICY_PROTOCOL_ID = 0;
    const UPTIME_VOTE_PROTOCOL_ID = 1;
    const REWARDS_PROTOCOL_ID = 2;
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

    const GWEI = 1e9;
    const VOTING_EPOCH_DURATION_SEC = 90;

    const ADDRESS_UPDATER = accounts[16];
    const CLEANER_CONTRACT = accounts[100];
    const CLEANUP_BLOCK_NUMBER_MANAGER = accounts[17];

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

        initialSigningPolicy = {rId: 0, startVotingRoundId: 0, threshold: Math.ceil(65535 / 2), seed: "123", voters: [accounts[0]], weights: [65535]};

        const finalisationSettings = {
            votingEpochsStartTs: now.toNumber(),
            votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
            rewardEpochsStartTs: now.toNumber(),
            rewardEpochDurationSeconds: 3600 * 5,
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
            0,
            encodeSigningPolicy(initialSigningPolicy)
        );

        submission = await Submission.new(governanceSettings.address, accounts[0], ADDRESS_UPDATER, false);

        await voterWhitelister.updateContractAddresses(
            encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FINALISATION, Contracts.ENTITY_MANAGER, Contracts.WNAT, Contracts.P_CHAIN_STAKE_MIRROR]),
            [ADDRESS_UPDATER, finalisation.address, entityManager.address, wNat.address, pChainStakeMirror.address], { from: ADDRESS_UPDATER });

        await finalisation.updateContractAddresses(
            encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.VOTER_WHITELISTER, Contracts.SUBMISSION]),
            [ADDRESS_UPDATER, voterWhitelister.address, submission.address], { from: ADDRESS_UPDATER });

        await submission.updateContractAddresses(
            encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FINALISATION]),
            [ADDRESS_UPDATER, finalisation.address], { from: ADDRESS_UPDATER });
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
        await time.increaseTo(now.addn(3600 * 3)); // 2 hours before new reward epoch
        expectEvent(await finalisation.daemonize(), "RandomAcquisitionStarted", { rId: toBN(1) });
    });

    it("Should get good random", async () => {
        const votingRoundId = 3600 * 3 / VOTING_EPOCH_DURATION_SEC + 1;
        const quality = true;

        const hash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
            ["uint64", "uint64", "bool", "bytes32"],
            [FTSO_PROTOCOL_ID, votingRoundId, quality, RANDOM_ROOT]));

        const signature = web3.eth.accounts.sign(hash, privateKeys[0].privateKey);
        const signatureWithIndex = {
            index: 0,
            v: signature.v,
            r: signature.r,
            s: signature.s
        };

        await finalisation.finalise(initialSigningPolicy, FTSO_PROTOCOL_ID, votingRoundId, quality, RANDOM_ROOT, [signatureWithIndex]);
        expect((await finalisation.getCurrentRandomWithQuality())[1]).to.be.true;
    });

    it("Should select vote power block", async () => {
        expectEvent(await finalisation.daemonize(), "VotePowerBlockSelected", { rId: toBN(1) });
    });

    it("Should register a few voters", async () => {
        for (let i = 0; i < 4; i++) {
            expectEvent(await voterWhitelister.requestWhitelisting(registeredCAddresses[i], { from: accounts[20 + i]}),
                "VoterWhitelisted", {voter : registeredCAddresses[i], rewardEpoch: toBN(1), signingAddress: accounts[20 + i], dataProviderAddress: accounts[10 + i]});
        }
    });

    it("Should initialise new signing policy", async () => {
        for (let i = 0; i < 20; i++) {
            await time.advanceBlock(); // create required number of blocks to proceed
        }
        await time.increaseTo(now.addn(3600 * 4)); // at least 30 minutes from the vote power block selection
        const startVotingRoundId = 3600 * 5 / VOTING_EPOCH_DURATION_SEC;
        newSigningPolicy = {
            rId: 1,
            startVotingRoundId: startVotingRoundId,
            threshold: Math.floor(65535 / 2),
            seed: RANDOM_ROOT,
            voters: accounts.slice(20, 24),
            weights: [39718, 19859, 3971, 1985]
        };
        expectEvent(await finalisation.daemonize(), "SigningPolicyInitialized",
            { rId: toBN(1), startVotingRoundId: toBN(startVotingRoundId), voters: newSigningPolicy.voters,
                seed: toBN(RANDOM_ROOT), threshold: toBN(32767), weights: newSigningPolicy.weights.map(x => toBN(x)) });
        expect(await finalisation.getConfirmedMerkleRoot(NEW_SIGNING_POLICY_PROTOCOL_ID, 1)).to.be.equal(encodeSigningPolicy(newSigningPolicy));
    });

    it("Should sign new signing policy", async () => {
        const rewardEpochId = 1;
        const newSigningPolicyHash = await finalisation.getConfirmedMerkleRoot(NEW_SIGNING_POLICY_PROTOCOL_ID, rewardEpochId);
        const hash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
            ["uint64", "bytes32"],
            [rewardEpochId, newSigningPolicyHash]));

        const signature = web3.eth.accounts.sign(hash, privateKeys[0].privateKey);
        expectEvent(await finalisation.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature, { from: accounts[0] }), "SigningPolicySigned",
            { rId: toBN(1), signingAddress: accounts[0], voter: accounts[0], thresholdReached: true });
    });

    it("Should start new reward epoch and initiate new voting round", async () => {
        await time.increaseTo(now.addn(3600 * 5));
        expect((await finalisation.getCurrentRewardEpoch()).toNumber()).to.be.equal(1);
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
        await time.increaseTo(now.addn(3600 * 5 + VOTING_EPOCH_DURATION_SEC));
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
        const votingRoundId = 3600 * 5 / VOTING_EPOCH_DURATION_SEC + 1;
        const quality = true;
        const root = web3.utils.keccak256("root1");
        const hash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
            ["uint64", "uint64", "bool", "bytes32"],
            [FTSO_PROTOCOL_ID, votingRoundId, quality, root]));

        const signaturesWithIndex = [];
        for (let i = 0; i < 4; i++) {
            const signature = web3.eth.accounts.sign(hash, privateKeys[20 + i].privateKey);
            const signatureWithIndex = {
                index: i,
                v: signature.v,
                r: signature.r,
                s: signature.s
            };
            signaturesWithIndex.push(signatureWithIndex);
        }

        await submission.finalise(newSigningPolicy, FTSO_PROTOCOL_ID, votingRoundId, quality, root, signaturesWithIndex);
        expect(await finalisation.getConfirmedMerkleRoot(FTSO_PROTOCOL_ID, votingRoundId)).to.be.equal(root);
        expect((await finalisation.getCurrentRandom()).eq(toBN(root))).to.be.true;
        expect((await finalisation.getCurrentRandomWithQuality())[1]).to.be.true;
    });

    it("Should commit 2", async () => {
        for (let i = 0; i < 4; i++) {
            expect(await submission.commit.call( { from: accounts[10 + i]})).to.be.true;
        }
    });

    it("Should start random acquisition for reward epoch 2", async () => {
        await time.increaseTo(now.addn(3600 * 8)); // 2 hours before new reward epoch
        expectEvent(await finalisation.daemonize(), "RandomAcquisitionStarted", { rId: toBN(2) });
    });

    it("Should get good random for reward epoch 2", async () => {
        const votingRoundId = 3600 * 8 / VOTING_EPOCH_DURATION_SEC + 1;
        const quality = true;

        const hash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
            ["uint64", "uint64", "bool", "bytes32"],
            [FTSO_PROTOCOL_ID, votingRoundId, quality, RANDOM_ROOT2]));

        const signaturesWithIndex = [];
        for (let i = 0; i < 4; i++) {
            const signature = web3.eth.accounts.sign(hash, privateKeys[20 + i].privateKey);
            const signatureWithIndex = {
                index: i,
                v: signature.v,
                r: signature.r,
                s: signature.s
            };
            signaturesWithIndex.push(signatureWithIndex);
        }

        await submission.finalise(newSigningPolicy, FTSO_PROTOCOL_ID, votingRoundId, quality, RANDOM_ROOT2, signaturesWithIndex);
        expect((await finalisation.getCurrentRandomWithQuality())[1]).to.be.true;
    });

    it("Should select vote power block for reward epoch 2", async () => {
        expectEvent(await finalisation.daemonize(), "VotePowerBlockSelected", { rId: toBN(2) });
    });

    it("Should register a few voters for reward epoch 2", async () => {
        for (let i = 0; i < 4; i++) {
            expectEvent(await voterWhitelister.requestWhitelisting(registeredCAddresses[i], { from: accounts[20 + i]}),
                "VoterWhitelisted", {voter : registeredCAddresses[i], rewardEpoch: toBN(2), signingAddress: accounts[20 + i], dataProviderAddress: accounts[10 + i]});
        }
    });

    it("Should initialise new signing policy for reward epoch 2", async () => {
        for (let i = 0; i < 20; i++) {
            await time.advanceBlock(); // create required number of blocks to proceed
        }
        await time.increaseTo(now.addn(3600 * 9)); // at least 30 minutes from the vote power block selection
        const votingRoundId = 3600 * 10 / VOTING_EPOCH_DURATION_SEC;
        expectEvent(await finalisation.daemonize(), "SigningPolicyInitialized",
            { rId: toBN(2), startVotingRoundId: toBN(votingRoundId), voters: accounts.slice(20, 24),
                seed: toBN(RANDOM_ROOT2), threshold: toBN(32767), weights: [toBN(39718), toBN(19859), toBN(3971), toBN(1985)] });
    });

    it("Should sign new signing policy for reward epoch 2", async () => {
        const rewardEpochId = 2;
        const newSigningPolicyHash = await finalisation.getConfirmedMerkleRoot(NEW_SIGNING_POLICY_PROTOCOL_ID, rewardEpochId);
        const hash = web3.utils.keccak256(web3.eth.abi.encodeParameters(
            ["uint64", "bytes32"],
            [rewardEpochId, newSigningPolicyHash]));

        const signature = web3.eth.accounts.sign(hash, privateKeys[21].privateKey);
        expectEvent(await finalisation.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature, { from: accounts[21] }), "SigningPolicySigned",
            { rId: toBN(2), signingAddress: accounts[21], voter: registeredCAddresses[1], thresholdReached: false });
        const signature2 = web3.eth.accounts.sign(hash, privateKeys[20].privateKey);
        expectEvent(await finalisation.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature2, { from: accounts[20] }), "SigningPolicySigned",
            { rId: toBN(2), signingAddress: accounts[20], voter: registeredCAddresses[0], thresholdReached: true });
        const signature3 = web3.eth.accounts.sign(hash, privateKeys[22].privateKey);
        await expectRevert(finalisation.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature3, { from: accounts[22] }), "new signing policy already signed");

    });

    it("Should start new reward epoch (2) and initiate new voting round", async () => {
        await time.increaseTo(now.addn(3600 * 10));
        expect((await finalisation.getCurrentRewardEpoch()).toNumber()).to.be.equal(2);
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
            { rId: toBN(1), signingAddress: accounts[21], voter: registeredCAddresses[1], thresholdReached: false });
        const signature2 = web3.eth.accounts.sign(hash, privateKeys[20].privateKey);
        expectEvent(await finalisation.signUptimeVote(rewardEpochId, uptimeVoteHash, signature2, { from: accounts[20] }), "UptimeVoteSigned",
            { rId: toBN(1), signingAddress: accounts[20], voter: registeredCAddresses[0], thresholdReached: true });
        const signature3 = web3.eth.accounts.sign(hash, privateKeys[22].privateKey);
        await expectRevert(finalisation.signUptimeVote(rewardEpochId, uptimeVoteHash, signature3, { from: accounts[22] }), "uptime vote hash already signed");
        expect(await finalisation.getConfirmedMerkleRoot(UPTIME_VOTE_PROTOCOL_ID, rewardEpochId)).to.be.equal(uptimeVoteHash);
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
            { rId: toBN(1), signingAddress: accounts[21], voter: registeredCAddresses[1], noOfWeightBasedClaims: toBN(noOfWeightBasedClaims), thresholdReached: false });
        const signature2 = web3.eth.accounts.sign(hash, privateKeys[20].privateKey);
        expectEvent(await finalisation.signRewards(rewardEpochId, noOfWeightBasedClaims, rewardsVoteHash, signature2, { from: accounts[20] }), "RewardsSigned",
            { rId: toBN(1), signingAddress: accounts[20], voter: registeredCAddresses[0], noOfWeightBasedClaims: toBN(noOfWeightBasedClaims), thresholdReached: true });
        const signature3 = web3.eth.accounts.sign(hash, privateKeys[22].privateKey);
        await expectRevert(finalisation.signRewards(rewardEpochId, noOfWeightBasedClaims, rewardsVoteHash, signature3, { from: accounts[22] }), "rewards hash already signed");
        expect(await finalisation.getConfirmedMerkleRoot(REWARDS_PROTOCOL_ID, rewardEpochId)).to.be.equal(rewardsVoteHash);
        expect((await finalisation.noOfWeightBasedClaims(rewardEpochId)).toNumber()).to.be.equal(noOfWeightBasedClaims);
    });
});
