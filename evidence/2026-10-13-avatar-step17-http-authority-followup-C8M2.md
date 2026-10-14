# Avatar Step 17 HTTP authority follow-up

Date: 2026-10-13 UTC. Work was performed on branch `feature` against full commit
`aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`. The worktree contained extensive unrelated changes.
This follow-up changed only the APP and ORG Avatar transfer controller test files; those changes
were uncommitted during verification.

## Scope and observed behavior

The earlier Step 17 partial evidence marked AV-5 BLOCKED because its APP/ORG refusal matrix had not
been established. This follow-up adds actual HTTP-path coverage for the remaining authority cases:

- Both APP and ORG refuse a transfer request after the selected Persona or Agent loses owner
  membership; neither request creates a transfer.
- Both surfaces refuse a request from a principal in a login-blocked `RESERVED` status; neither
  request creates a transfer.
- An ORG principal cannot use the APP transfer endpoint, and an APP principal cannot use the ORG
  endpoint.
- A Client cannot accept a transfer addressed to a different Enterprise, and an Operator cannot
  accept one addressed to a different Bureau. Both reservations remain pending and ownership stays
  with the source.
- Destination-side authority alone cannot cancel an app-originated or org-originated transfer;
  each remains pending.
- A different authorized Client or Operator with owner membership in the source organization can
  cancel through the respective HTTP endpoint. The persisted cancel actor is the alternate
  Persona or Agent.
- The APP request that supplies the public ID of a real ORG Avatar still acts on the selected APP
  Avatar. The ORG nil-selection refusal uses a real APP Avatar ID and does not let the request
  parameter substitute for the missing selected Avatar.

The pre-existing controller cases continue to cover each operation's Step-Up scope, valid accept
and cancel flows, stable idempotent request replay, and refusal of legacy Registry transport before
cutover. No application behavior or schema changed in this follow-up.

## Verification

- `env -u POSTGRESQL_ISOLATED_TEST_RUN_ID PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/avatar_ownership_transfers_controller_test.rb test/controllers/base/org/avatar_ownership_transfers_controller_test.rb`:
  `29 runs, 145 assertions, 0 failures, 0 errors, 0 skips`.
- `bundle exec rubocop test/controllers/base/app/avatar_ownership_transfers_controller_test.rb test/controllers/base/org/avatar_ownership_transfers_controller_test.rb`:
  no offenses.
- `git diff --check`: passed.

The Rails test task used the standard configured test databases, with the isolated-run ID unset and
one worker. It performed no development or production database operation, reset, migration,
backfill or cutover-marker write. The checks used ordinary test transactions.

A subsequent read-only Rails runner confirmed `database=test_avatar_db`, 1 Avatar, 4 AvatarGroups,
0 legacy ownership periods, 1 concrete Enterprise ownership period, 0 concrete Bureau ownership
periods, 0 legacy transfers, 0 transfer reservations, and 0 cutover markers. This revalidated the
standard test target and its state after the controller tests.

AV-5 / REQ-071 is now PASS for the APP/ORG HTTP authority matrix. Step 17 remains BLOCKED by
AV-3/AV-6 independent-connection concurrency acceptance and MIG-2/MIG-4 committed migration,
restore and cutover rehearsal; the earlier Step 17 evidence records those blockers and their
resume conditions.

## Read-only rehearsal preparation

On the same commit and dirty worktree, a custom-format backup of the standard `test_avatar_db` was
prepared at `/tmp/umaxica-avatar-test-db-20261013.pgcustom`. The archive is mode `600`, 282,178
bytes, with SHA-256
`5cd5508faa64552ab8a3120db3e6d1a92edab248264923e5a803acbb092702bb`. `pg_restore --list` and full
archive decoding with `pg_restore --file /dev/null` both passed. A read-only Rails runner verified
that `Avatar` uses `test_avatar_db`; the observed counts were 1 Avatar, 4 AvatarGroups, 0 legacy
ownership periods, 1 Enterprise period, 0 Bureau periods, 0 transfers, 0 reservations, and 0
cutover markers. `POSTGRESQL_ISOLATED_TEST_RUN_ID` was unset. No restore, reset, migration, backfill,
or cutover-marker write was performed. The archive is only a recovery input; it does not authorize
any database mutation and must be refreshed if the database changes before a rehearsal.
