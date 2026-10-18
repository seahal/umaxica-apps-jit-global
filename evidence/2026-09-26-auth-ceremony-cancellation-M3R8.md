# Auth ceremony cancellation and plain-text boundary

Commit: e423890e7357e1fa7975eac45aeacdb416b3bce9. The worktree carried unrelated uncommitted work
(preference credential recovery, org administration, `authentication_base.rb` credential-failure
categories) that was present while these checks ran.

## Changes verified

- MFA sign-in cancellation: `DELETE /sign/in/challenge` on app, com and org. It fails the
  `MFA_PENDING` sign-in cycle, clears the cycle locator, `pending_mfa` and `mfa_user_id`, issues no
  token, and returns 303 to the sign-in entry point (the OIDC ceremony stays in its cookie). The
  method-selection page no longer offers a Back link; cancellation is its only exit. Challenge pages
  keep Back (GET, method selection) and add Cancel (DELETE form).
- Step-Up: every Auth verification page (method selection, email, passkey, TOTP) carries a Cancel
  form posting to the existing `SignVerificationCancellation` endpoint. A posted `return_to` and the
  Referer do not change the Auth-side destination.
- Sign-up state-machine rejections return fixed i18n plain text instead of the internal status
  (`invalid_transition` was observed before the change) and log the status server-side.

## Commands

- Red before the change: app MFA tests (404 on DELETE, `back_link` present), seven Step-Up page
  tests (missing `cancel`), the sign-up transition test (body `invalid_transition`).
- Targeted suites: challenges, verification, sign-up and cancellation tests all pass.
- `bun run test`: 1057 passed. `bun run typecheck`: one pre-existing error in
  `src/pages/base/org/avatars/show.tsx`.
- `bin/rails test` over all files except the untracked
  `test/integration/preference_credential_recovery_matrix_test.rb` (fails to load:
  `PreferenceLifecycleSurfaces` undefined): 11914 runs, 9 failures. Two were caused by this change
  and fixed (architecture baseline, now passing). The other seven are in
  `preference_corrupt_cookie_test`, `core_browser_api_boundary_test`,
  `auth/app/edge/v0/token/checks_controller_test` and `standard_error_rescue_inventory_test`, all in
  files under concurrent edit and not touched here.
- Com MFA tests were written after the implementation; red was not observed for them. The Step-Up
  return_to and Referer test passed before and after (existing behavior).
- Org pending MFA is unreachable (every org sign-in completes with `auth_method: "passkey"`, which
  bypasses MFA); org cancellation was verified only for the no-pending path.
