# Architecture Decision Records

This directory stores accepted architecture and design decisions.

Current Rails naming note (2026-09-25): references to the Rails `Side`/`Wide` surface in older
decisions are historical. Its current internal namespace is `Warp`; registered OIDC client IDs, JWT
namespaces, MCP realm, persisted logout values, and public hostnames retain their established
values.

- Write ADRs in English. Do not add Japanese or other non-English prose unless the ADR explicitly
  discusses localization, translation data, or a quoted source whose original language matters.
- Keep decision records focused on what was decided and why.
- Include tradeoffs when they matter to future readers.
- Update `docs/` separately when implementation changes become current behavior.
- Keep non-authoritative decision notes and implementation handoff notes in `research/`, not under
  `adr/`.

Current Inertia decision:

- `adr/inertia-rails-thin-adapter.md` — Inertia Rails is used through its public API only, with no
  fork, patch, or compatibility layer; history encryption is mandatory, each origin is its own
  Inertia application, and leaving an origin is a `409` with `X-Inertia-Location`.

- `adr/inertia-initializer-file-name.md` — the configuration stays in
  `config/initializers/inertia_rails.rb` (gem-named); upstream's `inertia.rb` example is merged into
  it, never added as a second file.

Current authentication Security Mode decision (accepted; not implemented):

- `adr/authentication-security-mode.md` — `mfa_level_id` becomes `security_mode_id` with `NORMAL=3`
  and `ADVANCED=7`; owner-held mode with no Operator downgrade, per-mode step-up methods and
  windows, passkey lifecycle without session revocation, Recovery Key/no-key recovery cases, and the
  open decisions that remain before implementation.

- `adr/authentication-security-cycle-consolidation-2026-10-15.md` — WU-1..WU-9 cycle record
  (`XU-N` = `WU-N`): two-passkey `ADVANCED` minimum, owner downgrade rule, ORG Emergency intent and
  2 hour target, `required_aal` retirement, WebAuthn race invariants; recovery, ORG sign-up,
  `acr`/`amr`, WU-3/5/8/9 Pending or deferred. Partially supersedes the Security Mode ADR above.
  Decisions only; not implemented.

Current org federated sign-in decision:

- `adr/org-entra-id-sign-in-boundary.md` — accepted decision for org-surface Microsoft Entra ID SSO:
  sign-in only with no JIT provisioning, `tid + oid` as the sole lookup key, `email`/`upn` never
  requested or stored, records placed in `org_zenith`, and OmniAuth left untouched on the org
  surface.

Current identity authority decision:

- `adr/sign-in-first-and-sign-up-handoff.md` — **Accepted (2026-10-18)**; Sign In is the canonical
  session-admission boundary and completed App/Com Sign Up enters it through a trusted handoff. D11,
  D12, and D14 remain unresolved.

- `adr/passkey-current-state-limit-and-chronicle-outbox.md` — **Accepted (2026-10-19)**; APP, COM,
  and ORG Passkeys are limited to ten per owner by an owner-locked registration operation (not by a
  database constraint), use physical lifecycle deletion, and deliver common Chronicle facts through
  principal transactional outboxes. Chronicle retention is still TBC.

- `adr/app-com-withdrawal-deadline-snapshot.md` — **Accepted (2026-10-19)**; Client and Visitor
  withdrawal deadlines use an immutable policy, persisted confirmation timestamps, and strict
  development/test-only overrides. Operator timing remains separate.

- `adr/email-sign-in-otp-ceremony-binding-and-risk-acceptance.md` — accepted APP/COM Email Sign-In
  ceremony/continuity binding target, one-time consumption and resend invariants, and limited
  browser-secret theft/external-mailbox risk acceptances (2026-10-11); conformity is unverified and
  implementation remains deferred under the Auth workflow freeze.

- `adr/jump-directed-rails-handoff-contract.md` — current same-TLD Jump graph, Auth issuer naming,
  Palm browser/native handoff, development trust prerequisites, and rollout boundaries.

- `adr/base-auth-ceremony-and-seven-rp-boundary.md` — **current** physical boundary: Base is the
  sole IdP/AS and Auth is ceremony-only. It records the original seven-RP baseline and later Base
  implementation amendments; `adr/tech-and-palm-browser-rp-participation.md` updates RP membership
  with Tech and Palm. The current authority-driven sign-out route is defined by the first-party
  shared-database sign-out ADR below.

