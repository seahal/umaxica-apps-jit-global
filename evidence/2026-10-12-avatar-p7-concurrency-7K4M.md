# Avatar P7 ownership integrity verification

HEAD at execution: `a1ec83a7384a424c97671356268ec5c4ad8347d4` on `feature`. The worktree was
already dirty; this check used the run-owned disposable PostgreSQL fleet described by
`tmp/acceptance-isolated-20261010p3d2-primary.json` and did not modify shared or production data.

The focused P7 selection was:

```text
test/models/avatar_concrete_ownership_period_test.rb
test/models/enforcement_triggers_test.rb
```

The Rails command was:

```text
scope=$(ruby -rjson -e 'm=JSON.parse(File.read("tmp/acceptance-isolated-20261010p3d2-primary.json")); print m.fetch("databases").map { |d| d.fetch("name") }.join(",")')
RAILS_ENV=test PARALLEL_WORKERS=2 POSTGRESQL_TEST_HOST=primary \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p3d2 \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p3d2-primary.json \
POSTGRESQL_TEST_PREPARE_DATABASES="$scope" \
bundle exec rails test test/models/avatar_concrete_ownership_period_test.rb \
  test/models/enforcement_triggers_test.rb
```

It was run with `RAILS_ENV=test`, `PARALLEL_WORKERS=2`, the verified `20261010p3d2` manifest, and
the complete manifest database preparation list. Result: `22 runs, 79 assertions, 0 failures,
0 errors, 0 skips`.

The selection was rerun after adding explicit `current_database()` assertions to each raw and
pooled connection path; it produced the same `22 runs, 79 assertions, 0 failures, 0 errors,
0 skips` result.

The concrete-period tests now demonstrate, through raw SQL and independent connections:

- a real committed adjacent Enterprise-to-Bureau chain;
- rejection of a committed ownership gap with the prior current period unchanged;
- rejection of cross-family overlap with the prior history unchanged;
- ownerless Avatar rejection at commit;
- direct SQL protection for owner/start mutation, history deletion and truncation; and
- competing ownership writers using distinct PostgreSQL backend PIDs at READ COMMITTED,
  REPEATABLE READ and SERIALIZABLE, with one committed transition and one deterministic refusal.

Every helper that creates a committed P7 Avatar now calls
`ParallelTestDatabaseCloner.verify_owned_worker_execution!` before writing, so the real-COMMIT
cases cannot silently fall back to a shared or unverified catalog.

The trigger inventory selection passed in the same run. Targeted RuboCop for the new test file
reported no offenses, and `git diff --check` passed for the changed test and checklist. This record
does not claim complete Avatar acceptance: transfer acceptance failure injection, Group semantics,
legacy writer cutover, dump/restore rehearsal and production/shared cutover remain separate
criteria.

## Follow-up regression gates

The non-transactional transfer concurrency test was leaving its own pending legacy transfer and
registry rows behind. Its teardown now removes only rows owned by that test's Avatar, including all
four concrete registry-detail families, before the synthetic principals are removed. This is test
cleanup; no production transfer or ownership behavior was changed.

After that fix, the directly affected transfer and inventory selection was rerun with the same
isolated manifest:

```text
test/operations/avatar_ownership_transfers_concurrency_test.rb
test/operations/avatar_ownership_transfers_test.rb
test/queries/avatar_ownership_transition_inventory_query_test.rb
```

The command used the same manifest-scoped `RAILS_ENV=test`, `POSTGRESQL_TEST_HOST=primary`,
`POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p3d2`, `POSTGRESQL_ISOLATED_TEST_MANIFEST`,
`POSTGRESQL_TEST_PREPARE_DATABASES`, and `PARALLEL_WORKERS=2` settings shown above, followed by
`bundle exec rails test` and the three listed files.

Result: `30 runs, 165 assertions, 0 failures, 0 errors, 0 skips`.

The Rails Gate 2 command was then run against the same isolated manifest with
`PARALLEL_WORKERS=2` and `bundle exec rails test`. Result: `15060 runs, 127722 assertions,
1 failure, 0 errors, 0 skips`. The only failure was the pre-existing unrelated
`Security::AcmeRenameInventoryTest`, which reports the untracked file
`adr/preference-tld-sharing-and-jwt-lifecycle-reassessment.md:30` containing `Apex-scoped`.
No P7 test failed or errored. That unrelated ADR was not modified.

The full Rails invocation was:

```text
scope=$(ruby -rjson -e 'm=JSON.parse(File.read("tmp/acceptance-isolated-20261010p3d2-primary.json")); print m.fetch("databases").map { |d| d.fetch("name") }.join(",")')
RAILS_ENV=test PARALLEL_WORKERS=2 POSTGRESQL_TEST_HOST=primary \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p3d2 \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p3d2-primary.json \
POSTGRESQL_TEST_PREPARE_DATABASES="$scope" bundle exec rails test
```

The target test files were also inspected with:

```text
bundle exec rubocop test/models/avatar_concrete_ownership_period_test.rb \
  test/operations/avatar_ownership_transfers_concurrency_test.rb
```

