# Coverage Batch 21

Date: 2026-07-17 UTC

## Scope

This batch intentionally covered Rails only. VP/Vitest commands were not run because the user
requested a Rails coverage batch.

## Coverage Snapshot

- Starting Rails line coverage: 91.0965% (45,019 / 49,419 lines) from the repository report at batch
  start.
- Ending Rails line coverage: 91.1896% (45,003 / 49,351 lines).
- Rails line coverage delta: +0.0931 percentage points.
- Starting Rails branch coverage: 70.2653% (10,303 / 14,663 branches).
- Ending Rails branch coverage: 70.4007% (10,313 / 14,649 branches).
- VP coverage: not measured in this Rails-only batch. The previous repository note recorded VP at
  0%, but no current VP result was generated.

The ending SimpleCov report excluded one result older than the 600-second merge timeout, so the line
denominator changed between the two reports. The percentage is reported as emitted by the official
full Rails run.

## Failures / Errors

- Starting failures / errors: 1 failure, 1 error, as recorded by the previous full Rails batch
  report.
- Ending failures / errors: 0 failures, 0 errors, 0 skips.
- Ending full run: 9,123 runs, 43,442 assertions.

## Selected Targets

1. `GroupAvatarMembership` removal timestamp validation branch.
2. `Publishing::MediaUsage` invalid owner-XOR branch.
3. `Publishing::MediaUsage` valid single-owner branch.
4. `PromotionalEmailUnsubscribeHeaders#configured_promotional_unsubscribe_host` configured
   environment branch.
5. `PromotionalEmailUnsubscribeHeaders#configured_promotional_unsubscribe_host` surface-default
   branch.

## Tests Added

- `test/services/group_avatar_memberships_test.rb`
  - rejects a removal timestamp before assignment.
- `test/models/publishing/schema_and_models_test.rb`
  - rejects two media owners;
  - accepts exactly one media owner.
- `test/mailers/concerns/promotional_email_unsubscribe_headers_test.rb`
  - uses a configured unsubscribe host;
  - uses the deterministic surface default when the environment key is absent.

All three focused files passed together: 16 runs, 43 assertions, 0 failures, 0 errors, 0 skips.

## App / DB Changes

- No application or database files changed.
- No dead-code deletion was attempted.

## Dead-Code Evidence

- None. This batch was test-only.

## Commands Run

- `bin/rails test test/services/group_avatar_memberships_test.rb`
- `bin/rails test test/models/publishing/schema_and_models_test.rb`
- `bin/rails test test/mailers/concerns/promotional_email_unsubscribe_headers_test.rb`
- `bin/rails test test/services/group_avatar_memberships_test.rb test/models/publishing/schema_and_models_test.rb test/mailers/concerns/promotional_email_unsubscribe_headers_test.rb`
- `bundle exec rubocop -a` (pre-existing unrelated corrections were reverted; remaining offenses are
  outside this batch)
- `COVERAGE=true bin/rails test test/`

## Skipped Risky Areas

- VP/Vitest tests and coverage, including `vp test --coverage`, were intentionally skipped.
- `vp check --fix` was skipped because this batch was restricted to Rails coverage.
- Authentication, sessions, OIDC, token, payment, withdrawal, external integrations, routes,
  configuration, fixtures, factories, CI files, and dependencies were not changed.
- The external-path warnings emitted during the Rails run were treated as runtime context only; no
  external files were inspected.

## Next Batch Candidates

- Re-read the ending Rails report and select another small set of deterministic, non-security
  model/helper/value branches.
- Avoid expanding into authentication, token, OIDC, controller workflow, or destructive-flow targets
  without a separate safety review.
