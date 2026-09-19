# Owner-scoped quota policy verification

- Date: 2026-09-18 UTC
- Branch: `feature`
- Starting commit: `4f8833687`
- Existing unrelated worktree changes were preserved and not staged.

## Implemented boundary

`Acme::AccountQuotaPolicy` and `Acme::OrganizationQuotaPolicy` now resolve ownership through the
surface-local concrete ownership tables and principal foreign keys. An optional resource relation is
intersected with that owner relation rather than replacing it. The policies reject unsupported
surface/principal combinations and do not count an unowned or another-principal resource.

The resource lifecycle state is not yet implemented in the current authority foundation, so this
slice does not invent the adopted ACTIVE/SUSPENDED/DISCARDED filter. Lifecycle quota semantics
remain blocked by `CF-004`.

## Checks

- `bundle exec ruby -c` over both policy files and all three affected Ruby tests — passed.
- `bundle exec rubocop` over both policy files and all three affected Ruby tests — passed; no
  offenses.
- `VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 CACHE_REDIS_URL=redis://127.0.0.1:6379/3 RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5 VALKEY_NAMESPACE_RUN_ID=codex-20260918-quota-owner-scope PARALLEL_WORKERS=1 bundle exec bin/rails test test/policies/acme/account_quota_policy_test.rb test/policies/acme/organization_quota_policy_test.rb`
  — passed, 10 runs / 66 assertions / 0 failures / 0 errors / 0 skips.
- `... bundle exec bin/rails test test/values/unsupported_input_refusals_test.rb test/operations/client_persona_creator_test.rb test/operations/surface_resource_creators_test.rb`
  — passed, 22 runs / 115 assertions / 0 failures / 0 errors / 0 skips.
- Final combined focused run with the same isolated test-service environment over the two quota
  policy files, unsupported-input regressions, and both creator suites — passed, 33 runs / 185
  assertions / 0 failures / 0 errors / 0 skips.

No migration, authority cutover, lifecycle transition, or external datastore was executed.
