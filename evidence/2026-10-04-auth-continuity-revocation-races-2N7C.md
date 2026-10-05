# Auth continuity revocation races

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and concurrent unrelated work. No deployment or schema change.
- Database: owned isolated run `20261003auth6f3`, manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, isolated APP ticket preparation and one worker.

`bin/rails test test/models/auth_ceremony_revocation_concurrency_test.rb` passed:
**3 runs, 21 assertions, no failures/errors/skips**, seed 5444.

Each actor surface commits its own synthetic parent/continuity rows, then releases the main
connection and starts two writer threads. PostgreSQL backend IDs prove distinct connections.
A queue barrier releases both to revoke the same expired continuity at its exact deadline.
One transition succeeds and the competing transition refuses terminal state. The single stored
revocation time remains fixed, continuity remains terminal, and later authentication evidence is
refused. Cleanup deletes only the test's committed rows after joining its threads. No authentication
credential or Base root session is injected or created.

The first APP attempt failed with connection-pool timeout because the main test retained its
connection. Releasing through Rails' existing connection-handler API corrected the harness; no
pool configuration or global test infrastructure was changed. APP alone then passed 1 run and
7 assertions, seed 40116, before the independent COM/ORG cases were added.

The additional APP purge-versus-revocation race passed with the three cases above:
**4 runs, 29 assertions, no failures/errors/skips**, seed 51182. Two distinct writer connections
compete to purge the expired cohort and revoke its continuity. A retained cohort must retain both
rows and refuse later evidence; a purged cohort must remove both rows. A restrictive foreign-key
failure is an explicit cleanup refusal. This run does not demonstrate every scheduling order.

The combined command `bin/rails test test/operations/identity_step_up_ceremony_transaction_purger_test.rb
test/models/auth_ceremony_revocation_concurrency_test.rb` passed **11 runs, 76 assertions,
no failures/errors/skips**, seed 22536. The added fault test raises through Rails SQL instrumentation
after continuity deletion, observes both rows restored by rollback, and then successfully retries
cleanup. This is a controlled statement failure, not a database disconnect or commit failure.

This proves the model-owned revocation race on APP/COM/ORG and the tested APP cleanup outcomes.
It does not prove Base finalization vs logout, cancellation vs success, credential-removal races or
distributed commit faults. Those full-ledger requirements remain open. Browser checks are user-owned; OTP logging
remediation is excluded; Passkey candidate shape approval remains pending.
