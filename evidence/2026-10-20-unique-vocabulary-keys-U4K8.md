# Unique-index review and vocabulary key validation

Date: 2026-10-20 UTC. Revision: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`, branch `feature`. The
worktree contained extensive uncommitted earlier remediation/configuration/schema/test work; those
changes affect the result and were retained. Start patch/status: ignored unique-start files.

## C13 scope and observed implementation

User prioritized UniqueIndexChecker after delegating validation design. Read-only current catalogs
and the starting report set map every one of **605** findings to model/connection/table/index: 369
ordinary nonpartial, 122 containing primary id, 102 partial, twelve NULLS NOT DISTINCT, zero
expression-index reports. All matched indexes were unique/ready/valid; 94 of the 122 PK-containing
indexes were actually referenced by PostgreSQL FKs. The review retains the distinction between index
facts and unverified business/duplicate contracts; no blanket validation or checker change. Detailed
stable IDs and dispositions: `specs/database-consistency-remediation/unique-index-review.md`.

The twelve Vocabulary.key indexes implement the accepted taxonomy ADR's physical-family scope,
independent of kind/locale/archival. Existing normal term-slug exceptions remain protected by D1. No
normal vocabulary collision handler was found in the inspected application writers; the existing
vocabulary duplicate test explicitly bypasses model validation. Within the user-delegated validation
scope, add create-only key uniqueness to PublishingVocabularyRecord and a Key attribute label to all
four canonical bundles. Normal duplicate creation now raises RecordInvalid/key:taken; direct
validation-disabled duplicates retain RecordNotUnique, and immutable key updates retain the DB
RestrictViolation. Existing valid casts, labels, format and cross-family independence are preserved.

C13 root causes fixed: **one**; affected models: **12**; added tests: **49**; migrations authored:
**0**. No callback, trigger, schema, deletion, audit, authorization, session or provider-flow change
was introduced by C13. One added key SELECT per new-record validation was measured through actual
sql.active_record events in all twelve models; unchanged existing-key validation adds none. This is
administrative creation preflight, not race protection; the database unique index is retained.

## TDD and verification

Commands use the existing `run_tests.py` runner under tmp/database-consistency-20261019 (one worker,
exact current prepare list); no test infrastructure or established assertion was changed.

| Receipt prefix      | Result                                                                                          |
| ------------------- | ----------------------------------------------------------------------------------------------- |
| unique-key-red      | 37 runs, 180 assertions, 24 expected failures, 0 errors/skips; exit 1                           |
| unique-key-green    | 444 runs, 12268 assertions, 0 failures/errors/skips; exit 0                                     |
| unique-key-final    | Draft extension: 37 runs, 408 assertions, 0 failures, 1 test-declaration error, 0 skips; exit 1 |
| unique-key-verified | 456 runs, 12472 assertions, 0 failures/errors/skips; exit 0                                     |

The first Red retained thirteen successful cross-family/DB-uniqueness/immutable-key
characterizations; expected failures were missing duplicate preflight and missing key SELECT. A
format-sentinel test extension was initially declared inside a running test; corrected its placement
at class definition without removing assertions or altering production behavior for the test. The
final 49-test new file covers all twelve model consumers, kind/archive scope, cross-family
independence, nil/empty/whitespace, zero, invalid alphabet/case, false string casting, minimum valid
lengths 1/2, existing-key validation, DB UNIQUE/NOT NULL/CHECK refusal and immutable key updates.
Full English/Japanese errors render. Final broad scope: Publishing model and operation tests plus
locale bundle integrity. Scoped RuboCop: two files, no offenses, exit 0. `git diff --check` passed.
All 873 project model targets and all checker enabled states match the previous capture.

## Checker checkpoints and concurrent work

- Starting default full checker: exit 1, 605 UniqueIndex, 1814 displayed failure groups; previous
  raw receipt had 1829 individual failures and one warning. No internal checker failure.
- After C13 validator: default full checker exit 1, **593 UniqueIndex**, 1802 displayed groups; raw
  **1817 failures**, 18643 OK, one warning. Exactly twelve Vocabulary.key identities disappear, no
  new non-OK identity. This isolates the model-validation reduction.
- During work, an independent migration
  `db/publishing_migrate/20261020090000_remove_redundant_publishing_locale_unique_indexes.rb`,
  Publishing structure changes and separate R7M2 evidence appeared. C13 did not author, edit, roll
  back or manually run that migration. **The final 456-test run's standard preparation automatically
  applied it to the test DB**, as its stdout explicitly records. Therefore no claim is made that no
  DDL occurred during C13's test command. The successful tests use that resulting test schema.
- Preserve the concurrent worktree changes. A later full default checker/raw capture confirms **569
  UniqueIndex, zero RedundantUniqueIndex, 1769 individual failures, 1754 displayed groups**, 18643
  OK reports and one warning, exit 1, without internal checker errors. The additional 48 absent
  reports are 24 UniqueIndex plus 24 RedundantUniqueIndex, separate from C13's twelve.
- Latest ledger retains all 2194 historical/current IDs. Concurrent migration rows are marked absent
  after the concurrent migration, not resolved by C13. PK-containing indexes left after that work:
  98; ordinary 357, partial 102 and NULLS NOT DISTINCT twelve sum to 569 unresolved UniqueIndex.

## Limits

Full Rails suite, production workload/data/lock assessment, migration rollback/reconstruction and
schema-drift checks were not performed by C13. The independent R7M2 migration's own evidence is a
separate work product, not a C13 verification or approval of its dump/migration workflow. D1 and all
remaining uniqueness/idempotency/exception/PK-FK-target conflicts remain open. Overall zero findings
and full remediation are not achieved. No checker setting, ignore, exclusion or fork changed.

## Local artifacts

Untruncated outputs, receipts, catalog/report JSON and starting worktree snapshots remain under
ignored tmp paths. Evidence contains summaries and digests rather than raw logs or data.

| Artifact                                                       | SHA-256                                                            |
| -------------------------------------------------------------- | ------------------------------------------------------------------ |
| `tmp/database-consistency-20261020/unique-before.stdout`       | `77abaa223b716d7943a0afc11e18198df9c5451d8cbe47caf8333fd55dc03f8e` |
| `tmp/database-consistency-20261020/unique-before.stderr`       | `8d52c661652a3702f600645c75d5f2b25d6edb1d98c0ca8de1e6e1b66afcbf4b` |
| `tmp/database-consistency-20261020/unique-after.stdout`        | `f242f283e32e2fdad096a3ef6c1095b1c80933ac168320cd3a2a99e3e12a98fb` |
| `tmp/database-consistency-20261020/unique-after.stderr`        | `3b925ab946edd9b4a20c7f621f0765612ba3db368b8945b06823d46e797f001b` |
| `tmp/database-consistency-20261020/unique-raw.json`            | `05190ccf3881d02155f4c36dc759b76f0fbded483dff1424b4c9cadd32dbd75d` |
| `tmp/database-consistency-20261020/unique-catalog.json`        | `3cd6b6c57fc6873979c1dc6ef137d418ab62891c0bbb9a210abeed72de1b9e1e` |
| `tmp/database-consistency-20261020/unique-classification.json` | `8b342ec5b8a2c26eee66d17d5ca55849e1d3f0b6e3e747172b76834bc0821896` |
| `tmp/database-consistency-20261020/unique-terminal.stdout`     | `eebfeb2edfe7c52382f3e3fe9a8e416915bcb185c94972e6c4987eca5a7289d9` |
| `tmp/database-consistency-20261020/unique-terminal.stderr`     | `a53ebac68ac03139c84edab8b1a3fc2c0a761ecf68f9634634364e46b269d370` |
| `tmp/database-consistency-20261020/unique-terminal-raw.json`   | `2f7efbfc8edec6171241d705244242d31b1e878e99903a4943445e24ca38a2ff` |
| `tmp/database-consistency-20261020/unique-final-targets.json`  | `971661acdce3855eb23f98ce641b02b5dba0f45184ca4b2f9cba30d716ecf5ac` |
