# R5-WU02 protocol foundation evidence

Date: 2026-10-16

Repository HEAD: `17903f7d121aa33efe29f2db9235c9aa5db4b001`.

The worktree already contained uncommitted R1-R3 changes when this packet was verified. The R5
results below were run against that worktree with the R5-WU02 changes present; they are not a
clean-commit result.

## Scope

Implemented the additive Zenith authentication-epoch and invalidation-intent shape, the three
realm-local OP contract-epoch rows, consumed-JTI replay records, logout flow/participant/receipt,
outbox and inbound-receipt tables, and their realm-specific models. Runtime logout orchestration,
RP-local stores, credential redistribution and deployment were not part of this packet.

## Verification

- `RAILS_ENV=development bin/rails db:migrate` completed successfully for the affected Zenith and OP
  base migration paths, including the forward epoch seed migrations.
- `RAILS_ENV=development bin/rails zeitwerk:check` completed with `Otherwise, all is good!`.
- Direct development catalog inspection found every new model table, all foundation constraints
  validated, and current contract epochs `app=1`, `com=1`, `org=1`.
- Focused tests passed: `8 runs, 2,760 assertions, 0 failures, 0 errors, 0 skips`.
- The disposable isolated fleet was rebuilt under the approved run manifest: 20 databases and 12
  scoped HMAC roles were verified, recreated and migrated.
- The full isolated Rails suite passed:
  `15,381 runs, 130,799 assertions, 0 failures, 0 errors, 0 skips` with eight workers.
- Six owner structure dumps were regenerated successfully: the three Zenith dumps and the three OP
  base dumps.
- `git diff --check` passed.

## Blocked verification

`RAILS_ENV=development bin/rails db:verify_no_schema_drift` stopped before comparing dumps because
the local `development_com_zenith_db` HMAC definer role does not match the verifier's
database-derived role. No role or credential change was made. Repository-wide drift remains an open
R3-WU08 issue, and CI workflow verification remains open under R3-WU06.

The packet does not claim `AT-R5-02` release activation, R5 runtime logout activation, RP-local
schema readiness, effective secret/process isolation or production/US runtime readiness.
