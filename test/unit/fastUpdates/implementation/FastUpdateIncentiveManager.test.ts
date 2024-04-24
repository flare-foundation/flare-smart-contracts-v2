import { expectEvent, expectRevert } from '@openzeppelin/test-helpers'
import { Contracts } from '../../../../deployment/scripts/Contracts'
import { MockContractContract, MockContractInstance } from '../../../../typechain-truffle/@gnosis.pm/mock-contract/contracts/MockContract.sol/MockContract'
import type {
    FastUpdateIncentiveManagerContract,
    FastUpdateIncentiveManagerInstance,
} from '../../../../typechain-truffle/contracts/fastUpdates/implementation/FastUpdateIncentiveManager'
import { getTestFile } from '../../../utils/constants'
import { encodeContractNames } from '../../../utils/test-helpers'

const FastUpdateIncentiveManager = artifacts.require('FastUpdateIncentiveManager') as FastUpdateIncentiveManagerContract
const MockContract = artifacts.require('MockContract') as MockContractContract

const SAMPLE_SIZE = 5 * 2 ** 8 // 2^8 since scaled for 2^(-8) for fixed precision arithmetic
const RANGE = 2 * 2 ** 8
const SAMPLE_INCREASE_LIMIT = 5 * 2 ** 8
const RANGE_INCREASE_PRICE = 5
const DURATION = 8

