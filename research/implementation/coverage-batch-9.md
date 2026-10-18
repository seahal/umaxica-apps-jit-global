# Coverage Batch 9 — 2026-06-18

## Summary

This batch added focused unit and integration tests for safe, low-risk Rails targets left after
Batch 8: the `FlowSignUp` concern, `SignUp::BasePolicy` and `SignUp::ParticipantPolicy`, read-only
content API revision endpoints, and the remaining health-controller show actions across all declared
surfaces.

No application or database code was changed. All changes were test-only.

## Starting metrics

- Rails line coverage: **91.02%** (40,997 / 45,041 relevant lines)
- VP line coverage: **100%**
- Baseline `COVERAGE=true bin/rails test test/` (from Batch 8): 7,972 runs, 89 failures, 5 errors

## Ending metrics

- Rails line coverage: **91.20%** (41,103 / 45,067 relevant lines)
- VP line coverage: **100%**
- Ending `COVERAGE=true bin/rails test test/`: 7,986 runs, 89 failures, 7 errors (exit 2 because
  SimpleCov minimum threshold of 98% was not met)

## Coverage deltas

- Rails: **+0.18%** (91.02% → 91.20%)
- VP: **0.00%** (100% → 100%)

The full-suite run had two more errors than the Batch 8 baseline. The new errors are PostgreSQL
fixture-loading deadlocks (`LayoutMetaTagsTest` and
`Sign::App::Settings::Mfa::ChallengesControllerTest`) and are not related to the new tests, which
all pass in isolation.

## Targets selected

1. `app/models/concerns/flow_sign_up.rb` — predicates, class methods, lifecycle transitions, and the
   `CANCELLED` rescue path.
2. `app/policies/sign_up/base_policy.rb` — `surface_matches?` ArgumentError rescue,
   `terminal_status_ids` KeyError rescue, `pending_actor_matches?`, and `actor_class_matches?`
   branches.
3. `app/policies/sign_up/participant_policy.rb` — `enter_guardrail?` and `enter_checkpoint?` for
   mutable tickets at the correct steps.
4. Content surface revision controllers (6 files):
   - `app/controllers/docs/com/api/v0/entries/revisions_controller.rb`
   - `app/controllers/docs/org/api/v0/entries/revisions_controller.rb`
   - `app/controllers/help/com/api/v0/entries/revisions_controller.rb`
   - `app/controllers/help/org/api/v0/entries/revisions_controller.rb`
   - `app/controllers/news/com/api/v0/entries/revisions_controller.rb`
   - `app/controllers/news/org/api/v0/entries/revisions_controller.rb`
5. Health endpoints for all declared surfaces in `test/integration/health_endpoints_test.rb` —
   covers the remaining missed `show` lines in `healths_controller.rb` and `health/*_controller.rb`
   files across acme, sign, base, palm, core, docs, help, and news surfaces.

## Tests added

- `test/models/operator_sign_up_flow_test.rb` (reused path; tests `FlowSignUp` via an in-test
  `ApplicationRecord` subclass with a temporary table).
- `test/policies/sign_up/base_policy_test.rb` (new file).
- `test/policies/sign_up/participant_policy_test.rb` (new file).
- `test/integration/docs_help_news_revisions_test.rb` (new file).
- Added one integration test to `test/integration/health_endpoints_test.rb` that requests
  `/health.json`, `/health/liveness`, `/health/readiness`, and `/health/startup` for every surface
  declared in the existing `SURFACES` array.

## App/DB changes

None. All changes were test-only.

## Dead-code evidence

No dead code was removed.

## Commands run

- `bin/rails test test/integration/health_endpoints_test.rb test/integration/docs_help_news_revisions_test.rb test/models/operator_sign_up_flow_test.rb test/policies/sign_up/base_policy_test.rb test/policies/sign_up/participant_policy_test.rb`
  — narrow validation (28 runs, 0 failures, 0 errors)
- `vp test` — VP regression check
- `vp check --fix` — passed
- `bundle exec rubocop -a` — 10 auto-corrected offenses in the new `FlowSignUp` test file
- `COVERAGE=true bin/rails test test/` — final Rails coverage
- `vp test --coverage` — final VP coverage

## Skipped risky areas

- Authentication / OIDC / token / credential / session flows
- Payment, withdrawal, and destructive flows
- External service integrations
- Redis / network / browser / system-test paths
- Time-sensitive, random, or parallelism-sensitive behavior
- Framework callbacks and monkey patches

## Next batch candidates

- Static/read-only controllers with one or two missed lines (e.g., `WelcomesController`,
  `SelectorsController`, `AccountsController`, `RobotsController`, `SitemapsController`,
  root/configuration controllers) using request tests or an integration loop.
- Deterministic model concerns still below 100% such as `ApplicationRecord` fixed-ID seed fallback
  paths, `SignOutFlow` scopes/delegates, and `OauthCallbackStateable#connection_owner` branches —
  stay away from the OAuth state consumption path itself.
- Low-risk service objects with small miss counts, e.g. `RetentionCrossDatabaseChildPurge` and
  `OrgOperatorLifecycleExecute`.
- Continue extending policy coverage for non-credential policies.
