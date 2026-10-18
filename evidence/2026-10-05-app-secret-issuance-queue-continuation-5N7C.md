# app Secret issuance collection continuation

Observed on 2026-10-05 (UTC), against HEAD
`e8f2371bc5cbefd2087c728aeeef4e318463d33f`, with uncommitted changes affecting
issuance collection, purge validation, tests and documentation. Unrelated work
was preserved. No shared-database migration, deployment or external write occurred.

## Implementation and public callers

`ClientSecretLifecycleJob#perform`, already called by the app retention path,
now invokes `ClientSecretIssuanceCollectionJob#perform`. The latter captures an
upper ID horizon, visits at most 500 allocations and queues the next cursor on
the existing Solid Queue `retention` queue. Retained original authority does not
prevent traversal to later allocations. A fresh periodic scan recovers lost
enqueue; cursor progression conveys no deletion authority.

The worker reuses `ClientSecretIssuanceExpiryInvalidator.call!` for expired
allocations and `ClientSecretIssuancePurger` for dependency-gated collection.
Expired payload erasure and source retirement audits commit together. The purge
operation now requires full matching durable Chronicle facts, rather than UUID
and success result alone. DELETE and the surviving purge outbox still share the
Source transaction. No PostgreSQL VACUUM task was introduced.

The user accepted issuance/payload 600 seconds, terminal purge delay 86400 seconds,
delivered source outbox retention 604800 seconds and proof retention 2592000 seconds.
The ADR, security document and decision gates distinguish accepted values from
shared deployment authorization. All settings remain explicit. Short test values
are isolated verification inputs, not operational defaults.

## Tests and static checks

Commands use the existing guarded runner
`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test` and the task-owned
`codex_integrity_20261005recovery_*` PostgreSQL fleet. Its manifest verifies database
names, owners and OIDs; observed server was PostgreSQL 17.7 at `10.89.2.3:5432`.

- Expired continuation reproduction: `test/jobs/client_secret_issuance_collection_job_test.rb
  --include '/retires_expired/'`, seed 2476: 1 run, 2 assertions, 1 failure.
  The queued continuation left the expired encrypted payload present.
- Durable audit identity reproduction:
  `test/operations/client_secret_completed_issuance_purger_test.rb
  --include '/matching_audit_UUID/'`, seed 42327: 1 run, 1 assertion, 1 failure.
  A conflicting Chronicle action with the same UUID wrongly allowed deletion.
- After fixes, the collection job, expiry invalidator, completed issuance purger,
  audit delivery job, outbox purger and outbox purge job files passed together:
  seed 5569, **31 runs, 307 assertions, 0 failures/errors/skips**, 13.989780 seconds.
  The command supplied those six files explicitly. Tests cover fixed horizons,
  traversal past retained authority, expiry cleanup without premature deletion,
  replay without deadline extension and eight conflicting Chronicle fact partitions.
- An intermediate six-file run, seed 60537, had 30 runs/281 assertions and one
  audit delivery test failure. The test assumed its new event was first despite
  durable outboxes surviving fixture replacement. It now delivers existing work
  through the public job before asserting the single new event. Subsequent seed
  47907 passed 30 runs/289 assertions; the final 31-run result includes the added
  Chronicle identity regression.
- RuboCop passed the new collection job, lifecycle job, collection tests and
  delivery tests (4 files). The purger and its tests required layout-only
  autocorrection; no exclusion or threshold changed.
  Final `bundle exec rubocop` over all eight changed Ruby files passed with no
  offenses; `git diff --check` also exited 0 at 2026-10-05T14:04:19+00:00.
- HTTP/DB regression command supplied `test/integration/app_secret_login_journey_test.rb`,
  `test/integration/app_secret_signup_journey_test.rb`,
  `test/integration/app_secret_parallel_login_test.rb` and
  `test/jobs/client_secret_outbox_recovery_test.rb`: seed 36027,
  **50 runs, 1622 assertions, 0 failures/errors/skips**, 18.615053 seconds.
  An earlier seed 34915 run had 50 runs/1617 assertions and one failure: the
  recovery test assumed the whole shared disposable fleet had no issuance rows,
  although the actual-worker observation intentionally retained other Clients'
  authority-bound allocations. The test now verifies its event's Client has no
  source rows, preserves other Clients' rows, delivers earlier work through the
  public delivery job, and explicitly supplies proof retention. The recovery
  assertion still requires real periodic delivery and durable Chronicle storage.
  No source records were deleted to make the check pass.

## Actual Solid Queue observation

`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb runner
/tmp/umaxica-secret-issuance-queue-observation.rb` exited 0. The observation was
repeated sequentially after the regression tests because its first invocation
overlapped a test process against the same fleet. Only the sequential observation
is used for the runtime claim here.

The guarded queue database was `codex_integrity_20261005recovery_queue`.
Actual `SolidQueue::Worker` processed persisted continuation jobs after initially
being stopped. The first allocation remained bound to retained authority; a later
eligible omitted allocation was deleted. The surviving purge outbox and original
session remained present, and failed job count was zero. The worker stopped in
the observation's ensure block. Fixture allocations and explicit one-second proof
retention exercised collection, not Passkey registration authorization.

E2E was excluded by the user; no new E2E execution was started during this resume.
The previously owned browser server PID 462145 was stopped. Earlier browser
results remain separate observations and are not substituted for these tests.

## Remaining scope

This is partial implementation, not Phase 1 completion. Replay-barrier retirement,
fair traversal in other lifecycle stages, full remaining claim/receipt and signup
collection failure/race/boundary coverage, schema-drift resolution and remaining
non-E2E acceptance checks still require work. Shared-database destructive
application remains unauthorized. Chronicle retention is a separate operational
decision from the four accepted Secret lifetimes.
