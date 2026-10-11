# Sign-Up Authority Inversion Partial Implementation Notes

## Context

- Original request: harden the sign-up authority boundary, freeze the accepted routing vocabulary,
  and remove stale `/auth/google_app/callback` / `/auth/apple/callback` references.
- Related docs/plans:
  - `docs/identity/authority-boundary.md`
  - `docs/security/sign-up-sequence.md`
  - `adr/sign-up-authentication-handoff-and-social-rt.md`
  - GH issue #834
- Implementation date: 2026-06-21

## Decisions Made During Implementation

- Kept the public sign-up route vocabulary frozen and updated the accepted callback wording to
  `/social/google/callback` and `/social/apple/callback`.
  - Why: the live route contract already uses `/social/*`; the stale `/auth/*` strings were only
    document drift.
- Removed flash usage from `Sign::Org::Sign::Up::InvitationsController`.
  - Why: the org invitation flow was the immediate repository-policy violation in the live code.
  - Follow-up needed: if other org sign-up flows still use flash, they need separate cleanup slices.
- Added inline invitation error feedback in the org invitation form.
  - Why: keeps validation errors visible without flash-backed transient state.

## Deviation From Full Migration Target

- The shared sign-up finalization helper in
  `app/controllers/concerns/sign_up_sequence_controller_support.rb` still performs the durable
  email/telephone actor mutation and then calls `handoff_to_sign_in_flow!`.
  - Why: a full authority inversion would require a broader refactor across the sign-up finalize
    flow, Acme completion path, and related tests than was safely actionable in this pass.
  - Risk: the repository still has an active Sign-owned durable sign-up writer for email/telephone.
  - Follow-up: continue the authority inversion work from the shared finalize seam before claiming
    completion for migrated sign-up methods.

## Review Notes

- Tests run:
  - `bin/rails test test/controllers/sign/org/up/invitations_controller_test.rb`
  - `bin/rails test test/integration/routes/sign_route_contract_test.rb`
  - `bin/rails test test/controllers/sign/app/auth/omniauth_callbacks_controller_test.rb`
    - This file still has pre-existing failures unrelated to the invitation/doc cleanup.
  - `bin/rails zeitwerk:check`
  - `git diff --check`
- Tests not run:
  - Full sign-up/state-machine suites.
- Documentation promotion needed:
  - The live docs now reflect the frozen route vocabulary, but the remaining authority inversion
    still needs code changes in `sign_up_sequence_controller_support.rb`.
