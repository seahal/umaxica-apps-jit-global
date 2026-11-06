# Post-switch OP-mediated Step-Up regression rerun

Date: 2026-11-04

Full commit hash: `b30345216886c98af1f04cbd434f067f12decf01`.

The worktree had extensive uncommitted changes. This result describes the current worktree and does
not attribute the failures to this continuation's documentation updates.

## Commands and results

- `PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/avatar_ownership_transfers_controller_test.rb test/integration/step_up_authentication_test.rb`
  — **50 runs, 229 assertions, 3 failures, 0 errors, 0 skips**.
  - `StepUpAuthenticationTest#test_a_Security_Mode_downgrade_through_the_controller_revokes_every_session_including_the_current_one`:
    expected redirect, received 422. The valid `ADVANCED → NORMAL` path is refused at the current RP
    session-token guard.
  - `StepUpAuthenticationTest#test_email_verification_completion_retains_current_session_and_revokes_other_sessions_and_step-up_grants`:
    expected redirect, received 503.
  - `StepUpAuthenticationTest#test_POST_sensitive_action_returns_401_when_step-up_is_not_satisfied`:
    expected 401, received 503.
  - The expired-event and revoked-root downgrade refusal cases passed.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/base_rp_contact_registration_refusal_test.rb`
  — **2 runs, 36 assertions, 0 failures, 0 errors, 0 skips**. APP/ORG contact-registration requests
  remain fail-closed at the interim refusal path.
- `git diff --check` on the scoped OP committer, tests and lock-inventory files — passed.

Only configured test databases were accessed. No database cleanup or application-code change was
performed in this rerun. The contact-registration refusal result confirms the current refusal
behavior; it does not verify a working RP-owned registration flow.
