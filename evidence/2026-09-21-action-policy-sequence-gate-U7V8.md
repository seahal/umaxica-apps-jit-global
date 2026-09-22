# Action Policy sequence-gate authorization

Date: 2026-09-21

## Scope

The Base app/com/org Welcome controllers and Auth app/com/org sign-in check controllers used
`allowed_to?` for sign-in sequence state, but private actions still needed an explicit
`authorize!` record for `verify_authorized`. The change keeps the existing state gate and records
the matching Action Policy authorization after the current session is bound.

## Adversarial finding and correction

The public `Base::App::WelcomesController#show` dispatch was reproduced with a valid
`DASHBOARD_PENDING` client flow and failed with `ActionPolicy::UnauthorizedAction` from
`AuthenticationBase#verify_private_action_authorized!`. The failure was a missing authorization
record, not a CSRF, authentication, or cookie-boundary failure.

The sequence gate now authorizes `show_dashboard?` for a dashboard-pending cycle and
`consume_return?` for a return-pending cycle. The checkpoint continuation authorizes
`show_checkpoint?` after its existing state check. The three Base Welcome controllers and three
Auth checkpoint controllers no longer carry the confirmed-obsolete TODO comments.

## Verification

- Focused controller and sequence suite: 102 runs, 245 assertions, 0 failures, 0 errors, 0 skips.
- Full Rails suite: 11,442 runs, 73,145 assertions, 0 failures, 0 errors, 5 skips.
- Targeted RuboCop over 11 changed controller/test files: no offenses.
- The full suite retained its existing skips and did not disable CSRF, Action Policy, rate limits,
  or authentication controls.

## Scope and remaining limits

No routes, cookies, CSRF declarations, authentication modes, database schema, or external services
were changed. `TokenEmergencyService` and `OutageService` remain unimplemented placeholders because
their product contract and callers are not established by the current repository evidence; no
speculative authority or state machine was introduced.

No commit was created because the workspace `.git` index is read-only. No GitHub or external write
was performed.
