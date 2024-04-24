import { bn254 } from '@noble/curves/bn254'

import {
    Sign,
    generateSortitionKey,
    generateVerifiableRandomnessProof,
    randomInt,
} from '../../../utils/sortition'
import type { Proof, Signature, SortitionKey } from '../../../utils/sortition'
import { getTestFile } from '../../../utils/constants'
import { SortitionMockContract, SortitionMockInstance } from '../../../../typechain-truffle'

const SortitionContract = artifacts.require(
    'SortitionMock'
) as SortitionMockContract

contract(
    `Sortition.sol; ${getTestFile(__filename)}`,
    (accounts) => {
        let sortition: SortitionMockInstance
        before(async () => {
            const governance = accounts[0]
            if (!governance) {
                throw new Error('No governance account')
            }
            sortition = await SortitionContract.new(
                governance as Truffle.TransactionDetails
            )
        })

        it('should verify signature', async () => {
            const key: SortitionKey = generateSortitionKey()
            const msg = "0x0000000000000000000000000000000000000000000000000000000000000002";
            
            const signature: Signature = Sign(key, msg);
            
            const check = await sortition.verifySignatureTest(
                [key.pk.x.toString(), key.pk.y.toString()],
                msg,
                signature.s.toString(),
                [signature.r.x.toString(), signature.r.y.toString()]
            )

            expect(check).to.equal(true)
        })

        it('should generate a verifiable randomness', async () => {
            const key: SortitionKey = generateSortitionKey()
            const seed = randomInt(bn254.CURVE.n).toString()
            const blockNum = (await web3.eth.getBlockNumber()).toString()
            const replicate = randomInt(bn254.CURVE.n).toString()
            const proof: Proof = generateVerifiableRandomnessProof(
                key,
                seed,
                blockNum,
                replicate
            )
            const pubKey = { x: key.pk.x.toString(), y: key.pk.y.toString() }
            const sortitionCredential = {
                replicate: replicate,
                gamma: {
                    x: proof.gamma.x.toString(),
                    y: proof.gamma.y.toString(),
                },
                c: proof.c.toString(),
                s: proof.s.toString(),
            }
            const sortitionState = {
                baseSeed: seed,
                blockNumber: blockNum,
                scoreCutoff: 0,
                weight: 0,
                pubKey: pubKey,
            }

            const check = await sortition.verifySortitionProofTest(
                sortitionState,
                sortitionCredential
            )

            expect(check).to.equal(true)
        })
        it('should correctly accept or reject the randomness', async () => {
            const key: SortitionKey = generateSortitionKey()
            const scoreCutoff = 2n ** 248n
            for (;;) {
                const seed = randomInt(bn254.CURVE.n).toString()
                const replicate = randomInt(bn254.CURVE.n)
                const blockNum = (await web3.eth.getBlockNumber()).toString()
                const weight = replicate + 1n

                const proof: Proof = generateVerifiableRandomnessProof(
                    key,
                    seed,
                    blockNum,
                    replicate.toString()
                )
                const pubKey = {
                    x: key.pk.x.toString(),
                    y: key.pk.y.toString(),
                }
                const sortitionCredential = {
                    replicate: replicate.toString(),
                    gamma: {
                        x: proof.gamma.x.toString(),
                        y: proof.gamma.y.toString(),
                    },
                    c: proof.c.toString(),
                    s: proof.s.toString(),
                }
                const sortitionState = {
                    baseSeed: seed,
                    blockNumber: blockNum,
                    scoreCutoff: scoreCutoff.toString(),
                    weight: weight.toString(),
                    pubKey: pubKey,
                }

                const check = await sortition.verifySortitionCredentialTest(
                    sortitionState,
                    sortitionCredential
                )

                if (proof.gamma.x > scoreCutoff) {
                    expect(check).to.equal(false)
                } else {
                    expect(check).to.equal(true)
                    break
                }
            }
        })
    }
)
