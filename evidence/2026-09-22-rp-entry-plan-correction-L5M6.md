# RP entry contract plan correction

- Date: 2026-09-22
- HEAD: `277673d13547d722fc88f830711eee69b923a7e8`
- Worktree: uncommitted changes were present; this check did not modify application code, routes,
  migrations, databases, Valkey data, or external services.

## Correction

The accepted Base/Auth boundary defines the first-party RP contract as `GET /sign`, CSRF-protected
`POST /sign`, and protocol `GET /sign/callback`. Auth credential ceremonies may still use
`/sign/in/*`, but those paths are not RP entrypoints. The architecture summary and integrated plan
were corrected so their RP route requirements no longer describe `/sign/in` or
`/sign/in/callback`.

No compatibility route, authentication behavior, client registration, redirect URI, cookie, or
database change was made.

## Verification

Command:

```text
env UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example RAILS_ENV=test POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db PARALLEL_WORKERS=1 bin/rails test test/integration/routes/core_route_contract_test.rb test/integration/jump_rt_return_verification_test.rb
```

Result: `22 runs, 265 assertions, 0 failures, 0 errors, 0 skips`.

The route contract and Jump RT integration tests therefore pass against the current local Compose
test services. External RP registrations, keys, and deployment routing remain outside this check.