contract(
    `FastUpdateIncentiveManager.sol; ${getTestFile(__filename)}`,
    accounts => {
        let fastUpdateIncentiveManager: FastUpdateIncentiveManagerInstance
        let rewardManagerMock: MockContractInstance
        let fastUpdatesConfiguration: MockContractInstance
        const governance = accounts[0]
        const addressUpdater = accounts[1]
        const inflation = accounts[2]
        const fastUpdater = accounts[3]
        const flareSystemManager = accounts[100]

        beforeEach(async () => {
            if (!governance) throw new Error('Governance account not found')

            rewardManagerMock = await MockContract.new()
            fastUpdatesConfiguration = await MockContract.new()

            fastUpdateIncentiveManager = await FastUpdateIncentiveManager.new(
                accounts[0],
                governance,
                addressUpdater,
                SAMPLE_SIZE,
                RANGE,
                SAMPLE_INCREASE_LIMIT,
                RANGE_INCREASE_PRICE,
                DURATION
            )

            await fastUpdateIncentiveManager.updateContractAddresses(
                encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.INFLATION, Contracts.REWARD_MANAGER, Contracts.FAST_UPDATER, Contracts.FAST_UPDATES_CONFIGURATION]),
                [addressUpdater, flareSystemManager, inflation, rewardManagerMock.address, fastUpdater, fastUpdatesConfiguration.address],
                { from: addressUpdater }
            );
        })

        it('should get expected sample size', async () => {
            const sampleSize =
                await fastUpdateIncentiveManager.getExpectedSampleSize()
            expect(sampleSize).to.equal(SAMPLE_SIZE)
        })

        it('should get range', async () => {
            const range = await fastUpdateIncentiveManager.getRange()
            expect(range).to.equal(RANGE)
        })

        it('should get precision', async () => {
            const precision = await fastUpdateIncentiveManager.getPrecision()
            // precision scaled for 2^(-127)
            expect(precision).to.equal(
                (BigInt(RANGE) << 127n) / BigInt(SAMPLE_SIZE)
            )
        })

        it('should get scale', async () => {
            const scale = await fastUpdateIncentiveManager.getScale()
            expect(scale).to.equal(
                (1n << 127n) + (BigInt(RANGE) << 127n) / BigInt(SAMPLE_SIZE)
            )
        })

        it('should offer incentive', async () => {
            const rangeIncrease = RANGE
            const rangeLimit = 4 * 2 ** 8
            const offer = {
                rangeIncrease: rangeIncrease.toString(),
                rangeLimit: rangeLimit.toString(),
            }
            if (!accounts[1]) throw new Error('Account not found')
            await fastUpdateIncentiveManager.offerIncentive(offer, {
                from: accounts[1],
                value: '100000',
            })

            const newRange = (
                await fastUpdateIncentiveManager.getRange()
            ).toNumber()
            expect(newRange).to.equal(RANGE * 2)

            const newSampleSize = (
                await fastUpdateIncentiveManager.getExpectedSampleSize()
            ).toNumber()
            expect(newSampleSize).to.equal(SAMPLE_SIZE * 2 - 1)

            const precision = await fastUpdateIncentiveManager.getPrecision()
            expect(precision).to.equal(
                (BigInt(newRange) << 127n) / BigInt(newSampleSize)
            )

            const scale = await fastUpdateIncentiveManager.getScale()
            expect(scale).to.equal(
                (1n << 127n) + (BigInt(newRange) << 127n) / BigInt(newSampleSize)
            )
        })

        it('should offer incentive and not increase range', async () => {
            const rangeIncrease = 4;
            const rangeLimit = 4 * 2 ** 7;
            const offer = {
                rangeIncrease: rangeIncrease.toString(),
                rangeLimit: rangeLimit.toString(),
            }
            const oldRange = (
                await fastUpdateIncentiveManager.getRange()
            ).toNumber()
            expect(oldRange).to.equal(512);

            await fastUpdateIncentiveManager.offerIncentive(offer, {
                from: accounts[1],
                value: '100000',
            })

            const newRange = (
                await fastUpdateIncentiveManager.getRange()
            ).toNumber()
            expect(newRange).to.equal(512);
        });

        it('should offer incentive and not increase range (2)', async () => {
            const rangeIncrease = 4;
            const rangeLimit = 2;
            const offer = {
                rangeIncrease: rangeIncrease.toString(),
                rangeLimit: rangeLimit.toString(),
            }
            const oldRange = (
                await fastUpdateIncentiveManager.getRange()
            ).toNumber()
            expect(oldRange).to.equal(512);

            await fastUpdateIncentiveManager.offerIncentive(offer, {
                from: accounts[1],
                value: '100000',
            })

            const newRange = (
                await fastUpdateIncentiveManager.getRange()
            ).toNumber()
            expect(newRange).to.equal(512);
        });

        it('should revert if offer would make the precision greater than 100%', async () => {
            const rangeIncrease = SAMPLE_SIZE + 20;
            const rangeLimit = SAMPLE_SIZE + 10;
            const offer = {
                rangeIncrease: rangeIncrease.toString(),
                rangeLimit: rangeLimit.toString(),
            }

            await expectRevert(fastUpdateIncentiveManager.offerIncentive(offer, {
                from: accounts[1],
                value: '100000',
            }),
            "Offer would make the precision greater than 100%"
            );
        })

        it('should revert if not calling advance from fast updater', async () => {
            await expectRevert(fastUpdateIncentiveManager.advance(), "only fast updater");
        });

        it('should change incentive duration', async () => {
            const incentiveDuration =
                await fastUpdateIncentiveManager.getIncentiveDuration()
            expect(incentiveDuration.toString()).to.equal(DURATION.toString())

            if (!accounts[0]) throw new Error('Account not found')
            await fastUpdateIncentiveManager.setIncentiveParameters(SAMPLE_SIZE, RANGE, 10, {
                from: accounts[0],
            })

            const newIncentiveDuration =
                await fastUpdateIncentiveManager.getIncentiveDuration()

            expect(newIncentiveDuration.toString()).to.equal('10')
        })

        it("should revert if setting circular length to zero", async() => {
            await expectRevert(fastUpdateIncentiveManager.setIncentiveParameters(SAMPLE_SIZE, RANGE, 0, { from: governance }), "CircularListManager: circular length must be greater than 0");
        });

        it("Should trigger inflation offers", async() => {
            const DAY = 60 * 60 * 24;

            const getFeedConfigurationsBytes = web3.utils.sha3("getFeedConfigurationsBytes()")!.slice(0, 10);
            const getFeedConfigurationsBytesReturn = web3.eth.abi.encodeParameters(['string', 'string', 'string'], ['', '', '']);
            await fastUpdatesConfiguration.givenMethodReturn(getFeedConfigurationsBytes, getFeedConfigurationsBytesReturn);

            expect(await fastUpdateIncentiveManager.getContractName()).to.equal("FastUpdateIncentiveManager");

            // set daily authorized inflation
            await fastUpdateIncentiveManager.setDailyAuthorizedInflation(5000, { from: inflation});

            let block = await web3.eth.getBlockNumber();
            let time = (await web3.eth.getBlock(block)).timestamp as string;
            // set daily authorized inflation
            await fastUpdateIncentiveManager.receiveInflation( { from: inflation, value: "5000" });

            // trigger switchover, which will trigger inflation offers
            // interval start = time + 3*DAY - 2*DAY = time + DAY
            // interval end = max(time + DAY, time + 3*DAY - DAY) = time + 2*DAY
            // totalRewardAmount = 5000 * DAY / (2*DAY - DAY) = 5000
            expect(await web3.eth.getBalance(fastUpdateIncentiveManager.address)).to.equal("5000");

            let trigger = await fastUpdateIncentiveManager.triggerRewardEpochSwitchover(2, 3 * DAY + time, DAY, { from: flareSystemManager });
            expectEvent(trigger, "InflationRewardsOffered", { rewardEpochId: "3", amount: "5000"})
            expect(await web3.eth.getBalance(fastUpdateIncentiveManager.address)).to.equal("0");
            expect(await web3.eth.getBalance(rewardManagerMock.address)).to.equal("5000");

            let tokenPoolSupplyData = await fastUpdateIncentiveManager.getTokenPoolSupplyData();
            expect(tokenPoolSupplyData[0]).to.equal("0");
            expect(tokenPoolSupplyData[1]).to.equal("5000");
            expect(tokenPoolSupplyData[2]).to.equal("5000");
        })

        it("Should set price increase range and sample increase limit", async() => {
            expect(await fastUpdateIncentiveManager.sampleIncreaseLimit()).to.equal(SAMPLE_INCREASE_LIMIT);
            expect(await fastUpdateIncentiveManager.rangeIncreasePrice()).to.equal(RANGE_INCREASE_PRICE);

            // change values
            await fastUpdateIncentiveManager.setSampleIncreaseLimit(SAMPLE_INCREASE_LIMIT * 2, { from: governance });
            await fastUpdateIncentiveManager.setRangeIncreasePrice(RANGE_INCREASE_PRICE * 2, { from: governance });

            expect(await fastUpdateIncentiveManager.sampleIncreaseLimit()).to.equal(SAMPLE_INCREASE_LIMIT * 2);
            expect(await fastUpdateIncentiveManager.rangeIncreasePrice()).to.equal(RANGE_INCREASE_PRICE * 2);
        });

        it("Should set sample size and range", async() => {
            expect(await fastUpdateIncentiveManager.getExpectedSampleSize()).to.equal(SAMPLE_SIZE);
            expect(await fastUpdateIncentiveManager.getRange()).to.equal(RANGE);

            // change values
            await fastUpdateIncentiveManager.setIncentiveParameters(SAMPLE_SIZE * 2, RANGE * 2, DURATION, { from: governance });

            expect(await fastUpdateIncentiveManager.getExpectedSampleSize()).to.equal(SAMPLE_SIZE * 2);
            expect(await fastUpdateIncentiveManager.getRange()).to.equal(RANGE * 2);
        })

        it("should revert when setting sample increase limit or range increase price if value too big", async() => {
            let value = (2 ** 255).toString(16);

            await expectRevert(fastUpdateIncentiveManager.setSampleIncreaseLimit(value, { from: governance }), "Sample increase limit too large");

            await expectRevert(fastUpdateIncentiveManager.setRangeIncreasePrice(value, { from: governance }), "Range increase price too large");
        });

        it("should revert when setting sample size or range if value too big", async() => {
            let value = (2 ** 255).toString(16);

            await expectRevert(fastUpdateIncentiveManager.setIncentiveParameters(value, RANGE, DURATION, { from: governance }), "Sample size too large");

            await expectRevert(fastUpdateIncentiveManager.setIncentiveParameters(SAMPLE_SIZE, value, DURATION, { from: governance }), "Range too large");

            await expectRevert(fastUpdateIncentiveManager.setIncentiveParameters(100, 200, DURATION, { from: governance }), "Range must be less than sample size");
        });

        it("should revert if not setting base sample size, base range etc. from governance", async() => {
            await expectRevert(fastUpdateIncentiveManager.setIncentiveParameters(SAMPLE_SIZE, RANGE, DURATION, { from: accounts[1] }), "only governance");

            await expectRevert(fastUpdateIncentiveManager.setSampleIncreaseLimit(SAMPLE_INCREASE_LIMIT, { from: accounts[1] }), "only governance");

            await expectRevert(fastUpdateIncentiveManager.setRangeIncreasePrice(RANGE_INCREASE_PRICE, { from: accounts[1] }), "only governance");
        });
    }
)
