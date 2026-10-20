# Immutable Publishing version sequence creation

Date: 2026-10-19 UTC. HEAD: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`. Uncommitted relevant
changes: the prior inverse-key and revision sequence fixes, the new creation-only EntryVersion
sequence validation, four canonical locale labels, and new/expanded tests. Concurrent normal DB
naming/ADR/configuration/dump changes and diagnostic deletions were preserved separately. This
record covers C5 before the pending ordered-position unit is verified.

## Model and database contract

The twelve version tables already require NOT NULL and CHECK(sequence > 0); PostgreSQL integer
storage supplies the upper bound. PublishingEntryVersionRecord now validates integer sequence
1–2,147,483,647 on creation. It intentionally leaves persisted updates on the existing immutable
ReadOnlyRecord boundary; adding an unconditional validator would preempt that refusal for invalid
sequence changes. No DB protection, callback, data, ownership, state, trigger or deletion policy was
changed. Normal promotion continues assigning max+1. Numeric string assignment remains supported.

`test/models/publishing/version_sequence_contract_test.rb` lists every concrete version family. It
verifies saves at 1/2/max-1/max, rejects
NULL/empty/false/true/negative/fractional/malformed/overflow creation, and preserves
immutable-update rejection at NULL/zero/overflow. A failed direct SQL INSERT copies a valid stored
row while changing only sequence, bypassing the immutable-update callback and AR validation/type
serialization. Tests assert exact PG NOT NULL/CHECK/native-overflow failures, constraint names and
unchanged original data inside savepoints.

## Executed checks

| Check                                                      | Result                                                            |
| ---------------------------------------------------------- | ----------------------------------------------------------------- |
| Red before version validation                              | 48 tests, 324 assertions, 12 expected failures, zero errors/skips |
| Combined relevant suite after version validation           | 263 tests, 2,894 assertions, zero failures/errors/skips; exit 0   |
| RuboCop: two sequence Concerns and two sequence test files | 4 files inspected, no offenses; exit 0                            |
| Full default CLI on the verified isolated fleet            | 2,089 displayed failure groups; exit 1; no internal errors        |
| Full raw report capture                                    | 18,269 OK, 2,147 fail, one warning; diagnostic exit 0             |
| Baseline/after reported model target comparison            | 873 each, identical sets                                          |

The combined suite contains all C4 public-boundary files plus the new version matrix and expanded
boolean sequence sentinels. It includes existing promotion, immutable snapshot, taxonomy, RP grant
retention/rotation, reference models, identifier and locale checks. PARALLEL_WORKERS=2 used fresh
receipt-owned clones of the previously verified 32-parent isolated manifest. Parents were not
rebuilt or migrated, and no production connection was used. Parent checker reads and template
cloning were sequenced to avoid source-database contention.

Twelve more NullConstraint findings disappeared, with no new finding: cumulative removal is thirty
individual failures (2,177 → 2,147; 2,119 → 2,089 CLI groups). C4/C5 share one sequence cause
family; combined with inverse keys, two cause families have verified fixes. Twenty-seven models
changed behavior, zero migrations were created, and 105 new tests belong to verified slices.
Position tests and model edits are a separate pending unit, excluded from those verification totals.

Local artifacts under `tmp/database-consistency-20261019/`:

| Artifact                        | SHA-256                                                            |
| ------------------------------- | ------------------------------------------------------------------ |
| version-sequence-raw-after.json | `c1544cb9a1a2046067b4b490a695e18811c63411c6148c15cb6f7f6826616ee1` |
| sequence-both-green.stdout      | `31c3764aa2a94e64ef49e2bb226b0d95849aebc4e503ab20958fe7d0309783d3` |

The checker remains failing and one additional warning remains. Fifteen findings remain unresolved
under explicit user decisions D1/D3. Full isolated Rails suite success, normal dump reconstruction
and production transition prerequisites are not established by these focused results.
