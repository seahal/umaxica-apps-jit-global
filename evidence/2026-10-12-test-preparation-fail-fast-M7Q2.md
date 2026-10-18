# Test preparation scope fail-fast

- Repository: `/home/global/workspace`
- Branch: `feature`
- Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`
- The worktree was already dirty. The status count was 234 paths at the end of this check; all
  unrelated staged, unstaged and untracked changes were preserved.
- No CI job, Podman command, production operation, shared-database reset, drop or migration was
  used.

## TDD slice

The preparation contract was first changed to require an incomplete writer scope to fail. The
focused test then failed with one assertion because `prepare_database_names!` accepted the subset
`test_primary_db`. The implementation was changed to derive the verified writable databases from
the effective test configurations, exclude replica configurations, and reject any missing writer.

The focused Green command was:

```text
POSTGRESQL_TEST_PREPARE_DATABASES=<all twenty non-replica writer names> bundle exec rails test \
  test/config/test_environment_isolation_contract_test.rb \
  test/config/test_environment_edge_contract_test.rb
```

Result: `28 runs, 137 assertions, 0 failures, 0 errors, 0 skips`.

The stale four-database preparation command was also executed:

```text
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db \
RAILS_ENV=test bundle exec rails db:test:prepare
```

It exited non-zero before the migration loop with an explicit list of the missing verified writer
databases. No schema mutation occurred in that invocation.

## Verification

- `bin/rubocop lib/umaxica/test_environment/database_safety.rb test/config/test_environment_isolation_contract_test.rb test/config/test_environment_edge_contract_test.rb` — 3 files, no offenses.
- `ruby -c` on the changed Ruby source and both changed tests — all `Syntax OK`.
- Rails full Gate 2, using the run-owned twenty-database manifest and four workers — `15155 runs, 128349 assertions, 0 failures, 0 errors, 0 skips` in 346.959799 seconds.
- `bun run test` — `99` files and `1140` tests passed in 12.98 seconds.
- A read-only PostgreSQL catalog query after the Rails run reported `run_owned_worker_databases=0`
  and `active_sessions=0`; the twenty run-owned parent databases remain separately owned and were
  not removed.
- `bin/rubocop` — 5,381 files inspected with no offenses.
- `bundle exec erb_lint --lint-all` — 4,391 files linted with no errors.
- `bin/brakeman` — 0 errors and 0 security warnings.
- `bin/bundler-audit` — no vulnerabilities.
- `git diff --check` — passed.
- `scripts/check-repository-knowledge --base ccceabd05d2e3a8f923ce398046f99d026a5b78e9` for the affected paths — passed.

The Rails and Vitest results are current local Gate 2 evidence for this dirty worktree. They are
not an independent acceptance decision and do not claim CI, host-container recreation, production,
or the remaining nine.md operational holds.
