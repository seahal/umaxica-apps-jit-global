# Authentication Controller Surface Extraction Implementation Notes

## Context

- Original plan/spec: PR-3 of controller concern lifecycle cleanup.
- Related docs: `docs/architecture/controller-lifecycle.md`,
  `.agents/harnesses/rules/project/surfaces.mdc`.
- Implementation date: 2026-05-30.

## Decisions Made During Implementation

- Decision: `Authentication::Base` no longer includes `Sign::ErrorResponses` or `SessionLimitGate`,
  and role authentication concerns no longer include `AuthorizationAudit`.
  - Why: authentication concerns should provide auth capabilities, while controller lifecycle and
    response-surface concerns should be visible on the controller class that owns the request
    boundary.
  - Alternatives considered: leaving includes in authentication concerns and only adding tests for
    current behavior. Rejected because it preserves hidden rescue handler registration.
  - Follow-up needed: continue extracting remaining `rescue_from` registrations from general-purpose
    concerns where practical.

- Decision: authenticated surface application controllers include `Sign::ErrorResponses`,
  `SessionLimitGate`, and `AuthorizationAudit` explicitly.
  - Why: this preserves existing capabilities while making controller surface changes reviewable at
    the lifecycle boundary.
  - Alternatives considered: removing `Sign::ErrorResponses` from the authenticated surfaces
    entirely. Rejected because ApplicationError and CSRF JSON handling are still existing surface
    behavior.
  - Follow-up needed: evaluate whether ApplicationError and CSRF handlers should also be declared
    directly in application controllers instead of inside `Sign::ErrorResponses`.

- Decision: `ActionPolicy::Unauthorized` is handled only by
  `AuthorizationAudit#handle_authorization_error` on authenticated surface controllers.
  - Why: prior behavior registered both `Sign::ErrorResponses#handle_not_authorized` and
    `AuthorizationAudit#handle_authorization_error`, making the final handler order-dependent.
  - Alternatives considered: keeping `Sign::ErrorResponses` as the final handler. Rejected because
    it would remove authorization failure audit logging from the main surface path.
  - Follow-up needed: keep `test/unit/security/action_policy_usage_test.rb` as the guard for handler
    uniqueness.

## Deviations From Plan

- Change: This PR kept `Authentication::Base` including `ActionPolicy::Controller`.
  - Why: PR-3 specifically targeted `Sign::ErrorResponses`, `SessionLimitGate`,
    `AuthorizationAudit`, and the duplicate unauthorized handler. Removing ActionPolicy support from
    authentication base is a separate compatibility change.
  - Risk: authentication base still changes controller class API by including ActionPolicy when
    included in test harnesses or non-standard controllers.
  - Follow-up: handle in a later PR if the controller-surface extraction continues.

## Review Notes

- Tests run:
  - `bin/rails test test/controllers/concerns/auth/base_included_do_test.rb test/controllers/concerns/authentication/client_included_do_test.rb test/controllers/concerns/authentication/operator_included_do_test.rb test/controllers/concerns/authentication/visitor_included_do_test.rb`
  - `bin/rails test test/controllers/concerns/sign/error_responses_included_do_test.rb test/controllers/concerns/authorization_audit_included_do_test.rb`
  - `bin/rails test test/unit/security/action_policy_usage_test.rb`
  - `bin/rails test test/controllers/concerns/sign/error_responses_test.rb test/concerns/authorization_audit_test.rb test/controllers/concerns/session_limit_gate_test.rb`
  - `bin/rails test test/security/invariants/controller_lifecycle_order_invariant_test.rb`
- Tests not run: full suite.
- Documentation or ADR promotion needed: none yet; this is still part of staged concern cleanup.
