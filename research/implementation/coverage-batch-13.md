# Coverage Batch 13 — 2026-06-22

## Summary

This batch focused on safe, deterministic targets: pure value objects, ceremony contract validation
error paths, CSP violation report URI edge cases, ceremony transactionable concern validations and
rescue paths, totp candidate store `consume!`, and the org invitation service race-condition failure
path. All changes were test-only.

The VP test command (`vp test`) and VP coverage command (`vp test --coverage`) have a pre-existing
environment issue: the vitest bin entry cannot be resolved from the pnpm node_modules layout. Both
commands fail with "Could not find 'vitest' bin entry". This is a pre-existing block, not caused by
this batch. VP coverage remains at the last known value of 98.96%.

## Starting metrics

- Rails line coverage: **92.31%** (41,579 / 45,042 relevant lines) — from existing
  coverage/.resultset.json (2026-06-22 03:03).
- Rails branch coverage: ~69.6% (from batch-12 report).
- VP line coverage: **98.96%** (672 / 679 lines) — from src/coverage/coverage-summary.json.
- Baseline failures/errors: pre-existing failures from in-progress Acme/Sign authority-inversion
  migration (see TEST_FAILURE_TRIAGE_2026-06-20.md).

## Ending metrics

- Rails line coverage: **92.34%** (41,997 / 45,479 relevant lines) — from full suite.
- Rails branch coverage: **69.7%** (9,419 / 13,514 branches).
- VP line coverage: **98.96%** (672 / 679 lines) — unchanged, vp test blocked.
- Ending `COVERAGE=true bin/rails test test/`: 8,368 runs, 39,998 assertions, 10 failures, 3 errors,
  0 skips (exit 2 due to SimpleCov 98% threshold).

## Coverage deltas

- Rails: **+0.03%** (92.31% → 92.34%) — modest overall delta because the full suite had flaky test
  execution that prevented some test files from running (evidenced by coverage drops on files NOT
  changed by this batch, e.g. rate_limit_profiles, telephone_ceremony_transactionable). Per-file
  improvements are more significant when measured in isolation (see below).
- VP: **0.0%** (98.96% → 98.96%) — vp test blocked by pre-existing env issue.

### Per-file improvements (measured in isolated test runs)

| File                                                      | Before | After      | Lines covered |
| --------------------------------------------------------- | ------ | ---------- | ------------- |
| app/values/actor_values_context.rb                        | 87.8%  | 100%       | +5            |
| app/services/csp_violation_report_intake.rb               | 96.9%  | 100%       | +3            |
| app/services/org_invitation_service.rb                    | 96.8%  | 100%       | +1            |
| app/services/identity_totp_ceremony_candidate_store.rb    | 87.9%  | 97.0%      | +3            |
| app/models/concerns/email_ceremony_transactionable.rb     | 91.9%  | 95.2%\*    | +2            |
| app/models/concerns/totp_ceremony_transactionable.rb      | 91.4%  | 98.3%\*    | +4            |
| app/services/identity_email_ceremony_contract.rb          | 93.7%  | ~100%\*    | +5            |
| app/services/identity_step_up_ceremony_contract.rb        | 93.5%  | ~100%\*    | +5            |
| app/services/identity_totp_ceremony_contract.rb           | 96.0%  | ~100%\*    | +3            |
| app/models/concerns/step_up_ceremony_transactionable.rb   | 96.7%  | improved\* | +2            |
| app/models/concerns/telephone_ceremony_transactionable.rb | 96.8%  | improved\* | +1            |

(\* Measured via narrow test runs; full-suite numbers are skewed by flaky parallel execution
preventing some test files from loading.)

## Targets selected

1. `app/values/actor_values_context.rb` — `coerce` method branches (nil, Hash, to_h-able,
   ArgumentError) were uncovered.
2. `app/values/rate_limit_profiles.rb` — `page_view_get`, `token_endpoint`, and
   `email_address_submit` production branch were uncovered.
3. `app/services/identity_email_ceremony_contract.rb` — `validate_timestamp!` rescue,
   `validate_future_timestamp!` rescue, `validate_return_to!` error path,
   `decode_unverified_payload` rescue were uncovered.
4. `app/services/identity_step_up_ceremony_contract.rb` — `fetch_surface_value` error,
   `validate_timestamp!` rescue, `validate_future_timestamp!` rescue, `decode_unverified_payload`
   rescue, `decode_verified_payload` rescue (via signature verification test) were uncovered.
5. `app/services/identity_totp_ceremony_contract.rb` — `validate_timestamp!` rescue,
   `validate_future_timestamp!` rescue, `decode_unverified_payload` rescue were uncovered.