- `adr/oidc-oauth-participation-allowlist-and-non-participant-surfaces.md` — OAuth/OIDC
  participation is allowlisted and never inferred from hostname, TLD, or shared code; all `.dev` and
  `.net` surfaces, the Info/Docs/News/Help content faces, Auth, and any future Xper surface are
  Non-Participants, and reclassifying one requires a new accepted ADR. The Phase 0 Rails surface is
  retired by `adr/xper-rails-surface-retirement.md`.

- `adr/defer-auth-xper-transient-workflow-redesign.md` — scope decision for the current Base/RP
  cycle: no Auth or Xper workflow, token, or cookie redesign and no shared transient-capability
  implementation now; Auth remains unchanged, and the Xper Phase 0 Rails surface is retired by the
  decision below.

- `adr/xper-rails-surface-retirement.md` — retires the Xper Phase 0 Rails surface without changing
  data, Preference/Auth behavior, Flipper records, or Edge/Cloudflare ownership; the future Web Push
  requirement remains open.

Current participation change (implemented locally; deployment and shared sign-out follow-up remain):

- `adr/tech-and-palm-browser-rp-participation.md` — Tech (`tech-org`, operator, `tech.umaxica.org`,
  requires `tech.access`) is admitted as a first-party browser RP, and Palm (`palm-app`) changes
  from native RP to first-party browser RP with its native role retired. Answers the
  Reclassification Rule of `adr/oidc-oauth-participation-allowlist-and-non-participant-surfaces.md`.

The repository currently implements Tech and Palm browser RP entry, callback, host-local session,
and local sign-out routes. The shared parent-and-RP sign-out transaction is locally implemented and
focused-tested; full authority, race and deployment acceptance remain incomplete. See the
implementation status in the participation ADR before relying on global revocation behavior.

Current sign-out decision (target contract; local runtime is partial):

- `adr/first-party-sign-out-shared-database-without-backchannel-logout.md` — the parent session on
  the realm Ticket writer is the single source of truth; a global sign-out revokes the parent and
  all of its RP session rows in one transaction, and a confirmed COMMIT is the point of no return.
  Back-Channel Logout is not used between the IdP and first-party RPs and must not be reintroduced
  without a new ADR. Local first-party completion routes and the 12-client continuation matrix are
  implemented; the shared global transaction is locally implemented and focused-tested, while BCL
  removal and final authority/browser acceptance remain open. The rejected design is recorded in
  `research/2026-10-13-first-party-backchannel-logout-rejected-design.md`.
- `adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md` — Accepted
  (2026-10-16); not implemented. For first-party RPs activated with their own session store under
  the OP/RP separation, sign-out is established by the realm OP commit and RP sessions end by
  durable Back-Channel Logout with a bounded residual window. It supersedes the shared-database ADR
  above only for those separated clients.

Current IdP flow lifecycle decisions (target contract; runtime not yet migrated):

- `adr/idp-flow-lifecycle-vocabulary.md` — lifecycle, event, request-semantics, and outcome
  vocabulary for sign-in, sign-up, and sign-out.
- `adr/idp-flow-state-machine-lifecycle.md` — DB-backed state storage: one state id per flow row,
  id-only per-flow reference tables, immutable ids, shared terminal ids, FK versus application
  transition responsibility.

Current browser credential recovery decision:

- `adr/invalid-browser-credential-recovery.md` — **current** contract for refused auth and
  preference browser credentials: credential rejection and lifecycle ends are detached, system
  failures raise, and stale preference reads never delete a newer generation. Supersedes
  `adr/preference-credential-entry-recovery.md`, which is retained for history.

Current Ruby source decision (target contract; repository not yet conforming):

- `adr/frozen-string-literals.md` — every owned Ruby file, migrations and `bin/` executables
  included, declares `# frozen_string_literal: true`; enforced by RuboCop `always_true`; no global
  switch and no third-party patch. Single authority for the topic.

Current configuration decision:

