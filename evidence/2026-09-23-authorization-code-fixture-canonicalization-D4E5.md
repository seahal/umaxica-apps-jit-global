# Authorization-code fixture canonicalization

- Date: 2026-09-23
- HEAD before verification: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: existing changes were preserved; no application, migration, configuration, or external
  service change was made.

## Change

The generic Valkey authorization-code store test used retired browser-contract examples:
`core-app-rp` and `/sign/in/callback`. Those values were not production call sites, but they could
mislead future maintenance into treating the retired `/sign/in` contract as canonical. The test
now uses the current first-party `core-app` client identifier and `/sign/callback` redirect URI
through local constants. Store behavior and protocol assertions are unchanged.

## Verification

```text
bin/rubocop test/services/valkey/auth_state/authorization_code_store_test.rb
1 file inspected, no offenses detected

PARALLEL_WORKERS=1 bin/rails test \
  test/services/valkey/auth_state/authorization_code_store_test.rb
8 runs, 34 assertions, 0 failures, 0 errors, 0 skips

git diff --check -- test/services/valkey/auth_state/authorization_code_store_test.rb
passed
```

No production compatibility path was removed by this test-only canonicalization. The remaining
`core-next-rp` references are separately audited bridge compatibility paths and were not changed.

After the fixture cleanup, the full Rails suite was rerun with the explicit Compose-backed test
environment:

```text
bin/rails test
11540 runs, 73472 assertions, 0 failures, 0 errors, 8 skips
```

The suite's expected OmniAuth diagnostics and pre-existing skips were unchanged. No external
service was contacted and no test was weakened or skipped for this change.
