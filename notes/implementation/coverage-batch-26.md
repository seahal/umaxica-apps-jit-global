# Rails Coverage Batch 26

- Date/time: 2026-07-18 04:04 UTC
- Scope: Rails/Minitest only. VP and Vitest were intentionally not run.

## Results

- Starting Rails line coverage: 45,064 / 49,351 (91.3132459322%)
- Ending Rails line coverage: 45,056 / 49,152 (91.6666666667%)
- Line coverage delta: +0.3534207345 percentage points
- Starting Rails branch coverage: 10,331 / 14,649 (70.5235852277%)
- Ending Rails branch coverage: 10,348 / 14,661 (70.5818157015%)
- Branch coverage delta: +0.0582304738 percentage points
- Remaining line gap to 99%: 7.3333333333 percentage points
- Starting full-suite result: 9,152 runs, 43,153 assertions, 3 failures, 90 errors
- Ending coverage-suite result: 9,152 runs, 43,652 assertions, 0 failures, 0 errors, 0 skips
- A non-coverage full fail-fast verification also completed with 9,152 runs, 43,661 assertions, 0
  failures, and 0 errors.

The covered-line count decreased by eight while the denominator decreased by 199. The resulting
percentage increased by 0.3534 points. The final report noted that one result older than SimpleCov's
600-second merge timeout was excluded; the figures above are the generated final report and command
output.

## Selected Targets

- Side app/com/org health, liveness, readiness, and startup endpoint behavior
- Current app/com/org passkey assertion and registration verifier contracts
- Passkey challenge actor, RP ID, origin, challenge ID, and credential binding
- Missing registration challenge behavior
- WebAuthn security source-layout and rescue inventories
- Parallel test database cloner regression coverage

## Tests Added or Repaired

- Expanded `test/integration/health_endpoints_test.rb` across all three Side surfaces.
- Replaced removed `Webauthn.trusted_origins` and legacy `WebAuthn::Credential.from_get` assumptions
  with current repository verifier boundaries.
- Updated passkey tests to use current `PasskeyCeremonyContext`, actor-global-key, challenge
  consumption, RP configuration, and verifier contracts.
- Added observable assertions for challenge binding and active operator passkey verification.
- Updated WebAuthn source-layout, class-name, and standard-error rescue inventories to current
  repository files.
- Preserved the parallel database cloner behavior and verified its focused test after formatting.

## Application Changes

- `app/controllers/auth/org/sign/in/challenge/passkeys_controller.rb`: issue the Org challenge for
  `@mfa_staff`, matching the actor consumed on verification.
- `app/controllers/concerns/passkey_registration_flow.rb`: return `false` after rendering a
  missing-challenge response so callers do not continue into a second render.
- No database changes.
- No dead code was deleted, so dead-code evidence is not applicable.

## Commands Run

- `bin/rails test`
- `bin/rails test --fail-fast` (repeated while localizing baseline failures)
- Narrow `bin/rails test` runs for each repaired passkey, concern, invariant, support, and health
  target
- Combined target verification: 230 runs, 2,032 assertions, 0 failures, 0 errors
- `bundle exec rubocop -a` (3,734 files inspected; 92 corrections; exit 1 because 27
  pre-existing/non-autocorrectable offenses remain)
- `COVERAGE=true bin/rails test test/`
- Read-only parsing of `coverage/coverage.json`

## Skipped Risky Areas

- No routes, configuration, fixtures, factories, dependencies, CI, package files, or external paths
  were inspected or changed.
- No token, OIDC, logout, credential-secret, payment, destructive, Redis, network, browser, or
  external-service flow was broadened.
- External paths printed by warnings were treated only as runtime context and were not opened.
- VP and Vitest commands were not run per the requested Rails-only scope.

## Next Batch Candidates

After rechecking risk and existing tests, prefer deterministic branches in:

- `app/services/avatar_backfill/audit_legacy_client_bindings.rb` (10 missed lines)
- `app/services/avatar_backfill/backfill_legacy_client_bindings.rb` (9 missed lines)
- `app/services/publishing_migration_audit.rb` (7 missed lines)
- `app/jobs/processor_erasure_notification_job.rb` (7 missed lines)
- `app/models/concerns/withdrawal_occurrence_recording.rb` (5 missed lines)

Avoid `withdrawal_lifecycle` until its destructive-flow safety can be established from
repository-local tests.
