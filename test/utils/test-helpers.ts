import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
// This sometimes break tests
// @ts-ignore
import { time } from '@openzeppelin/test-helpers';
import BN from "bn.js";
import { ContractTransaction, Signer } from "ethers";
import { ethers } from "hardhat";

/**
 * Helper function for instantiating and deploying a contract by using factory.
 * @param name Name of the contract
 * @param signer signer
 * @param args Constructor params
 * @returns deployed contract instance (promise)
 */
export async function newContract<T>(name: string, signer: Signer, ...args: any[]) {
    const factory = await ethers.getContractFactory(name, signer);
    let contractInstance = (await factory.deploy(...args));
    await contractInstance.deployed();
    return contractInstance as unknown as T;
}

/**
 * Auxilliary date formating.
 * @param date 
 * @returns 
 */
export function formatTime(date: Date): string {
    return `${ ('0000' + date.getFullYear()).slice(-4) }-${ ('0' + (date.getMonth() + 1)).slice(-2) }-${ ('0' + date.getDate()).slice(-2) } ${ ('0' + date.getHours()).slice(-2) }:${ ('0' + date.getMinutes()).slice(-2) }:${ ('0' + date.getSeconds()).slice(-2) }`
}

/**
 * Sets parameters for shifting time to future. Note: seems like 
 * no block is mined after this call, but the next mined block has
 * the the timestamp equal time + 1 
 * @param tm 
 */
export async function increaseTimeTo(tm: number, callType: 'ethers' | 'web3' = "ethers") {
    if (process.env.VM_FLARE_TEST == "real") {
        // delay
        while (true) {
            let now = Math.round(Date.now() / 1000);
            if (now > tm) break;
            // console.log(`Waiting: ${time - now}`);
            await new Promise((resolve: any) => setTimeout(() => resolve(), 1000));
        }
        return await advanceBlock();
    } else if (process.env.VM_FLARE_TEST == "shift") {
        // timeshift
        let dt = new Date(0);
        dt.setUTCSeconds(tm);
        let strTime = formatTime(dt);
        const got = require('got');
        let res = await got(`http://localhost:8080/${ strTime }`)
        // console.log("RES", strTime, res.body)
        return await advanceBlock();
    } else {
        // Hardhat
        if (callType == "ethers") {
            await ethers.provider.send("evm_mine", [tm]);
        } else {
            await time.increaseTo(tm);
        }

        // THIS RETURN CAUSES PROBLEMS FOR SOME STRANGE REASON!!!
        // ethers.provider.getBlock stops to work!!!
        // return await ethers.provider.getBlock(await ethers.provider.getBlockNumber());
    }
}

/**
 * Hardhat wrapper for use with web3/truffle
 * @param tm 
 * @param advanceBlock 
 * @returns 
 */
export async function increaseTimeTo3(tm: number, advanceBlock: () => Promise<any>) {
    return increaseTimeTo(tm, "web3")
}

/**
 * Finalization wrapper for ethers. Needed on Flare network since account nonce has to increase
 * to have the transaction confirmed.
 * @param address 
 * @param func 
 * @returns 
 */
export async function waitFinalize(signer: SignerWithAddress, func: () => Promise<ContractTransaction>): Promise<any> {
    let nonce = await ethers.provider.getTransactionCount(signer.address);
    let res = await (await func()).wait();
    if (res.from !== signer.address) {
        throw new Error("Transaction from and signer mismatch, did you forget connect()?");
    }
    while ((await ethers.provider.getTransactionCount(signer.address)) == nonce) {
        await sleep(100);
    }
    return res;
}

/**
 * Finalization wrapper for web3/truffle. Needed on Flare network since account nonce has to increase
 * to have the transaction confirmed.
 * @param address 
 * @param func 
 * @returns 
 */
export async function waitFinalize3<T>(address: string, func: () => Promise<T>) {
    let nonce = await web3.eth.getTransactionCount(address);
    let res = await func();
    while ((await web3.eth.getTransactionCount(address)) == nonce) {
        await sleep(1000);
    }
    return res;
}



