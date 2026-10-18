# Secret issuance facts resist direct persistence

Performed 2026-10-04, approximately 06:03–06:07 UTC (Etc/UTC).
Rails feature HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5; 428 dirty paths
at capture, including concurrent work. Results include uncommitted changes.

Public persistence tests reproduced clearing canceled_at through update_columns:
no exception was raised, allowing a terminal allocation to become pending again.
The recorded presentation/confirmation test also failed because direct writes
reached the DB CHECK rather than the model's immutable-fact boundary. Initial Red:
10 tests, 36 assertions, two failures, zero errors/skips.

ClientSecretIssuance now preserves already recorded presented_at, confirmed_at
and canceled_at at ordinary assignment and the installed Rails direct persistence
hook. update_column(s) and touch cannot overwrite recorded facts. An ordinary
assignment/save of the exact same timestamp remains an existing no-op. First-time
transitions continue through their existing operations and validation requirements.

The tests exercise public APIs only, using nil and adjacent/equal microsecond
timestamps, unchanged snapshots, terminal state and zero reservation. No private
test call, dynamic dispatch, schema change, payload shape, duration default or
authorization bypass was introduced. The Secret reference describes these guards.

Executed against the guarded registration disposable fleet via
`bundle exec ruby /tmp/umaxica-registration-fresh-db-task.rb test <paths>`:

- The final 15-file selection covers credential/issuance/outbox/receipt models,
  capacity/lookup/count, reservation and concurrency, cancellation/expiry,
  name/revocation and confirmation/concurrency: **101 tests, 1,362 assertions,
  zero failures/errors/skips**.
- Intermediate operation/query expectations assumed rejection at validated save;
  the replacement preserves refusal and verifies the earlier writer exception.
  Existing same-timestamp ordinary no-op expectations remain intact.
- `bundle exec rubocop app/models/client_secret_issuance.rb
  test/models/client_secret_issuance_test.rb
  test/queries/client_secret_capacity_query_test.rb
  test/operations/client_secret_manual_issuance_invalidator_test.rb`:
  four files, no offenses after ordinary assertion-spacing corrections.
- `git diff --check`: PASS.

NOT_RUN: full suite, protected plaintext delivery, signup/actual registration
coordinator, claim and arbitrary bulk-SQL enforcement. Chronicle dispatch and
audited physical purge remain incomplete; these model guards do not fix that
independent deletion problem or approve pending persistence refinements.