- `adr/env-fetch-without-default.md` — environment variables are read without a code-side default in
  every Ruby file, tests included: one-argument `ENV.fetch` for a needed variable, `ENV[...]` with
  an explicit `nil` branch for an optional one. Existing defaults are debt tracked in
  `plans/backlog/env-fetch-default-removal.md`.

Current runtime secret isolation decision (deferred; not implemented):

- `adr/runtime-secret-isolation-deferred.md` — R5-WU03A secret isolation is out of the current
  cycle; development keeps the `shared` role, production/staging sharing of one secret set stays an
  open defect, the future boundary is the pod and its secret-store policy, and `AT-R5-03A` stays
  NOT_RUN. Follow-up: `plans/backlog/2026-10-18-production-runtime-secret-isolation.md`. Amended
  2026-10-19: development and test use one Rails-standard credentials set, one `SECRET_KEY_BASE` and
  one fixed Dev Container database login for every role.

Current backend transport decision:

- `adr/backend-transport-tls-enforcement.md` — production Rails PostgreSQL requires `verify-full`
  and production Valkey requires `rediss://`; local development/test transport remains unchanged.

Legacy identity authority notes (superseded where they conflict):

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

Implementation note: the accepted Acme / Sign / Core / Base / Palm boundary remains historical
component context. Current Rails authority and RP membership are defined by the Base/Auth boundary
and `adr/tech-and-palm-browser-rp-participation.md`; existing Rails storage does not create a
competing authority assignment.

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
- `adr/preference-scope-and-browser-persistent-state-separation.md`

Current API design decisions:

- `adr/api-error-format-problem-details.md` — accepted adoption of RFC 9457 Problem Details
  (`application/problem+json`) for all non-protocol JSON API errors, the `urn:umaxica:problem:`
  identifier namespace, the two permitted extension members, and the protocol exemption list (OAuth
  / OIDC / WebAuthn / DBSC / MCP JSON-RPC / health / `.well-known`).
- `adr/api-collection-offset-pagination.md` — current pagination for public publishing collections:
  Pagy offset pages (`?page=`), server-controlled page size,
  `{ data, page: { current, previous, next, last } }`. Supersedes the signed-cursor mechanism in
  `adr/api-collection-contract.md`.
- `adr/api-collection-contract.md` — historical `{data, page}` envelope and the 2026-08-22 signed
  cursor implementation. Envelope and unwrapped single-resource object remain; cursor pagination
  does not.
- `adr/api-versioning-and-client-conventions.md` — accepted path-based major versioning,
  `Idempotency-Key` (an expired IETF draft adopted as Stripe de facto), `RateLimit` /
  `RateLimit-Policy` field names (an unpublished draft, adopted with no client dependency
  permitted), and OpenAPI 3.2.x. Records the areas where no standard exists, keeping
  `docs/reference/api-design-standards.md` limited to specification-backed rules.
- `adr/webhook-entry-point-namespace-reservation.md` — reserves `/hook/v{n}` on every surface for
  inbound webhook receivers, kept separate from `/api/v{n}`; no receiver is implemented yet.
- `adr/api-route-vocabulary-consolidation.md` — accepted naming direction consolidating `/web/v0`
  and `/edge/v0` under `/api/v0`; its 2026-09-15 amendment records the reviewed Core preference API
  migration, and its 2026-10-02 amendment the pre-deployment cutover of the Base, Auth, and Warp
  theme and cookie endpoints, while the remaining services stay subject to endpoint-specific review.

Current database naming decisions:

- `adr/global-regional-database-ownership.md` — accepted Global / Regional database ownership map:
  `*_zenith`, `*_ticket`, `*_setting`, `*_signal`, `avatar`, and `publishing` are Global-only;
  `chronicle`, `occurrence`, `primary`, and `queue` exist as independent (never shared) databases in
  both repositories; Regional gets one new application database. Resolves the `M1` question in
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
- `adr/identifier-contract.md` — accepted user contract for database-local bigint identity, NanoID
  issuance/capacity, semantic classification, preserved identities and scoped DB enforcement;
  implementation/verification remain in progress.
- `adr/authority-lifecycle-table-policy.md` — accepted policy requiring relationship semantics to
  live in lifecycle-rich authority tables written through use-case services, not controllers.
