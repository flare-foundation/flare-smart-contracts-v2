import { assert } from "chai";

/**
 * Asserts that `promise` reverts with the given Relay custom error (typed failure ABI —
 * the string reasons were replaced by custom errors in 2026-08).
 */
export async function expectCustomError(promise: Promise<unknown>, errorName: string): Promise<void> {
  try {
    await promise;
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    assert(
      message.includes(`custom error '${errorName}(`) || message.includes(`custom error '${errorName}'`),
      `Expected custom error '${errorName}', got: ${message}`
    );
    return;
  }
  assert.fail(`Expected custom error '${errorName}', but the call did not revert`);
}
