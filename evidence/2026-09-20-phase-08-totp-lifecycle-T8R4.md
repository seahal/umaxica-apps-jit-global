# Phase 08 TOTP lifecycle verification

Date: 2026-09-20

## Scope

This record covers the app-only TOTP credential lifecycle, credential-specific attempt
binding, terminal revocation, registration slot enforcement, settings status rendering,
and the explicit absence of com/org TOTP routes. Existing worktree changes from earlier
phases were preserved; no GitHub or external-service write was performed.

## Environment preflight

The required devcontainer environment was loaded with:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
set -a; . "$UMAXICA_ENV_FILE"; set +a
```

Checks completed without printing secret values:

- `config/credentials/test.key` was present.
- `POSTGRESQL_TEST_HOST`, `VALKEY_KVS_HOST`, and `VALKEY_KVS_PORT` were present.
- `bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'` succeeded.
- PostgreSQL and both required Valkey logical databases responded successfully.

## Database changes

The isolated test database was migrated with:

```text
RAILS_ENV=test bin/rails db:migrate
```

The TOTP failure-count check constraint and its subsequent validation migration succeeded.
No production or remote database was reset or modified.

## Verification results

Focused TOTP and surface-contract Rails tests:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/consumers/totp_window_consumer_test.rb \
  test/consumers/totp_window_consumer_concurrency_test.rb \
  test/models/client_totp_credential_test.rb \
  test/models/client_totp_credential_enrollment_concurrency_test.rb \
  test/controllers/auth/app/in/mfa/totps_controller_test.rb \
  test/controllers/auth/app/verification/totps_controller_test.rb \
  test/controllers/auth/app/settings/totps_controller_test.rb \
  test/operations/identity_totp_ceremony_final_committer_test.rb \
  test/controllers/auth/com/settings_controller_test.rb \
  test/controllers/concerns/sign_verification_totp_actions_test.rb \
  test/services/step_up/available_methods_test.rb \
  test/services/step_up/configured_methods_test.rb \
  test/integration/routes/auth_sign_ceremony_route_contract_test.rb
130 runs, 1023 assertions, 0 failures, 0 errors, 0 skips
```

Rails full suite:

```text
PARALLEL_WORKERS=1 bin/rails test
11389 runs, 72820 assertions, 0 failures, 0 errors, 5 skips
```

The five skips are existing suite skips. The full run also emitted existing OmniAuth test
diagnostic messages and Ruby warnings; neither produced a test failure.

Frontend focused tests passed with 50 tests. The complete frontend suite and static checks
also passed:

```text
bun run test
85 files passed, 1064 tests passed
bun run typecheck
passed
bun run lint
passed
bun run format:check
passed
git diff --check
passed
```

Targeted Ruby syntax checks and RuboCop for the changed TOTP implementation and tests passed.

## Verified behavior

- app TOTP is the only TOTP surface; com/org route and step-up contracts remain unchanged.
- Failure counts are bounded from 0 through 100 and the 100th credential-specific failure
  transitions the credential to terminal `REVOKED`.
- Successful verification resets only the selected credential; replay and revoked credentials
  do not authenticate or revive the credential.
- One active credential is selected automatically; multiple active credentials require an
  actor-scoped `public_id`, never a database-local ID.
- Concurrent verification and enrollment tests use independent database connections.
- `ACTIVE` and `INACTIVE` consume the two registration slots; `REVOKED`, `DELETED`, and
  `NOTHING` do not.
- Revoked credentials remain visible in app settings with a status and no reactivation action.