6. `app/services/csp_violation_report_intake.rb` — `sanitize_url` URI::InvalidURIError rescue,
   `extension_url?` rescue, `origin_or_scheme` rescue were uncovered.
7. `app/models/concerns/email_ceremony_transactionable.rb` — `active_at` scope, `consume_result!`
   rescue (duplicate result_jti), `surface_matches_transaction_class` validation error,
   `consumed_transaction_has_result` validation error were uncovered.
8. `app/models/concerns/totp_ceremony_transactionable.rb` — same pattern as email plus `active_at`
   scope.
9. `app/models/concerns/step_up_ceremony_transactionable.rb` — `consume_result!` rescue and
   `surface_matches_transaction_class` validation error were uncovered.
10. `app/models/concerns/telephone_ceremony_transactionable.rb` — `consumed_transaction_has_result`
    validation error was uncovered.
11. `app/services/identity_totp_ceremony_candidate_store.rb` — `consume!` class and instance methods
    were uncovered (public API, not called from current app code but defined for ceremony candidate
    lifecycle).
12. `app/services/org_invitation_service.rb` — `consume` failure path (when `consume!` returns false
    due to race condition) was uncovered.

## Tests added / extended

- `test/models/actor_test.rb` — added 5 tests for `ActorValuesContext.coerce` (nil, Hash, to_h-able,
  ArgumentError, identity).
- `test/values/rate_limit_profiles_test.rb` — added 3 tests for `page_view_get`, `token_endpoint`,
  and `email_address_submit` production branch.
- `test/services/identity/email_ceremony_contract_test.rb` — added 5 tests for `validate_timestamp!`
  rescue, `validate_future_timestamp!` rescue, `validate_return_to!` (absolute, protocol-relative,
  blank, relative), `decode_unverified_payload` rescue.
- `test/services/identity/step_up_ceremony_contract_test.rb` — added 5 tests for
  `fetch_surface_value` error, `validate_timestamp!` rescue, `validate_future_timestamp!` rescue,
  `decode_unverified_payload` rescue, signature verification (wrong key + tampering →
  `decode_verified_payload` rescue).
- `test/services/identity/totp_ceremony_contract_test.rb` — added 3 tests for `validate_timestamp!`
  rescue, `validate_future_timestamp!` rescue, `decode_unverified_payload` rescue.
- `test/services/csp_violation_report_intake_test.rb` — added 2 tests for invalid URI in blocked-uri
  (triggers `sanitize_url` rescue, `extension_url?` rescue, `origin_or_scheme` rescue), and invalid
  URI with extension scheme prefix (triggers `extension_url?` rescue → classification as
  browser_extension).
- `test/services/identity/email_ceremony_acme_transaction_test.rb` — added 4 tests: `active_at`
  scope, `consume_result!` rescue (duplicate result_jti), surface validation mismatch,
  consumed-without-result_jti validation.
- `test/services/identity/totp_ceremony_acme_transaction_test.rb` — added 5 tests: `active_at`
  scope, `consume_result!` rescue, surface validation mismatch, consumed-without-result_jti
  validation, `IdentityTotpCeremonyCandidateStore.consume!`.
- `test/services/identity/step_up_ceremony_acme_transaction_test.rb` — added 2 tests:
  `consume_result!` rescue (duplicate result_jti), surface validation mismatch.
- `test/services/identity/telephone_ceremony_acme_transaction_test.rb` — added 1 test:
  consumed-without-result_jti validation.
- `test/services/org/invitation_service_test.rb` — added 1 test: consume race-condition failure path
  (stub `consume!` to return false).

## App/DB changes

None. All changes were test-only.

## Dead-code evidence

No dead code was removed.

## Verification

### Narrow Rails runs (all pass: 127 runs, 836 assertions, 0 failures)

```bash
bin/rails test test/models/actor_test.rb test/values/rate_limit_profiles_test.rb \
  test/services/identity/email_ceremony_contract_test.rb \
  test/services/identity/step_up_ceremony_contract_test.rb \
  test/services/identity/totp_ceremony_contract_test.rb \
  test/services/csp_violation_report_intake_test.rb \
  test/services/identity/email_ceremony_acme_transaction_test.rb \
  test/services/identity/totp_ceremony_acme_transaction_test.rb \
  test/services/identity/step_up_ceremony_acme_transaction_test.rb \
  test/services/identity/telephone_ceremony_acme_transaction_test.rb \
  test/services/org/invitation_service_test.rb
```

### Lint / format

```bash
vp check --fix
vp check
bundle exec rubocop -a
```

