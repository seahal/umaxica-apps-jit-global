# ActionMailer span scrubber defense-in-depth

- Repository: `/home/global/workspace`
- Branch: `feature`
- Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`
- The worktree was already dirty with 239 changed paths before this evidence file was added.
  Existing staged, unstaged and untracked work was preserved.
- No CI job, Podman command, container recreation, production operation or shared-database
  destructive operation was used.

## TDD slice

The new regression test first ran against the existing scrubber and failed as intended: the
`email.subject` value was left unchanged (`10 runs, 15 assertions, 1 failure`). The failure was
observed after the complete run-owned test database scope was supplied; an earlier attempt with the
container's stale partial scope was rejected during preparation before loading tests.

The implementation now removes every `email.*` span attribute except the approved `email.x_mailer`
attribute, and removes `args` attributes at any span key depth. The existing ActionMailer
allowlist, Rails logger policy and Alloy defense-in-depth remain unchanged.

The focused Green command was:

```text
POSTGRESQL_TEST_PREPARE_DATABASES=<the 20 databases listed by tmp/acceptance-isolated-20261010p8b-primary.json> \
RAILS_ENV=test bundle exec rails test \
  test/unit/security/observability_span_scrubber_test.rb \
  test/unit/security/opentelemetry_initializer_test.rb
```

Result: `13 runs, 50 assertions, 0 failures, 0 errors, 0 skips`.

## Current Gate 2

Rails was run against the existing run-owned manifest
`tmp/acceptance-isolated-20261010p8b-primary.json` with four workers and the 20 manifest database
names in `POSTGRESQL_TEST_PREPARE_DATABASES`:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
POSTGRESQL_TEST_PREPARE_DATABASES=<the manifest's 20 database names> \
bundle exec rails test
```

Result: `15156 runs, 128351 assertions, 0 failures, 0 errors, 0 skips` in 335.967952 seconds.

Vitest:

```text
bun run test
```

Result: `99` files and `1140` tests passed in 12.96 seconds.

A read-only PostgreSQL catalog check after the Rails run reported
`run_owned_worker_databases=0 active_sessions=0`; the 20 run-owned parent databases were preserved.

## Static verification

- `bundle exec rubocop lib/observability_span_scrubber.rb test/unit/security/observability_span_scrubber_test.rb --force-exclusion` — 2 files, no offenses.
- `bin/rubocop` — 5,381 files, no offenses.
- `bundle exec erb_lint --lint-all` — 4,391 files, no errors.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` — 0 errors, 0 security warnings.
- `bin/bundler-audit` — no vulnerabilities.
- `scripts/check-repository-knowledge` — passed.
- `git diff --check` — passed.

This is current implementation evidence for the dirty worktree. It is not an independent
acceptance decision and does not establish host Alloy runtime behavior, production topology or any
of nine.md's separate operational cutover/privacy decisions.
