# Architecture Decision Records

This directory stores accepted architecture and design decisions.

- Write ADRs in English. Do not add Japanese or other non-English prose unless the ADR explicitly
  discusses localization, translation data, or a quoted source whose original language matters.
- Keep decision records focused on what was decided and why.
- Include tradeoffs when they matter to future readers.
- Update `docs/` separately when implementation changes become current behavior.
- Keep non-authoritative decision notes and implementation handoff notes in `notes/`, not under
  `adr/`.

Current org federated sign-in decision:

- `adr/org-entra-id-sign-in-boundary.md` — accepted decision for org-surface Microsoft Entra ID SSO:
  sign-in only with no JIT provisioning, `tid + oid` as the sole lookup key, `email`/`upn` never
  requested or stored, records placed in `org_zenith`, and OmniAuth left untouched on the org
  surface.

Current identity authority decision:

- `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md` — current source of
  truth for Core browser credential transport on `jp.umaxica.app`: Rails Core may consume a
  short-lived `core-browser` access JWT only from an HttpOnly host-only cookie, refresh remains
  opaque, reverse audience/transport use is rejected, and no `Cookie` header may reach Next.js or
  Side origins.
- `adr/core-browser-credential-transport.md` — superseded predecessor retained for traceability.
- `adr/core-canonical-public-host.md` — chooses `jp.umaxica.{app,com,org}` as the canonical Core
  public host, sends the Workers VPC `Host` from the `PUBLIC_*` family with no `X-Forwarded-Host`,
  and makes `config/routes/core.rb` the source of truth for edge path ownership. `jpx.umaxica.*` and
  `core-jp.umaxica.*` remain accepted until the `jpx.*` column defaults are migrated. No external
  identity provider re-registration is involved; the social callbacks live on the Auth and Base
  surfaces, not on Core.
- `adr/acme-sign-core-base-port-boundary.md` — current source of truth for the target component
  model: Acme is the only IdP / Authorization Server, Sign is a special RP, Core is the Next.js web
  RP/BFF, Base is the Rails foundation/control-plane subdomain, and Palm is the native bearer-token
  API Resource Server formerly tracked as Port. Its `__Host-core_sid`-only Core browser credential
  model is superseded by `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`.
- `adr/identity-authority-boundary.md` — current source of truth for Session, Token, Account,
  Preference, Authorization, Credential Gateway, ceremony-result, and downstream-token authority
  within the older Rails-only `acme/www` / `sign/id` model; superseded where it conflicts with the
  Acme / Sign / Core / Base / Palm component model.
- `adr/acme-session-and-token-authority.md` — refines the older identity authority boundary for
  `acme/www` owned user sessions, refresh-token families, step-up freshness, logout, session
  listing, compromise state, and downstream token issuance; superseded where it conflicts with the
  Acme / Sign / Core / Base / Palm component model.
- `adr/sign-credential-gateway-surface.md` — refines the identity authority boundary for permitted
  `sign/id` credential inventory, ceremony state, ceremony execution, signed ceremony results, and
  ceremony-only audit records; superseded where it conflicts with Sign as a special RP.
- `adr/sign-residual-idp-surface-retirement.md` — operational decision to retire the residual
  `sign/id` OIDC provider, `SIGN_*` signing keys, refresh-rotation endpoint, session-mutating
  sign-out paths, and step-up freshness writes; superseded where it conflicts with Sign as a special
  RP and Acme as the only IdP / Authorization Server.

Implementation note: the accepted Acme / Sign / Core / Base / Palm boundary is ahead of parts of the
current code and older plans. Active implementation work is tracked in
`plans/active/acme-sign-core-base-port-implementation.md`; existing Rails-only compatibility routes
or storage do not create a competing ADR-level authority assignment.

Superseded IdP/RP-centered ADRs:

- `adr/split-into-regional-and-global-repos.md`
- `adr/acme-rp-boundary-naming.md`
- `adr/oidc-claims-decision.md`
- `adr/oidc-authn-hardening-implementation-decisions.md`
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `adr/logout-primitive-and-composition.md`
- `adr/session-reset-on-privilege-transition.md`
- `adr/authentication-assurance-level-boundaries.md`
- `adr/step-up-authentication-redesign.md`
- `adr/sign-configuration-sprint-spec.md`
- `adr/sign-up-authentication-handoff-and-social-rt.md`
- `adr/sign-up-cycle-cancellation-retention.md`
- `adr/sign-withdrawal-and-membership-surface-policy.md`
- `adr/cookie-domain-scope-by-surface.md`
- `adr/preference-soft-bubble-doctrine.md`
- `adr/preference-setting-configurator-url-boundaries.md`

