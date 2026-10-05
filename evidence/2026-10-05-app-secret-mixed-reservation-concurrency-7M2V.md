# Mixed reservation concurrency and schema-expression observations

Observed 2026-10-05 UTC, through 15:09:21+00:00, against HEAD
`e8f2371bc5cbefd2087c728aeeef4e318463d33f` with uncommitted Secret and
unrelated concurrent changes. Used the guarded disposable
`codex_integrity_20261005recovery_*` fleet, PostgreSQL 17.7.

Extended `ClientSecretManualReservationConcurrencyTest` to cover A=18,19,20
for manual/manual, manual/registered-Passkey and
registered-Passkey/registered-Passkey operations. Separate writer backend PIDs,
browser sessions, Queue barriers and bounded PostgreSQL lock timeouts exercise
the actual public reservation operations. Positive allocations serialize to
one reservation and one explicit conflict. At capacity, manual operations refuse
and Passkey operations persist normal zero-count omissions. Assertions preserve
A/R separation, the winning operation's one/two-slot reservation, A+R<=20,
audit counts and absence of encrypted omission payloads.

Commands start with
`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test`:

- Focused mixed matrix, `test/operations/client_secret_manual_reservation_concurrency_test.rb
  --include '/separate writers/'`: seed 17242, 1 run, 72 assertions, no
  failures/errors/skips, 1.632339 seconds.
- Four concurrency files: manual reservation, storage confirmation, claim and
  resolution. First run seed 7160: 14 runs, 194 assertions, 1 error because
  the existing real-retention-job example omitted the now-required explicit
  proof-retention setting. Added the accepted setting and restoration of all
  three local environment values; production fail-fast behavior remains intact.
- Same four files after correction: seed 45285, **14 runs, 201 assertions,
  no failures/errors/skips**, 3.160729 seconds.
- RuboCop on the two changed tests: initial formatting offenses corrected;
  final 2 files inspected, no offenses. `git diff --check` exited 0.

Independent read-only DDL diagnostic:
`bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb runner
/tmp/umaxica-secret-check-expression-observation.rb` exited 0.
It evaluated the exact committed HEAD CHECK expression, current generated dump
expression and live `pg_get_constraintdef` expression using bound parameters
and SQL `IS NOT DISTINCT FROM`, including SQL NULL results.

- App/com/org admission-purpose constraints: all nine valid values, NULL,
  empty and unknown, 12 inputs each.
- App Secret issuance count constraint: five origin inputs (NULL, empty,
  unknown, manual, passkey_registration), count -1/0/1/2/3, attempt 0/1,
  50 combinations.
- All **86 input combinations** had matching HEAD/dump/live results.
  The first diagnostic incorrectly expected text `t` from Rails' decoded
  PostgreSQL booleans and exited 1; correcting the observation to Ruby true
  produced the reported result. No application behavior was changed for it.

This establishes the observed CHECK behavior despite the four array-cast
serialization differences. It does not pass `db:verify_no_schema_drift`, prove
arbitrary schema equivalence, or establish current fresh/legacy reconstruction.
No schema dump was hand edited and no new migration, shared DB application,
com/org implementation change, full suite or E2E run occurred. Live-owner
barrier retirement and remaining confirmation/root-issuance races remain open.
