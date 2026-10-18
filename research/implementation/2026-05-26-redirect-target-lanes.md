# Redirect Target Lanes Implementation Notes

## Context

- Original spec: user request on 2026-05-26 to destructively split redirect targets into `pt`, `nt`,
  and `xt`.
- Related ADR/docs: `adr/signed-return-targets-only.md`, `adr/redirect-target-lanes-pt-nt-xt.md`,
  `docs/security/redirect_targets.md`.

## Decisions Made During Implementation

- Added `Redirects::TargetResult`, `PathTargetResolver`, `NavigationTargetResolver`,
  `ExternalTargetResolver`, and `PriorityResolver`.
  - Why: controller concerns should be a facade only.
- Changed `Common::Redirect#safe_return_path` to path-only semantics.
  - Why: old behavior could collapse same-host absolute URLs into paths and blurred `pt` with
    external handling.
- Added `bin/audit_redirects` and a security regression test for direct param redirects and direct
  `allow_other_host: true`.
  - Why: the app still has many older redirect flows; mechanical detection keeps migration visible.

## Deviations From Plan

- Full call-site migration across all sign-in, sign-up, step-up, social, OIDC, and jump flows is not
  complete in this pass.
  - Risk: the new security regression test intentionally reports remaining direct
    `allow_other_host: true` users until they move behind `redirect_to_xt`.
  - Follow-up: migrate remaining legacy `rt`/`return_to` flow state to `pt` or `nt` per owning flow.

## Review Notes

- Tests run:
  - `bin/rails test test/services/redirects/path_target_resolver_test.rb test/services/redirects/navigation_target_resolver_test.rb test/services/redirects/external_target_resolver_test.rb test/services/redirects/priority_resolver_test.rb test/unit/security/redirect_target_usage_test.rb test/security/invariants/forbidden_patterns_invariant_test.rb test/controllers/concerns/common/redirect_test.rb test/services/request_context/contract_test.rb test/config/auth/io_keys_test.rb`
- Tests not run:
  - Full `bin/rails test`.
