# Coverage Batch 23

Date: 2026-07-17 UTC

## Scope

Rails coverage only. VP/Vitest commands were intentionally not run.

## Coverage Snapshot

- Starting Rails line coverage: 91.2180% (45,017 / 49,351 lines).
- Ending Rails line coverage: 91.3153% (45,065 / 49,351 lines).
- Rails line coverage delta: +0.0973 percentage points.
- Starting Rails branch coverage: 70.4417% (10,319 / 14,649 branches).
- Ending Rails branch coverage: 70.5372% (10,333 / 14,649 branches).
- VP coverage: not measured in this Rails-only batch.

The full run again excluded one SimpleCov result older than the 600-second merge timeout; the
aggregate line denominator remained stable.

## Failures / Errors

- Starting failures / errors: 0 / 0 from the previous full Rails run.
- Ending failures / errors: 0 / 0.
- Ending full run: 9,138 runs, 43,495 assertions, 0 skips.

## Selected Targets

1. `CollectiveMembership::Accept`.
2. `CollectiveMembership::Suspend`.
3. `CollectiveMembership::Revoke`, including idempotent re-entry.
4. `CollectiveMembership::TransferUnit`, same-enterprise success and cross-enterprise rejection.
5. `CollectiveMembership::MakePrimary`.
6. `CollectiveMembership::Grant`, success, duplicate active, duplicate primary, and mismatched unit
   branches.

## Tests Added

Added ten real-database behavior tests to `test/models/persona_enterprise_model_layer_test.rb`. The
tests cover state transitions, approver/revoker ownership, primary membership replacement, unit
ownership boundaries, duplicate membership rejection, and persisted field outcomes.

Focused verification passed: 24 runs, 90 assertions, 0 failures, 0 errors, 0 skips.

All six targeted service files now report 100% line coverage in the ending report:

- `accept.rb`: 13 / 13
- `grant.rb`: 30 / 30
- `make_primary.rb`: 14 / 14
- `revoke.rb`: 16 / 16
- `suspend.rb`: 12 / 12
- `transfer_unit.rb`: 15 / 15

## App / DB Changes

- No application or database files changed.
- No dead-code deletion was attempted.

## Dead-Code Evidence

- None. This batch was test-only.

## Commands Run

- `bin/rails test test/models/persona_enterprise_model_layer_test.rb`
- `bundle exec rubocop -a`
- `COVERAGE=true bin/rails test test/`

RuboCop auto-corrected unrelated pre-existing formatting in
`test/support/parallel_test_database_cloner.rb` and its test; those out-of-scope corrections were
restored. Corrections in the target test file were retained.

## Skipped Risky Areas

- VP/Vitest tests and coverage, including `vp test --coverage`, were skipped by explicit scope.
- Authentication, sessions, OIDC, tokens, payment, withdrawal, external integrations, routes,
  configuration, fixtures, factories, CI files, and dependencies were not changed.
- Runtime warnings and external paths were not investigated outside the repository.

## Next Batch Candidates

- Continue with deterministic non-security models, helpers, and simple services from the current
  SimpleCov report.
- Avoid coverage-only edits to authentication, token, OIDC, destructive, or incomplete TODO flows.
