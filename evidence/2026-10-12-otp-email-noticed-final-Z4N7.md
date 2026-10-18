# OTP email delivery fallback retirement

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD at verification: `8bd06dcd8261ed7697e23f1f0eace535254de1b3`
- Worktree: dirty with the OTP delivery implementation, tests, static baselines and ADR changes
  listed by `git status --short`; existing work was preserved. No reset, clean, stash, worktree, CI,
  Podman, production, shared-destructive operation or push was used.

## Change

The Email branch of `OtpAdapter.for` now selects `OtpEmailNotifierAdapter` directly for APP, COM and
ORG. The retired `OtpEmailAdapter`, `OtpEmailNotifierRollout` and their feature flags and tests were
removed. Existing Noticed, ActionMailer, interceptor, delivery-job and surface contracts were
retained. The architecture baseline was regenerated with `bin/rails architecture:baseline` after the
deleted files were found in the generated baseline.

## TDD and focused checks

The initial adapter expectation change produced four failures because the old adapter was still
returned (Red). After the smallest adapter change:

- `bundle exec rails test test/adapters/otp_adapter_test.rb` — 10 runs, 12 assertions, 0 failures, 0
  errors, 0 skips.
- Adapter/security collection — 41 runs, 367 assertions, 0 failures, 0 errors, 0 skips.
- Affected controller/integration collection — 123 runs, 2,963 assertions, 0 failures, 0 errors, 0
  skips.
- `bundle exec rails test test/tooling/architecture_baseline_test.rb` — 3 runs, 2,742 assertions, 0
  failures, 0 errors, 0 skips.

## Gate 2

The complete Rails command used the existing run-owned manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`, the twenty non-replica writer databases,
`RAILS_ENV=test`, `PARALLEL_WORKERS=4`, and `bundle exec rails test`. Result: 15,134 runs, 128,192
assertions, 0 failures, 0 errors, 0 skips, in 329.978810 seconds.

`bun run test` result: 99 test files and 1,140 tests passed in 12.93 seconds.

A read-only PostgreSQL catalog probe after Rails found 20 run-owned parent databases and 0 active
sessions for the run-owned database prefix.

## Static checks

- `bin/rubocop` — 5,377 files inspected, no offenses.
- `bin/brakeman` — 0 warnings and 0 errors.
- `bin/bundler-audit` — no vulnerabilities.
- `bun run check` — exit 0; formatting, lint, type checks, dead-code, and OpenAPI checks passed;
  existing Knip configuration hints were reported.
- `scripts/check-repository-knowledge` — passed.
- `git diff --check` — passed.

These are implementation and regression results for this worktree. They are not an independent
acceptance decision, and they do not close the remaining operational, host-runtime, privacy,
retention, legacy-identifier, historical rollback or user-excluded acceptance boundaries.
