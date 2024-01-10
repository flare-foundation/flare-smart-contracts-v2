import { asError, errorString } from "./error";
import { sleepFor } from "./time";

const DEFAULT_MAX_RETRIES = 3;
const DEFAULT_INITIAL_BACKOFF_MS = 1_000;
const DEFAULT_BACKOFF_MULTIPLIER = 2;
const DEFAULT_TIMEOUT_MS = 15_000;
const DEFAULT_TIMEOUT_MULTIPLIER = 1.5;

export class TimeoutError extends Error {
  constructor(timeoutMs?: number) {
    super(timeoutMs ? `Action did not complete in ${timeoutMs} ms.` : "Timed out");
  }
}

export class RetryError extends Error {
  constructor(message: string, cause?: Error) {
    super(message, { cause: cause });
  }
}
/** Retries the {@link action} {@link maxRetries} times until it completes without an error. */
export async function retry<T>(
  action: () => T,
  maxRetries: number = DEFAULT_MAX_RETRIES,
  initialBackOffMs: number = DEFAULT_INITIAL_BACKOFF_MS
): Promise<T> {
  let attempt = 1;
  let backoffMs = initialBackOffMs;
  while (attempt <= maxRetries) {
    try {
      return await action();
    } catch (e) {
      const error = asError(e);
      console.log(`Error in retry attempt ${attempt}/${maxRetries}: ${errorString(error)}`);
      attempt++;
      if (attempt > maxRetries) {
        throw new RetryError(`Failed to execute action after ${maxRetries} attempts`, error);
      }
      const randomisedBackOffMs = backoffMs / 2 + Math.floor(backoffMs * Math.random());
      await sleepFor(randomisedBackOffMs);
      backoffMs *= DEFAULT_BACKOFF_MULTIPLIER;
    }
  }

  throw new Error("Unreachable");
}

/** Re-evaluates the {@link predicate} until it returns true, or throws an error if evaluates to false on all retries. */
export async function retryPredicate(
  predicate: () => Promise<boolean>,
  maxRetries: number = DEFAULT_MAX_RETRIES,
  initialBackOffMs: number = DEFAULT_INITIAL_BACKOFF_MS
): Promise<void> {
  const throwIfFalse = async () => {
    if (!(await predicate())) throw new Error("Predicate not satisfied");
  };
  try {
    await retry(throwIfFalse, maxRetries, initialBackOffMs);
  } catch (e) {
    const error = asError(e);
    if (error instanceof RetryError) {
      throw new Error(`Condition not met after ${maxRetries} attempts`, { cause: error.cause });
    }
  }
}

/**
 * Retries the {@link action} {@link maxRetries} times until it completes without an error.
 * If the action does not terminate within {@link timeoutMs}, it will result in a timeout error and will be retried as well.
 */
export async function retryWithTimeout<T>(
  action: () => Promise<T>,
  timeoutMs = DEFAULT_TIMEOUT_MS,
  maxRetries: number = DEFAULT_MAX_RETRIES,
  retryBackOffMs: number = DEFAULT_INITIAL_BACKOFF_MS
): Promise<T> {
  let timeout = timeoutMs;
  return await retry(
    async () => {
      const result = await promiseWithTimeout(action(), timeout);
      timeout = Math.floor(timeout * DEFAULT_TIMEOUT_MULTIPLIER);
      return result;
    },
    maxRetries,
    retryBackOffMs
  );
}

/** Throws {@link TimeoutError} if the {@link promise} is does not resolve in {@link timeoutMs} milliseconds. */
export function promiseWithTimeout<T>(promise: Promise<T>, timeoutMs: number = DEFAULT_TIMEOUT_MS): Promise<T> {
  const timeoutError = new TimeoutError(timeoutMs);
  const timeout = new Promise<never>((_, reject) => {
    setTimeout(() => {
      reject(timeoutError);
    }, timeoutMs);
  });
  return Promise.race<T>([promise, timeout]);
}
