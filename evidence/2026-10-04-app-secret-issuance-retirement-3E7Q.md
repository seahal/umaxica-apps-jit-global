# app Secret cancellation and expiry retirement

Performed 2026-10-04, completed at 02:38:50 UTC (Etc/UTC).
HEAD: f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5, branch `feature`.
The shared worktree was dirty: 317 paths at continuation start, 322 at this
record's initial capture. Concurrent agent changes were preserved. These results
include the uncommitted operation, model, localization and test changes; they are
not results against a clean commit or a CI workflow.

## Implemented boundary

`ClientSecretManualIssuanceInvalidator` rereads the owning current Ticket session,
checks scoped Step-Up and retires a pending manual allocation under the Zenith
Client lock. Candidate discard, payload removal, cancellation and source outbox
commit together. The Ticket session is unchanged. Replay cannot extend retention
or create another reservation; model validation prevents clearing/replacing a
stored cancellation and creating a confirmed candidate for canceled/omitted issuance.

`ClientSecretIssuanceExpiryInvalidator` is an autonomous write operation. It uses
writer DB time after the Client lock and retains the derived expired state;
there is no fabricated cancellation or new persisted status. It retires pending
candidates and removes the remaining payload with `secret.discarded` source
events and `flow_expired` reason. The existing parent event's absent credential
reference and planned item count identify issuance retirement. Autonomous actor
columns are null and the caller supplies the job execution identifier. Replay
requires existing retirement evidence and leaves its purge deadline unchanged.
Retention duration is explicit, with no production default added.

No migration, serialized payload format, Chronicle projection, GET mutation,
encryption fallback, new authentication method or token storage was added.

## Execution

The existing `/tmp/umaxica-secret-db-task.rb` wrapper checked the manifest and
ownership of twenty task-owned `codex_integrity_20261003secret_*` databases on
PostgreSQL 17.7 before test preparation. No shared/deployed database was used.

- Initial cancellation Red: 2 tests, 1 assertion, 1 failure, 1 error; missing
  operation after successful environment preparation. A subsequent terminal-fact
  Red reproduced ordinary save clearing cancellation: 2 tests, 24 assertions,
  1 failure. The earlier operation work is retained in this shared worktree.
- Expiry Red: `bundle exec ruby /tmp/umaxica-secret-db-task.rb test
  test/operations/client_secret_issuance_expiry_invalidator_test.rb`:
  3 tests, 1 assertion, 1 failure, 2 errors; missing implementation.
- Initial expiry implementation failed on PostgreSQL infinity/Time comparison.
  Explicit handling of the existing positive-infinity retention sentinel fixed
  this; no default lifetime was introduced.
- Expanded regression: wrapper `test` with expiry/cancellation/manual reservation
  operations and concurrency tests, revocation/name operations, outbox/credential/
  issuance models, count value, capacity/lookup queries, ownership/auth-method
  policies and both credential inventory tests:
  **109 tests, 1,123 assertions, zero failures/errors/skips**.
- After formatting corrections, wrapper `test` with expiry invalidator, manual
  invalidator and manual reservation concurrency tests:
  **15 tests, 263 assertions, zero failures/errors/skips**.
- `bundle exec rubocop` on the two invalidators, issuance/credential models and
  their three cancellation/expiry/concurrency test files:
  **7 files, no offenses**. No suppression, exclusion or gate change.
- `git diff --check`: PASS.
- Wrapper `test test/unit/security/forbidden_rails_patterns_test.rb`:
  **5 tests, 9 assertions, zero failures/errors/skips**. This verifies the
  existing forbidden-pattern guard, not full application security or all-surface
  behavioral regression.

The concurrency cases use actual distinct PostgreSQL writer connections,
backend PID assertions and Queue barriers, not timing sleeps. At A=19, expiry
cleanup and a new scoped manual reservation both succeed; A stays 19 and R is 1.
The separate cancellation race accepts either serialized legitimate outcome,
with A + R at most 20. Boundary tests separately control the public writer-clock
seam at expiry minus/equal/plus one microsecond; this is not evidence of real
browser clock behavior. Audit-failure cases induce invalid event UUID validation
and verify actual rollback rather than mocking successful persistence.

## Limits

Payload fixtures are opaque strings used to prove removal, not encryption or
safe delivery. Step-Up facts are prepared directly; these operation tests do not
prove a full Step-Up ceremony. The executor fixture comes from a new ApplicationJob
instance; no live periodic expiry job was executed or scheduled.

HTTP activation, periodic cleanup and duration policy, all-or-none confirmation,
Passkey 2/1/0 journeys, normal Secret claim/login/receipt, Chronicle delivery,
audited physical purge and browser secrecy remain incomplete. The generic direct
app Secret purge path has not been cut over. No browser, production gateway,
external service, deployment or full repository test suite was run in this increment.