Current API design decisions:

- `adr/api-error-format-problem-details.md` — accepted adoption of RFC 9457 Problem Details
  (`application/problem+json`) for all non-protocol JSON API errors, the `urn:umaxica:problem:`
  identifier namespace, the two permitted extension members, and the protocol exemption list (OAuth
  / OIDC / WebAuthn / DBSC / MCP JSON-RPC / health / `.well-known`).
- `adr/api-collection-offset-pagination.md` — current pagination for public publishing collections:
  Pagy offset pages (`?page=`), server-controlled page size, `{ data, page: { current, previous,
  next, last } }`. Supersedes the signed-cursor mechanism in `adr/api-collection-contract.md`.
- `adr/api-collection-contract.md` — historical `{data, page}` envelope and the 2026-08-22 signed
  cursor implementation. Envelope and unwrapped single-resource object remain; cursor pagination
  does not.
- `adr/api-versioning-and-client-conventions.md` — accepted path-based major versioning,
  `Idempotency-Key` (an expired IETF draft adopted as Stripe de facto), `RateLimit` /
  `RateLimit-Policy` field names (an unpublished draft, adopted with no client dependency
  permitted), and OpenAPI 3.2.x. Records the areas where no standard exists, keeping
  `docs/reference/api-design-standards.md` limited to specification-backed rules.
- `adr/api-route-vocabulary-consolidation.md` — accepted naming direction consolidating `/web/v0`
  and `/edge/v0` under `/api/v0`. Direction only; no route was changed.

Current database naming decisions:

- `adr/global-regional-database-ownership.md` — accepted Global / Regional database ownership map:
  `*_zenith`, `*_ticket`, `*_setting`, `*_signal`, `avatar`, and `publishing` are Global-only;
  `chronicle`, `occurrence`, `primary`, and `queue` exist as independent (never shared) databases
  in both repositories; Regional gets one new application database. Resolves the `M1` question in
  `evidence/2026-09-08-global-regional-database-split-assessment.md` — `*_zenith` is Global
  canonical Account / Identity / Organization authority. Retires the reserved-`*_principal`
  "regional-ready storage" role.
- `adr/umaxica-v1-core-resource-architecture.md` — accepted v1 core resource architecture: Identity
  / Account / Organization / Unit are core-side resources, Identity is not Account-owned, Avatar /
  Group stay in Avatar DB, and relationships use authority/lifecycle tables rather than direct
  ownership foreign keys.
- `adr/avatar-db-content-db-boundary.md` — accepted Avatar DB vs content DB boundary: Avatar DB owns
  current actor/settings/relation/social graph state, while UGC and posting-time actor snapshots
  belong to content/media/interaction/read-model domains.
- `adr/avatar-lifecycle-state-authority.md` — accepted initial Avatar lifecycle authority states and
  the rule that Avatar DB provides current state while content/moderation owns display and ranking
  decisions.
- `adr/cross-db-reference-policy.md` — accepted policy forbidding new cross-DB bigint/integer ID
  associations and native cross-DB FK assumptions.
- `adr/authority-lifecycle-table-policy.md` — accepted policy requiring relationship semantics to
  live in lifecycle-rich authority tables written through use-case services, not controllers.
- `adr/actor-db-naming-policy.md`
- `adr/surface-database-connection-naming.md`
- `adr/principal-zenith-physical-consolidation.md` — accepted decision to apply each surface's
  principal migration history through the matching zenith database and keep semantic principal base
  classes. Its reserved-empty `*_principal` "future regional-ready application data" role is
  superseded by `adr/global-regional-database-ownership.md`: `*_zenith` is Global authority and
  regional-ready data lives in the Regional repository's own application database.
