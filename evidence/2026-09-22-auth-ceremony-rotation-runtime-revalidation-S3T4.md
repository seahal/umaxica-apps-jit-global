# Auth ceremony admission rotation runtime revalidation

- Date: 2026-09-22 UTC
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Branch: `feature`
- Worktree: pre-existing staged, unstaged, and untracked changes were preserved.
- External writes: none. No GitHub, AWS, Cloudflare, provider, production, shared database,
  email, or SMS service was contacted.

## Environment

The repository-supported Compose-backed test environment was used with
`UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example` and the test database
manifest including `test_primary_db`, `test_app_ticket_db`, `test_com_ticket_db`,
`test_org_ticket_db`, and `test_app_zenith_db`. PostgreSQL and Valkey service names resolved;
secret values were not printed.

## Verification

```text
PARALLEL_WORKERS=1 bin/rails test test/models/auth_ceremony_session_test.rb test/models/auth_ceremony_session_concurrency_test.rb
```

Result: `36 runs, 219 assertions, 0 failures, 0 errors, 0 skips`.

The runtime check verifies the public Auth ceremony rotation contract, including predecessor
revocation and replacement admission in one database transaction, uniqueness-failure rollback,
rejection of a second replacement, and independent-connection concurrency with one winner.

This closes the previous local-test environment gap for the Auth-local rotation sub-boundary. It
does not change the separate CF-010 limits: production worker topology, external RP registration,
live provider/Cloudflare acceptance, and any first-admission coordination outside the persisted
predecessor row remain separate boundaries.
