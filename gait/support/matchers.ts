// Vitest's asymmetric matchers, named as `unknown`.
//
// `expect.any(...)` and `expect.objectContaining(...)` are declared to return `any`, so composing
// them into an object literal makes every surrounding property unchecked too. Naming the result
// `unknown` here confines that to one place: the matcher still behaves the same at runtime, and
// the object a spec builds around it stays type-checked.
import { expect } from "vitest";

/** Matches any function, for the lifecycle callbacks a spec does not otherwise inspect. */
export const A_FUNCTION: unknown = expect.any(Function);

/** Matches an object carrying at least `shape`. */
export function containing(shape: Record<string, unknown>): unknown {
  return expect.objectContaining(shape);
}
