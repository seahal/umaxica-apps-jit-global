# Sign-In State Machine Pilot Implementation Notes

## Context

- Related ADR/docs/plans:
  - `adr/authentication-assurance-level-boundaries.md`
  - `adr/actor-current-facade.md`
  - `adr/static-and-guest-controller-boundaries.md`
  - `docs/security/sign-in-sequence.md`
  - `docs/architecture/controller-lifecycle.md`
- Implementation date: 2026-05-20

## Decisions Made During Implementation

- Decision: Use `session[:sign_in_sequence]` as the canonical short-lived sign-in sequence carrier
  for the pilot.
  - Why: The flow is not deployed yet, and a single canonical session payload avoids maintaining
    legacy scattered sign-in sequence state.
  - Alternatives considered: compatibility wrappers over existing checkpoint-only session state.
  - Follow-up needed: decide later whether OIDC/RP or multi-device sequence handling requires a
    DB-backed short-lived carrier.

- Decision: Enforce Action Policy on the `app` checkpoint participant first.
  - Why: Checkpoint direct access was the most visible participant gap and can be closed without
    changing credential verification or token issuance internals.
  - Alternatives considered: broad policy enforcement across all sign-in routes in one change.
  - Follow-up needed: extend the same participant policy pattern to MFA challenge, session-limit
    gate, dashboard participant, `com`, and `org`.

## Deviations From Plan

- Change: The initial pilot does not yet make dashboard an advancing participant.
  - Why: Keeping ordinary dashboard rendering stable limits the first change to checkpoint sequence
    enforcement while introducing the shared carrier and state machine classes.
  - Risk: Dashboard still needs the planned split between ordinary dashboard access and
    sequence-participant access.
  - Follow-up: implement dashboard participant behavior after checkpoint coverage is stable.

## Review Notes

- Tests run:
  - `ruby -c` on changed Ruby files.
  - `RAILS_ENV=test bin/rails db:migrate`
  - `bin/rails test test/controllers/sign/app/in/checkpoints_controller_test.rb`
  - `bin/rails test test/controllers/sign/com/in/checkpoints_controller_test.rb`
  - `bin/rails test test/controllers/sign/org/in/checkpoints_controller_test.rb`
  - `bin/rails test test/policies/sign_in_sequence_policy_test.rb`
  - `bin/rails test test/controllers/sign/app/in/emails_controller_test.rb:188`
  - `bin/rails test`
- Full-suite result:
  - `bin/rails test` completed with `5563 runs, 19717 assertions, 24 failures, 38 errors, 0 skips`.
  - The sign-in checkpoint policy regression found during the full-suite pass was fixed by making
    `SignIn::Sequence#blank?` explicit and rerunning the app/com/org checkpoint tests.
  - Remaining full-suite failures are outside the checkpoint participant change surface and include
    existing expectation drift around logged-in guest routes, `RateLimit::STORE_REGISTRY` private
    constant access in tests, Prosopite reports during fixture validation/preference paths, and
    preference/test fixture setup issues.
- Documentation or ADR promotion needed:
  - Update `docs/security/sign-in-sequence.md` after the participant policy pattern is implemented
    across all surfaces.
