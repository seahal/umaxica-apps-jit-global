# Withdrawal cycle verification

Date: 2026-10-19 HEAD: `ff58ff28125fafe405dc76809f6498b64d69e627` Worktree: pre-existing changes in
`AGENTS.md`, `Gemfile`, `Gemfile.lock`, `bun.lock`, and `package.json` were present; the withdrawal
and documentation changes in this worktree were also uncommitted.

## Focused checks

The following checks passed with the current test database configuration after removing the stale
shell-level `POSTGRESQL_TEST_PREPARE_DATABASES` value:

```text
env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails test test/services/withdrawal_lifecycle_test.rb
24 tests, 74 assertions, 0 failures, 0 errors, 0 skips

env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails test \
  test/services/withdrawal_lifecycle_test.rb test/integration/withdrawal_ceremony_session_test.rb
29 tests, 97 assertions, 0 failures, 0 errors, 0 skips

env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails test \
  test/integration/withdrawal_ceremony_reentry_test.rb
6 tests, 68 assertions, 0 failures, 0 errors, 0 skips

env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails test \
  test/models/concerns/withdrawable_test.rb
35 tests, 82 assertions, 0 failures, 0 errors, 0 skips
```

## Whole-suite check

The serial command below was intentionally interrupted after the dominant existing failures had been
identified:

```text
env -u POSTGRESQL_TEST_PREPARE_DATABASES -u POSTGRESQL_ISOLATED_TEST_RUN_ID \
  -u POSTGRESQL_ISOLATED_TEST_MANIFEST PARALLEL_WORKERS=1 RAILS_ENV=test bin/rails test
```

At interruption it reported `9920 runs, 79167 assertions, 3 failures, 384 errors, 0 skips`. The
recurring errors were outside this change, principally a pre-existing positional/keyword argument
mismatch in `BaseStepUpAdmissionIssuer.persist_session!` and related Step-Up helpers, plus tests
that require run-owned parallel worker receipts. A prior parallel invocation was also invalid as
evidence because it ran without an isolated worker manifest and contaminated shared test databases.
No whole-suite result is claimed as a pass.

## Boot validation

`bin/rails runner` validated the timing policy defaults and startup guard: standard durations were
`3600`, `604800`, and `2678400` seconds; production override presence raised; and a valid
development override produced `1`, `2`, and `3` seconds. The Rails initializer is therefore a
boot-time guard, not evidence that persisted withdrawal deadline columns are implemented.

The pure value-object contract also passed:

```text
env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails test \
  test/values/umaxica/withdrawal/timing_policy_value_test.rb
3 tests, 14 assertions, 0 failures, 0 errors, 0 skips

bundle exec rubocop app/values/umaxica/withdrawal/timing_policy_value.rb \
  test/values/umaxica/withdrawal/timing_policy_value_test.rb \
  config/initializers/withdrawal_timing_policy.rb
3 files inspected, no offenses detected
```

## Additional focused checks

These checks ran against the same full HEAD `ff58ff28125fafe405dc76809f6498b64d69e627` with the
worktree still containing the unrelated pre-existing changes listed above and the cycle changes.

- `env -u POSTGRESQL_TEST_PREPARE_DATABASES -u POSTGRESQL_ISOLATED_TEST_RUN_ID -u POSTGRESQL_ISOLATED_TEST_MANIFEST PARALLEL_WORKERS=1 RAILS_ENV=test bin/rails test test/integration/withdrawal_ceremony_session_test.rb`
  — 7 tests, 34 assertions, 0 failures, 0 errors. APP and COM `status` ceremonies were rejected for
  irreversible termination and remained active.
- `env -u POSTGRESQL_TEST_PREPARE_DATABASES -u POSTGRESQL_ISOLATED_TEST_RUN_ID -u POSTGRESQL_ISOLATED_TEST_MANIFEST PARALLEL_WORKERS=1 RAILS_ENV=test bin/rails test test/services/withdrawal_lifecycle_test.rb`
  — 25 tests, 78 assertions, 0 failures, 0 errors. Active retention holds and Enforcement purge
  blocks prevented early termination without a terminal marker.
- `env -u POSTGRESQL_TEST_PREPARE_DATABASES -u POSTGRESQL_ISOLATED_TEST_RUN_ID -u POSTGRESQL_ISOLATED_TEST_MANIFEST PARALLEL_WORKERS=1 RAILS_ENV=test bin/rails test test/jobs/retention_purge_job_test.rb`
  — 19 tests, 78 assertions, 0 failures, 0 errors. A retained-model failure was reported, later
  models were still attempted, and the job re-raised the failure.
