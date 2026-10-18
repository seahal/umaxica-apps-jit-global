# Coverage Batch 12 — 2026-06-20

## Summary

This batch focused on safe, deterministic utility/value-object targets that lacked dedicated
coverage or had brittle indirect coverage. It also closed the last uncovered VP controller
auto-registration file.

The initial Rails coverage run was anomalously low (83.32%) due to database-level fixture deadlocks
and foreign-key violations that prevented many existing test classes from loading. A second full run
completed with much healthier numbers (91.83%), confirming the baseline drop was transient
test-suite instability rather than lost code coverage. Final numbers are reported from the second,
complete run.

## Starting metrics

- Rails line coverage: **83.32%** (37,424 / 44,918 relevant lines) — first run, unstable
- Rails branch coverage: **54.89%** (7,231 / 13,174 branches) — first run
- VP line coverage: **98.37%** (668 / 679 lines)
- Baseline failures/errors (first run): not fully summarized due to truncation; dominated by
  migration-related failures plus PG deadlocks/FK violations.

## Ending metrics

- Rails line coverage: **91.83%** (40,885 / 44,521 relevant lines)
- Rails branch coverage: **69.60%** (9,154 / 13,152 branches)
- VP line coverage: **98.96%** (672 / 679 lines)
- Ending `COVERAGE=true bin/rails test test/`: 8,178 runs, 56 failures, 58 errors, 0 skips (exit 2
  because SimpleCov minimum threshold of 98% was not met).

## Coverage deltas

- Rails: **+8.51%** (83.32% → 91.83%)
- VP: **+0.59%** (98.37% → 98.96%)

The Rails delta is largely recovery from the unstable first run; the newly added tests contributed
coverage for previously untested or under-tested files and strengthened existing files.

## Targets selected

1. `src/controllers/index.js` — VP controller auto-registration (0% → 100%).
2. `app/services/chronicle_fallback_recorder.rb` — no dedicated test; audit fallback logger.
3. `app/services/application_service.rb` — default `#initialize` was uncovered.
4. `app/services/outbound_result.rb` — no dedicated test; simple delivery result value object.
5. `app/services/outbound_provider_response.rb` — no dedicated test; provider response value object.
6. `app/services/analytics_consent_guard_pre_consent_allowlist.rb` — only indirectly covered; added
   direct allowlist tests.
7. `app/models/actor/configuration.rb` / `Actor::Configuration::NullValue` — existing unit test had
   a broken `assert_nil` assertion for the custom null object and lacked several method branches.

Two initially drafted targets were abandoned after discovering existing duplicate test classes:

- `test/services/core_surface_test.rb` duplicated `test/lib/core/surface_test.rb`.
- `test/models/actor/configuration_test.rb` duplicated `test/unit/actor/configuration_test.rb`.

Both duplicates were deleted and the existing tests were extended instead.

## Tests added / extended

- `test/services/chronicle_fallback_recorder_test.rb` (new)
  - Covers error logging with and without an exception.
- `test/services/application_service_test.rb`
  - Added coverage for the default no-op `#initialize` accepting arbitrary arguments.
- `test/services/outbound_result_test.rb` (new)
  - Covers accepted/rejected factory methods, predicate, and manual construction.
- `test/services/outbound_provider_response_test.rb` (new)
  - Covers accepted factory, type coercion, and default timestamp.
- `test/services/analytics_consent_guard_test.rb`
  - Added direct coverage for every allowlist category and rejection of nil/empty/non-allowed event
    names.
- `test/unit/actor/configuration_test.rb`
  - Fixed `assert_nil` on `NullValue` (it overrides `nil?` but is not `nil` itself).
  - Added coverage for `NULL`, freeze behavior, string-key fetch, `with`, null predicates, `to_h`,
    `NULL_VALUE` chaining, and equality/hash.
- `spec/controllers/index.test.js` (new)
  - Mocks `@hotwired/stimulus` and asserts that `src/controllers/index.js` registers discovered
    controllers with kebab-cased names.
- `spec/setup.ts`
  - Added `export const specSetup = {};` to satisfy the `no-empty-file` lint rule.

## App/DB changes

None. All changes were test-only.

## Dead-code evidence

No dead code was removed.

## Verification

### Narrow Rails runs (all pass)

```bash
bin/rails test test/services/chronicle_fallback_recorder_test.rb
bin/rails test test/services/application_service_test.rb
bin/rails test test/services/outbound_result_test.rb
bin/rails test test/services/outbound_provider_response_test.rb
bin/rails test test/services/analytics_consent_guard_test.rb
bin/rails test test/unit/actor/configuration_test.rb
```

### VP run

```bash
vp test
```

16 test files passed, 287 tests passed.

### Lint / format

```bash
vp check --fix
vp check
bundle exec rubocop -a
```

`vp check` passes. RuboCop has residual offenses in existing files unrelated to this batch; changed
files are clean.

### Full suite

```bash
COVERAGE=true bin/rails test test/
```

Second complete run:

```
8178 runs, 33318 assertions, 56 failures, 58 errors, 0 skips
Line Coverage: 91.83% (40885 / 44521)
Branch Coverage: 69.60% (9154 / 13152)
```

```bash
vp test --coverage
```

```
16 passed (16)
287 passed
All files: 98.96% Lines
```

## Notes

- The first Rails full-suite run produced an anomalously low 83.32% with many fixture-level
  deadlocks and foreign-key violations. A second run completed normally at 91.83%. This suggests the
  test databases had transient lock contention; the final report uses the complete run.
- `Actor::Configuration::NullValue` intentionally overrides `nil?` while remaining an object, so
  `assert_nil` fails. Tests use `assert null.nil?` with RuboCop disables for the assertion cops that
  otherwise auto-correct back to the failing `assert_nil`.
- `spec/setup.ts` needed a non-empty export to satisfy both `unicorn/no-empty-file` and
  `unicorn/require-module-specifiers`.

## Skipped risky areas

- Authentication / OIDC / token / credential / secret / session / logout flows (except indirect
  coverage via chronicle/result value objects).
- Payment, withdrawal, and destructive flows.
- External service integrations.
- Redis / network / browser / system-test paths.
- Time-sensitive, random, or parallelism-sensitive behavior.
- Framework callbacks and monkey patches.

## Next batch candidates

- VP: cover `src/entrypoints/inertia.tsx` with a safe deterministic mock (attempted in Batch 10 and
  removed due to unhandled promise rejections; a different mock strategy may work).
- Rails: low-risk service value objects still without dedicated tests, e.g.
  `app/services/outbound_sms.rb`, `app/services/core_cookie_options.rb`,
  `app/services/request_context_contract.rb`.
- Rails: extend existing tests for `app/services/health.rb` remaining branches and
  `app/services/core_host_normalization.rb` edge cases.
- Rails: simple model concerns/utilities with partial coverage, e.g.
  `app/models/concerns/flow_base.rb`, `app/models/concerns/preference_resettable.rb`.
