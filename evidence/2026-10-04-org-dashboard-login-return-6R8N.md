# org Dashboard local login and selector destination

Executed on 2026-10-04, approximately 00:46–00:57 UTC, against feature HEAD
`f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`. The shared worktree had concurrent
uncommitted changes (211 paths at the final observation). Only the guarded
`codex_integrity_20261003secret_*` disposable database fleet was used.

## Observed journey and correction

The new public HTTP integration test begins at anonymous org Dashboard, displays
passive Base Sign, and explicitly posts with CSRF protection enabled. It verifies
the real Jump JWT signature and configured issuer/audience before delivering its
target to a separate Auth browser session. External gateway execution is simulated.

The Auth browser performs real Entra JWT verification with a test RSA key and
real WebAuthn assertion verification using FakeClient. Only Microsoft token HTTP,
JWKS retrieval and Turnstile are substituted. Entra and Passkey evidence do not
create OperatorToken. Result delivery returns to the original Base browser;
canonical login creates exactly one root Token with Passkey attribution and a
root-login timestamp. The test then follows the context selector's actual `next`
value and requires a successful Dashboard response.

An initial fixture Operator already occupied its one-session allowance. Completion
correctly moved its flow to SESSION_LIMIT_PENDING and returned 403 without a new
Token. This was a test-precondition error, not product Red. Replaced that actor
with a fresh active Operator without changing session limits or deleting sessions.

Following the selector's actual result then exposed product Red: `next: "/"`
led to authenticated Home's intentional 404. Changed only that existing destination
value to `/dashboard`, as required by the accepted Home/Dashboard ADR. The JSON
keys and value types are unchanged; no return protocol, caller URL, authorization
bypass or callback was added. Updated the app service assertion and added a com
automatic-selection case. The org HTTP journey covers its selector behavior.

## Commands and results

All Ruby test commands used
`bundle exec ruby /tmp/umaxica-secret-db-task.rb test` followed by the listed paths.

- New org journey before the selector correction: 1 test, 34 assertions,
  one failure at the final response (404), no errors/skips.
- New org journey plus `test/services/acme/selector_authority_test.rb` and
  `test/services/selected_context_step_up_boundary_test.rb` after correction:
  8 tests, 128 assertions, no failures/errors/skips. The com case was added later.
- Expanded selection: the three files above, `local_authentication_boundary_test.rb`,
  `auth_base_browser_authority_test.rb`, `root_login_establishment_flow_test.rb`
  under test/integration; `session_issuance_boundary_surfaces_test.rb` and
  `login_cooldown_surfaces_test.rb` under test/controllers/concerns/auth; org
  `in/passkeys_controller_test.rb` and `omniauth/entra_callback_guards_test.rb`:
  95 tests, 674 assertions, 16 failures, no errors/skips.
- Isolated `test/controllers/auth/org/in/passkeys_controller_test.rb`:
  17 tests, 24 assertions, the same 16 failures, no errors/skips. These cases
  enter the Passkey endpoint without its currently mandatory local ceremony
  admission and receive 400 before the old asserted behavior. This test file was
  not changed. Isolation excludes contamination from the new journey; it does
  not establish a clean historical baseline.
- Expanded selection excluding that failing file: 78 tests, 650 assertions,
  no failures/errors/skips. The failing selection remains recorded and unresolved.
- `bundle exec rubocop test/integration/base_org_dashboard_local_login_journey_test.rb
  app/services/base_selector_authority.rb test/services/acme/selector_authority_test.rb`:
  three files, no offenses. Initial formatting offenses in the new test were
  autocorrected without changing thresholds or adding suppressions.
- `git diff --check`: PASS before this evidence record was added.

## Remaining limits

This is HTTP integration, not real-browser or external gateway verification.
It covers org's normal Entra-plus-Passkey journey with region jp; arbitrary original
fullpath and other regional restoration are unproven. Full app/com Dashboard
journeys still require matching end-to-end coverage. The old org Passkey suite's
admission mismatch remains a regression task; success expectations were not
weakened or skipped. Secret, refresh, production routing and deployment were not
changed or verified in this slice.