- `adr/member-client-membership-organization-decomposition-before-placement.md`
- `adr/read-only-content-surfaces-in-rails.md` — current decision for v1 read-only docs/news/help
  content delivery in this Rails repository, including temporary placement in the existing surface
  zenith databases.

Current audit / chronicle decisions:

- `adr/chronicle-audit-db-consolidation.md`
- `adr/chronicle-audit-implementation-guidance.md`

Current account enforcement decisions:

- `adr/administrative-access-lock.md` — accepted `admin_locked` account-wide runtime access gate for
  `Client`, `Visitor`, `Operator`; unchanged and reused, not superseded, by Unified Enforcement.
- `adr/unified-enforcement.md` — current source of truth for Identity BAN, Identity Freeze, and
  Authentication Method Lock as one Enforcement Case substrate with independently combinable
  Principal / Authentication Method / Identifier effects, per-surface `*_zenith` storage, and no
  dedicated enforcement database.
- `adr/authentication-method-lock.md` — superseded by `adr/unified-enforcement.md`; retained for
  traceability of the 2026-07-26 decision.
- `adr/database-trigger-usage-boundary.md` — accepted narrow trigger-usage policy; Context corrected
  2026-07-27 (five orphaned functions, not eight; no credential-table `ON DELETE CASCADE`), Decision
  unchanged.

Preference decisions:

- `adr/app-actor-client-naming.md`
- `adr/com-actor-visitor-naming.md`
- `adr/org-actor-operator-naming.md`
- `adr/preference-setting-configurator-url-boundaries.md` — superseded where it assigns preference
  authority outside `acme/www`; retained for historical URL-boundary context.
- `adr/preference-relogin-reconciliation-record-recency.md`
- `adr/preference-extended-option-reference-tables.md`

Current hierarchy / collective decisions:

- `adr/collective-hierarchy-model.md`
- `adr/surface-account-collective-model-naming.md`

Current request-context decisions:

- `adr/actor-current-facade.md`
- `adr/signed-return-targets-only.md`
- `adr/redirect-target-lanes-pt-nt-xt.md` — supersedes the deferred return-target naming direction
  in signed-return-targets-only; current redirect target lanes are `pt`, `nt`, and `xt`.

Current URL boundary decisions:

- `adr/public-private-url-boundaries.md`

Current routing decisions:

- `adr/rails-routing-resourceful-policy.md`

Current logging / observability decisions:

- `adr/application-logging-boundary.md`
- `adr/non-log-event-reporting-boundary.md` — permits `Rails.event.notify` only for non-log
  observability events, with CSP violation reports as the first in-process subscriber use.
- `adr/traces-and-metrics-routing-via-alloy.md`

Current health / edge access decisions:

- `adr/internal-health-endpoint-edge-isolation.md` — `/health` and every path beneath it are
  internal-only checkpoints blocked at the Cloudflare edge; user-facing availability is served by a
  separate integrated status page (external service).
- `adr/dos-and-firewall-controls-at-cdn-aws-edge-not-in-rails.md` — current source of truth for
  keeping DoS and firewall controls at the CDN/AWS edge instead of in Rails, including CloudFront +
  AWS WAF, ALB origin gating, ECS task ingress, and Rails semantic rate limiting.

Current browser security header decisions:

- `adr/csp-and-permissions-policy.md`
- `adr/csp-violation-report-route-naming.md` — keep `csp_violation_report` route resource naming for
  the `POST /csp-violation-report` endpoint instead of shortening it to bare `csp`.

Current localization decisions:

- `adr/i18n-explicit-translation-keys.md`

Current controller-boundary decisions:

- `adr/two-base-authentication-mode-boundaries.md`
- `adr/static-and-guest-controller-boundaries.md` — deprecated on 2026-05-24 and superseded by the
  two-base authentication mode direction; retained only as historical context.

Sign configuration decisions:

- `adr/authentication-assurance-level-boundaries.md` — partially superseded for authority ownership;
  AAL vocabulary remains useful.
- `adr/finite-nonnegative-rate-limit-counts.md`
- `adr/sign-up-authentication-handoff-and-social-rt.md` — superseded where it assigns session,
  account, or authorization authority to `sign/id`.
- `adr/sign-up-checkpoint-turnstile-boundary.md`
- `adr/sign-up-cycle-cancellation-retention.md` — superseded where it assigns account lifecycle to
  `sign/id`.
