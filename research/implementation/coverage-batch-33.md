# Rails coverage batch 33

## Context

- Implementation date: 2026-07-19 UTC
- Scope: one test-only batch to raise total Rails coverage
- Starting line coverage: 45,535 / 49,210 (92.5320%)
- Ending line coverage: 45,559 / 49,210 (92.5808%)
- Line delta: +24 covered lines, +0.0488 percentage points
- Starting branch coverage: 10,542 / 14,675 (71.8365%)
- Ending branch coverage: 10,561 / 14,675 (71.9659%)
- Branch delta: +19 covered branches, +0.1295 percentage points
- Starting full-suite result: 9,292 runs, 44,508 assertions, 0 failures, 2 errors
- Ending full-suite result: 9,298 runs, 44,534 assertions, 0 failures, 0 errors

## Changes

- Replaced two unsupported negative-inclusion assertions in the standalone repository-language
  checker test with core Minitest assertions.
- Added deterministic coverage for live, blank, terminal, invalid, expired, and cleared
  `SignInSequenceCarrier` states.
- Added read-only audit coverage for existing lean and CMS publishing tables.
- Added WebAuthn option serialization coverage for hash-backed user IDs, snake-case credential
  lists, binary strings, byte arrays, integers, and pass-through objects.
- Application and database implementation changes: none.
- Dead-code changes: none.

The selected production targets now have 100% line coverage:

- `app/services/sign_in_sequence_carrier.rb`: 65 / 65
- `app/services/publishing_migration_audit.rb`: 67 / 67
- `app/values/webauthn/options_serializer.rb`: 36 / 36

## Verification

- `bin/rails test test/tooling/repository_language_check_test.rb`
- `bin/rails test test/services/sign_in/sequence_carrier_test.rb test/tooling/repository_language_check_test.rb`
- `bin/rails test test/services/publishing_migration_audit_test.rb`
- `bin/rails test test/values/webauthn_options_serializer_test.rb test/services/sign_in/sequence_carrier_test.rb test/services/publishing_migration_audit_test.rb test/tooling/repository_language_check_test.rb`
- `bin/rails test test/models/model_only_line_coverage_test.rb test/tooling/repository_language_check_test.rb test/services/sign_in/sequence_carrier_test.rb test/services/publishing_migration_audit_test.rb test/values/webauthn_options_serializer_test.rb`
- `bin/repository-language-check`
- `bundle exec rubocop -a`
- `COVERAGE=true bin/rails test test/`

The first full run exposed a timezone-dependent assertion added in this batch. It was changed to
compare against the same parsed time object's string representation. The focused tests then passed,
and the final full run completed with no failures or errors.

The repository-language checker command found extensive pre-existing non-English repository prose
outside this batch. No policy exceptions or unrelated prose were changed.

RuboCop reported pre-existing repository-wide offenses and exited nonzero. Its automatic edits
outside this batch were restored. Batch-specific formatting changes were retained where behavior
remained correct.

## Risk boundaries and next candidates

- No authentication, credential, token, OIDC, logout, payment, destructive, network, Redis, or
  browser implementation was changed.
- No configuration, routes, fixtures, factories, migrations, dependencies, or external paths were
  modified or inspected.
- A later low-risk batch can continue with deterministic serializers, read-only audits, pure value
  objects, and simple state carriers already covered by focused tests.
