import { expectEvent, expectRevert } from '@openzeppelin/test-helpers'
import { Contracts } from '../../../../deployment/scripts/Contracts'
import { MockContractContract, MockContractInstance } from '../../../../typechain-truffle/@gnosis.pm/mock-contract/contracts/MockContract.sol/MockContract'
import type {
    FastUpdateIncentiveManagerContract,
    FastUpdateIncentiveManagerInstance,
} from '../../../../typechain-truffle/contracts/fastUpdates/implementation/FastUpdateIncentiveManager'
import { getTestFile } from '../../../utils/constants'
import { encodeContractNames } from '../../../utils/test-helpers'
import { RangeOrSampleFPA } from "../../../utils/fixed-point-arithmetic";
import { FtsoConfigurations } from '../../../../scripts/libs/protocol/FtsoConfigurations'

const FastUpdateIncentiveManager = artifacts.require('FastUpdateIncentiveManager') as FastUpdateIncentiveManagerContract
const MockContract = artifacts.require('MockContract') as MockContractContract

const SAMPLE_SIZE = 1
const RANGE = 2**-13
const SAMPLE_INCREASE_LIMIT = 1/16
const RANGE_INCREASE_LIMIT = 16 * RANGE
const RANGE_INCREASE_PRICE = BigInt(10) ** BigInt(24);
const SAMPLE_SIZE_INCREASE_PRICE = BigInt(10) ** BigInt(24);
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
                RangeOrSampleFPA(SAMPLE_SIZE),
                RangeOrSampleFPA(RANGE),
                RangeOrSampleFPA(SAMPLE_INCREASE_LIMIT),
                RangeOrSampleFPA(RANGE_INCREASE_LIMIT),
                SAMPLE_SIZE_INCREASE_PRICE.toString(),
                RANGE_INCREASE_PRICE.toString(),
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
            expect(sampleSize).to.equal(BigInt(RangeOrSampleFPA(SAMPLE_SIZE)))
        })

        it('should get range', async () => {
            const range = await fastUpdateIncentiveManager.getRange()
            expect(range).to.equal(BigInt(RangeOrSampleFPA(RANGE)))
        })

        it('should get precision', async () => {
            const precision = await fastUpdateIncentiveManager.getPrecision()
            // precision scaled for 2^(-127)
            expect(precision).to.equal(
                (BigInt(RangeOrSampleFPA(RANGE)) << 127n) / BigInt(RangeOrSampleFPA(SAMPLE_SIZE))
            )
        })

        it('should get scale', async () => {
            const scale = await fastUpdateIncentiveManager.getScale()
            expect(scale).to.equal(
                (1n << 127n) + (BigInt(RangeOrSampleFPA(RANGE)) << 127n) / BigInt(RangeOrSampleFPA(SAMPLE_SIZE))
            )
        })

        it('should offer incentive', async () => {
            const rangeIncrease = RangeOrSampleFPA(RANGE)
            const rangeLimit = RangeOrSampleFPA(RANGE * 2)
            const offer = {
                rangeIncrease: rangeIncrease,
                rangeLimit: rangeLimit,
            }
            if (!accounts[1]) throw new Error('Account not found')
            await fastUpdateIncentiveManager.offerIncentive(offer, {
                from: accounts[1],
                value: (RANGE_INCREASE_PRICE / BigInt(1 / (RANGE))).toString(),
            })

            const newRange = (
                await fastUpdateIncentiveManager.getRange()
            )
            expect(newRange).to.equal(BigInt(RangeOrSampleFPA(RANGE * 2)))

            const newSampleSize = (
                await fastUpdateIncentiveManager.getExpectedSampleSize()
            )
            expect(newSampleSize).to.equal(BigInt(RangeOrSampleFPA(SAMPLE_SIZE)))

            const precision = await fastUpdateIncentiveManager.getPrecision()
            expect(precision).to.equal(
                (BigInt(newRange.toString()) << 127n) / BigInt(newSampleSize.toString())
            )

            const scale = await fastUpdateIncentiveManager.getScale()
            expect(scale).to.equal(
                (1n << 127n) + (BigInt(newRange.toString()) << 127n) / BigInt(newSampleSize.toString())
            )
        })

        it('should offer incentive and not increase range', async () => {
            const rangeIncrease = RangeOrSampleFPA(RANGE * 4);
            const rangeLimit = RangeOrSampleFPA(RANGE);
            const offer = {
                rangeIncrease: rangeIncrease.toString(),
                rangeLimit: rangeLimit.toString(),
            }
            const oldRange = (
                await fastUpdateIncentiveManager.getRange()
            )
            expect(oldRange).to.equal(RangeOrSampleFPA(RANGE));

            await fastUpdateIncentiveManager.offerIncentive(offer, {
                from: accounts[1],
                value: '100000',
            })

            const newRange = (
                await fastUpdateIncentiveManager.getRange()
            )
            expect(newRange).to.equal(RangeOrSampleFPA(RANGE));
        });

        it('should offer incentive and not increase range above range limit', async () => {
            const rangeIncrease = RangeOrSampleFPA(RANGE * 20);
            const rangeLimit = RangeOrSampleFPA(RANGE_INCREASE_LIMIT * 20);
            const offer = {
                rangeIncrease: rangeIncrease.toString(),
                rangeLimit: rangeLimit.toString(),
            }
            const oldRange = (
                await fastUpdateIncentiveManager.getRange()
            )
            expect(oldRange).to.equal(RangeOrSampleFPA(RANGE));

            await fastUpdateIncentiveManager.offerIncentive(offer, {
                from: accounts[1],
                value: '9000000000000000000000000000000',
            })

            const newRange = (
                await fastUpdateIncentiveManager.getRange()
            )
            expect(newRange).to.equal(RangeOrSampleFPA(RANGE_INCREASE_LIMIT));
        });

        it('should revert if the parameters would allow making the precision greater than 100%', async () => {
            await expectRevert(FastUpdateIncentiveManager.new(
                accounts[0],
                governance,
                addressUpdater,
                RangeOrSampleFPA(SAMPLE_SIZE),
                RangeOrSampleFPA(RANGE),
                RangeOrSampleFPA(SAMPLE_INCREASE_LIMIT),
                RangeOrSampleFPA(1),
                SAMPLE_SIZE_INCREASE_PRICE.toString(),
                RANGE_INCREASE_PRICE.toString(),
                DURATION
            ),
            "Parameters should not allow making the precision greater than 100%"
            );

            await expectRevert(fastUpdateIncentiveManager.setRangeIncreaseLimit(RangeOrSampleFPA(4), {
                from: governance
            }),
            "Parameters should not allow making the precision greater than 100%"
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
            await fastUpdateIncentiveManager.setIncentiveParameters(RangeOrSampleFPA(SAMPLE_SIZE), RangeOrSampleFPA(RANGE), SAMPLE_SIZE_INCREASE_PRICE.toString(), 10, {
                from: accounts[0],
            })

            const newIncentiveDuration =
                await fastUpdateIncentiveManager.getIncentiveDuration()

            expect(newIncentiveDuration.toString()).to.equal('10')
        })

        it("should revert if setting circular length to zero", async() => {
            await expectRevert(fastUpdateIncentiveManager.setIncentiveParameters(RangeOrSampleFPA(SAMPLE_SIZE), RangeOrSampleFPA(RANGE), SAMPLE_SIZE_INCREASE_PRICE.toString(), 0, { from: governance }), "CircularListManager: circular length must be greater than 0");
        });

        it("Should trigger inflation offers", async() => {
            const DAY = 60 * 60 * 24;

            const configs = [];
            for (let i = 0; i < 1000; i++) {
                configs.push([FtsoConfigurations.encodeFeedId({ category: 1, name: `Test${i}/USD` }), 5000, 10000]);
            }

            const getFeedConfigurations = web3.utils.sha3("getFeedConfigurations()")!.slice(0, 10);
            const getFeedConfigurationsReturn = web3.eth.abi.encodeParameters(
                ["tuple(bytes21,uint32,uint24)[]"], //  IFastUpdatesConfiguration.FeedConfiguration (bytes21 feedId, uint32 rewardBandValue, uint24 inflationShare)
                [configs]
            );
            await fastUpdatesConfiguration.givenMethodReturn(getFeedConfigurations, getFeedConfigurationsReturn);

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
            console.log("Gas used:", trigger.receipt?.gasUsed?.toString());

            let tokenPoolSupplyData = await fastUpdateIncentiveManager.getTokenPoolSupplyData();
            expect(tokenPoolSupplyData[0]).to.equal("0");
            expect(tokenPoolSupplyData[1]).to.equal("5000");
            expect(tokenPoolSupplyData[2]).to.equal("5000");
        })

        it("Should set price increase range and sample increase limit", async() => {
            expect(await fastUpdateIncentiveManager.sampleIncreaseLimit()).to.equal(RangeOrSampleFPA(SAMPLE_INCREASE_LIMIT));
            expect(await fastUpdateIncentiveManager.rangeIncreasePrice()).to.equal(RANGE_INCREASE_PRICE);
            expect(await fastUpdateIncentiveManager.rangeIncreaseLimit()).to.equal(RangeOrSampleFPA(RANGE_INCREASE_LIMIT));

            // change values
            await fastUpdateIncentiveManager.setSampleIncreaseLimit((BigInt(RangeOrSampleFPA(SAMPLE_INCREASE_LIMIT * 2))).toString(), { from: governance });
            await fastUpdateIncentiveManager.setRangeIncreaseLimit((BigInt(RangeOrSampleFPA(RANGE_INCREASE_LIMIT * 2))).toString(), { from: governance });
            await fastUpdateIncentiveManager.setRangeIncreasePrice((RANGE_INCREASE_PRICE * BigInt(2)).toString(), { from: governance });

            expect(await fastUpdateIncentiveManager.sampleIncreaseLimit()).to.equal(BigInt(RangeOrSampleFPA(SAMPLE_INCREASE_LIMIT * 2)));
            expect(await fastUpdateIncentiveManager.rangeIncreaseLimit()).to.equal(BigInt(RangeOrSampleFPA(RANGE_INCREASE_LIMIT * 2)));
            expect(await fastUpdateIncentiveManager.rangeIncreasePrice()).to.equal(RANGE_INCREASE_PRICE * BigInt(2));
        });

        it("Should set sample size and range", async() => {
            expect(await fastUpdateIncentiveManager.getExpectedSampleSize()).to.equal(RangeOrSampleFPA(SAMPLE_SIZE));
            expect(await fastUpdateIncentiveManager.getRange()).to.equal(RangeOrSampleFPA(RANGE));

            // change values
            await fastUpdateIncentiveManager.setIncentiveParameters(RangeOrSampleFPA(SAMPLE_SIZE * 2), RangeOrSampleFPA(RANGE * 2), (SAMPLE_SIZE_INCREASE_PRICE * BigInt(2)).toString(), DURATION, { from: governance });

            expect(await fastUpdateIncentiveManager.getExpectedSampleSize()).to.equal(RangeOrSampleFPA(SAMPLE_SIZE * 2));
            expect(await fastUpdateIncentiveManager.getRange()).to.equal(RangeOrSampleFPA(RANGE * 2));
            expect(await fastUpdateIncentiveManager.getCurrentSampleSizeIncreasePrice()).to.equal(SAMPLE_SIZE_INCREASE_PRICE * BigInt(2));
        })

        it("should revert when setting sample increase limit or range increase price if value too big", async() => {
            let value = (2 ** 255).toString(16);

            await expectRevert(fastUpdateIncentiveManager.setSampleIncreaseLimit(value, { from: governance }), "Sample increase limit too large");

            await expectRevert(fastUpdateIncentiveManager.setRangeIncreasePrice(value, { from: governance }), "Range increase price too large");
        });

        it("should revert when setting sample size, range etc. if value too big/small", async() => {
            let value = (2 ** 255).toString(16);

            await expectRevert(fastUpdateIncentiveManager.setIncentiveParameters(value, RangeOrSampleFPA(RANGE), SAMPLE_SIZE_INCREASE_PRICE.toString(), DURATION, { from: governance }), "Sample size too large");

            await expectRevert(fastUpdateIncentiveManager.setIncentiveParameters(RangeOrSampleFPA(RANGE * 2), RangeOrSampleFPA(RANGE), SAMPLE_SIZE_INCREASE_PRICE.toString(), DURATION, { from: governance }), "Parameters should not allow making the precision greater than 100%");

            await expectRevert(fastUpdateIncentiveManager.setIncentiveParameters(RangeOrSampleFPA(RANGE_INCREASE_LIMIT * 2), RangeOrSampleFPA(RANGE_INCREASE_LIMIT * 3), SAMPLE_SIZE_INCREASE_PRICE.toString(), DURATION, { from: governance }), "Range cannot be greater than the range increase limit");

            await expectRevert(fastUpdateIncentiveManager.setIncentiveParameters(RangeOrSampleFPA(1), RangeOrSampleFPA(2**(-30)), SAMPLE_SIZE_INCREASE_PRICE.toString(), DURATION, { from: governance }), "Precision value of updates needs to be at least 2^(-25)");
        });

        it("should revert if not setting base sample size, base range etc. from governance", async() => {
            await expectRevert(fastUpdateIncentiveManager.setIncentiveParameters(RangeOrSampleFPA(SAMPLE_SIZE), RangeOrSampleFPA(RANGE), SAMPLE_SIZE_INCREASE_PRICE.toString(), DURATION, { from: accounts[1] }), "only governance");

            await expectRevert(fastUpdateIncentiveManager.setSampleIncreaseLimit(RangeOrSampleFPA(SAMPLE_INCREASE_LIMIT), { from: accounts[1] }), "only governance");

            await expectRevert(fastUpdateIncentiveManager.setRangeIncreasePrice(RANGE_INCREASE_PRICE.toString(), { from: accounts[1] }), "only governance");

            await expectRevert(fastUpdateIncentiveManager.setRangeIncreaseLimit(RangeOrSampleFPA(RANGE_INCREASE_LIMIT), { from:accounts[1] }), "only governance");
        });

        it("should revert when setting base range, range increase price or range increase limit too low", async() => {
            await expectRevert(fastUpdateIncentiveManager.setIncentiveParameters(RangeOrSampleFPA(1), 1e5, SAMPLE_SIZE_INCREASE_PRICE.toString(), DURATION, { from: governance }), "Range increase price too low, range increase of 1e-6 of base range should cost at least 1 wei");

            await expectRevert(fastUpdateIncentiveManager.setRangeIncreasePrice(5, { from: governance }), "Range increase price too low, range increase of 1e-6 of base range should cost at least 1 wei");

            await expectRevert(fastUpdateIncentiveManager.setRangeIncreaseLimit(5, { from: governance }), "Range cannot be greater than the range increase limit");
        });
    }
)
