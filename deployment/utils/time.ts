
export async function sleepFor(ms: number) {
  await new Promise((resolve: any) => {
    setTimeout(() => resolve(), ms);
  });
}

export async function randomDelay(minDelayMs: number, maxDelayMs: number): Promise<void> {
  const delayMs = Math.floor(Math.random() * (maxDelayMs - minDelayMs + 1) + minDelayMs);
  await sleepFor(delayMs);
}

export async function runWithDuration<T>(label: string, fn: () => Promise<T>): Promise<T> {
  const start = process.hrtime();
  const res = await fn();
  const diff = process.hrtime(start);
  const diffMs = (diff[0] * 1e9 + diff[1]) / 1e6;
  console.log(`[${label}] Duration: ${Math.round(diffMs)}ms`);
  return res;
}
