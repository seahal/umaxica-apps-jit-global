# TOTP lifecycle revalidation evidence

- Date: 2026-09-22
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing uncommitted changes were preserved; this verification ran with a dirty worktree.
- Scope: app-only TOTP lifecycle, attempt binding, terminal failure transition, enrollment slots,
  concurrency, and com/org route absence.

## Verification

The Rails tests used the repository's Compose-backed test environment through
`UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example` and the four requested test
database names. No application, environment, database, or external-service configuration was
changed.

```text
PARALLEL_WORKERS=1 bin/rails test test/consumers/totp_window_consumer_test.rb test/consumers/totp_window_consumer_concurrency_test.rb test/models/client_totp_credential_test.rb test/models/client_totp_credential_enrollment_concurrency_test.rb test/controllers/auth/app/in/mfa/totps_controller_test.rb test/controllers/auth/app/verification/totps_controller_test.rb test/controllers/auth/app/settings/totps_controller_test.rb test/controllers/auth/route_naming_test.rb
```

Result: 90 runs, 746 assertions, 0 failures, 0 errors, 0 skips.

## Confirmed current contracts

- TOTP is app-only; the route contract rejects com/org TOTP settings helpers.
- Failed attempts bind to one active credential, and the 100th failure persists `REVOKED` with
  a count of 100.
- A correct code cannot revive a revoked credential; replay is treated as a failed attempt.
- Concurrent failure and enrollment tests use independent PostgreSQL connections.
- Only ACTIVE and INACTIVE credentials consume the two enrollment slots.

## Open schema issue

`client_totp_credentials.last_otp_at` still uses PostgreSQL `-infinity` as the never-used sentinel
and is `NOT NULL`. This is not counted as a TOTP lifecycle failure in this evidence: the focused
behavior remains green. It is recorded as a separate schema-contract issue because repository
database rules define occurrence timestamps as NULL or finite actual times. Correcting it requires
an explicitly reviewed, reversible schema/data transition and coordinated updates to all current
creation and replay paths; no such migration was introduced in this revalidation.
