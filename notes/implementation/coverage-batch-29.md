# Rails Coverage Batch 29

- Date/time: 2026-07-18 05:20 UTC
- Scope: Rails/Minitest only. VP and Vitest were intentionally not run.
- Stop condition for this batch: finish verification and notes, then wait for the user's next
  instruction.

## Results

- Starting line coverage: 45,179 / 49,152 (91.9169108073%)
- Ending line coverage: 45,415 / 49,152 (92.3970540365%)
- Line delta: +236 covered lines, +0.4801432292 percentage points
- Starting branch coverage: 10,409 / 14,661 (70.9978855467%)
- Ending branch coverage: 10,484 / 14,661 (71.5094468317%)
- Branch delta: +75 covered branches, +0.5115612850 percentage points
- Remaining line gap to 95%: 2.6029459635 percentage points, approximately 1,280 additional covered
  lines at the current denominator
- Ending full coverage run: 9,217 runs, 43,882 assertions, 0 failures, 1 error, 0 skips
- The isolated failing test immediately passed: 1 run, 10 assertions, 0 failures, 0 errors

SimpleCov excluded one worker result older than its 600-second merge timeout. The ending values
above are from the generated `coverage/coverage.json` report.

## Selected Targets and Tests Added

- `PreferenceCore`
  - child, cookie, and explicit-field reset defaults
  - coordinated source/mirror reset, authorization, audit, and token reload contract
  - expected reset error translation
  - app/org/com resource preference lookup
  - preference surface i18n and route-helper naming
- `SignUpSequenceControllerSupport`
  - result-to-HTTP-status mapping
  - direct and nested requirement/checkpoint parameters
  - explicit and split birthdate parsing
  - matching, stale, and malformed checkpoint versions
  - fail-closed requirement/finalization contexts and registry errors
  - sign-up authentication method labels and unsupported surfaces
  - unknown ticket finalization and model mapping
  - JSON, success, pending-MFA, session-limit, and failure handoff responses
  - HTML/JSON forbidden and failed finalization responses

All sign-up changes were test-only. Authentication order, authorization, verification, state-machine
transitions, controller code, and application behavior were not changed.

## Application and Database Changes

- No application changes.
- No database changes.
- No dead code was deleted.

## Verification and Commands

- Narrow `bin/rails test` runs after each edit
- Combined target run before formatting: 15 runs, 62 assertions, 0 failures, 0 errors
- `bundle exec rubocop -a`: 3,742 files inspected; 55 corrections; exit 1 because 30
  existing/non-autocorrectable offenses remain
- Combined target run after formatting: 20 runs, 70 assertions, 0 failures, 0 errors
- Existing and new sign-up concern tests together after class-name repair: 23 runs, 90 assertions, 0
  failures, 0 errors
- `COVERAGE=true bin/rails test test/`: 9,217 runs, 43,882 assertions, 0 failures, 1 error
- `bin/rails test test/controllers/auth/app/omniauth/omniauth_callbacks_controller_test.rb:519`: 1
  run, 10 assertions, 0 failures, 0 errors
- Read-only parsing of `coverage/coverage.json`

## Repaired Test Collision

The first full coverage attempt exposed that the newly added test class reused the existing
`SignUpSequenceControllerSupportTest` constant. This caused nested Harness and Result constants to
collide across the two files. The new class was renamed to
`SignUpSequenceControllerSupportCoverageTest`. Running both files together then passed with 23 runs
and 90 assertions. The failed collision run was not used as the ending result.

## Remaining Non-Reproducible Error

The final full run reported
`Auth::App::Omniauth::OmniauthCallbacksControllerTest#test_direct_action_early_exits_and_csrf_helpers`
with `NoMethodError: undefined method 'first' for nil`. This batch did not change OmniAuth,
callback, CSRF, or application authentication code. The exact test passed immediately in isolation.
No speculative authentication change was made.

## Skipped Risky Areas

- No routes, configuration, fixtures, factories, dependencies, CI, package files, or external paths
  were inspected or changed.
- No authentication, token, OIDC, credential-secret, payment, withdrawal, Redis, browser, network,
  or external-service application behavior was changed.
- External gem paths printed by warnings were not opened.

## Next Candidates

- Remaining test-only deterministic branches in `SignUpSequenceControllerSupport`, especially
  missing actor and non-finalizing checkpoint responses.
- Pure `PreferenceBase` option-class mapping, local connection fallback, and child lazy-load
  branches.
- The OmniAuth failure should only be investigated further if it becomes reproducible in a
  repository-local ordered or repeated run.
