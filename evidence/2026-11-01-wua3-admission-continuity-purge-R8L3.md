# WU-A3 admission continuity purge recheck

Date: 2026-11-01

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.

The worktree already contained extensive uncommitted changes. This slice remains uncommitted; no
staged changes were present. The owner approved both WU-A3 state shapes and local migrations in
conversation. No migration or database reset was run in this slice.

## Changes

- `AuthAdmissionBindingPurger` now removes an expired Auth ceremony session after its final binding
  reference is deleted, provided expiry and status-specific retention have elapsed. It covers
  issued, admitted, evidence-recorded, replaced, revoked, completed and cancelled sessions.
- App and Org purger tests cover admitted and terminal continuity, status-event retention, and
  shared references. The existing Step-Up and OIDC transaction purger fixture failures are recorded
  below; those tests were not changed.
- Auth admission redemption no longer passes the obsolete `now:` keyword to
  `AuthCeremonySession.rotate_and_admit!`; that writer owns its database clock.
- Mermaid inventory, storage/value coverage and README entries now describe status-specific,
  final-reference cleanup instead of limiting collection to issued, unadmitted sessions.

## Verification

- `bin/rails test test/operations/auth_admission_binding_purger_test.rb test/integration/acceptance_wua3_initial_attach_race_test.rb`:
  8 runs, 348 assertions, 0 failures, 0 errors, 0 skips.
- Before removing the stale keyword, `acceptance_wua3_initial_attach_race_test.rb` failed in both
  cases with expected HTTP 303 and actual HTTP 400. After the correction, both cases passed as part
  of the combined run above.
- Scoped RuboCop on the controller, purger, and two tests: 4 files inspected, no offenses.
- Ruby syntax checks passed for those four files. `git diff --check` passed.
- Search of `docs/mermaid` and `docs/architecture` found no remaining issued/unadmitted-only cleanup
  statements.

## Failed or unverified

- `test/operations/identity_step_up_ceremony_transaction_purger_test.rb`: 8 errors before any
  assertions. Fixture loading reported FK `fk_client_accounts_on_user_id`, with
  `client_accounts.user_id=980190964` missing from `clients`.
- `test/operations/oidc_authorization_transaction_purger_test.rb`: 2 errors before any assertions,
  with the same fixture FK failure.
- An initial combined invocation of purger, parent-purger and race tests had 2 failures and 10
  errors. The two race failures were fixed and the purger/race subset passed afterward; the parent
  purger fixture errors remain unresolved. No database reset was attempted.
- The full suite and WU-A3 acceptance beyond this slice were not run.
