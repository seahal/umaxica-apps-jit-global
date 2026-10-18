# Rails coverage batch 34

## Context

- Implementation date: 2026-07-19 UTC
- Long-term target: 94% total Rails line coverage
- Starting line coverage: 45,559 / 49,210 (92.5808%)
- Ending line coverage: 45,581 / 49,210 (92.6255%)
- Line delta: +22 covered lines, +0.0447 percentage points
- Starting branch coverage: 10,561 / 14,675 (71.9659%)
- Ending branch coverage: 10,571 / 14,675 (72.0341%)
- Branch delta: +10 covered branches, +0.0681 percentage points
- Ending full-suite result: 9,301 runs, 44,546 assertions, 0 failures, 0 errors

## Changes

- Added focused tests for `CommonRedirect` resolver success and failure outcomes.
- Covered invalid navigation and external targets through observable render results.
- Covered malformed return URLs, non-default ports, invalid host normalization, encoded redirect
  paths, fallback behavior, context parameters, and explicit surface resolution.
- Application and database implementation changes: none.
- Dead-code changes: none.

`app/controllers/concerns/common_redirect.rb` improved from 133 / 159 to 155 / 159 covered lines
(83.6478% to 97.4843%). Its remaining uncovered lines are 147, 166, 172, and 173.

## Verification

- `bin/rails test test/controllers/concerns/redirect_test.rb`
  - 9 runs, 28 assertions, 0 failures, 0 errors
- `COVERAGE=true bin/rails test test/`
  - 9,301 runs, 44,546 assertions, 0 failures, 0 errors

## Progress toward 94%

- A 94% result over the current 49,210-line denominator requires at least 46,258 covered lines.
- Current covered lines: 45,581.
- Remaining gain required: 677 lines.
- The goal remains active and is not yet complete.

## Risk boundaries and next candidates

- No authentication, authorization, credential, token, OIDC, logout, payment, destructive,
  external-service, browser, or Redis implementation was changed.
- No configuration, routes, fixtures, factories, migrations, dependencies, or external paths were
  changed or inspected.
- The next batch can finish the four remaining `CommonRedirect` lines, then continue with
  deterministic preference helpers, redirect value objects, serializers, and read-only audits before
  considering higher-risk workflow controllers.