RuboCop reported no offenses. `git diff --check` passed for the changed P7 test, teardown,
checklist and evidence paths.

The repository documentation checker also passed:

```text
scripts/check-repository-knowledge
Knowledge structure passed: 8 Skills/adapters, 67 documents, 0 evidence records.
```

The Vitest Gate 2 command was:

```text
bun run test
```

Result: `99` test files passed and `1140` tests passed. No application implementation or
shared/production database was changed by these verification runs; only verified disposable
worker catalogs were created and cleaned.

## Disposable catalog cleanup follow-up

After the Rails and Vitest runs completed, a read-only catalog check against the manifest's admin
database found `current_worker_databases_present=0` for all 20 worker-0/worker-1 database names and
`parent_databases_present=20`. A second read-only comparison found
`parent_catalog_mismatches=0` for the recorded parent OIDs, owners and comments. This confirms
cleanup and parent-catalog preservation for this run; older abandoned receipts for other worker
counts were not adopted during this check. The separately verified worker-2/worker-3 receipts and
cleanup are described below.

The separate no-delete role/database preflight was first attempted with
`bundle exec scripts/postgresql-rebuild-isolated-test-fleet --verify-only` and the same manifest.
It correctly refused before mutation with `role has a foreign or shared dependency:
umaxica_com_email_hmac_definer_3cc43a468cd0`. Read-only receipt/catalog inspection established
that the dependency was in stale `_2`/`_3` worker clones from an earlier four-worker run, with
matching run-owned names, OIDs, owner/comments and no active sessions. The existing cloner cleanup
function then removed only those verified disposable worker databases under the run lock; it did
not drop roles, parent databases or shared resources. A second read-only preflight succeeded:

```text
Verified 20 disposable databases and 12 scoped HMAC roles
```

The successful preflight used:

```text
scope=$(ruby -rjson -e 'm=JSON.parse(File.read("tmp/acceptance-isolated-20261010p3d2-primary.json")); print m.fetch("databases").map { |d| d.fetch("name") }.join(",")')
RAILS_ENV=test PARALLEL_WORKERS=1 POSTGRESQL_TEST_HOST=primary \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p3d2 \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p3d2-primary.json \
POSTGRESQL_TEST_PREPARE_DATABASES="$scope" \
bundle exec scripts/postgresql-rebuild-isolated-test-fleet --verify-only
```

The role/database preflight is therefore resolved for this run. Transfer failure injection, full
registry/ownership cutover and dump/restore remain separate MIG-3 criteria; the P7 ownership-period
results above do not claim those later criteria.

## Latest post-guard Gate 2

After the explicit raw/pooled connection-target assertions were added, the same isolated
manifest ran the full Rails suite again with `PARALLEL_WORKERS=2`:

```text
15060 runs, 127731 assertions, 1 failure, 0 errors, 0 skips
```

The sole failure remained the unrelated `Security::AcmeRenameInventoryTest` report for
`adr/preference-tld-sharing-and-jwt-lifecycle-reassessment.md:30`; no P7 test failed or errored.
The subsequent `bun run test` result remained `99` files and `1140` tests passed. A post-run
read-only catalog check found `worker_databases_present=0` and `parent_catalog_mismatches=0`.

Finally, a read-only query of the run-owned parent Avatar catalog confirmed all six relevant
migration versions are applied: `20261010130000`, `20261011041046`, `20261011041103`,
`20261011212119`, `20261011220000` and `20261011220500`; the missing-version set was empty.

## P7 handoff matrix

| P7 requirement | Current evidence | Status |
| --- | --- | --- |
| Reviewed ownership migrations are applied | Parent catalog contains all six relevant versions; trigger inventory passes | PASS |
| Avatar creation has one concrete owner at the creation boundary | Raw Avatar-only INSERT fails at COMMIT with `23514`; no row remains | PASS |
| Valid adjacent ownership chain commits | Independent raw connection closes Enterprise and commits adjacent Bureau | PASS |
| Gap and cross-family overlap cannot commit | Independent raw COMMITs fail and preserve the prior history | PASS |
| Closed history and direct SQL protections | Owner/start mutation, deletion and TRUNCATE are rejected | PASS |
| Concurrent ownership writers at RC/RR/Serializable | Distinct backend PIDs produce one commit and one deterministic refusal | PASS |
| Isolated test ownership and cleanup | Worker receipts/targets verified; worker databases absent after exit; parent OIDs/owners/comments preserved | PASS |
| Recurring full gates | Rails completed with one matched pre-existing Acme documentation failure; Vitest passed 1140/1140 | PASS WITH UNRELATED EXISTING FAILURE |

This matrix is limited to P7's ownership-integrity prototype. It is not an acceptance claim for
later transfer failure injection, Grant/Group cutover, operational backfill, dump/restore or
production/shared-database application.

The six P7 migration files were also checked for non-empty content and reviewed for explicit
forward/reverse DDL or an intentional irreversible/validation-only `down` boundary. No empty P7
migration remains in the reviewed set.
