# E0 isolated test environment evidence

Date: 2026-09-15

Starting repository state: branch `feature`, HEAD
`7bee4819ffe2a402c63a04af2a368bfcaf253c0d`. Existing unrelated dirty paths were preserved. No
GitHub write, database reset/drop, stage, commit, or provider request was performed.

## Read-only service preflight

Command shape (password value omitted):

```text
POSTGRESQL_TEST_HOST=primary.dns.podman POSTGRESQL_PORT=5432
POSTGRESQL_USER=root POSTGRESQL_DATABASE=db
CACHE_REDIS_URL=redis://valkey.dns.podman:6379/3
RATE_LIMIT_REDIS_URL=redis://valkey.dns.podman:6379/4
AUTH_STATE_REDIS_URL=redis://valkey.dns.podman:6379/5
VALKEY_NAMESPACE_RUN_ID=e0-preflight-20260915
bundle exec ruby scripts/test-environment-check
```

Exit: 0.

Observed: PostgreSQL 17.7 at the selected server, administration database `db`, 646 databases
named `test_*`; Valkey 7.2.4 at the selected host, PONG on logical DBs 3, 4, and 5. The probe
performed catalog/INFO/PING reads only. A final repeat after removing an unnecessary SQL helper
dependency (`VALKEY_NAMESPACE_RUN_ID=e0-preflight-final2-20260915`) also exited 0 with the same
identities and no writes. The final scoped cleanup (`e0-cleanup-final2-20260915`) exited 0 and
deleted zero keys.

## Rails assertion smoke

```text
PARALLEL_WORKERS=1 VALKEY_NAMESPACE_RUN_ID=e0-smoke-20260915c
scripts/test-isolated bin/rails test
  test/lib/umaxica/valkey/connection_and_cleanup_test.rb
```

Exit: 0. Result: 2 runs, 7 assertions, 0 failures, 0 errors, 0 skips. Scoped cleanup reported
the run prefix empty after deletion.

## E0 contract test

```text
scripts/test-isolated bin/rails test test/config/test_environment_isolation_contract_test.rb
```

Exit: 0. Result: 3 runs, 14 assertions, 0 failures, 0 errors, 0 skips.

A second run with `PARALLEL_WORKERS=2` combined the Valkey smoke and E0 contract tests. Exit: 0.
Result: 5 runs, 21 assertions, 0 failures, 0 errors, 0 skips. The run-scoped cleanup completed
after both worker processes.

After that run, the contract test gained one additional assertion that scans the real auth-state
store and checks the run/worker prefix. Its first rerun was not forced through a pending unrelated
migration: `scripts/test-isolated ... bin/rails test
test/config/test_environment_isolation_contract_test.rb` exited 1 before assertions because
Rails reported `db/migrate/20260915000000_create_blazer_tables.rb` pending. The earlier 3-run,
14-assertion result is the executed result; the post-addition contract test is unverified until
that migration is resolved by its owner. No migration was run.

## Auth-code and OTP target test

The authorization-code store, OIDC token exchange, app/com sign-up OTP, and app/com sign-in
email controller tests were run together through the same wrapper.

Exit: 1. Result: 147 runs, 725 assertions, 0 failures, 3 errors, 0 skips. The three errors are
application/test contract failures after Rails and the external test services were available:
two OIDC exchange helper calls omit required client/redirect/PKCE keywords, and one com sign-in
Turnstile test expects a missing `form_errors` prop. Cleanup removed 65 run-scoped auth-state
keys. These results are not a green authentication baseline.

## Remaining environment gap

The sandbox has no local PostgreSQL/Valkey binaries or container runtime. The host-authorized
Podman-DNS services were reachable, but their runtime could not be managed from this shell. The
repository CI workflow was not changed to publish datastore ports; CI still needs a compliant
service-network arrangement before this exact wrapper can be enabled there.

## Full Rails and coverage attempts

The full suite was then run with `PARALLEL_WORKERS=16` through the same wrapper. Exit: 1 after
452.716 seconds. Result: 12,995 runs, 78,688 assertions, 4 failures, 15 errors, and 3 skips.
The process reached the application tests and the wrapper cleanup deleted 31 run-scoped keys.
The failures/errors are existing application and contract issues (including OIDC exchange helper
arguments, authentication-event harness methods, com OTP/Turnstile props, an OpenAPI expected-set
assertion, an architecture baseline entry, and an invalid-grant expectation); they are not
PostgreSQL or Valkey connection failures.

`COVERAGE=true` was attempted after the full run with the repository's existing SimpleCov setup.
It exited 1 before tests because Rails found the newly present untracked
`db/migrate/20260915000000_create_blazer_tables.rb` pending. SimpleCov therefore produced only a
partial 52.02% line, 1.07% branch, and 2.52% method report after boot and explicitly excluded
older subprocess results; these are not a coverage baseline. The Blazer migration, structure dump,
and initializer changes appeared in the worktree during the suite and were preserved without
editing because they were not part of E0.
