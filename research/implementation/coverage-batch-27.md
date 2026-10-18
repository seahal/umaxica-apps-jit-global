# Rails Coverage Batch 27

- Date/time: 2026-07-18 04:28 UTC
- Scope: Rails/Minitest only. VP and Vitest were intentionally not run.
- Goal remains active: raise verified Rails line coverage to 95%.

## Results

- Starting line coverage: 45,056 / 49,152 (91.6666666667%)
- Ending line coverage: 45,087 / 49,152 (91.7297363281%)
- Line delta: +31 covered lines, +0.0630696614 percentage points
- Starting branch coverage: 10,348 / 14,661 (70.5818157015%)
- Ending branch coverage: 10,368 / 14,661 (70.7182320442%)
- Branch delta: +20 covered branches, +0.1364163427 percentage points
- Remaining line gap to 95%: 3.2702636719 percentage points (approximately 1,608 additional covered
  lines at the current denominator)
- Starting failures/errors: 0 / 0
- Ending full coverage run: 9,181 runs, 43,729 assertions, 1 failure, 0 errors
- The isolated failing test immediately passed: 1 run, 14 assertions, 0 failures, 0 errors.

SimpleCov excluded one worker result older than its 600-second merge timeout. The reported ending
figures are the generated `coverage/coverage.json` totals.

## Selected Targets and Tests Added

- Avatar legacy binding audit:
  - ambiguous subject classification
  - repository and unexpected error reporting
  - JSON report output
- Avatar legacy binding backfill:
  - all non-writing audit outcome mappings
  - JSON report output
- Publishing migration audit:
  - unknown surface rejection
  - unavailable surface reporting
- Processor erasure notification job:
  - unsupported but valid `payment` processor failure path
  - unsupported surface and notification class rejection
- Avatar group and group membership policies:
  - client/non-client decisions
  - selected/wrong account and surface decisions
  - active/archived/removed decisions
- Preference resource synchronization:
  - surface registry mapping
  - direct snapshot and cookie normalization
  - resource lookup, child synchronization, option dispatch, fallback prefixes
  - filtered cookie writes
  - expected and unexpected exception behavior
- Base app groups controller:
  - create, show, update, and archive behavior

## Application and Database Changes

- No application changes.
- No database changes.
- No dead code was deleted.

## Verification

- Combined narrow verification before formatting: 48 runs, 187 assertions, 0 failures, 0 errors
- Combined narrow verification after formatting: 53 runs, 195 assertions, 0 failures, 0 errors
- `bundle exec rubocop -a`: 3,737 files inspected; 48 corrections; exit 1 because 28
  existing/non-autocorrectable offenses remain
- `COVERAGE=true bin/rails test test/`: 9,181 runs, 43,729 assertions, 1 failure, 0 errors
- `bin/rails test test/integration/step_up_authentication_test.rb:278`: 1 run, 14 assertions, 0
  failures, 0 errors
- Read-only parsing of `coverage/coverage.json`

## Unexpected Full-Suite Failure

`StepUpAuthenticationTest#test_email_verification_completion_retains_current_session_and_revokes_other_sessions_and_step-up_grants`
expected a redirect but received HTTP 422 during the full coverage run. The same test passed
immediately in isolation. This batch did not change step-up, email verification, token, session, or
authentication application code. Per the risky-auth and unexpected-failure boundaries, no
speculative authentication change was made.

## Skipped Risky Areas

- No routes, configuration, fixtures, factories, dependencies, CI, package files, or external paths
  were inspected or changed.
- No token, OIDC, credential-secret, payment execution, destructive withdrawal, Redis, browser,
  network, or external-service behavior was changed.
- The `payment` value was used only as an existing valid processor key to test the job's unsupported
  integration branch; no payment flow was invoked.
- External gem paths printed by warnings were not opened.

## Next Batch Candidates

- Continue deterministic branches in `PreferenceResourceSync`, especially child creation, default
  reset, and transaction ownership paths.
- Add controller behavior coverage for group avatar membership create/reorder/detach using existing
  repository service contracts.
- Cover remaining pure policy branches in organization and operator lifecycle policies.
- Recheck the step-up test only for repeatable repository-local order dependence; do not change
  authentication behavior without reproducible evidence.
