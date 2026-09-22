# Auth-state focused test environment blocker

- Date: 2026-09-22
- Repository HEAD: `277673d13547d722fc88f830711eee69b923a7e8`
- Worktree: pre-existing modified and untracked files were present; no source or test file was changed for this check.
- External services: no AWS, Cloudflare, provider, production, or shared service was contacted or modified.

## Command

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
export RAILS_ENV=test
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
export PARALLEL_WORKERS=1
bin/rails test test/services/valkey/auth_state/authorization_code_store_test.rb test/services/valkey/auth_state/sign_out_notice_store_test.rb test/services/base_auth_admission_coordinator_test.rb test/services/oidc/token_exchange_service_test.rb
```

## Result

The test process stopped during Rails test-schema maintenance before any test assertion ran.
The complete connection error was:

```text
ActiveRecord::DatabaseConnectionError: There is an issue connecting with your hostname: primary.
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

The current process was not on the Compose network: `getent hosts primary` and
`getent hosts valkey-kvs` returned no records. `podman` was not available in this process, so no
container transition was attempted. No fallback host, localhost substitution, mock datastore, or
test weakening was used.

`config/credentials/test.key` and `.env.devcontainer.example` were present. Secret contents and
environment values were not printed.

## Follow-up runtime check

On the same checkout, `getent hosts primary` and `getent hosts valkey-kvs` still returned no
records. The container environment marker was present, but neither the Podman socket nor the
`podman` executable was available. A read-only `podman ps` check was also attempted with the
available host-execution path and returned `podman: command not found`. No container was started,
stopped, or reconfigured.

## Classification

`UNVERIFIED_ENVIRONMENT`: this result is not evidence of a Rails or test defect. The Valkey
authorization-code, sign-out notice, Auth/Base handoff, and OIDC exchange contracts remain
runtime-unverified in this process and must be rerun from the Compose core service before any
database-backed auth-boundary change is accepted.
