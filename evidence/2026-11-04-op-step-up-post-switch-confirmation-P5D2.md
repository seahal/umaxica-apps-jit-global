# Post-switch OP-mediated Step-Up regression recheck

- Date: 2026-11-04
- Full git HEAD: `b30345216886c98af1f04cbd434f067f12decf01`
- Worktree: extensively modified and uncommitted; no application code changed during this test run.

## Command and result

`PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/avatar_ownership_transfers_controller_test.rb test/integration/step_up_authentication_test.rb`
returned **50 runs, 229 assertions, 3 failures, 0 errors, 0 skips**.

The failures are:

- `StepUpAuthenticationTest#test_a_Security_Mode_downgrade_through_the_controller_revokes_every_session_including_the_current_one`
  — expected redirect, got 422. The RP-local update reaches the controller without the required OP
  current-session token.
- `StepUpAuthenticationTest#test_email_verification_completion_retains_current_session_and_revokes_other_sessions_and_step-up_grants`
  — expected redirect, got the interim 503 contact-registration refusal.
- `StepUpAuthenticationTest#test_POST_sensitive_action_returns_401_when_step-up_is_not_satisfied` —
  expected 401, got 503 at the same contact-registration boundary.

The expired-event and revoked-root downgrade refusal cases passed. The APP/ORG contact-registration
fail-closed test previously passed 2 runs / 36 assertions; it was not rerun here. The Q-1
API/session binding and O-11 API/receipt shapes remain unapproved, so this recheck made no code or
test expectation changes. Only configured test databases were accessed; no database cleanup was
performed.
