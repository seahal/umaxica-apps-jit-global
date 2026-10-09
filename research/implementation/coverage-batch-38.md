# Rails Coverage Batch 38

- Date/time: 2026-08-30
- Scope: Rails/Minitest coverage toward 99% line coverage

## Context

A `COVERAGE=true bin/rails test` invocation that passed extra non-path arguments aborted in Minitest
option parsing and reported 0.29% line coverage. A clean `COVERAGE=true bin/rails test test/` run
completed with 10,772 runs, 0 failures, 0 errors, 1 skip, and 51,336 / 53,803 (95.41%) line
coverage. SimpleCov also dropped stale `Integration Tests` results because `merge_timeout` defaults
to 600 seconds and a full coverage run lasts longer than that.

## Decisions

- Keep adding observable harness tests for remaining controller private methods rather than deleting
  live authentication branches.
- Set `SimpleCov.command_name` to a single name and `merge_timeout` to 3600 so a full-suite coverage
  run does not discard in-run results. Do not merge stale `.resultset.json` entries from older
  trees.
- Leave the `.simplecov` line minimum at 94 until a clean full-suite report is at or above 99%.
  Raising the gate first would fail CI without the coverage.

## Tests added

Harness coverage for SignAuthorityRedirect, SignEmailRegistrationFlow remaining branches,
ComSignUpCheckpointPage, AuthenticationVisitor, SignSocialAuthenticationEndpoint, com verification
base mapping, app verification passkeys, TOTP and passkey verification actions, and app/com/org
passkey options and verification identity helpers.

## Application changes

- `.simplecov` only: single command name and a 3600-second merge timeout.

## Follow-up

Remaining missed lines are concentrated in authentication controllers and concerns (~2,000 lines to
99%). Continue with the same harness pattern on preference concerns, sign-in/up controllers, and
OIDC callback branches.
