# Isolated test fleet retirement

- Date: 2026-10-20
- Commit: `2b23e9d20c61c695a5eb2353cbca70f9d900d3f4`
- Worktree: uncommitted retirement changes affected these results. Pre-existing changes in
  `Gemfile`, `Gemfile.lock`, `app/models/member.rb` and `test/models/association_contract_test.rb`
  were present and preserved.
- Scope: [accepted specification](../specs/retire-isolated-test-fleet/spec.md).

## Observed results

- `RAILS_ENV=test bundle exec rails runner` booted successfully. An ERB/YAML comparison of current
  `config/database.yml` against `git show HEAD:config/database.yml`, with normal test settings,
  produced equal effective configuration for all environments. All 62 effective test connections
  passed `DatabaseSafety.verify!`. Development and retired `codex_integrity_*` targets were
  rejected.
- Public `DatabaseTasks.with_temporary_pool_for_each(env: "test")` inspection reported no pending
  migrations. No schema reconstruction/reset was needed.
- `PARALLEL_WORKERS=1 bin/rails test` with these five files passed: 44 runs, 203 assertions, 0
  failures/errors/skips, seed 42831: `test/models/avatar_concrete_ownership_period_test.rb`,
  `test/models/avatar_transfer_reservation_test.rb`,
  `test/operations/avatar_moniker_writer_operation_test.rb`,
  `test/operations/avatar_ownership_transfers_concurrency_test.rb`,
  `test/jobs/avatar_retention_purge_test.rb`. This includes real COMMIT and independent-connection
  cases without an isolated manifest/receipt.
- `PARALLEL_WORKERS=1 bin/rails test test/config/test_environment_edge_contract_test.rb --include /database/`
  passed: 9 runs, 60 assertions, 0 failures/errors/skips, seed 12839. These were existing cases; no
  environment-construction test was added.
- A preliminary rollback-scoped retention case also passed: 1 run, 6 assertions, no failures/errors.
- For those test commands, `POSTGRESQL_TEST_PREPARE_DATABASES` was supplied to the child process
  from its existing line in `.env.container.devcontainer`. The inherited process value was stale:
  the first attempt rejected retired `test_app_ticket_db`, `test_com_ticket_db` and
  `test_org_ticket_db` before migration. No persistent environment file was changed.
- `PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium bun run test:e2e:rails e2e/rails/auth-public.spec.ts`
  passed: 1 Chromium case, 5.0 s. Bootstrap verified 65 live pools against ordinary configured test
  targets, real CSRF, test adapters and Valkey reachability. Shutdown reported scoped Valkey
  cleanup, closed database connections and stopped Puma.
- The first browser attempt without the executable override reached server readiness but failed
  because the Playwright-managed Chromium executable was absent. Its server still stopped and
  reported scoped cleanup. The successful retry used the already installed system Chromium.
- Holding `tmp/parallel-test-databases.lock` with `fcntl.flock` and invoking the real Minitest and
  browser commands made each exit 1 with the concurrent-use refusal, before tests/HTTP service.
- `RAILS_ENV=development RACK_ENV=test ruby scripts/e2e/server.rb` refused non-test admission.
- RuboCop: 10 changed Ruby/Rake files inspected, no offenses. Ruby syntax checks passed. Oxfmt
  checks passed for the five current documentation/specification files. `git diff --check` passed.
- A source search under `lib`, `config`, `scripts` and `test` found no isolated PostgreSQL variable,
  old database prefix, worker-receipt verifier or isolated lifecycle consumer.
- Read-only PostgreSQL catalog queries before and after verification reported 1,388 `test_*`
  databases and 372 `codex_integrity_*` databases. Counts alone are not identity evidence. No
  database or cluster role was created/dropped by these serial tests or browser verification, and no
  old manifest/receipt file was deleted. The real-COMMIT tests wrote synthetic ordinary test data
  and retained their existing cleanup behavior.

## Acceptance and limits

- AC-1: configuration equality and effective-target checks passed.
- AC-2: executable-consumer search passed; the isolated rebuild command is removed locally.
- AC-3: the five-file Avatar collection passed on ordinary databases with one process.
- AC-4: browser rendering, startup, failure cleanup, non-test refusal and lock contention passed.
- AC-5: current database/test/browser operations docs and the replacement ADR were updated.

The full Rails suite, actual parallel-worker execution, CI, deployment and destructive recovery were
not run. Ordinary worker schema caching still does not reset committed test data. Existing isolated
resources remain for separately approved inventory/cleanup. This record does not claim that
Rails-standard schema loading can reproduce migration-created data or function ownership.
