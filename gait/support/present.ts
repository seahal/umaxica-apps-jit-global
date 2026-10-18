/**
 * Narrows a value the test knows must exist -- the first form in a rendered screen, the first
 * recorded call of a mock -- and fails with a description when it does not.
 *
 * Tests index into arrays and query results constantly, and under `noUncheckedIndexedAccess` every
 * such read is possibly-undefined. The alternative spelling is `!`, which asserts the same thing
 * silently and reports the miss as "cannot read property of undefined" several lines later. This
 * says what was expected instead.
 */
export function present<T>(value: T | null | undefined, description: string): T {
  if (value === null || value === undefined) {
    throw new Error(`Expected ${description} to be present, but it was ${String(value)}.`);
  }

  return value;
}