- `adr/actor-db-naming-policy.md`
- `adr/surface-database-connection-naming.md`
- `adr/database-names-without-region.md` — accepted (2026-10-19); database and connection names
  carry no region marker in any environment. Future regional deployments would be separate regional
  Rails repositories parameterized by environment variables; not in current scope.
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
- `adr/identity-centric-aaa-architecture.md` — accepted principle relating Authentication,
  Authorization, and Accounting to Identity; first scope is Identity Security Accounting, with
  Chronicle reused as its audit evidence store. Supplements the Chronicle and authority ADRs;
  detailed design and implementation are Pending.

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
- `adr/declarative-database-constraints-for-integrity-and-cardinality.md` — accepted 2026-10-18
  principle: integrity that validations cannot guarantee lives in PostgreSQL declarative
  constraints; per-owner limits prefer finite slots (`NOT NULL` + `CHECK` range +
  `UNIQUE (owner, slot)`) over counting triggers or callbacks. Narrows the trigger ADR for count
  limits only; no schema, limit or callback changed.

Preference decisions:

- `adr/app-actor-client-naming.md`
- `adr/com-actor-visitor-naming.md`
- `adr/org-actor-operator-naming.md`
- `adr/preference-setting-configurator-url-boundaries.md` — superseded where it assigns preference
  authority outside `acme/www`; retained for historical URL-boundary context.
- `adr/preference-relogin-reconciliation-record-recency.md`
- `adr/preference-extended-option-reference-tables.md`
- `adr/preference-browser-transport-family-capability.md` — theme and cookie controls are a
  family-and-surface capability with a server-declared, same-origin endpoint; Base, Auth, Core, and
  Warp serve one host-local `/api/v0/preferences` contract, and Auth serves it only as UX transport.

Current hierarchy / collective decisions:

- `adr/surface-account-collective-model-naming.md`
- `docs/architecture/persona-organization-authority.md` is the implementation reference for the
  amended Persona / Organization interface and authority-table boundary.

Deferred historical records:

- `adr/collective-hierarchy-model.md` — superseded; it must not be used to reintroduce a shared
  Collective hierarchy or authority table.
- `adr/avatar-account-bridge-boundary.md` — deferred and excluded from the current authority
  program.

Current request-context decisions:

- `adr/actor-current-facade.md`
- `adr/signed-return-targets-only.md`
- `adr/redirect-target-lanes-pt-nt-xt.md` — supersedes the deferred return-target naming direction
  in signed-return-targets-only; current redirect target lanes are `pt`, `nt`, and `xt`.
- `adr/secure-jump-link-redirector.md` — signed Jump `rt` gateway contract; the 2026-10-12 amendment
  deprecates `dst: "external"` for new use, keeps `dst: "internal"` for approved first-party
  cross-origin handoffs, and reserves external website navigation for `xt` and the future Away
  gateway.

Current URL boundary decisions:

- `adr/public-private-url-boundaries.md`

Current routing decisions:

- `adr/rails-routing-resourceful-policy.md`

Current logging / observability decisions:

- `adr/application-logging-boundary.md`
- `adr/non-log-event-reporting-boundary.md` — permits `Rails.event.notify` only for non-log
  observability events, with CSP violation reports as the first in-process subscriber use.
- `adr/traces-and-metrics-routing-via-alloy.md`

Current infrastructure / environment decisions:

- `adr/staging-aurora-postgresql-topology.md` — Amazon Aurora PostgreSQL is the direction for
  production, reached by way of staging. Whenever Aurora is the backend it is one cluster with two
  DB instances (writer 1 + reader 1, never zero readers) hosting all 20 logical databases behind the
  cluster and reader endpoints. Production stays on Neon until staging runs. **Staging's own
  database backend is deferred** — FakeCloud emulates no RDS or Aurora, so it is chosen when staging
  implementation begins. PostgreSQL major version alignment is deferred; `pg_cron` is kept as an
  unused local PoC and is deliberately not wired into `config/database.yml`.
- `adr/aurora-postgresql-minor-version-tracking.md` — development PostgreSQL follows each new Aurora
  PostgreSQL minor release on release day, using the AWS-confirmed community version; misses are
  recorded; production and major upgrades are decided separately.
