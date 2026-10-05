# app Secret persistence shape verification

Performed on 2026-10-03, approximately 21:53–22:15 UTC, against feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`. The worktree contained unrelated
concurrent changes and the uncommitted changes described here. Results apply to
this dirty worktree, not to the committed SHA alone.

## Refined shape

The approved direction is refined in
`plans/analysis/app-secret-persistence-shape-proposal.md`:

- Zenith `claimed_at` records irreversible acceptance. No new `consumed_at`
  duplicates acceptance or the independent successful Ticket commit.
- Issuance state and reserved count derive from count and fact timestamps. Zero
  count is terminal omission with no expiry or delivery facts. Positive reservation
  expires at equality with its deadline.
- A and R have explicit writer-time predicates and a common Client-lock order.
  Their complete implementation across capacity-changing operations is pending.
- The outbox contains explicit actor type, id, and immutable public reference,
  with optional actual job execution identity. The actor triple is wholly present
  or absent and uses the existing Client/Chronicle convention.
- Ticket receipt requires a successful root-token reference and commit timestamp;
  failure attempts are not receipt rows. Canonical login integration is pending.

## Disposable database boundary

Two independently created, task-owned fleets were used:
`codex_integrity_20261003secret_*` for legacy-snapshot rebuild, and
`codex_integrity_20261003secretfresh_*` for fresh generated-schema loading.
Each contains 20 databases. OID, owner, hostname, port, and the identity comment
were recorded in task manifests and validated by the existing DatabaseSafety guard.
No existing normal test, shared development, or production database was selected.
The inherited guard requires a September 24 identity comment; actual creation
occurred on October 3. That comment is not represented as the creation date.

Temporary orchestration files under `/tmp` selected the repository's existing
isolated-database mechanism. They were not added as application infrastructure.
No DDL was implemented outside Rails migrations; database creation provisioned
only these new disposable fleets.

## Executed checks

The following commands ran through `bundle exec ruby
/tmp/umaxica-secret-db-task.rb`, which executes `bin/rails` against the rebuild fleet:

- `db:schema:load`: PASS, loading the then-current legacy snapshots into new databases.
- `db:migrate:app_zenith`: PASS after revising composite-FK declaration to occur
  inside new-table creation. The first attempt failed Strong Migrations and rolled
  back; the safety check was retained. Only the old app Secret credential,
  credential-kind, and credential-status tables were dropped by this migration.
- `db:migrate:app_ticket`: PASS, including the new success-receipt table and
  another agent's pending credential-ceremony migration.
- `db:migrate:com_ticket db:migrate:org_ticket`: PASS on the disposable fleet,
  applying another agent's pending migrations to permit test boot. This is not a
  claim that this Secret slice changed com/org behavior or verified their regressions.
- `test test/models/client_secret_issuance_test.rb`: Red was five missing-class
  errors after environment preparation succeeded. Initial Green was 5 tests,
  18 assertions, no failures, errors, or skips.
- `test test/models/client_secret_issuance_test.rb
  test/values/client_secret_issuance_count_value_test.rb`: final PASS, 15 tests,
  103 assertions, no failures, errors, or skips. An earlier combined run failed
  seven tests during unrelated legacy fixture loading; pure count tests now
  explicitly select no fixtures. No assertions were skipped or mocked.
- `db:schema:dump:app_zenith db:schema:dump:app_ticket`: PASS. Dumps were generated,
  not hand edited. Ticket output also contains another agent's applied migrations.
- `db:verify_no_schema_drift`: FAIL, detecting uncommitted generated differences
  in app Ticket/Zenith, com Ticket/Zenith, and org Ticket. The task dumps all schemas.
  com/org Ticket differences include the other agent's intentional migrations;
  com Zenith changes are PostgreSQL expression serialization. No schema-drift gate
  was weakened and no commit was created to conceal the failure.
- `runner /tmp/umaxica-secret-schema-check.rb`: PASS, checking new-table presence,
  old kind/status and duplicate-state absence, and five actual actor CHECK cases.
  Completely absent and complete Client actors were accepted; partial actor triples
  and an Operator actor were rejected by PostgreSQL. All inserted rows were rolled
  back. The first diagnostic attempt stopped on deprecated `connection`; it was
  corrected to `lease_connection` without disabling deprecation enforcement.

Fresh build ran through `bundle exec ruby
/tmp/umaxica-secret-fresh-db-task.rb`:

- `db:schema:load`: PASS into the separately provisioned empty fleet from generated
  dumps. This verifies the repository's schema-load construction path, not replay
  of every historical migration from an empty database.
- `runner /tmp/umaxica-secret-fresh-schema-check.rb`: PASS, repeating the new-table,
  old-state removal, and five rolled-back PostgreSQL actor-shape checks.

`bundle exec rubocop` on the two new migrations, issuance model, issuance test, and
count test: PASS, 5 files with no offenses. `git diff --check`: PASS.

## Limits

The old ClientSecretCredential Ruby implementation, fixtures, routes, and callers
have not yet been replaced by this slice. The new DDL must not be applied to an
ordinary shared checkout database as though application cutover were complete.
The destructive rebuild is intentionally irreversible and does not restore old
Secret values. Recreate only an approved disposable database for recovery; no
shared database reset is authorized.

Issuance creation/confirmation transactions, atomic claim, canonical receipt
writing, Chronicle delivery, purge ordering, API/UI integration, browser behavior,
and com/org regressions remain unverified for this new persistence shape. No full
implementation completion, production safety, or deployment readiness is claimed.
