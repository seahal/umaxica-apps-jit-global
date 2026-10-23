# WU-40: visible Turnstile on the account-recovery OTP send (APP, COM)

- Date: 2026-10-23. Base commit `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`; change uncommitted.
- Decisions: D-141, D-156.

## Change

- `EnforcementRecoveryCeremonyFlow#start_recovery_otp` verifies visible Turnstile before the address
  is resolved; a refusal re-renders the page with `errors` and a fresh challenge, issues nothing,
  writes no re-entry session state. The verify branch (`pass_code`) is unchanged.
- APP and COM recovery pages render `TurnstileWidget` on the address form and send
  `cf-turnstile-response`. Found while doing this: the APP page posted its payload wrapped in
  `data: {...}`, which the controller never read (`params[:recovery_reentry]`); the payload is now
  top-level, and the Vitest expectation that pinned the wrapper was corrected.
- Tests that model a passed challenge now enable the Turnstile stub
  (`identity_recovery_actions_test`, `identity_recovery_entrypoint_render_test`,
  `base_endpoint_rate_limit_test`).
- `docs/security/turnstile.md` lists the recovery send rows.

## Verification

- New `test/controllers/base/identity_recovery_turnstile_test.rb` (A40-1, A40-4, A40-5): 6 runs, 0 failures.
- Recovery actions, entry render, rate-limit and route-contract tests: 34 + 9 runs, 0 failures after
  enabling the stub (before: errors "Turnstile verification is not stubbed", as expected).
- Vitest `gait/pages/base/app/identity`, `gait/features/base_com`: 139 passed. `tsc --build` clean,
  `oxlint` clean, `oxfmt` applied. RuboCop clean.
- A40-2 (dummy path timing) and A40-3 (degradation) rely on the unchanged existing paths; not
  separately re-measured.
