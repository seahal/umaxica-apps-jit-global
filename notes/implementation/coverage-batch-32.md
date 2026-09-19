# Rails model-only coverage batch 32

## Context

- Implementation date: 2026-07-18 UTC
- Scope: raise line coverage for `app/models/**` under `COVERAGE=true bin/rails test:models`
- Changes allowed in this cycle: model tests only
- Starting model line coverage: 9,706 / 9,978 (97.2740%)
- Ending model line coverage: 9,978 / 9,978 (100.0000%)
- Model line delta: +272 covered lines, +2.7260 percentage points
- Starting model test result: 2,863 runs, 9,002 assertions, 0 failures, 0 errors
- Ending model test result: 2,894 runs, 9,299 assertions, 0 failures, 0 errors

## Tests added

Added `test/models/model_only_line_coverage_test.rb` with 31 focused tests and 297 assertions. The
tests cover model behavior that had previously been reached only by controller, service, policy, or
integration tests, including:

- step-up transaction creation, scopes, claims, cancellation, consumption, validation, connection
  owners, purgeability, and result-JTI collisions
- withdrawal ceremony issuance, authentication, defaults, expiration, token comparison, state
  changes, and occurrence recording
- identity ceremony candidate lookup, expiration, consumption, and social assertion shape validation
- privacy request, retention hold, and processor notification defaults and transitions
- OIDC usage rotation and authorization resume URLs
- session-limit transaction creation, lookup, predicates, and completion transitions
- one-time secret credential usability and final-use consumption
- Actor configuration and preference value semantics
- DBSC mappings and downgrade behavior
- MFA compatibility behavior and sign-in flow legacy states
- avatar group and membership state validation
- preference value defaults and fixed reference records
- small public model APIs, scopes, reference defaults, and chronicle actor assignment

No application or database implementation was changed. No dead code was removed.

## Verification

- `bin/rails test test/models/model_only_line_coverage_test.rb`
  - Final targeted result: 31 runs, 297 assertions, 0 failures, 0 errors
- `COVERAGE=true bin/rails test:models`
  - Final model result: 2,894 runs, 9,299 assertions, 0 failures, 0 errors
  - Generated report aggregate for `app/models/**`: 9,978 / 9,978 lines, 100%
  - No `app/models/**` file remains below 100% line coverage

The coverage command exits with status 2 because the repository's global SimpleCov thresholds
evaluate all application files: running only model tests reports 57.87% overall line coverage and
14.33% overall branch coverage. This does not indicate a test failure and does not change the
separately verified 100% `app/models/**` line aggregate.

## Boundaries and follow-up

- Controller tests and controller implementation were not changed in this cycle.
- Authentication, OIDC, credential, logout, and withdrawal application implementations were not
  changed; only their existing model APIs were exercised.
- VP, Vitest, full Rails coverage, RuboCop, external services, installed gems, configuration,
  routes, fixtures, factories, and system paths were not changed or inspected.
- Future model work should preserve the 100% model-only line baseline and focus on branch coverage
  only if explicitly requested.
