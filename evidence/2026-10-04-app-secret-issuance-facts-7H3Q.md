# app Secret issuance fact immutability and withdrawal diagnosis

Performed 2026-10-04, recorded at 03:11 UTC (Etc/UTC).
Repository: seahal/umaxica-apps-jit-global, branch `feature`.
HEAD: f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5.
The shared worktree was dirty: 330 paths at implementation continuation start,
337 at this record's preceding status check. Concurrent changes were preserved.
These results include uncommitted changes and are not clean-commit or CI results.

## Implemented boundary

ClientSecretIssuance rejects clearing or replacing a stored confirmed_at or
presented_at through ordinary validated updates. Tests use nil and the nearest
PostgreSQL timestamp neighbors, one microsecond before and after the stored
fact. Re-saving the same timestamp remains allowed. A confirmed two-item batch
continues to count A=2/R=0; a presented pending allocation keeps its reservation.

This is a persistence guard, not implementation of browser presentation or
atomic confirmation. No schema, payload codec, new authentication method,
Chronicle projection, production duration or refresh protocol was introduced.

## Execution

The existing `/tmp/umaxica-secret-db-task.rb` wrapper verified the manifest and
ownership of task-owned `codex_integrity_20261003secret_*` databases before test
preparation. No shared or deployed database was used.

- Red: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test
  test/queries/client_secret_capacity_query_test.rb`: 6 tests, 31 assertions,
  2 failures, zero errors/skips. Ordinary updates did not reject fact changes.
- Green: wrapper `test` with capacity query, issuance model, manual cancellation,
  expiry retirement and manual reservation concurrency tests: 29 tests,
  354 assertions, zero failures/errors/skips.
- Related regression: wrapper `test` with those boundaries plus manual reservation,
  name/revocation operations, outbox/credential models, count/lookup queries,
  ownership/auth-method policies and both credential inventory tests:
  **111 tests, 1,151 assertions, zero failures/errors/skips**.
- `bundle exec rubocop app/models/client_secret_issuance.rb
  test/queries/client_secret_capacity_query_test.rb`: 2 files, no offenses.

## Required integration failure

`bundle exec ruby /tmp/umaxica-secret-db-task.rb runner
/tmp/umaxica-secret-withdrawal-probe.rb` invoked the public withdrawal anonymizer
with a task-created Client and confirmed Secret inside a rollback-only Zenith
transaction. It reproduced ActiveModel::UnknownAttributeError on the retired
`user_secret_status_id` column; the Secret remained available before rollback.
No Secret value or digest was printed. The probe's successful exit reports the
expected diagnosis, not successful withdrawal.

FAIL: app withdrawal still uses the retired Secret status model. Its replacement
must distinguish the authenticated initiating actor from autonomous job execution
and write lifecycle facts plus source audit together. This component probe does
not establish full withdrawal, cleanup-job or HTTP behavior.

NOT_RUN: full suite, browser secrecy, complete Secret issuance/login, Chronicle
delivery and audited purge. Existing independent implementation gaps remain.
