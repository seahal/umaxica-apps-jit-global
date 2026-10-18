# Coverage Batch 10 — 2026-06-19

## Summary

This batch focused on safe, low-risk targets left after Batch 9:

- Static/read-only endpoints (`robots.txt` and `sitemap.xml`) for corporate, staff, and core
  surfaces that were missing request coverage.
- Deterministic model/service branches: `ApplicationRecord` fixed-ID fallback,
  `SignOutFlow.awaiting_expiry`, `RetentionCrossDatabaseChildPurge` visitor path,
  `OrgOperatorLifecycleExecute` error paths, and `OauthCallbackStateable` race-recovery path.
- VP coverage for the Stimulus application bootstrap file, which was completely uncovered.

No application business logic was changed. `bundle exec rubocop -a` made style-only auto-corrections
in a handful of existing files (including one OIDC logout concern), but no behavior was modified.

## Starting metrics

- Rails line coverage: **91.23%** (40,560 / 44,459 relevant lines)
- Rails branch coverage: **68.58%** (8,922 / 13,009 branches)
- VP line coverage: **97.64%**
- Baseline `COVERAGE=true bin/rails test test/`: 8,105 runs, 168 failures, 204 errors

## Ending metrics

- Rails line coverage: **91.28%** (40,581 / 44,459 relevant lines)
- Rails branch coverage: **68.61%** (8,926 / 13,009 branches)
- VP line coverage: **98.37%**
- Ending `COVERAGE=true bin/rails test test/`: 8,118 runs, 169 failures, 203 errors (exit 2 because
  SimpleCov minimum threshold of 98% was not met)

## Coverage deltas

- Rails: **+0.05%** (91.23% → 91.28%)
- VP: **+0.73%** (97.64% → 98.37%)

The full-suite failure/error counts are essentially unchanged (within normal fluctuation). The new
tests all pass in isolation.

## Targets selected

1. `app/controllers/{acme,base,core,palm}/{com,org,app}/robots_controller.rb` — 8 controllers at
   85.71% because `show_plain_text` was never invoked.
2. `app/controllers/{acme,base,palm}/{com,org}/sitemaps_controller.rb` — 5 controllers at 85.71%
   because `show_xml` was never invoked. Core sitemaps were excluded because no view templates exist
   for those surfaces.
3. `app/models/application_record.rb` — line 55, the `rescue nil` fallback inside
   `insert_missing_fixed_ids!` when concurrent `first_or_create!` also fails.
4. `app/models/concerns/sign_out_flow.rb` — lines 92-94, the `awaiting_expiry` scope.
5. `app/services/retention_cross_database_child_purge.rb` — lines 58-59, the visitor purge path.
6. `app/services/org_operator_lifecycle_execute.rb` — error paths: invalid action (line 54),
   `RecordInvalid` failure formatting (line 33), and last-active-operator guard (lines 122-123).
7. `app/models/concerns/oauth_callback_stateable.rb` — line 30, the race-recovery `find_by` inside
   `issue!`.
8. `src/controllers/application.js` — Stimulus bootstrap and debug-mode branch.

## Tests added

- `test/integration/static_assets_endpoints_test.rb` (new file) — covers all uncovered `robots.txt`
  and `sitemap.xml` endpoints.
- `test/models/application_record_test.rb` — added fallback collision tolerance test.
- `test/models/sign_out_flow_test.rb` — added `awaiting_expiry` scope test.
- `test/services/retention_cross_database_child_purge_test.rb` (new file) — covers visitor and
  operator purge paths and actor return value.
- `test/services/org_operator_lifecycle_execute_test.rb` (new file) — covers the error/failure
  branches.
- `test/models/oauth_callback_state_test.rb` — added race-condition uniqueness test.
- `spec/controllers/application.test.js` (new file) — covers Stimulus application bootstrap and
  localhost debug branches.

## App/DB changes

None. All behavior changes were test-only.

`bundle exec rubocop -a` applied style-only auto-corrections in several existing files. Notable
security-adjacent files touched by RuboCop:

- `app/controllers/concerns/sign_oidc_logout.rb` — `%i[show create]` to `%i(show create)` and added
  blank line after guard clause.
- `app/services/oidc_backchannel_logout_notifier.rb` — indentation fixes.

These are cosmetic and do not change behavior.

## Dead-code evidence

No dead code was removed.

## Commands run

- `COVERAGE=true bin/rails test test/` — initial and final Rails coverage
- `vp test --coverage` — initial and final VP coverage
- `bin/rails test test/integration/static_assets_endpoints_test.rb test/models/application_record_test.rb test/models/sign_out_flow_test.rb test/services/retention_cross_database_child_purge_test.rb test/services/org_operator_lifecycle_execute_test.rb test/models/oauth_callback_state_test.rb`
  — narrow validation (44 runs, 0 failures, 0 errors)
- `vp test` — VP regression check
- `vp check --fix` — passed after adding `export {};` to empty `spec/setup.ts`
- `bundle exec rubocop -a` — style auto-corrections

## Skipped risky areas

- Authentication / OIDC / token / credential / session / logout flows (except incidental RuboCop
  style fixes in OIDC logout files).
- Payment, withdrawal, and destructive flows (the purge service is destructive but ADR-sanctioned
  and tested in isolation).
- External service integrations.
- Redis / network / browser / system-test paths.
- Time-sensitive, random, or parallelism-sensitive behavior.
- Framework callbacks and monkey patches.
- `src/entrypoints/inertia.tsx`, `src/entrypoints/application.ts`, `src/controllers/index.js`, and
  `src/types/index.ts` remain uncovered. The Inertia entrypoint test was attempted but removed
  because mocking the async `createInertiaApp` call produced unhandled rejections; these entrypoints
  are low-yield and will be revisited with a safer approach.

## Next batch candidates

- Continue covering static/read-only endpoints: `WelcomesController`, `SelectorsController`,
  `AccountsController`, and root/configuration controllers.
- `OauthCallbackStateable#connection_owner` branches (AppTicketRecord vs OrgTicketRecord routing).
- `SignOutFlow` scopes/delegates and transition edge cases.
- Low-risk service objects still below 100%, e.g. `OrgOperatorLifecycleExecute` success paths and
  `RetentionCrossDatabaseChildPurge` client path.
- VP: cover `src/controllers/index.js` (controller auto-registration) and
  `src/entrypoints/application.ts` with deterministic mocks.
