# SimpleCov Environment Verification Implementation Notes

## Context

- Original plan/spec: verify the SimpleCov setup end to end, starting from a single test worker. Get
  `bin/rails test` green first, then take a coverage measurement. Raising coverage was explicitly
  out of scope.
- Related decisions/docs/plans: `notes/implementation/2026-07-16-simplecov-phase-3.md` (superseded,
  see below), `README.md` "Testing", `.simplecov`, `test/test_helper.rb`.
- Implementation date: 2026-08-06

## Decisions Made During Implementation

- Decision: `.simplecov` is the authoritative coverage configuration. `test/test_helper.rb` now
  calls `SimpleCov.start` without a profile argument.
  - Why: `require "simplecov"` loads `.simplecov` (`simplecov/defaults.rb`), and its first line is
    `load_profile "rails"`. Passing `"rails"` to `start` applied the profile a second time. Measured
    effect of the second application: three duplicate filters (`test_frameworks`, `config/`, `db/`)
    and nothing else. Removing the argument keeps the configuration in one place.
  - Alternatives considered: moving the whole configuration into `test_helper.rb`. Rejected —
    SimpleCov 1.0 treats `.simplecov` as the configuration file and `start` in the test helper as
    the tracking trigger.
  - Follow-up needed: none.

- Decision: `COVERAGE=true` now raises when `PARALLEL_WORKERS` is set to anything other than `1`.
  - Why: `ActiveSupport::TestCase.parallelize` reads `ENV["PARALLEL_WORKERS"]` in preference to its
    `workers:` argument, so `parallelize(workers: 1)` alone did not pin a coverage run to one
    worker. `ParallelTestDatabaseCloner.install!` returns early at `workers <= 1`, so it would have
    prepared no per-worker clones and registered no `after_fork_hook` while Rails forked N workers —
    every worker sharing one unprepared test database. The combination was silently broken.
  - Alternatives considered: deleting `PARALLEL_WORKERS` from `ENV` inside the coverage branch.
    Rejected — silently rewriting the caller's environment hides the conflict instead of naming it
    (`no-silent-fallback`).
  - Follow-up needed: none. `.github/workflows/ci.yml` does not set `PARALLEL_WORKERS`.

- Decision: fixed the order-dependent failure in `OidcClientAssertionJwtTest` on the test side, in
  `test/services/enforcement_identifier_digest_test.rb`.
  - Why: `Rails.application.envs.reload` re-snapshots the entire environment
    (`ActiveSupport::EnvConfiguration#reload` does `@envs = ENV.to_h`) into the first backend of
    `Rails.app.creds`. `config/initializers/jwt.rb` installs local JWT signing material into `ENV`
    after that snapshot is first taken, so an unrestored reload publishes those keys through
    `Rails.app.creds` for the rest of the process. `JitSecurityJwtKeySource#value` falls back from
    live `ENV` to `Rails.app.creds`, so a later test that deletes a key from `ENV` still resolved
    it. `EnforcementIdentifierDigestTest` now restores the original snapshot in `teardown`.
  - Alternatives considered: changing `JitSecurityJwtKeySource` to fall back to
    `Rails.application.credentials` instead of `Rails.app.creds`, which would stop the credentials
    path from re-reading a stale copy of `ENV`. Equivalent in test and production, but it would drop
    `.env` support for JWT material in development, so it is a real behavior change and was not made
    under a task scoped to test verification.
  - Follow-up needed: the double-`ENV` lookup in `JitSecurityJwtKeySource#value`
    (`lib/jit_security_jwt_key_source.rb:15`) remains. Deleting a JWT variable from `ENV` at runtime
    still cannot take effect while a refreshed creds snapshot holds it. Worth promoting into the
    planning system if runtime key rotation is ever expected.

## Deviations From Plan

- Change: raising the parallel worker count for coverage runs was investigated but not attempted.
  - Why: the task asked to establish a working single-worker environment first, and that goal was
    met. The SimpleCov 1.0.3 `rails` profile sets `merge_subprocesses true`
    (`simplecov/profiles/rails.rb`), and the stable subprocess-serial naming that SimpleCov 1.0.x
    introduced removes the resultset pile-up that the 2026-07-16 note reacted to, so parallel
    coverage is worth revisiting on this version.
  - Risk: none taken; the current behavior is unchanged.
  - Follow-up: revisit parallel coverage against SimpleCov 1.0.3 as separate work.

## Review Notes

- Contradiction found and resolved: `notes/implementation/2026-07-16-simplecov-phase-3.md` records a
  91 percent line gate and a 70 percent branch gate. `.simplecov` currently sets a 95 percent line
  gate and no branch gate. `.simplecov` is authoritative; the 2026-07-16 note is historical and was
  left unchanged as a record of that decision.
- Stale documentation corrected: `README.md` claimed coverage reports are written to
  `coverage/rails/`. `.simplecov` does not override `coverage_dir`, so the destination is
  `coverage/`. Measured `coverage_path` is `<root>/coverage`.
- Measurement gotcha worth knowing: `merge_timeout` defaults to 600 seconds, so a narrow coverage
  run started within ten minutes of a full run merges with it and reports the full run's totals
  under a combined `command_name`. Clear `coverage/.resultset.json` before measuring a subset. This
  explains the partial-run figures questioned in earlier coverage batch notes.

- Tests run:
  - `bin/rails test` (16 processes) — 9,698 runs, 1 failure before the fix; the failure is the
    order-dependent `OidcClientAssertionJwtTest` case described above. A second run of the same
    unmodified tree was green, confirming order dependence rather than a deterministic break.
  - `bin/rails test --seed {1..5} test/services/enforcement_identifier_digest_test.rb test/services/oidc_client_assertion_jwt_test.rb`
    — reproduced the failure deterministically at seed 2 before the fix (18 runs, 28 assertions, 1
    failure); all five seeds green after (18 runs, 31 assertions).
  - `COVERAGE=true bin/rails test` (single worker) — 9,698 runs, 46,376 assertions, 0 failures, 0
    errors, 0 skips in 621.9s. Line 47,457 / 51,155 (92.77%), branch 10,984 / 15,256 (71.99%). Exit
    2 comes from the `.simplecov` 95 percent line gate, not from a test failure.
  - `COVERAGE=true PARALLEL_WORKERS=4 bin/rails test test/services/enforcement_identifier_digest_test.rb`
    — the new guard raises `ArgumentError` at `test/test_helper.rb`.
  - `bundle exec rubocop test/test_helper.rb test/services/enforcement_identifier_digest_test.rb` —
    no offenses.
- Tests not run: Vitest (`pnpm test`), RuboCop over the whole repository, Brakeman,
  `database_consistency`. This work touched Ruby test infrastructure and one README line only.
- Documentation promotion needed: none.
