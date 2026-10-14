# Model Coverage Is Measured Standalone Without an Enforced Threshold

## Status

Accepted on 2026-10-14 by the repository owner.

## Context

A full `bin/rails test` run is slow, so model coverage was measured by running only `test/models`
with `COVERAGE=true` and aggregating the SimpleCov result for `app/models/`. Measured at commit
`aa92265b7e63bf874fddd0aa8f278d5ed19de6b5` with uncommitted worktree changes present, over 911
files:

| Metric | Covered / Total | Coverage |
| ------ | --------------- | -------- |
| Line   | 15089 / 15788   | 95.57%   |
| Branch | 1418 / 2134     | 66.45%   |
| Method | 1842 / 2141     | 86.03%   |

The run had six errors from Avatar committed-history tests that require an isolated worker fleet,
so their coverage is excluded. The weakest branch coverage sits mainly in long-standing concerns for
authentication, sessions, tokens and credentials, such as `auth_email_otp_challenge.rb`,
`session_limit_resolution_transactionable.rb`, `client_secret_credential.rb` and
`telephone_contact_binding.rb`.

A full-suite run exercises models through controllers and integration tests and inflates model
coverage. The standalone figure shows how well the model tests alone protect model behavior.

## Decision

- Models **SHOULD** have their coverage measured by running the model tests alone
  (`COVERAGE=true bin/rails test test/models`), counting only `app/models/`, and that coverage
  **SHOULD** be raised over time, with branch coverage as the main gap.
- This is not added to configuration. `.simplecov`, `test/test_helper.rb` and CI gain no minimum
  coverage threshold, no model-only group or profile, and no failing gate for this measurement.

## Consequences

- Model coverage gaps stay visible through a repeatable manual measurement without slowing or
  failing ordinary test runs.
- Nothing prevents regressions automatically; improvement depends on deliberate follow-up work.
- Revisiting enforcement in configuration requires amending this ADR.
