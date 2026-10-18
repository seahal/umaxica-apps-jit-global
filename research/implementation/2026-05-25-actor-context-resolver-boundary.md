# Actor Context Resolver Boundary Implementation Notes

## Context

- Original review: Actor/CurrentAttributes boundary review on 2026-05-25.
- Related ADR/docs/plans:
  - `adr/actor-current-facade.md`
  - `docs/architecture/current_context.md`
  - `docs/architecture/controller-lifecycle.md`

## Decisions Made During Implementation

- Decision: Keep `Actor` as a read facade, but restrict writes to lifecycle installer paths.
  - Why: The application still benefits from Rails `CurrentAttributes` request-local reads, but
    direct writes from normal application code split resolver ownership.
  - Follow-up needed: Gradually retire compatibility setters in favor of `Actor.install_context!`.

- Decision: Add `Actor.authn`, `Actor.authz`, `Actor.preferences`, and `Actor.step_up`, and remove
  the old authentication/preference compatibility reader names.
  - Why: Keeping both names left the three-layer context model incomplete and allowed policy and
    preference fallback paths to drift.
  - Follow-up needed: Gradually retire direct writer convenience methods in favor of
    `Actor.install_context!`.

- Decision: Prefer JWT `prf` over DB preference associations for normal request preference
  resolution.
  - Why: Runtime preference read SSoT is the verified access token plus request overlay.
  - Follow-up needed: Keep DB refresh paths bounded to preference edit/write entrypoints.

- Decision: Introduce `StepUp::Resolver` and route the existing satisfied checks through it.
  - Why: Step-up satisfaction must have one condition set for token usability, scope, timestamp,
    expiry, and required AAL.
  - Follow-up needed: Move more redirect/session orchestration out of controller concerns.

## Deviations From Plan

- Change: `ApplicationPolicy#current_token` reads `Actor.authz.token_claims` only.
  - Why: Policy token claims are authorization context, not an implicit fallback into authentication
    storage.
  - Risk: Policy tests and controller setup must install explicit authz context when claims are
    required.

## Review Notes

- Tests run:
  - `bin/rails test test/models/actor_test.rb test/models/actor_context_test.rb test/unit/actor/attributes_test.rb test/unit/actor/support_test.rb test/services/step_up/resolver_test.rb test/security/invariants/actor_context_invariant_test.rb`
  - `bin/rails test test/controllers/concerns/actor_support_included_do_test.rb test/controllers/concerns/authentication/base_coverage_test.rb test/controllers/concerns/verification/base_bootstrap_return_path_test.rb test/controllers/concerns/verification/base_rt_issuer_test.rb test/policies/application_policy_jwt_test.rb test/policies/sign_in_cycle_policy_test.rb`
  - `bin/rails test test/controllers/concerns/preference/global_test.rb test/controllers/concerns/preference/base_test.rb test/unit/actor/preference_test.rb test/security/invariants/actor_context_invariant_test.rb test/services/request_context/contract_test.rb`
- Tests not passing:
  - `bin/rails test test/integration/step_up_authentication_test.rb test/integration/verification_flow_test.rb test/controllers/sign/app/settings/mfa/challenges_controller_test.rb test/controllers/sign/app/settings/telephones/registrations_controller_test.rb test/controllers/concerns/sign/app_verification_base_test.rb test/controllers/concerns/sign/com_verification_base_test.rb`
  - Failures are in DB-backed step-up return-target/session expectations and require a focused
    follow-up before broad Step-Up migration is complete.