- `adr/fakecloud-podman-staging-environment.md` — staging is a Podman-hosted FakeCloud environment
  provisioned with Terraform (not OpenTofu, not an AWS account); environment-agnostic
  `terraform/modules/` with all emulator specifics in `terraform/environments/<env>/`; staging owns
  bucket names distinct from local development; `DEPLOYMENT_TIER=staging` runs production Rails
  configuration against the emulator while `production` keeps the AWS credential chain. The unit of
  deployment is the OCI container run by Podman with no host-OS assumption (the RHEL-host intent is
  dropped; Kubernetes is left open but not adopted). The no-real-AWS scope covers object storage and
  streaming only: the relational database is outside FakeCloud's coverage and is deferred, while
  Valkey stays a plain container and needs no alternative. Outbound email (SES over SMTP) and SMS
  (SNS, whose client accepts no custom endpoint) keep using real AWS, making SMS the second real-AWS
  exception after the database. Records that no Terraform command has yet been run against any
  environment.

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

Current HTTP cache policy decision:

- `adr/global-and-publishing-default-no-store-policy.md` — Global and Publishing policy-root
  controllers default to `Cache-Control: no-store` through an explicitly declared, prepended
  `DefaultNoStore` callback; an action opts into caching only through Rails' `fresh_when`, `stale?`,
  `expires_in`, `expires_now`, or `http_cache_forever`. Core, Palm, Warp, and Regional-owned roots
  are outside the default. Current rules: `docs/reference/http-cache-policy.md`.

Current CSRF decision:

- `adr/csrf-protection-disabled-in-test-environment.md` — settled decision that `bin/rails test`
  keeps `allow_forgery_protection` off while development and production must keep it on. Read this
  before proposing to enable CSRF suite-wide; it records why that change buys appearance rather than
  coverage, and the one condition that would reopen it.

Current retention / deletion decisions:

- `adr/retainable-concern-and-retention-purge.md`
- `adr/retention-lifecycle-column-boundary.md`
- `adr/processor-erasure-notification-delivery-contract.md` — provider-neutral processor
  notification receipt, bounded retry, terminal failure, recovery, and parent-retention cascade
  contract.

Proposed and deferred directions (not accepted, not implemented):

- `adr/remembered-account-projection-and-store-boundary.md` — proposed direction for listing
  previously used accounts on the sign-in screen: an allow-listed snapshot written at sign-in, an
  opaque browser identifier, no authentication authority, and a logically independent store whose
  placement in the `*_ticket` database is provisional. Open items are in
  `plans/backlog/remembered-account-chooser.md`.

Repository / application boundary decisions:

- `adr/split-into-regional-and-global-repos.md` — the two-repository structure (Global vs Regional)
  remains in force; superseded where it treats `sign/id` as IdP and `acme/www` as RP. Database
  ownership between the two repositories is now fixed by
  `adr/global-regional-database-ownership.md`.
- `adr/acme-rp-boundary-naming.md` — superseded where it treats `acme/www` as an RP boundary instead
  of the identity authority boundary.

Testing decisions:

- `adr/model-standalone-coverage-without-enforced-threshold.md` — models SHOULD be measured with
  model tests alone and that coverage raised over time; no threshold or gate is added to SimpleCov
  or CI configuration.

Historical engine-era ADRs are retained for traceability only. They do not authorize reintroducing
`engines/`, wrapper apps under `apps/<name>`, `Jit::<EngineName>` namespaces, or `isolate_namespace`
boundaries in this repository.

- `valkey-nonprod-logical-db-topology.md` — one nonprod Valkey, DBs 0–5, AUTH_STATE_REDIS_URL.
- `sign-neutral-entry-and-logout-target-authorization.md` — neutral `/sign` entry, 403 for an
  authenticated new Sign (including Base-only sessions), and `id_token_hint` never authorizes
  revoking a session the browser does not hold. Amends `adr/logout-ceremony-boundary.md`.

Current OpenAPI coverage deferral:

- `adr/owner-api-openapi-description-deferred.md` — the R5 Base owner APIs (server-to-server from
  the realm's Base Self-RP) stay out of `openapi/` for now; the coverage test skips them, and the
  gap is revisited before any other caller uses them.