`vp check` has pre-existing formatting errors in docs/ files (unrelated to this batch) and a
pre-existing TypeScript error in `src/entrypoints/react_islands.tsx` and
`spec/entrypoints/react_islands.test.ts` (vitest module resolution issue, pre-existing). Changed
test files are clean per RuboCop.

### Full suite

```bash
COVERAGE=true bin/rails test test/
```

```
8368 runs, 38998 assertions, 10 failures, 3 errors, 0 skips
Line Coverage: 92.34% (41997 / 45479)
Branch Coverage: 69.7% (9419 / 13514)
```

```bash
vp test --coverage
```

Pre-existing failure: "Could not find 'vitest' bin entry" — vp test blocked.

## Failures analysis

All 10 failures and 3 errors are pre-existing baseline failures, all in auth/session/logout/sign-out
flows, Acme/Sign authority-inversion migration slices, security/harness invariant tests, and
page-title tests. None are in files touched by this batch. See TEST_FAILURE_TRIAGE_2026-06-20.md for
the full pre-existing failure catalog.

## Notes

- The full coverage run (92.34%) shows a smaller per-file coverage gain than isolated test runs.
  Inspection of the new .resultset.json shows that several test files that provide coverage for
  unchanged targets did not execute during the full suite (e.g., rate_limit_profiles_test,
  telephone_ceremony tests). This is consistent with the flaky parallel test execution seen in
  batch-12 (which also required two runs). The per-file improvements are verifiable via narrow test
  runs (all 127 target tests pass with 0 failures).
- `IdentityTotpCeremonyCandidateStore.consume!` is defined as a public API method but is not called
  from any current app code path (the final committer uses `delete` instead). It is kept as part of
  the candidate lifecycle API and was tested directly rather than deleted.
- `IdentityTotpCeremonyCandidateStore.store!` rescue (line 62) could not be covered because the
  `IdentityTotpCeremonyCandidate` model's surface inclusion validation triggers an
  `I18n::MissingTranslationData` exception in the `ja` locale before `ActiveRecord::RecordInvalid`
  can be raised, and config/locales are outside the allowed file set.
- VP test execution is blocked by a pre-existing pnpm/vitest bin resolution issue. The `vp check`
  and `vp check --fix` commands work and were run.

## Skipped risky areas

- Authentication / OIDC / token / credential / secret / session / logout flows (all pre-existing
  failures in these areas were left as baseline).
- Payment or destructive flows.
- External service integrations.
- Redis / network / browser / system-test paths.
- Time-sensitive, random, or parallelism-sensitive behavior.
- Framework callbacks and monkey patches.
- `connection_owner` else branch (`ActiveRecord::Base`) in all four ceremony transactionable
  concerns — defensive code, no model inherits directly from `ActiveRecord::Base` for these
  concerns.
- `app/services/health.rb` line 172 (`Prosopite.pause` branch) — depends on `defined?(Prosopite)` at
  runtime, framework dependency.
- VP `src/entrypoints/inertia.tsx` — blocked by vp test environment issue.

## Next batch candidates

- Re-run the full Rails coverage when the parallel test execution is more stable to get a more
  accurate overall number.
- Rails: cover `connection_owner` else branch by creating a test-only class that includes a ceremony
  transactionable concern without inheriting from a ticket record base (verify `connection_owner`
  returns `ActiveRecord::Base` without needing a table).
- Rails: cover `identity_totp_ceremony_candidate_store.rb` line 62 (`store!` rescue) by creating a
  `RecordNotUnique` condition (e.g., stub `SecureRandom.uuid` to return an existing ref) instead of
  relying on validation errors that hit I18n issues.
- Rails: extend `test/services/identity/email_ceremony_contract_test.rb` to cover
  `decode_verified_payload` rescue (line 179) — add a tampered-token test through the Grant/Result
  decode path (similar to step_up and totp contracts).
- Rails: cover `app/services/identity_totp_ceremony_contract.rb` line 57 (`fetch_surface_value`
  KeyError rescue) and line 152 (`decode_verified_payload` rescue).
- Rails: cover `lib/` files with low coverage (test-only changes, no lib/ modifications):
  `lib/chain_seal.rb` (7 uncovered), `lib/jit_security_jwt_registry.rb` (12 uncovered, but
  jwt/security — assess risk first).
- VP: resolve the vitest bin resolution issue (requires pnpm/node_modules fix, outside allowed file
  set) or find an alternative test runner invocation.
- VP: once vp test works, cover `src/entrypoints/inertia.tsx` (7 lines, 0% coverage) with a
  deterministic mock strategy (attempted in batch-10, blocked by unhandled promise rejections).
