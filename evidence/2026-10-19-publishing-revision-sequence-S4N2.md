# Publishing revision sequence boundaries

Date: 2026-10-19 UTC. HEAD: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`. Uncommitted behavior
changes: C1 token reference inverses; one bounded numericality declaration in
PublishingEntryRevisionRecord, affecting all twelve concrete family revisions. Four canonical locale
bundles now define attributes.sequence so actual validation messages render. Tests and specification
artifacts are uncommitted. Concurrent changes to database naming/configuration, ADR, structure dumps
and diagnostic deletions were observed outside this task and were not reverted or adopted as fixes.

## Contract and implementation

Actual migration-owned schema requires sequence NOT NULL, CHECK(sequence > 0), and PostgreSQL
integer storage. CreateEntryOperation assigns 1; ReviseEntryOperation and RestoreVersionOperation
use max+1. These writers do not accept a request-provided revision sequence. The new model rule
requires an integer greater than zero and at most 2,147,483,647. The real DB protections remain. No
schema migration, new trigger, new SELECT, deletion policy or authentication writer was added.

Every one of the twelve concrete EntryRevision families is exercised by
`test/models/publishing/revision_sequence_contract_test.rb`. Boundaries are 0/1/2 and
2,147,483,646/2,147,483,647/2,147,483,648, plus NULL/empty/false/negative/fractional/malformed
inputs. The existing integer-string assignment remains valid. Direct SQL in a savepoint bypasses AR
validation and serialization, asserts the exact PostgreSQL failure/constraint, and verifies that the
original sequence remains intact. No behavior mock or private access is used.

## Results

| Stage                                                                             | Observed result                                                                                                                |
| --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Red, original revision model                                                      | 48 tests, 252 assertions, 12 expected validation failures, 0 errors/skips                                                      |
| First Green                                                                       | 127 tests, 662 assertions, 0 failures, 12 MissingTranslationData errors; missing sequence label exposed while rendering errors |
| Green with explicit labels in all four bundles                                    | 127 tests, 1,130 assertions, 0 failures/errors/skips                                                                           |
| Expanded verification including full-message assertions                           | 215 tests, 1,742 assertions, 0 failures/errors/skips, exit 0                                                                   |
| Full default checker against development schema before concurrent topology change | 2,101 displayed failure groups, exit 1, no internal errors                                                                     |
| Full default checker against verified isolated test schema                        | Same exact 2,101 finding lines, exit 1, no internal errors                                                                     |
| Raw isolated capture                                                              | 18,245 OK, 2,159 fail, one warning, diagnostic exit 0                                                                          |
| Reported model target sets                                                        | Exactly 873 at baseline and after C4; no added or missing model target                                                         |

The general catalog inventory has 893 existing-table models, including twenty dependency-owned
models. The checker's unchanged built-in project ownership filter selects the same 873 application
models before and after these changes. No checker was disabled and no suppression/configuration file
was supplied. Publishing and Avatar remain in the identical target set.

The expanded test command selected the new revision sequence file, existing family promotion,
version immutability/snapshot, revision coverage, taxonomy constraints/retirement, RpSessionTest,
three token reference-model files, public-ID generation/capacity and the existing two locale
initializer files. The complete RpSessionTest pass also verifies the retained grant
deletion/rotation contract behind user decision D3; its three checker findings remain unresolved
intentionally.

## Environment qualification

Tests used the existing identity-verified parent manifest
`tmp/acceptance-isolated-20261017c1a2.json` and PARALLEL_WORKERS=2. A read-only preflight verified
all 32 parent database identities, no pending migrations, no active parent sessions and no existing
worker names. The existing harness created fresh receipt-owned worker clones and performed its
normal verified cleanup; no parent rebuild, schema DDL or reset was requested by this task.

One expanded-test setup attempt overlapped the parent's read-only checker connection and stopped
with PG::ObjectInUse during template cloning, before tests. After that checker process exited, the
test was rerun sequentially; the completed retry is the 215-test result above. No force-drop or
safety bypass was used.

The initial normal-fleet full run finished with 15,595 tests, 130,388 assertions, six failures, 358
errors, zero skips. Distinct errors: 340 NoDatabaseError, fourteen owned-worker precondition errors,
three KeyError and one RuntimeRole::UnownedRoute. During that run, normal DB configuration changed
concurrently and the checked-in dumps became empty-schema outputs. The run is not evidence of either
full-suite success or attribution of those failures to these model changes. A proper isolated
full-suite run remains required. Existing normal schemas/dumps were not overwritten.

## Retained local artifacts

Paths are under `tmp/database-consistency-20261019/`.

| Artifact                     | SHA-256                                                            |
| ---------------------------- | ------------------------------------------------------------------ |
| sequence-raw-after.json      | `db883a145443d649bf4ba038d050734876bd25c17dc835421cad2d5a55538ae8` |
| current-targets.json         | `bac95ccd151bc0ba1fb4a2c525eea1110524b2ecc56e35e213f07c6d03a3caee` |
| sequence-verify-retry.stdout | `3d86edeabe6937e8e1ae5080dd1e83d56f4e814523494566fce5601987f760ea` |

Totals since the baseline: eighteen individual findings removed from two fixed cause families; three
reference models plus twelve revision models changed behavior; zero migrations; 57 new tests in
verified slices. The separate pending version-sequence unit is not counted as verified here. Full
remediation, production migration readiness and full-suite success remain unproven.
