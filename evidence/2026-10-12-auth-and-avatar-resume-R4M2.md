# Authentication and Avatar resume verification

- Repository: `/home/global/workspace`
- Branch: `feature`
- Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`
- Worktree: pre-existing staged, unstaged, and untracked changes were preserved. No reset,
  clean, stash, push, production operation, or shared destructive database operation was used.
- Database target: the run-owned disposable PostgreSQL fleet described by
  `tmp/acceptance-isolated-20261010p8b-primary.json`; Podman was not required or used.

## Changes verified

The Avatar ownership-period source now normalizes the public `surface` argument before selecting
the concrete Enterprise or Bureau relation. The public source-selection test first reproduced the
symbol input failure with a PostgreSQL missing-join error and then passed after the smallest fix.

Sign-in phase refusal now obtains its fixed Japanese response from
`errors.messages.phase_violation_refused` with `locale: :ja` in both the shared flow-binding
support and the Org normal sign-in transaction. The public App MFA refusal test requires that
translation call and preserves the `409`, no-store response and exact body.

## Commands and results

The Avatar source Red run failed with `PG::UndefinedTable` for the missing Enterprise join when
`surface: :app` was supplied as a symbol. After normalization, the focused source test passed:

```text
2 runs, 6 assertions, 0 failures, 0 errors, 0 skips
```

The authentication slice covering App MFA refusal and Org normal passkey boundaries passed:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
POSTGRESQL_TEST_PREPARE_DATABASES=<the 20 manifest database names> \
bundle exec rails test \
  test/controllers/auth/app/in/challenges_controller_test.rb \
  test/controllers/auth/org/in/passkeys_controller_test.rb
```

Result: `30 runs, 259 assertions, 0 failures, 0 errors, 0 skips`.

The OTP and dead-identifier focused selection passed:

```text
199 runs, 2120 assertions, 0 failures, 0 errors, 0 skips
```

The Rails full gate passed with four workers:

```text
bundle exec rails test
15084 runs, 128057 assertions, 0 failures, 0 errors, 0 skips
```

The Vitest full gate passed:

```text
bun run test
99 test files passed, 1140 tests passed
```

Targeted RuboCop passed for the three authentication files and the previously changed Avatar
source/test files: the inspected files reported no offenses. `git diff --check` also passed for
the reviewed tracked files and the new evidence file.

## Limits and remaining work

These results do not close nine.md globally. Avatar Group semantic evidence, the P10b/P12b writer
and cutover work, full identifier consumer/DB transition, isolated committed-transaction role
lifecycle verification, host Alloy remount/runtime verification, and unresolved privacy-retention
policy remain separate dispositions. The current registry admission guard keeps the registry path
unreachable before the verified Avatar cutover; direct registry operation tests are not evidence of
cutover activation. No production data or external service was inspected or changed.
