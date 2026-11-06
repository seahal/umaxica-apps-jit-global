# WU-A3 mismatched SID-less first admission target refusal

Date: 2026-11-01

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.

The worktree contained existing uncommitted changes. This work remains uncommitted; no commit was
created.

## Finding and change

The approved AC-53 initial-admission exception can leave two admitted ceremonies when two first
requests have no `auth_sid`. A request for the admitted target that does not match the currently
delivered cookie must receive the D-52 phase-refusal response. Before the change, the new
public-path case reproduced HTTP 400 for APP where the contract requires 409.

`AuthCeremonyAdmission` now compares a redeemed binding's admitted ceremony with the active ceremony
selected by the current `auth_sid`; a mismatch returns 409 through the existing refusal boundary.
Requests for a switched binding also return that refusal. The acceptance test verifies APP and ORG,
both cookie arrival orders, unchanged parent/binding/ceremony/cookie state, no authentication-cookie
or DBSC response headers, and continued access to the selected target. The App Switch test also
verifies that an old switched entry reference returns 409 without changing the old or new ceremony.
The first-admission test creates both resulting admission sessions in separate test sessions and
then models shared-browser cookie delivery; it does not run two simultaneous network requests.

## Verification

- Before the controller change, the focused new case failed: 1 run, 15 assertions, expected 409,
  received 400 for APP.
- After the change, `acceptance_wua3_initial_attach_race_test.rb`, `sign_entry_exit_flow_test.rb`,
  and `sign_entry_exit_org_flow_test.rb` passed together: 16 runs, 476 assertions, 0 failures, 0
  errors, 0 skips.
- The existing A12-3 redeemed-entry repeat boundary passed: 1 run, 25 assertions, 0 failures, 0
  errors, 0 skips.
- Scoped RuboCop inspected `auth_ceremony_admission.rb` and
  `acceptance_wua3_initial_attach_race_test.rb`: no offenses.
- Ruby syntax checks passed for those files; `git diff --check` passed.

## Not verified

The test models the accepted cookie-arrival outcome with separate sequential HTTP sessions; it does
not verify simultaneous network requests or a real browser. The full suite and broader WU-A3
acceptance were not run.
