# Retired RP reference cleanup

- Date: 2026-09-23
- HEAD before verification: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: existing changes were preserved. No external service, deployment, credential, or
  database configuration was changed.

## Scope

The repository-wide authentication reference audit found two additional test-only uses of retired
RP examples: `core-app-rp` and `side-app-rp` in RP-session revocation fixtures, and
`core-app-rp` in an authorization-code result value assertion. These are not production call
sites, but using retired identifiers in current tests can preserve a misleading contract.

The fixtures now use the current local `core-app` and `side-app` client identifiers. Superseded
ADR wording was also made unambiguous: later historical references to `base-rails-rp`, Acme/Sign
authority, and legacy `/sign/in` routes are explicitly historical and must not be read as current
registration or routing instructions. No `core-next-rp` bridge reference was changed.

## Verification

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/operations/rp_session_revoker_test.rb \
  test/services/valkey/auth_state/authorization_code_consume_result_test.rb \
  test/services/valkey/auth_state/authorization_code_store_test.rb
15 runs, 71 assertions, 0 failures, 0 errors, 0 skips

bin/rubocop test/operations/rp_session_revoker_test.rb \
  test/services/valkey/auth_state/authorization_code_consume_result_test.rb
2 files inspected, no offenses detected

bin/rails test
11540 runs, 73472 assertions, 0 failures, 0 errors, 8 skips

git diff --check
passed
```

The full suite's expected OmniAuth diagnostics and pre-existing skips were unchanged. No tests
were deleted, skipped, weakened, or replaced with mocks.

## Boundary

This cleanup does not implement regional RP identities, remove the `core-next-rp` compatibility
client, or change external registrations and keys. Those remain the separate `CF-007` gate.
