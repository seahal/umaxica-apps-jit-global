# Core Next.js Zero-Cookie Boundary Implementation Notes

## Context

- Original spec: Core Next.js + Rails Core BFF/API boundary with zero-cookie Next.js origin.
- Related decisions/docs:
  - `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`
  - `adr/acme-sign-core-base-port-boundary.md`
  - `adr/api-route-vocabulary-consolidation.md`
  - `adr/internal-health-endpoint-edge-isolation.md`
  - `docs/operations/core-nextjs-zero-cookie-edge-contract.md`
- Implementation date: 2026-06-14

## Decisions Made During Implementation

- Decision: Add a self-contained Rails Core `/api/v0` API base instead of inheriting the existing
  Core HTML `ApplicationController`.
  - Why: the existing HTML controller lifecycle writes unrelated preference/session cookies and
    would weaken the new API cookie boundary.
  - Alternatives considered: inheriting the surface `ApplicationController` and skipping callbacks.
    That would violate the local no-skip controller guidance.
  - Follow-up needed: review whether a project-standard JSON API base should replace this
    self-contained base after the Core boundary settles.

- Decision: Gate the new Core browser API with `CORE_BROWSER_JWT_COOKIE_ENABLED`, default false.
  - Why: no deployable Cloudflare/IaC config exists in this repository, so production enablement is
    blocked until edge cookie stripping and Set-Cookie stripping are deployed and verified.
  - Alternatives considered: enabling the API unconditionally. Rejected because it would allow
    rollout before the zero-cookie edge invariant is proven.
  - Follow-up needed: wire the flag through the project-standard rollout system if one is chosen.

## Deviations From Plan

- Change: Core `/sso/authorize`, `/auth/callback`, and logout intentionally stay on the existing
  Rails auth/OIDC concerns and cookie names.
  - Why: Core should not fork the auth ceremony into separate cookie concerns. The safety boundary
    is host-only cookie behavior plus `core-browser` JWT audience-to-transport binding.
  - Risk: documentation or tests that expect `__Host-core_access`, `__Secure-core_refresh`, or
    `__Host-core_oidc` as ceremony-specific names are stale.
  - Follow-up: keep Core API transport-binding tests focused on cookie transport and audience, not
    Core-only cookie names.

- Change: Side routes/controllers were not added.
  - Why: the repository has no accepted Side route file or deployable edge host configuration yet.
  - Risk: Side acceptance criteria remain documentation-only.
  - Follow-up: add Side after an ADR or route plan accepts the private surface.

## Review Notes

- Tests run:
  - `bin/rails test test/unit/core_browser_credential_contract_test.rb test/integration/core_browser_api_boundary_test.rb`
    initially reached one failing assertion, then later could not run because the test database has
    pending migrations.
  - `bundle exec rubocop app/services/core_browser_credential_contract.rb app/controllers/concerns/core_browser_api_boundary.rb app/controllers/core/app/api/v0 app/controllers/core/com/api/v0 app/controllers/core/org/api/v0 test/integration/core_browser_api_boundary_test.rb test/unit/core_browser_credential_contract_test.rb`
  - `ruby -c` on the new service, concern, and test files.
- Tests not run:
  - Full Rails suite, because `RAILS_ENV=test bin/rails db:prepare` failed with unresolved database
    host `primary`.
  - Next.js/Vitest checks, because no Next.js app exists in this Rails repository.
- Documentation promotion needed:
  - Promote edge verification evidence into
    `docs/operations/core-nextjs-zero-cookie-edge-contract.md` after Cloudflare rules are deployed.
