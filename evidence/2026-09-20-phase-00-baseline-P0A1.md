# Phase 00 baseline verification

Date: 2026-09-20

## Scope

Phase 00 was run against the existing checkout without changing application source code,
tests, migrations, configuration, or the pre-existing worktree changes.

- Branch: `feature`
- HEAD: `52efa31df2a28763ad405f604bb3ef0c416b3b93`
- Required environment file: present at `/home/global/workspace/.env.devcontainer.example`
- `config/credentials/test.key`: present; contents were not displayed
- Required PostgreSQL/Valkey variable names: present; values were not displayed

## Required preflight

Command:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'
```

The first run stopped before the Valkey checks because `lib/umaxica/valkey/settings.rb` calls
`Array#index_with` while the standalone script did not require
`active_support/core_ext/enumerable`.

The minimal fix was to require that existing ActiveSupport extension from the script. The original
command was then rerun unchanged and completed successfully:

- PostgreSQL test target: PostgreSQL 17.7; 646 `test_*` databases visible
- Valkey `rate_limit`: PING `PONG`; version 7.2.4
- Valkey `auth_state`: PING `PONG`; version 7.2.4

The initial error was a preflight-script loading defect, not a PostgreSQL or Valkey availability
failure.

## Rails tests

Focused test:

```text
PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/token_csrf_test.rb
```

Result: 1 run, 3 assertions, 0 failures, 0 errors, 0 skips.

Full suite:

```text
bin/rails test
```

Result: 11,331 runs, 72,149 assertions, 0 failures, 0 errors, 5 skips; exit code 0.

## Phase status

PostgreSQL, Valkey, focused Rails tests, the full Rails suite, and the exact required preflight
command are operational in the core service environment. Phase 00 is complete. No Phase 01
implementation was started.

## Revalidation after subsequent local slices

The Phase 00 environment and baseline were rechecked on the same branch and HEAD after the
existing local implementation slices had advanced. No application, test, migration, or
configuration file was changed during this revalidation.

- Branch: `feature`
- HEAD: `52efa31df2a28763ad405f604bb3ef0c416b3b93`
- Worktree before verification: 257 tracked paths changed and 75 untracked paths; all were
  preserved
- `config/credentials/test.key`: present; contents were not displayed
- Required variable names in `.env.devcontainer.example`: present; values were not displayed
- PostgreSQL preflight: PostgreSQL 17.7; 646 `test_*` databases visible
- Valkey preflight: `rate_limit` and `auth_state` both returned `PONG`; version 7.2.4

Focused revalidation:

```text
PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/token_csrf_test.rb
```

Result: 1 run, 3 assertions, 0 failures, 0 errors, 0 skips; exit code 0.

Full-suite revalidation:

```text
bin/rails test
```

Result: 11,409 runs, 73,003 assertions, 0 failures, 0 errors, 5 skips; exit code 0.

The suite emitted expected test-path OmniAuth failure/deprecation log lines and repeated
`LocalEnvironment::KEY` initialization warnings, but no test failure or error. The five skips
remain recorded as skips rather than being treated as passes.
