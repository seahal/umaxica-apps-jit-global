# Environment-Test Retirement Verification

## Development Host Authorization observation

Revision: `1e239dedd3b62ed5f4e705868bfea93828532004` (full `git rev-parse HEAD`). The tracked
worktree was clean for this observation. Ignored local `.env.local` values supplied the development
environment; the file was not changed.

Booted `RAILS_ENV=development` with `bin/rails runner` and manually exercised
`ActionDispatch::HostAuthorization` using `Rails.application.config.hosts` and
`Rails.application.config.host_authorization`. A `Rack::MockRequest` sent `GET /` to a stub
endpoint; the probe did not invoke Minitest or Vitest.

- 17 private `*.localhost` origins returned HTTP 200.
- 17 configured browser-facing public hostnames returned HTTP 200, including `jp.umaxica.app`,
  `jp.umaxica.com` and `jp.umaxica.org`.
- The unconfigured `core-jp.umaxica.app` and `evil.example.com` returned HTTP 403.
- The command exited successfully. Bundler used a temporary workspace home because `/home/global`
  was not writable.

This is a point-in-time observation of the development configuration, not an automated test-suite
guard. The detailed behavior is described in `config/environments/development.rb`.

## Retirement change and retained behavior check

The worktree later contained uncommitted Step 4 changes against the same revision above: the three
environment-construction test files named in frozen `one.md`'s Environment test retirement module
were deleted with no replacement. The three current documents identified in that module now describe
the manual check and link to this record. `git diff --check` passed after those edits.

The retained application-behavior test `test/config/test_environment_edge_contract_test.rb` ran
through `scripts/test-isolated` against the verified isolated PostgreSQL manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`, with one worker and a unique Valkey run
namespace. Result: 13 tests, 68 assertions, zero failures, errors or skips. Its scoped Valkey
cleanup completed and found zero matching keys.

No Minitest or Vitest case was run to verify development environment construction. The retired
`test_environment_isolation_contract_test.rb` also contained database-safety reporting/catalog
cases; the frozen plan retires that mixed file without replacement, while the separate edge contract
and dedicated Valkey service tests remain. A comment in `test/test_helper.rb` still names the
deleted host-configuration consistency test; it was left unchanged because the selected testing rule
prohibits editing `test_helper.rb` while changing tests.
