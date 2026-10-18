# Resume Gate and Static Verification

Date: 2026-10-12

Repository: `/home/global/workspace`  
Branch: `feature`  
Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`  
Worktree: already dirty with 222 staged, unstaged or untracked paths; existing changes were
preserved. No reset, clean, stash, worktree, push, production operation or shared-database
operation was performed.

Following nine.md Sections 5.3, 16 and 14.2, the run-owned test manifest was prepared with all 20
writer databases. The first focused test invocation without the required preparation environment
was refused before tests because `PARALLEL_WORKERS` was missing and the databases still had pending
migrations. The corrected preparation command completed with exit status 0:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_TEST_PREPARE_DATABASES=<20 manifest database names> \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
bundle exec rails db:test:prepare
```

The focused restart sample then passed:

```text
bundle exec rails test test/models/dead_identifier_destroy_test.rb \
  test/operations/avatar_ownership_transfers_test.rb
35 runs, 188 assertions, 0 failures, 0 errors, 0 skips
```

The current full Rails gate used the same manifest and four workers:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_TEST_PREPARE_DATABASES=<20 manifest database names> \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
bundle exec rails test
```

Result: `15155 runs, 128326 assertions, 0 failures, 0 errors, 0 skips` in 334.240 seconds.
The required JavaScript gate `bun run test` passed with `99 files` and `1140 tests` in 13.09
seconds. The four newest worker receipts each record `cleanup_completed: true`; the manifest
contains 20 run-owned databases and no worker database entry.

Static and boot checks also passed:

- `bun run check` passed: format, lint, TypeScript, deadcode and OpenAPI validation/bundle checks.
- `bin/rubocop` passed for all 5,381 inspected files.
- `bundle exec erb_lint --lint-all` passed with no ERB errors.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` passed with zero warnings.
- `scripts/check-repository-knowledge` passed.
- A direct test-environment Rails server boot on loopback reached Puma `Listening` and was stopped
  locally after readiness.
- `bin/bundler-audit` passed with no vulnerabilities.
- `bun audit` reported one existing moderate advisory in `postcss-selector-parser@6.0.10`, and no
  dependency change was made.
- `git diff --check` passed.

This record is current verification evidence for the dirty worktree. It does not claim the
remaining D-11 committed-transaction matrix, P10b Group semantic decision, P12b operational
cutover/write barrier, held legacy identifier candidates, host Alloy runtime remount, or privacy
retention policy. No production, shared data, CI, Podman or external service was used.
