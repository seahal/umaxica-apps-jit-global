# Full gate recheck

## Scope

This record covers a verification recheck of the current dirty worktree. It does not claim that
the integrated implementation is complete. No application source, migration, or database state was
changed by the verification commands recorded here.

## Repository state

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD: `a1ec83a7384a424c97671356268ec5c4ad8347d4`
- Worktree: pre-existing staged, unstaged, and untracked changes were present and preserved.
- Rails database target: run-owned disposable PostgreSQL databases described by
  `tmp/acceptance-isolated-20261010p3d2-primary.json`.
- The test manifest contained 20 databases and was used with four Rails workers.

## Commands and results

### Rails

```text
scope=$(ruby -rjson -e 'm=JSON.parse(File.read("tmp/acceptance-isolated-20261010p3d2-primary.json")); print m.fetch("databases").map { |d| d.fetch("name") }.join(",")')
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p3d2 POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p3d2-primary.json POSTGRESQL_TEST_PREPARE_DATABASES="$scope" bundle exec rails test
```

The isolated preparation completed and Rails ran 15,060 tests with 127,717 assertions. The result
was one failure, zero errors, and zero skips. The failure was the existing
`Security::AcmeRenameInventoryTest` check for the phrase `Apex-scoped` in the untracked
`adr/preference-tld-sharing-and-jwt-lifecycle-reassessment.md`; no change was made to that ADR.

### Vitest

```text
bun run test
```

Result: 99 test files passed and 1,140 tests passed.

`bun run test:coverage` was not used as a completion claim in this record. An earlier run executed
all 1,140 tests but exited non-zero because the existing global branch and function coverage
thresholds were below 99%; thresholds were not lowered.

## Interpretation

The isolated full Rails and ordinary Vitest executions are useful current evidence, but they do
not close the remaining implementation and cutover criteria in `nine.md`. In particular, the
identifier consumer/DB transition, unresolved Group semantics, final Avatar writer cutover and
legacy write barrier activation, and their corresponding acceptance evidence remain open.