- `env -u POSTGRESQL_TEST_PREPARE_DATABASES -u POSTGRESQL_ISOLATED_TEST_RUN_ID -u POSTGRESQL_ISOLATED_TEST_MANIFEST PARALLEL_WORKERS=1 RAILS_ENV=test bin/rails test test/jobs/dead_identifier_retention_test.rb`
  — 7 tests, 53 assertions, 0 failures, 0 errors. A later Contact deadline deferred parent
  completion and recorded the `identifier_retention` reason.

These are focused sub-slice results only. Persisted timing deadlines, Passkey constraints/outbox,
Avatar preparation, browser UI behavior, production worker execution, and legal/external-storage
contracts remain unverified or decision-blocked.

## Queue configuration check

The environment/tooling check was run outside Minitest, as required for Solid Queue setup:

```text
RAILS_ENV=development bin/jobs check
Solid Queue configuration is valid. (exit 0)
```

`RAILS_ENV=production bin/jobs check` could not reach the queue validation because the current shell
lacks the required `UMAXICA_RUNTIME_ROLE` boot variable (`KeyError`). This is an environment
readiness limitation, not evidence that production scheduling or workers are healthy. Actual
production worker execution remains unverified.

## Final focused verification after fixture and constraint updates

The latest changed-test batch was run serially with the repository's current test database manifest
(`POSTGRESQL_TEST_PREPARE_DATABASES` read from `.env`, `PARALLEL_WORKERS=1`):

```text
1081 tests, 11029 assertions, 0 failures, 0 errors, 0 skips
```

The dedicated Passkey slot, audit-delivery, sanitizer, and timing-policy group also passed:

```text
31 tests, 119 assertions, 0 failures, 0 errors, 0 skips
```

That group includes PostgreSQL checks executed with model validation bypassed: out-of-range slots
are rejected by the CHECK constraint and owner-slot duplicates are rejected by the unique index for
APP, COM, and ORG. `test/operations/auth_method_guard_concurrency_test.rb` was rerun after a
style-only block-parameter cleanup (`1 test, 7 assertions, 0 failures, 0 errors`).

Repository loading and migration state checks also passed:

```text
RAILS_ENV=development bin/rails zeitwerk:check
All loaded directories reported OK (only the existing optional rails_db warning remained).

RAILS_ENV=development bin/rails db:migrate:status
All 11 cycle migrations (APP/COM/ORG deadlines, slots, outboxes, and check validation) reported up.
```

Syntax validation passed for every changed Ruby test file. Production RuboCop passed for the 32
changed application Ruby files and the new operation/job/outbox/value tests. A scoped
`git diff --check` over cycle paths was clean; the unscoped command still reports a trailing-space
line in the pre-existing `Gemfile` dependency edit.

The earlier serial whole-suite run remains a negative/limited result, not a pass:

```text
15547 tests, 132024 assertions, 1 failure, 61 errors, 0 skips
```

It was executed before the final fixture corrections and included repository-environment failures
(run-owned worker receipts and RP cell check constraints) as well as stale Passkey fixture
expectations. The full suite was not repeated after the final focused corrections; no repository-
wide green claim is made. `RAILS_ENV=development bin/jobs check` passed, while the production check
stopped at the shell's missing `UMAXICA_RUNTIME_ROLE`; production worker execution and external
storage/runtime retention remain unverified.

The worktree was still dirty during all checks. The tested HEAD was
`ff58ff28125fafe405dc76809f6498b64d69e627`; no unrelated staged, unstaged, or untracked changes were
removed.

## Schema-drift check

The repository-required command was run outside Minitest:

```text
RAILS_ENV=development bin/rails db:verify_no_schema_drift
```

It failed because the repository reports drift in twelve committed structure dumps (`app_setting`,
`app_zenith`, `avatar`, `chronicle`, `com_setting`, `com_zenith`, `occurrence`, all three
`op_base_*`, `org_setting`, and `org_zenith`). The APP/COM/ORG Zenith dumps do contain the
corresponding new slot, outbox, deadline, index, constraint, and migration-version entries; the
checker compares the whole repository and cannot isolate this cycle from the pre-existing dump
changes. No broad dump regeneration or unrelated dump rewrite was performed.

## Post-review focused verification

After reconciling the timing policy with `two.md` (development/test may omit individual override
variables and receive the standard for that duration), the following current-HEAD checks passed:

