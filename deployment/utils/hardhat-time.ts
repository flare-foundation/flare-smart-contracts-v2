import { time } from "@nomicfoundation/hardhat-network-helpers";
import { HardhatRuntimeEnvironment } from "hardhat/types";

/**
 * Increase time to the given timestamp for hardhat networks.
 * Note: will fail if using on a non-hardhat network.
 */
export async function increaseTimeTo(timestampSec: number) {
  const currentBlockTime = await time.latest();
  if (timestampSec <= currentBlockTime) {
    console.log(`Already ahead of time, not increasing time: current ${currentBlockTime}, requested ${timestampSec}`);
    return;
  }

  await time.increaseTo(timestampSec);
}

/**
 * Update time to now for hardhat networks.
 * If the time is too far in the past we get issues when calculating price epoch ids.
 */
export async function syncTimeToNow(hre: HardhatRuntimeEnvironment) {
  if (isHardhatNetwork(hre)) {
    const now = Math.floor(Date.now() / 1000);
    await increaseTimeTo(now);
  }
}

export function isHardhatNetwork(hre: HardhatRuntimeEnvironment) {
  const network = hre.network.name;
  return network === "local" || network === "localhost" || network === "hardhat";
}
