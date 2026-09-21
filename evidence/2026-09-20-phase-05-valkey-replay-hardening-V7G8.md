# Phase 05 Valkey and replay hardening

Date: 2026-09-20
Repository HEAD at start: `52efa31df2a28763ad405f604bb3ef0c416b3b93`
Working tree: pre-existing user and implementation changes were present; no commit, push, or
external write was performed.

## Changes verified

- Auth-state Valkey clients now pass explicit 250ms connect, read, and write timeouts and
  `reconnect_attempts: 0` to the installed `redis` 6.0.0 / `redis-client` 0.30.1 stack.
- The adapter already performs one command call without an application retry; this behavior was
  preserved.
- Replay cleanup now requires an exact `rp_session_ref`. A consumed authorization-code tombstone
  with only `refresh_family_ref` is treated as a safe no-op and cannot select or revoke sibling RP
  Sessions.

## TDD and verification

The new bounded-network-policy assertion first failed because the client-options contract was not
defined. The new family-only replay test first failed because cleanup queried
`refresh_token_family_id`. After the implementation changes:

- `PARALLEL_WORKERS=1 bin/rails test test/lib/umaxica/valkey/connection_and_cleanup_test.rb
  test/services/oidc/token_exchange_service_test.rb`
  — 95 runs, 420 assertions, 0 failures, 0 errors, 0 skips.
- `bundle exec rubocop app/services/oidc_token_exchange_coordinator.rb
  lib/umaxica/valkey/connection.rb test/services/oidc/token_exchange_service_test.rb
  test/lib/umaxica/valkey/connection_and_cleanup_test.rb`
  — 4 files inspected, no offenses.
- Read-only Rails runner inspection of the constructed Redis client reported the Hiredis driver,
  0.25-second connect/read/write timeouts, and an empty reconnect-attempt list. No credentials or
  raw configuration secrets were recorded.
- `bin/rails test` — 11,362 runs, 72,531 assertions, 0 failures, 0 errors, 5 skips.

The tests used the configured development-container environment file and the existing PostgreSQL
and Valkey services. No database reset or destructive data operation was performed.

## Scope and remaining work

This slice does not complete the Base/Auth authority migration, POST-only Auth-to-Base result
transport, neutral Base transaction intent, callback credential handoff, or the remaining frozen
plan phases. Those remain separate implementation work and are not represented as complete by this
evidence.