```text
TEST_DBS="$(grep '^POSTGRESQL_TEST_PREPARE_DATABASES=' .env | cut -d= -f2-)" \
PARALLEL_WORKERS=1 POSTGRESQL_TEST_PREPARE_DATABASES="$TEST_DBS" \
  bin/rails test \
  test/values/umaxica/withdrawal/timing_policy_value_test.rb \
  test/operations/passkey_registration_slot_operation_test.rb \
  test/jobs/passkey_audit_delivery_job_test.rb \
  test/services/withdrawal_lifecycle_test.rb \
  test/integration/withdrawal_lifecycle_security_test.rb \
  test/resolvers/oidc_authorize_request_resolver_test.rb \
  test/controllers/base/com/oauth/authorizations_controller_test.rb \
  test/controllers/base/org/oauth/authorizations_controller_test.rb
59 tests, 211 assertions, 0 failures, 0 errors, 0 skips

bundle exec rubocop --force-exclusion \
  app/values/umaxica/withdrawal/timing_policy_value.rb \
  config/initializers/withdrawal_timing_policy.rb \
  test/values/umaxica/withdrawal/timing_policy_value_test.rb
3 files inspected, no offenses detected

RAILS_ENV=development bin/rails zeitwerk:check
All loaded directories reported OK.

RAILS_ENV=development bin/jobs check
Solid Queue configuration is valid.
```

The test database manifest was read from the current `.env`; the worktree remained dirty and the
full suite was not rerun after this focused review. Production worker execution and the whole-repo
schema-drift check remain unverified/blocked as described above.

The withdrawal lifecycle and security subset was then rerun after moving the confirmation DB-clock
read inside the locked transaction:

```text
27 tests, 93 assertions, 0 failures, 0 errors, 0 skips
```

`bundle exec rubocop --force-exclusion app/services/withdrawal_lifecycle.rb` also passed.

## Passkey delivery and surface-bound registration follow-up

The current worktree remained dirty with 179 changed/staged/untracked paths; no unrelated work was
removed. The checks below ran against HEAD `ff58ff28125fafe405dc76809f6498b64d69e627` plus the
uncommitted cycle changes:

```text
env -u POSTGRESQL_TEST_PREPARE_DATABASES \
  POSTGRESQL_TEST_PREPARE_DATABASES="$(grep '^POSTGRESQL_TEST_PREPARE_DATABASES=' .env | cut -d= -f2-)" \
  PARALLEL_WORKERS=1 bin/rails test \
  test/operations/passkey_registration_operation_test.rb \
  test/jobs/passkey_audit_delivery_job_test.rb
8 tests, 48 assertions, 0 failures, 0 errors, 0 skips

bundle exec rubocop --force-exclusion \
  app/jobs/passkey_audit_delivery_job.rb \
  app/operations/passkey_registration_operation.rb \
  test/jobs/passkey_audit_delivery_job_test.rb \
  test/operations/passkey_registration_operation_test.rb
4 files inspected, no offenses detected
```

The delivery test demonstrates that a conflicting Chronicle event remains unacknowledged while a
later event in the same source is delivered, and the job still raises for retry visibility. The
registration test demonstrates that a Visitor actor cannot register a ClientPasskey. The scoped
`git diff --check` for the changed files and notes was clean.

## Combined authentication and delivery verification

The following current-HEAD boundary set also passed with the dirty worktree preserved:

```text
bin/rails test \
  test/controllers/base/oauth_oidc_authority_test.rb \
  test/controllers/base/com/oauth/authorizations_controller_test.rb \
  test/controllers/base/org/oauth/authorizations_controller_test.rb \
  test/controllers/base/app/oidc/callbacks_controller_test.rb \
  test/operations/passkey_registration_operation_test.rb \
  test/jobs/passkey_audit_delivery_job_test.rb
80 tests, 558 assertions, 0 failures, 0 errors, 0 skips
```

The first attempted command referenced a non-existent APP controller test path and stopped before
loading tests; it was corrected to the repository's actual APP OIDC callback path and the command
above is the authoritative result.

## Current runtime/static checks

Against the same dirty worktree and HEAD `ff58ff28125fafe405dc76809f6498b64d69e627`:

```text
RAILS_ENV=development bin/jobs check
Solid Queue configuration is valid.

RAILS_ENV=development bin/rails zeitwerk:check
All loaded directories reported valid (rails_db remains an optional warning).

ruby -c app/jobs/passkey_audit_delivery_job.rb
ruby -c app/operations/passkey_registration_operation.rb
Syntax OK for both files.
```