- `adr/turnstile-visible-placement-policy.md`
- `adr/sign-withdrawal-and-membership-surface-policy.md` — superseded where it assigns account
  lifecycle to `sign/id`.
- `adr/mfa-reset-account-recovery.md`
- `adr/identifier-hmac-emergency-rotation.md`

Session and token decisions:

- `adr/base-lobby-unauthenticated-entry.md` — Base anonymous entry is `GET /lobby`, authenticated
  entry remains `GET /dashboard`, and Base local sign-out is PRG (`303`) onto `/lobby` with the
  existing `SignOutNotice` marker. Amends `adr/logout-ceremony-boundary.md` for Base only.
- `adr/acme-session-and-token-authority.md`
- `adr/social-login-cooldown-and-one-shot-completion.md` — accepted decision that repeated social
  login completion inside the 30-second login cooldown is a valid Acme-side cooldown rejection, and
  consumed social ceremony results must fail closed on retry.
- `adr/token-lifetime-policy-by-surface.md` — per-surface access/refresh token lifetimes (`app` vs
  `org`); implementation tracked in
  `plans/backlog/token-lifetime-policy-by-surface-implementation.md`.
- `adr/session-token-hardening-baseline.md` — accepted hardening posture for production auth cookies
  (`__Host-`/host-only/Secure/HttpOnly/`SameSite=Strict`/Partitioned), opaque-refresh + JWT-access,
  rotation/reuse/family-revoke, re-issue on security events, server-side timeouts, HSTS, and IP/UA
  as risk signal; implementation tracked in
  `plans/backlog/session-token-hardening-implementation.md`.
- `adr/session-reset-on-privilege-transition.md` — superseded where it assigns session issuance or
  step-up freshness to `sign/id`.
- `adr/logout-primitive-and-composition.md` — superseded where it assigns session authority to
  `sign/id`.
- `adr/device-session-dbsc-device-id-boundary.md` — partially superseded for authority ownership;
  device-session, DBSC, and device-id vocabulary remains useful.

Credential gateway decisions:

- `adr/sign-credential-gateway-surface.md`
- `adr/sign-prefix-routing.md` — partially superseded where it describes `sign/id` as an IdP host;
  retained for historical route-prefix context.

Cookie / session-transport decisions:

- `adr/cookie-domain-scope-by-surface.md` — partially superseded for authority ownership; cookie
  security vocabulary remains useful.

Current tooling / code-quality decisions:

- `adr/ruby-static-analysis-reek-flog-flay.md`

Current outbound delivery decisions:

- `adr/notification-orchestration-via-noticed.md` — accepted decision that Noticed notifiers under
  `Notify::<Surface>` are the notification orchestration entry point, with the surface mailers,
  `OutboundSms`, and `ApplicationPushNotification` kept as the transport layer that carries the kill
  switches and the encryption boundary.
- `adr/outbound-message-delivery-interface.md` — partially superseded for the `Notification` naming
  reservation and the call-site entry point; its payload shape, result object, and job-argument
  encryption rule remain in force.

Current CSRF decision:

- `adr/csrf-protection-disabled-in-test-environment.md` — settled decision that `bin/rails test`
  keeps `allow_forgery_protection` off while development and production must keep it on. Read this
  before proposing to enable CSRF suite-wide; it records why that change buys appearance rather than
  coverage, and the one condition that would reopen it.

Current retention / deletion decisions:

- `adr/retainable-concern-and-retention-purge.md`
- `adr/retention-lifecycle-column-boundary.md`

Repository / application boundary decisions:

- `adr/split-into-regional-and-global-repos.md` — the two-repository structure (Global vs Regional)
  remains in force; superseded where it treats `sign/id` as IdP and `acme/www` as RP. Database
  ownership between the two repositories is now fixed by
  `adr/global-regional-database-ownership.md`.
- `adr/acme-rp-boundary-naming.md` — superseded where it treats `acme/www` as an RP boundary instead
  of the identity authority boundary.

Historical engine-era ADRs are retained for traceability only. They do not authorize reintroducing
`engines/`, wrapper apps under `apps/<name>`, `Jit::<EngineName>` namespaces, or `isolate_namespace`
boundaries in this repository.
