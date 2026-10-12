# Resume Gate after writer-scope alignment

- Repository: `/home/global/workspace`
- Branch: `feature`
- Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`
- The worktree was already dirty and all existing staged, unstaged and untracked paths were
  preserved. No reset, clean, stash, worktree, push, CI job, Podman run, production operation or
  shared-database operation was used.

The local test-preparation source was aligned to the twenty non-replica writer databases. The
focused configuration contract passed separately with `15 runs, 66 assertions, 0 failures, 0
errors, 0 skips`.

## Gate commands and results

Rails was run against the existing run-owned twenty-database manifest with four workers:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres POSTGRESQL_TEST_PREPARE_DATABASES=<the manifest's 20 writer databases> bundle exec rails test
```

Result: `15155 runs, 128338 assertions, 0 failures, 0 errors, 0 skips` in 334.271947 seconds.

Vitest was then run locally:

```text
bun run test
```

Result: `99` test files and `1140` tests passed in 12.86 seconds.

These are current local Gate 2 results for this dirty worktree. They do not close the outstanding
operational, host-runtime, privacy-retention, legacy-identifier, or historical migration rollback
boundaries listed in nine.md, and they are not an independent acceptance decision.