/**
 * Artificial advance block making simple transaction and mining the block
 * @returns Returns data about the mined block
 */
export async function advanceBlock(): Promise<any> {
    let signers = await ethers.getSigners();
    await waitFinalize(signers[0], () => signers[0].sendTransaction({
        to: signers[1].address,
        // value: ethers.utils.parseUnits("1", "wei"),
        value: 0,
        data: ethers.utils.hexlify([1])
    }));
    let blockInfo = await ethers.provider.getBlock(await ethers.provider.getBlockNumber());
    return blockInfo;
    // // console.log(`MINE BEAT: ${ blockInfo.timestamp - blockInfoStart.timestamp}`)
}

/**
 * Helper wrapper to convert number to BN 
 * @param x number expressed in any reasonable type
 * @returns same number as BN
 */
export function toBN(x: BN  | number | string): BN {
    if (x instanceof BN) return x;
    return web3.utils.toBN(x);
}


export function numberedKeyedObjectToList<T>(obj: any) {
    let lst: any[] = []
    for (let i = 0; ; i++) {
        if (i in obj) {
            lst.push(obj[i])
        } else {
            break;
        }
    }
    return lst as T[];
}

export function doBNListsMatch(lst1: BN[], lst2: BN[]) {
    if (lst1.length != lst2.length) return false;
    for (let i = 0; i < lst1.length; i++) {
        if (!lst1[i].eq(lst2[i])) return false;
    }
    return true;
}

export function lastOf(lst: any[]) {
    return lst[lst.length-1];
}

export function zip<T1, T2>(a: T1[], b: T2[]): [T1, T2][] {
    return a.map((x, i) => [x, b[i]]);
}

export function zip_many<T>(l: T[], ...lst: T[][]): T[][] {
    return l.map(
        (x, i) => [x, ...lst.map( l => l[i])]
    );
}

export function zipi<T1, T2>(a: T1[], b: T2[]): [number, T1, T2][] {
    return a.map((x, i) => [i, x, b[i]]);
}

export function zip_manyi<T>(l: T[], ...lst: T[][]): [number, T[]][] {
    return l.map(
        (x, i) => [i, [x, ...lst.map( l => l[i])]]
    );
}

export function compareNumberArrays(a: BN[], b: number[]) {
    expect(a.length, `Expected array length ${a.length} to equal ${b.length}`).to.equals(b.length);
    for (let i = 0; i < a.length; i++) {
        expect(a[i].toNumber(), `Expected ${a[i].toNumber()} to equal ${b[i]} at index ${i}`).to.equals(b[i]);
    }
}

export function compareArrays<T>(a: T[], b: T[]) {
    expect(a.length, `Expected array length ${a.length} to equal ${b.length}`).to.equals(b.length);
    for (let i = 0; i < a.length; i++) {
        expect(a[i], `Expected ${a[i]} to equal ${b[i]} at index ${i}`).to.equals(b[i]);
    }
}

export function compareSets<T>(a: T[] | Iterable<T>, b: T[] | Iterable<T>) {
    const aset = new Set(a);
    const bset = new Set(b);
    for (const elt of aset) {
        assert.isTrue(bset.has(elt), `Element ${elt} missing in second set`);
    }
    for (const elt of bset) {
        assert.isTrue(aset.has(elt), `Element ${elt} missing in first set`);
    }
}

export function assertNumberEqual(a: BN, b: number, message?: string) {
    return assert.equal(a.toNumber(), b, message);
}

export async function sleep(ms: number) {
    await new Promise<void>(resolve => setTimeout(() => resolve(), ms));
}

export function encodeContractNames(names: string[]): string[] {
    return names.map( name => encodeString(name) );
}

export function encodeString(text: string): string {
    return web3.utils.keccak256(web3.eth.abi.encodeParameters(["string"], [text]));
}

export function findRequiredEvent<E extends Truffle.AnyEvent, N extends E['name']>(res: Truffle.TransactionResponse<E>, name: N): Truffle.TransactionLog<Extract<E, { name: N }>> {
    const event = res.logs.find(e => e.event === name) as any;
    assert.isTrue(event != null);
    return event;
}

