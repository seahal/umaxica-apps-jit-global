# Coverage Batch 22

Date: 2026-07-17 UTC

## Scope

Rails coverage only. VP/Vitest commands were intentionally not run.

## Coverage Snapshot

- Starting Rails line coverage: 91.1896% (45,003 / 49,351 lines).
- Ending Rails line coverage: 91.2180% (45,017 / 49,351 lines).
- Rails line coverage delta: +0.0284 percentage points.
- Starting Rails branch coverage: 70.4007% (10,313 / 14,649 branches).
- Ending Rails branch coverage: 70.4417% (10,319 / 14,649 branches).
- VP coverage: not measured in this Rails-only batch.

The full run again excluded one SimpleCov result older than the 600-second merge timeout. The ending
report retained the same aggregate line denominator as the starting report.

## Failures / Errors

- Starting failures / errors: 0 / 0 from the previous full Rails run.
- Ending failures / errors: 0 / 0.
- Ending full run: 9,128 runs, 43,457 assertions, 0 skips.

## Selected Targets

1. `GroupAvatarMemberships::Reorder` active success path.
2. `GroupAvatarMemberships::Reorder` inactive membership rejection.
3. `GroupAvatarMemberships::Reorder` negative position rejection.
4. `GroupManagement::Update` active update path with attribute filtering.
5. `GroupManagement::Update` archived group rejection.

## Tests Added

- `test/services/group_avatar_memberships_test.rb`
  - added active reorder, inactive rejection, and negative-position rejection tests.
- `test/services/group_management_test.rb`
  - added active update and archived-group rejection tests.

Focused verification passed: 11 runs, 33 assertions, 0 failures, 0 errors, 0 skips.

## App / DB Changes

- No application or database files changed.
- No dead-code deletion was attempted.

## Dead-Code Evidence

- None. This batch was test-only.

## Commands Run

- `bin/rails test test/services/group_avatar_memberships_test.rb test/services/group_management_test.rb`
- `bundle exec rubocop -a`
- `COVERAGE=true bin/rails test test/`

RuboCop auto-corrected unrelated pre-existing formatting in
`test/support/parallel_test_database_cloner.rb` and its test; those out-of-scope corrections were
restored. The target test formatting corrections were retained.

## Skipped Risky Areas

- VP/Vitest tests and coverage, including `vp test --coverage`, were skipped by explicit scope.
- Authentication, sessions, OIDC, tokens, payment, withdrawal, external integrations, routes,
  configuration, fixtures, factories, CI files, and dependencies were not changed.
- TODO-only `OutageService` and security-sensitive coverage gaps were not selected merely for
  coverage gain.
- Runtime warnings and external paths were not investigated outside the repository.

## Next Batch Candidates

- Continue with deterministic, non-security model/helper/value targets from the current report.
- Prefer targets adjacent to existing tests and avoid coverage-only changes to incomplete TODOs or
  authentication/token/OIDC workflows.
