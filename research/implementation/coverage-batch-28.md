# Rails Coverage Batch 28

- Date/time: 2026-07-18 04:48 UTC
- Scope: Rails/Minitest only. VP and Vitest were intentionally not run.
- Goal remains active: verified Rails line coverage of 95%.

## Results

- Starting line coverage: 45,087 / 49,152 (91.7297363281%)
- Ending line coverage: 45,179 / 49,152 (91.9169108073%)
- Line delta: +92 covered lines, +0.1871744792 percentage points
- Starting branch coverage: 10,368 / 14,661 (70.7182320442%)
- Ending branch coverage: 10,409 / 14,661 (70.9978855467%)
- Branch delta: +41 covered branches, +0.2796535025 percentage points
- Remaining line gap to 95%: 3.0830891927 percentage points, approximately 1,516 additional covered
  lines at the current denominator
- Starting failures/errors: 0 / 0 in the isolated rerun following batch 27's non-reproducible
  failure
- Ending failures/errors: 0 / 0
- Ending suite: 9,198 runs, 43,794 assertions, 0 failures, 0 errors, 0 skips

SimpleCov excluded one worker result older than its 600-second merge timeout. The ending values
above are from the generated `coverage/coverage.json` report.

## Selected Targets and Tests Added

- `PreferenceResourceSync`
  - resetting child defaults and consent values
  - existing and newly created preference children
  - no-owner, same-owner, and cross-owner dual-write transaction paths
- `PreferenceAdoption`
  - app/org/com and unknown resource mappings
  - local preference snapshots and flat-value copying
  - direct cookie consent copying
  - cross-database option-name resolution and no-match behavior
  - theme normalization and timestamp touch behavior
- `PreferenceWebCookieEndpoint`
  - decode fallback
  - non-fatal buffer synchronization failure
  - override state
  - filtered and cast hash parameters
  - refresh-expiry lookup fallback
  - existing and newly created cookie rows
- `Base::App::GroupAvatarMembershipsController`
  - attach/create response
  - reorder/update response
  - detach/destroy response

## Application and Database Changes

- No application changes.
- No database changes.
- No dead code was deleted.

## Commands Run

- Narrow `bin/rails test` runs after each target edit
- Combined target verification before formatting: 38 runs, 140 assertions, 0 failures, 0 errors
- `bundle exec rubocop -a`: 3,739 files inspected; 34 corrections; exit 1 because 30
  existing/non-autocorrectable offenses remain
- Combined target verification after formatting: 43 runs, 148 assertions, 0 failures, 0 errors
- `COVERAGE=true bin/rails test test/`: 9,198 runs, 43,794 assertions, 0 failures, 0 errors
- Read-only parsing of `coverage/coverage.json`

## Skipped Risky Areas

- No routes, configuration, fixtures, factories, dependencies, CI, package files, or external paths
  were inspected or changed.
- No authentication, step-up, token, OIDC, credential-secret, payment, destructive withdrawal,
  Redis, browser, network, or external-service application behavior was changed.
- External gem paths printed by warnings were not opened.

## Next Batch Candidates

- Remaining deterministic `PreferenceResourceSync` child creation and direct-option write paths.
- `PreferenceCore` reset helpers, context-key mapping, and pure URL/helper selection branches.
- Remaining simple group membership error responses where existing controller contracts provide a
  safe precedent.
- Pure policies with uncovered nil, wrong-resource, inactive-state, and ownership decisions.
