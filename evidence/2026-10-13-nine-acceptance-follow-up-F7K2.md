# Nine acceptance follow-up

Date: 2026-10-13. Commit: `4828aeedd141b54163236672890799b9b01128c2`. The worktree contained the
follow-up initializer, tests and documentation described below. No commit or shared/production
cutover was performed. This supplements, rather than rewrites,
`2026-10-13-nine-independent-acceptance-N6A2.md`.

## Dispositions

- ID-4 remains open. Ordinary validation exists, but the previously reproduced `update_columns` path
  bypasses it. The user requested an explanation, not a new database immutability mechanism.
- The OTel processor now returns numeric `OpenTelemetry::SDK::Trace::Export::SUCCESS` from
  `force_flush` and `shutdown`, matching the installed SDK aggregation contract.
- The user accepted the observed JavaScript function/branch coverage shortfall for this delivery.
  `acceptance.md` records the scoped exception; thresholds and historical failed results are intact.
- Behavioral coverage was expanded by 22 Minitest cases. Broad route/purpose/provider coverage
  remains partially verified; successful suite counts alone do not establish that matrix.
- Isolated rebuild, restore and concrete cutover rehearsals passed as described below.
- Host Alloy execution, effective read-only bind verification and final privacy/retention policy
  remain open. Neither Docker, Podman nor Alloy was available in this environment.

## Behavior and telemetry checks

The real development initializer reproduced `ArgumentError: comparison of TrueClass with 0 failed`
on `OpenTelemetry.tracer_provider.force_flush`. After the two return-value changes, development
Rails runner with `OPEN_TELEMETRY=true` and all three `OTEL_*_EXPORTER=none` settings exercised an
in-memory exporter, flush timeouts nil/0/0.01 and shutdown successfully. Six synthetic
process/deliver notifications across APP/COM/ORG retained exactly the allowed action/mailer or
email.x_mailer span attributes. No actual email or external telemetry was sent. This does not
certify Alloy or every actual-delivery failure/retry sink. Configuration execution was checked
directly, not in Minitest.

New public-boundary tests:

- APP and COM MFA challenge controllers: safe GET/HEAD refusal preserves state, unusable bindings
  preserve state, and a phase-violation halt is absorbing on replay (six cases total).
- COM sign-up: twelve phase/binding/reload/stale-tab/terminal/audit/expiry cases, matching the
  existing APP integration contract. Visitor audit events intentionally use the existing client
  chronicle owner. This is email sign-up coverage, not a full social/telephone family proof.
- Avatar registry transfer: four ownership directions inject destination persistence failure, assert
  transaction rollback preserves ownership/period records, retry successfully, and verify idempotent
  replay. The injected failure is at the persistence collaborator; operation and transaction
  execution are real.

The focused controller run passed 25 tests / 324 assertions. The nine-file regression run covering
these additions, cutover/backfill/barrier and purge failure/concurrency passed 47 tests / 438
assertions, zero failures/errors/skips. Initial new-test failures were fixture preparation errors
(overlong moniker and wrong chronicle class), corrected before the passing run; they were not
production defects. Targeted RuboCop passed five Ruby files. `bun run test` passed 99 files and
1,140 tests.

The final full `bin/rails test` run passed 15,226 tests / 128,835 assertions, with zero
failures/errors/skips in 334.13 seconds. The repository knowledge checker passed with 69 documents
and this evidence record selected; `git diff --check` passed. These results include the new tests
and the initializer correction in the uncommitted worktree. An early postflight overlapped process
teardown and observed 43 remaining worker databases. After the test process exited with status 0,
the repeated read-only postflight verified all 20 parent identities and zero remaining worker
databases. No manual worker cleanup was performed.

Existing coverage additionally inspected/executed includes six-model normalized-contact creation,
six-model purge/reuse races and Client/Visitor/Operator cross-database partial purge failures. These
were not absent merely because the initial independent assessment had not certified their matrix.
Remaining unclosed coverage includes the complete authentication route/purpose/provider
safe/unsafe/callback matrix, every family audit/diagram edge, and the complete Avatar HTTP
actor/authority/Grant subject/capability matrix. No blanket acceptance is claimed for these.

## Isolated migration and recovery

Existing parent fleet `20261010p8b` remained intact. A separate disposable fleet `20261013n9a` was
created from template0 with a manifest recording database names, OIDs and owners. The existing
`scripts/postgresql-rebuild-isolated-test-fleet` ran twice successfully against only these new 20
databases. It validated scoped ownership and recreated 12 HMAC roles. Source migrations and test
preparation completed. Verify-only checks passed before and after the rehearsals.

`pg_dump --format=custom` and `pg_restore --exit-on-error` restored all 20 databases into a second
new fleet, `20261013n9r`, preserving original ownership and privileges. A committed synthetic
AppPreference retained its identity/public ID and sequence last_value/is_called after restore. The
first data probe needed reference-table defaults seeded; the corrected run passed. This was a small
synthetic dataset, not a production-volume recovery or timing claim.

While restored databases still depended on the source fleet's HMAC roles, the rebuild verify-only
guard correctly refused the foreign dependency before any destructive operation. Restore targets
were then removed only after matching their receipt OIDs, owners, comments and absence of active
connections. Source verification again passed for 20 databases and 12 roles. Source fleet n9a is
retained for inspection; dump/receipt artifacts are local ignored files, not evidence payloads.

On that new source fleet, real committed synthetic Avatar/AvatarGroup records exercised public
GroupBackfill dry-run, apply and replay; cutover refusal without writer quiescence; successful
cutover and idempotent replay; public-ID and concrete-period identity preservation; owner
resolution; and legacy-write rejection with SQLSTATE 55006. These passed. Actual shared-writer
quiescence, production data reconciliation and production activation were not performed.

Reproducibility identifiers: manifests `tmp/acceptance-isolated-20261010p8b-primary.json` and
`tmp/acceptance-isolated-20261013n9a.json`; local restore receipts under
`tmp/nine-dump-restore-20261013n9a`. Temporary runner probes were `/tmp/nine-dump-restore.rb` and
`/tmp/nine-cutover-rehearsal.rb`. These transient scripts are execution aids, not durable test
coverage. Rails test execution used `RAILS_ENV=test`, `PARALLEL_WORKERS=4`, the p8b manifest/run ID,
and all 20 manifest database names explicitly in `POSTGRESQL_TEST_PREPARE_DATABASES`.
