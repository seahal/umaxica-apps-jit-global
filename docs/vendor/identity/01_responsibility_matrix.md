---
title: Identity Responsibility Matrix
status: rfi-draft
version: "2026-06-24-r4"
audience:
  - SIer
  - security-vendor
  - internal-architecture
  - implementation-team
owner: internal-architecture-owner
last-reviewed: 2026-06-24
source-of-truth: current-repository-evidence
confidentiality: internal-vendor-shareable
related-audit-ledger: plans/umaxica-immutable-pinwheel.md
---

# Purpose

Define which component owns each identity capability, what a SIer may implement, what is prohibited,
and what requires security-vendor verification. This document supersedes the capability section of
`02_responsibility-boundary.md` and is the normative source for all vendor-facing scope discussions.

# Scope

This matrix covers:

- Protocol authority (OAuth/OIDC private profile, informed by OAuth 2.1 draft)
- Credential ceremony boundaries
- Token, session, and cookie lifecycle
- Authorization enforcement
- Audit and security control ownership
- SIer implementation scope and prohibitions
- Security-vendor assessment scope

# Non-scope

- Detailed controller implementation
- Database schema design
- Infrastructure / TLS configuration
- Front-end toolchain choices (see `docs/vendor/identity/01_current-architecture.md`)

# Source Evidence

- `app/services/oidc_issuer.rb`
- `app/services/oidc_discovery_document.rb`
- `app/controllers/concerns/authentication_base.rb`
- `app/controllers/concerns/authentication_cookie_store.rb`
- `app/controllers/concerns/authentication_cookie_name.rb`
- `app/controllers/concerns/session_limit_gate.rb`
- `app/services/dpop_proof_validator.rb`
- `app/services/palm_access_token_authenticator.rb`
- `app/policies/application_policy.rb`
- `app/models/concerns/secret_credential.rb`
- `app/services/recovery_passcode_top_up.rb`
- `config/routes/acme.rb`, `sign.rb`, `core.rb`, `base.rb`, `palm.rb`
- `docs/identity/authority-boundary.md`
- `docs/security/session-token-authority.md`
- `docs/security/social-callback-boundary.md`
- `docs/security/credential-gateway.md`
- `docs/security/sign-in-sequence.md`
- `docs/security/logout-sequence.md`
- `docs/architecture/dpop.md`
- `adr/acme-sign-core-base-port-boundary.md`
- `adr/security-audit-findings-2026-06-13.md`
- `plans/umaxica-immutable-pinwheel.md` (audit ledger, DECISION DEC-001~013)

# Non-negotiable Authority Boundaries

The following boundaries are architecture invariants. They cannot be changed by a SIer, overridden
by configuration, or relaxed by product decision without a new accepted ADR.

| Invariant             | Statement                                                                                                                                                                                                                                         |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **AS Authority**      | Acme is the only Authorization Server, OpenID Provider, and Identity Authority. No other surface may issue OAuth tokens, OIDC ID tokens, or act as AS.                                                                                            |
| **Sign Role**         | Sign is the Credential Ceremony UI and an OIDC RP toward external social providers. Sign does not issue session tokens, refresh tokens, or access tokens.                                                                                         |
| **Core Role**         | Core is an OAuth Client / OIDC RP / BFF. It exchanges authorization codes and holds tokens server-side. Cookie transport details (artifact names, attributes, lifetimes) are defined in `docs/vendor/identity/04_cookie-session-token-matrix.md`. |
| **Base Role**         | Base is an RP (view surface) and Resource Server (API surface). It validates tokens from Acme; it does not issue tokens.                                                                                                                          |
| **Palm Role**         | Palm is a native API Resource Server. It accepts bearer tokens issued by Acme. It does not support DPoP (explicitly rejects DPoP-bound tokens).                                                                                                   |
| **DPoP**              | DPoP is opt-in infrastructure. New flows must explicitly adopt it. Palm is permanently bearer-only.                                                                                                                                               |
| **Social Linking**    | Social identity linking MUST use `provider + uid/sub` as primary key. Email matching MUST NOT be used for automatic account linking. (NR-001, DEC-008)                                                                                            |
| **Signing Algorithm** | JWT signing uses ES384 only. RS256 is intentionally absent. This is a private profile; third-party OIDC conformance suites should not expect RS256.                                                                                               |

---

# Role Legend

| Symbol          | Meaning                                                                                                      |
| --------------- | ------------------------------------------------------------------------------------------------------------ |
| `OWN`           | Authority owner. Accountable. Cannot be delegated.                                                           |
| `EXEC`          | Executes or hosts this capability per spec.                                                                  |
| `OWN+EXEC`      | Owns authority and executes directly.                                                                        |
| `IMPL`          | SIer may implement following normative spec. Subject to code review and acceptance test.                     |
| `AUDIT`         | Reviews, validates, or tests this capability.                                                                |
| `TEST/EVIDENCE` | SIer must provide test coverage and acceptance evidence for this capability; SIer does not own or implement. |
| `C`             | Consumes / depends on this output.                                                                           |
| `–`             | Not applicable.                                                                                              |
| `✗`             | Prohibited. Must not touch.                                                                                  |
| `[OPEN]`        | Capability status is partially unresolved. See Notes column.                                                 |
| `[BLOCKER]`     | Known gap blocking production readiness. See Notes column.                                                   |

---

# Section A: Protocol Authority (OAuth/OIDC private profile, informed by OAuth 2.1 draft)

_These capabilities are Acme-only. No SIer action may modify or relocate them._

| Capability                                        | Acme     | Sign | Core | Base | Palm | Browser | Operator/Support | Internal Team | SIer          | Security Vendor | Decision Owner | Evidence                                                            | Notes                                                                                                                                                                               |
| ------------------------------------------------- | -------- | ---- | ---- | ---- | ---- | ------- | ---------------- | ------------- | ------------- | --------------- | -------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| OAuth authorization endpoint (`/oauth/authorize`) | OWN+EXEC | ✗    | C    | C    | –    | C       | –                | AUDIT         | ✗             | AUDIT           | Internal Arch  | `config/routes/acme.rb`, `adr/acme-sign-core-base-port-boundary.md` | Acme owns protocol surface. SIer MUST NOT implement or proxy this endpoint.                                                                                                         |
| OAuth token endpoint (`/oauth/token`)             | OWN+EXEC | ✗    | C    | C    | C    | –       | –                | AUDIT         | ✗             | AUDIT           | Internal Arch  | `config/routes/acme.rb`                                             | Back-channel. SIer MUST NOT implement or proxy.                                                                                                                                     |
| OIDC discovery / `.well-known`                    | OWN+EXEC | ✗    | C    | C    | C    | C       | –                | AUDIT         | ✗             | AUDIT           | Internal Arch  | `app/services/oidc_discovery_document.rb`                           | ES384 only. No RS256. Private profile.                                                                                                                                              |
| JWKS publication                                  | OWN+EXEC | ✗    | C    | C    | C    | –       | –                | AUDIT         | ✗             | AUDIT           | Internal Arch  | `JitSecurityJwtRegistry`                                            | Dev/test keys not publishable in production environments.                                                                                                                           |
| OIDC userinfo endpoint (`/oauth/userinfo`)        | OWN+EXEC | ✗    | C    | C    | –    | –       | –                | AUDIT         | ✗             | AUDIT           | Internal Arch  | `config/routes/acme.rb`                                             | Bearer access token required. No cookie fallback.                                                                                                                                   |
| Access token issuance                             | OWN+EXEC | ✗    | C    | C    | C    | –       | –                | AUDIT         | ✗             | AUDIT           | Internal Arch  | `app/services/oidc_token_exchange_service.rb`                       | ES384-signed JWT. Audience is surface-specific.                                                                                                                                     |
| Refresh token issuance                            | OWN+EXEC | ✗    | C    | –    | C    | –       | –                | AUDIT         | ✗             | AUDIT           | Internal Arch  | `app/controllers/concerns/authentication_base.rb`                   | Digest-stored, family-ID tracked.                                                                                                                                                   |
| Refresh token rotation                            | OWN+EXEC | ✗    | –    | –    | –    | –       | –                | AUDIT         | ✗             | AUDIT           | Internal Arch  | `authentication_base.rb` `rotate_refresh_token!`                    | Replay = compromise (ADR). Old token invalidated on rotation.                                                                                                                       |
| Refresh token revocation                          | OWN+EXEC | ✗    | EXEC | –    | EXEC | –       | EXEC             | AUDIT         | ✗             | AUDIT           | Internal Arch  | `authentication_base.rb`                                            | Palm logout revokes entire token family.                                                                                                                                            |
| ID token issuance                                 | OWN+EXEC | ✗    | C    | C    | –    | –       | –                | AUDIT         | ✗             | AUDIT           | Internal Arch  | `app/services/oidc_id_token_service.rb`                             | ES384. Audience bound to surface.                                                                                                                                                   |
| Token endpoint null_session behavior              | OWN+EXEC | –    | –    | –    | –    | –       | –                | AUDIT         | TEST/EVIDENCE | AUDIT           | Internal Arch  | `adr/security-audit-findings-2026-06-13.md` GQ-05                   | Fail-closed. SIer MUST NOT implement alternative behavior. SIer MUST provide request tests confirming: null_session → deterministic OAuth error, no token issued. (DEC-012, NR-003) |

---

# Section B: Credential Ceremony

_Sign owns ceremony UI. Acme owns ceremony result processing and session authority._

| Capability                                   | Acme           | Sign                 | Core | Base | Palm | Browser | Operator/Support | Internal Team | SIer | Security Vendor | Decision Owner          | Evidence                                                                           | Notes                                                                                                                                                                                   |
| -------------------------------------------- | -------------- | -------------------- | ---- | ---- | ---- | ------- | ---------------- | ------------- | ---- | --------------- | ----------------------- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Sign-in ceremony UI                          | –              | OWN+EXEC             | –    | –    | –    | C       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch           | `docs/security/sign-in-sequence.md`, `config/routes/sign.rb`                       | SIer may add new ceremony steps but MUST NOT remove authentication controls or reorder the pipeline.                                                                                    |
| Sign-up ceremony UI                          | –              | OWN+EXEC             | –    | –    | –    | C       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch           | `docs/security/sign-up-sequence.md`                                                | Same constraint as sign-in.                                                                                                                                                             |
| Sign-out / logout                            | OWN            | EXEC                 | EXEC | EXEC | EXEC | C       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch           | `docs/security/logout-sequence.md`                                                 | Authority is Acme. UI may be hosted on multiple surfaces. Session revocation must go through Acme.                                                                                      |
| Social provider callback                     | –              | OWN+EXEC             | –    | –    | –    | C       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch           | `docs/security/social-callback-boundary.md`                                        | Sign receives social callback, validates, sends signed ceremony result to Acme.                                                                                                         |
| Signed ceremony result handoff (Sign → Acme) | OWN (consumer) | OWN (producer)       | –    | –    | –    | –       | –                | AUDIT         | ✗    | AUDIT           | Internal Arch           | `app/controllers/acme/app/social/authentications_controller.rb`                    | One-shot signed JWT. Audience = Acme. SIer MUST NOT intercept or modify this handoff.                                                                                                   |
| Session limit enforcement                    | OWN+EXEC       | –                    | –    | –    | –    | –       | EXEC             | AUDIT         | ✗    | AUDIT           | Internal Arch           | `app/controllers/concerns/session_limit_gate.rb`                                   | app=2+1, com=1+1, org=1+1 (active+restricted). Cannot be changed by SIer without ADR.                                                                                                   |
| Restricted session / sign-in limitation UI   | –              | EXEC                 | –    | –    | –    | C       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch           | `sign/in/limitations_controller.rb` (WORKTREE rename of session_limit_resolutions) | UI rename is WORKTREE change. Authority remains Acme.                                                                                                                                   |
| Passkey registration                         | –              | OWN+EXEC             | –    | –    | –    | EXEC    | –                | AUDIT         | IMPL | AUDIT           | Internal Arch           | `app/controllers/sign/app/settings/passkeys_controller.rb`                         | ES256/ES384. Public Auth hosts must configure WebAuthn trusted origins in production. SIer may not relax origin constraints.                                                            |
| Passkey authentication                       | –              | OWN+EXEC             | –    | –    | –    | EXEC    | –                | AUDIT         | IMPL | AUDIT           | Internal Arch           | `app/controllers/sign/app/settings/passkeys/verifications_controller.rb`           | Challenge must be Acme-bound. Replay protection must remain.                                                                                                                            |
| TOTP verification                            | –              | OWN+EXEC             | –    | –    | –    | EXEC    | –                | AUDIT         | IMPL | AUDIT           | Internal Arch           | `app/controllers/sign/app/settings/totps_controller.rb`                            | same-window replay PROHIBITED (DEC-011, NR-002). Replay rejection must be audited.                                                                                                      |
| Recovery passcode generation                 | OWN+EXEC       | –                    | –    | –    | –    | –       | –                | AUDIT         | ✗    | AUDIT           | Internal Arch           | `app/services/recovery_passcode_top_up.rb` (TARGET=10, MINIMUM=2)                  | 184-bit entropy, Argon2, single-use. SIer MUST NOT modify passcode generation.                                                                                                          |
| Recovery passcode consumption                | OWN+EXEC       | EXEC (UI)            | –    | –    | –    | EXEC    | –                | AUDIT         | IMPL | AUDIT           | Internal Arch + DEC-005 | `app/models/concerns/secret_credential.rb`                                         | **[BLOCKER]** No rate limit / lockout. Remediation required before production (DEC-005, GAP-NEW-001).                                                                                   |
| MFA reset / account recovery                 | OWN            | EXEC (UI — DISABLED) | –    | –    | –    | –       | EXEC             | AUDIT         | IMPL | AUDIT           | Internal Arch + DEC-009 | `sign/app/settings/mfa/resets_controller.rb`                                       | **[BLOCKER]** UI DISABLED. 5 prerequisites must be met before enablement: Runbook, State Machine, Abuse Protection, Audit Requirements, Acceptance Criteria. (DEC-009, GAP-NEW-006/007) |

---

# Section C: Session and Cookie Lifecycle

| Capability                        | Acme     | Sign | Core | Base | Palm | Browser | Operator/Support | Internal Team | SIer | Security Vendor | Decision Owner          | Evidence                                                    | Notes                                                                                                               |
| --------------------------------- | -------- | ---- | ---- | ---- | ---- | ------- | ---------------- | ------------- | ---- | --------------- | ----------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Browser auth cookie issuance      | OWN+EXEC | –    | EXEC | EXEC | –    | C       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch           | `authentication_cookie_store.rb`                            | `__Host-` prefix in production. SameSite=Strict, HttpOnly, Secure. SIer MUST NOT change cookie security attributes. |
| Browser auth cookie purge         | OWN+EXEC | EXEC | EXEC | EXEC | –    | –       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch           | `authentication_base.rb` `clear_auth_cookies!`              | Must clear all auth cookies (access + refresh). Partial purge is prohibited.                                        |
| Transparent refresh               | OWN+EXEC | –    | EXEC | EXEC | –    | –       | –                | AUDIT         | ✗    | AUDIT           | Internal Arch           | `authentication_base.rb` `transparent_refresh_access_token` | FAIL-CLOSED. Failure clears auth cookies. SIer MUST NOT modify this behavior.                                       |
| Session cookie (`__Host-session`) | OWN+EXEC | EXEC | EXEC | EXEC | –    | C       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch           | `authentication_cookie_name.rb`                             | SameSite=Lax, HttpOnly, partitioned in production.                                                                  |
| DPoP opt-in handling              | OWN+EXEC | –    | IMPL | IMPL | ✗    | –       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch + DEC-006 | `app/services/dpop_proof_validator.rb`                      | DPoP is optional infrastructure. Palm is bearer-only (permanently). New flows must explicitly adopt DPoP. (DEC-006) |

---

# Section D: Resource Server Authentication

| Capability                       | Acme               | Sign | Core     | Base     | Palm                 | Browser | Operator/Support | Internal Team | SIer | Security Vendor | Decision Owner | Evidence                                          | Notes                                                                                                              |
| -------------------------------- | ------------------ | ---- | -------- | -------- | -------------------- | ------- | ---------------- | ------------- | ---- | --------------- | -------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Palm bearer token authentication | OWN (token issuer) | –    | –        | –        | OWN+EXEC (validator) | –       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch  | `app/services/palm_access_token_authenticator.rb` | AUDIENCE="palm-api", REQUIRED_SCOPE="palm.read". DPoP-bound tokens REJECTED. access=5min, refresh=30days, idle=8h. |
| Core browser API boundary        | OWN (token)        | –    | OWN+EXEC | –        | –                    | C       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch  | `core_browser_api_boundary.rb`                    | HttpOnly cookie transport. DBSC device binding. No DPoP.                                                           |
| Base API resource validation     | OWN (token)        | –    | –        | OWN+EXEC | –                    | –       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch  | `authentication_current_resource_resolver.rb`     | Validates Acme-issued bearer token.                                                                                |

---

# Section E: Authorization

| Capability                                  | Acme     | Sign | Core | Base | Palm | Browser | Operator/Support | Internal Team | SIer | Security Vendor | Decision Owner              | Evidence                                                 | Notes                                                                                                                                          |
| ------------------------------------------- | -------- | ---- | ---- | ---- | ---- | ------- | ---------------- | ------------- | ---- | --------------- | --------------------------- | -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Authorization framework                     | OWN+EXEC | EXEC | EXEC | EXEC | EXEC | –       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch + DEC-003/004 | `app/policies/application_policy.rb`, ActionPolicy 0.7.6 | Default deny-all. `enforce_access_policy!` cannot be skipped. SIer MUST add `authorize!` to every new action.                                  |
| Authorization policy files                  | OWN      | EXEC | EXEC | EXEC | EXEC | –       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch + DEC-004     | 339 policy files                                         | SIer MUST provide policy tests covering owner-allows and non-owner-denies for every new policy. Evidence of coverage is SIer's responsibility. |
| Domain / audience gating                    | OWN+EXEC | –    | –    | –    | –    | –       | –                | AUDIT         | ✗    | AUDIT           | Internal Arch               | `app/policies/application_policy.rb`                     | Surface isolation enforced at policy layer. SIer MUST NOT bypass audience gating.                                                              |
| `after_action :verify_authorized` (missing) | –        | –    | –    | –    | –    | –       | –                | OWN           | –    | AUDIT           | Internal Arch + DEC-003     | `adr/security-audit-findings-2026-06-13.md` FINDING-04   | DEFERRED. Risk owner = Internal Arch. SIer responsible for new actions; internal team responsible for framework-level enablement.              |

---

# Section F: Audit and Security Controls

| Capability                       | Acme     | Sign | Core | Base | Palm | Browser | Operator/Support | Internal Team | SIer | Security Vendor | Decision Owner          | Evidence                                                                                                   | Notes                                                                                                                                                                                                                           |
| -------------------------------- | -------- | ---- | ---- | ---- | ---- | ------- | ---------------- | ------------- | ---- | --------------- | ----------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Audit event recording            | OWN+EXEC | EXEC | EXEC | EXEC | EXEC | –       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch + DEC-013 | Chronicle system                                                                                           | event_uuid UNIQUE, retention policies, application-level sanitization. SIer MUST emit audit events for all security-relevant actions per NR-004.                                                                                |
| Audit log integrity              | OWN+EXEC | –    | –    | –    | –    | –       | –                | OWN           | –    | AUDIT           | Internal Arch + DEC-013 | `docs/vendor/identity/08_threat-model.md`                                                                  | **[BLOCKER]** DB-level immutability absent. application-level sanitization + event_uuid UNIQUE alone are insufficient. Short-term: DB append-only or tamper-evidence required. Long-term: ChainSeal. (DEC-013, NR-004, GAP-002) |
| Rate limiting / abuse protection | OWN+EXEC | EXEC | EXEC | EXEC | EXEC | –       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch           | `app/controllers/concerns/authentication_base.rb`                                                          | SIer MUST NOT disable rate limiting. Recovery passcode rate limit is a known gap (DEC-005).                                                                                                                                     |
| CSRF protection                  | OWN      | EXEC | EXEC | EXEC | EXEC | C       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch           | All surface controllers                                                                                    | `skip_forgery_protection` is PROHIBITED. BareController keeps CSRF. Token endpoints exempt by OAuth design (DEC-012).                                                                                                           |
| CSP / security headers           | OWN+EXEC | EXEC | EXEC | EXEC | EXEC | C       | –                | AUDIT         | IMPL | AUDIT           | Internal Arch           | `config/initializers/content_security_policy.rb`                                                           | CSP `report-uri` URLs are immutable (browser caches policy). SIer MUST NOT rename these URLs.                                                                                                                                   |
| Social identity linking policy   | OWN+EXEC | EXEC | –    | –    | –    | –       | –                | AUDIT         | ✗    | AUDIT           | Internal Arch + DEC-008 | `adr/security-audit-findings-2026-06-13.md` FINDING-03, `docs/vendor/identity/07_social-linking-policy.md` | email matching auto-linking is PROHIBITED. uid+provider is identity key. (DEC-008, NR-001)                                                                                                                                      |
| Key rotation                     | OWN+EXEC | –    | –    | –    | –    | –       | –                | OWN           | ✗    | AUDIT           | Internal Arch           | `docs/operations/jwt-key-rotation.md`                                                                      | ES384 keys only. Dev/test keys cannot be published in production. SIer MUST NOT generate or manage signing keys.                                                                                                                |

---

# Section G: Operations and Support

| Capability                            | Acme            | Sign | Core | Base | Palm | Browser | Operator/Support | Internal Team | SIer | Security Vendor | Decision Owner          | Evidence                                      | Notes                                                                                                                                                              |
| ------------------------------------- | --------------- | ---- | ---- | ---- | ---- | ------- | ---------------- | ------------- | ---- | --------------- | ----------------------- | --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Operator / support action on accounts | OWN (authority) | –    | –    | –    | –    | –       | OWN+EXEC         | AUDIT         | –    | AUDIT           | Internal Arch           | `docs/security/mfa-reset-account-recovery.md` | Administrative lock/unlock exists. Identity verification procedure for support actions is partially undefined.                                                     |
| Incident response                     | OWN             | –    | –    | –    | –    | –       | EXEC             | OWN           | –    | AUDIT           | Internal Arch + DEC-010 | `docs/vendor/identity/08_threat-model.md`     | **[BLOCKER]** Incident runbook absent. Threat model is DRAFT (context only). Appendix required before security-vendor engagement. (DEC-010, G-005 in gap register) |
| IP anomaly / session revocation       | OWN+EXEC        | –    | –    | –    | –    | –       | –                | AUDIT         | ✗    | AUDIT           | Internal Arch           | `adr/ip-anomaly-session-revocation.md`        | Coarse IP/ASN anomaly detection. SIer MUST NOT modify revocation logic without ADR.                                                                                |

---

# Section H: Vendor Scope Boundaries

## SIer: What You May Implement

| Area                                        | Permitted Scope                                                         | Constraints                                                                                                                                   |
| ------------------------------------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| New ceremony flows on Sign                  | New sign-in/sign-up/recovery UI steps within existing surface structure | Must not remove or reorder authentication controls. Must not bypass rate limiting or CSRF.                                                    |
| New RP surfaces (new Core/Base deployments) | New surfaces that consume Acme tokens as an OAuth client                | Must register as a confidential client. Must implement PKCE S256. Must validate redirect URI exactly. Must call `authorize!` on every action. |
| New authorization policies                  | New policy files following ActionPolicy pattern                         | Must provide owner-allows and non-owner-denies tests. Must not shadow ApplicationPolicy methods accidentally.                                 |
| New audit event types                       | Additional Chronicle audit events for SIer-implemented flows            | Must follow NR-004 critical event class. Must emit events for all security-relevant actions.                                                  |
| Palm API client integration                 | Implement mobile/native clients that consume Palm bearer tokens         | Must use bearer token only. DPoP-bound tokens will be rejected by Palm.                                                                       |
| New route endpoints (non-protocol)          | New resource endpoints under existing surface routes                    | Must follow controller inheritance contract. Must call `authorize!`. Must not claim OAuth/OIDC authority.                                     |
| MFA reset UI (deferred)                     | May implement when 5 prerequisites are met (DEC-009)                    | Must include operator workflow, state machine, abuse protection, audit events, and acceptance criteria.                                       |

## SIer: What You Must Not Touch

| Prohibition                                                                                                             | Reason                                                                             |
| ----------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `/oauth/*` and `/oidc/*` endpoints                                                                                      | These are Acme protocol surfaces. Token authority cannot be delegated or proxied.  |
| Token issuance logic                                                                                                    | Access token, refresh token, ID token issuance are Acme-owned invariants.          |
| Signing key generation or management                                                                                    | ES384 keys are managed by Internal Team. SIer has no key management role.          |
| Cookie security attributes (`__Host-`, `Secure`, `HttpOnly`, `SameSite`)                                                | Changing these weakens the token transport security model.                         |
| `transparent_refresh_access_token` behavior                                                                             | Fail-closed. Any modification could introduce fail-open risk.                      |
| Session limit constants (app=2+1, com=1+1, org=1+1)                                                                     | Changing limits requires an ADR.                                                   |
| `enforce_access_policy!` removal or bypass                                                                              | SkipNotAllowedError. This is a non-skippable invariant.                            |
| Social provider callback processing                                                                                     | Acme is the signed ceremony result consumer. SIer must not intercept this handoff. |
| `email_verified=false` rejection                                                                                        | FINDING-03 fix. Must remain rejected at assertion boundary.                        |
| Recovery passcode entropy or algorithm                                                                                  | 184-bit entropy and Argon2 are minimum security baselines.                         |
| DPoP JTI replay stateful tracking (login/refresh)                                                                       | Replay = compromise (ADR). Stateful JTI tracking must remain for login/refresh.    |
| CSP `report-uri` URLs                                                                                                   | Immutable; browsers cache the policy for TTL duration.                             |
| IP anomaly session revocation logic                                                                                     | Security invariant. Changes require ADR.                                           |
| `skip_before_action`, `skip_authorization`, `skip_forgery_protection`, `html_safe`, `raw(...)`, `permit!`, `rescue nil` | Absolute prohibitions (AGENTS.md Non-negotiable Rules).                            |

## Security Vendor: Assessment Scope

| Scope Item                            | Coverage                                                        | Notes                                                                                                               |
| ------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| OAuth 2.1 / OIDC protocol conformance | All `A`, `OWN+EXEC` cells in Sections A–B                       | Verify: PKCE S256, auth code single-use, redirect URI exact match, token TTLs                                       |
| Token and session security            | Sections C–D                                                    | Verify: cookie attributes, transparent refresh fail-closed, session limit enforcement                               |
| Authorization model                   | Section E                                                       | Verify: default deny-all, enforce_access_policy! cannot be skipped, domain gating                                   |
| Audit log integrity                   | Section F (audit log integrity row)                             | **[BLOCKER]** DB-level immutability absent. Verify current detective controls and recommend remediation.            |
| Social linking policy                 | Section F, Section B (social provider callback)                 | Verify: uid+provider primary key, email_verified=false rejection, no email-based auto-linking                       |
| DPoP enforcement                      | Section C, Section D                                            | Verify: DPoP optional design is correct for in-scope flows; Palm rejection of DPoP-bound tokens is intentional      |
| MFA / credential recovery             | Section B (MFA reset)                                           | **[BLOCKER]** MFA reset UI disabled. Verify that current passcode controls are adequate until reset is implemented. |
| Threat model validation               | `docs/vendor/identity/08_threat-model.md` (context only, DRAFT) | Verify 29 scenarios, identify gaps, recommend runbook appendix                                                      |
| Rate limiting / abuse                 | Section F (rate limiting)                                       | Note: recovery passcode has no rate limit (known gap, DEC-005)                                                      |

---

# Normative Requirements (NR-001 — NR-004)

The following requirements are verbatim normative constraints. They apply to all SIer-implemented
capability and to any internal implementation that touches the affected boundary.

## NR-001: Social Identity Linking

```
Social identity linking MUST NOT be performed solely by matching email address.
Social identity linking MUST be based on provider stable subject identifier (uid/sub).
email_verified=false MUST be rejected at the assertion boundary.
If explicit account linking is introduced in the future, it MUST require:
  (a) an authenticated existing account session,
  (b) explicit user action,
  (c) provider callback validation,
  (d) audit log,
  (e) conflict handling,
  (f) rollback/revocation behavior.
```

Status: GQ-01 CLOSED for initial release (DEC-008). Future explicit linking = DEFERRED.

## NR-002: TOTP Replay Prevention

```
A successfully accepted TOTP code MUST NOT be accepted again for the same
credential and ceremony purpose within the same time-step.
The system MUST distinguish verification failure from already-used replay.
Replay rejection MUST be audited.
The implementation SHOULD avoid permanent lockout caused by accidental duplicate submission.
```

Status: GQ-04 CLOSED (DEC-011, hardened policy).

## NR-003: Token Endpoint null_session Behavior

```
Token endpoint MUST authenticate and validate the OAuth client / authorization code / PKCE
independently of browser session state.
If request context becomes null_session or lacks required protocol context, the endpoint
MUST return a deterministic OAuth error and MUST NOT issue tokens.
This behavior MUST be covered by request tests.
```

Status: GQ-05 CLOSED (DEC-012, fail-closed).

## NR-004: Audit Log Integrity

```
Critical security audit events MUST be append-only at the application boundary.
Update/delete of critical audit events MUST be prevented or detectable.
Operator/admin access to audit records MUST be logged.
Audit event mutation, if technically possible, MUST leave independent evidence.
Token, cookie, OTP, passcode, private key, secret values MUST NOT be logged.
Audit retention and export policy MUST be documented.
```

**Minimum critical event class (all surfaces):**

- Credential created / changed / destroyed
- MFA enrolled / removed / reset
- Social identity linked / unlinked
- Token issued / refreshed / revoked
- Session created / limited / revoked
- Passkey registered / removed
- Recovery passcode consumed
- Operator action on user account
- Privilege change

**Implementation candidates (short-term):** DB trigger blocking update/delete; separate append-only
audit table; restricted DB role with no delete privilege; hash chain / periodic digest; external log
sink replication.

**Long-term hardening:** ChainSeal production deployment.

Status: GQ-R3-005 CLOSED (DEC-013). **[BLOCKER]** Implementation method not yet selected.

---

# Unresolved / Deferred Items

| ID               | Description                                                                                  | Status                                  | Prerequisite                                                                      |
| ---------------- | -------------------------------------------------------------------------------------------- | --------------------------------------- | --------------------------------------------------------------------------------- |
| GQ-06            | Telephone-only AAL1: whether telephone OTP alone qualifies as AAL1 for all ceremony purposes | **OPEN**                                | Product/security decision required                                                |
| GAP-NEW-001      | Recovery passcode rate limit / lockout absent                                                | OPEN (remediation target)               | DEC-005: specify before implementation                                            |
| GAP-NEW-006/007  | MFA reset UI disabled; catastrophic account recovery undefined                               | OPEN                                    | DEC-009: 5-prerequisite runbook/spec must precede UI enablement                   |
| GAP-002 / NR-004 | Chronicle DB-level immutability absent                                                       | OPEN (implementation method unselected) | DEC-013: method selection required before RFP                                     |
| GAP-010          | 08_threat-model.md DRAFT, owner TBD                                                          | OPEN                                    | DEC-010: owner must be confirmed before RFP; RFI share with "context only" caveat |
| GAP-004          | `after_action :verify_authorized` not enabled                                                | DEFERRED                                | DEC-003/004: risk accepted by Internal Arch; long-term backlog                    |
| RSK-010          | DPoP-bound tokens rejected by Palm — SIer may not be aware                                   | OPEN (doc gap)                          | Add design intent to SIer implementation guide                                    |

---

# Acceptance Evidence

The following evidence is required for SIer-implemented capability to be accepted.

| Evidence Type                   | Requirement                                                                                                                                                         |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Controller action authorization | Every new action must call `authorize!`. Policy test must cover owner-allows and non-owner-denies.                                                                  |
| Audit event emission            | Every security-relevant action must emit a Chronicle audit event. Event schema must be reviewed against NR-004 critical event class.                                |
| Social linking                  | Any linking flow must be verified against NR-001. No email-matching path may exist in delivered code.                                                               |
| TOTP                            | Replay rejection must be covered by test asserting same time-step acceptance is rejected on second use.                                                             |
| Token endpoint                  | Null session and missing protocol context must be covered by request tests returning deterministic OAuth error.                                                     |
| Audit log integrity             | Implementation method selection from DEC-013 candidates must be reviewed and approved before merge.                                                                 |
| MFA reset (if in scope)         | All 5 DEC-009 prerequisites (Runbook, State Machine, Abuse Protection, Audit Requirements, Acceptance Criteria) must be reviewed and approved before UI enablement. |
| Rate limiting                   | No new authentication boundary endpoint may be delivered without rate limit coverage.                                                                               |

---

# Relationship to Other Documents

| Document                                                 | Relationship                                                                    |
| -------------------------------------------------------- | ------------------------------------------------------------------------------- |
| `docs/vendor/identity/02_responsibility-boundary.md`     | Simplified predecessor. This document supersedes the capability matrix section. |
| `docs/vendor/identity/04_cookie-session-token-matrix.md` | Artifact-level detail for Section C above. Read together.                       |
| `docs/vendor/identity/07_social-linking-policy.md`       | Normative source for NR-001.                                                    |
| `docs/vendor/identity/08_threat-model.md`                | DRAFT (context only / not normative / subject to internal approval). DEC-010.   |
| `docs/vendor/identity/09_acceptance-criteria.md`         | Detailed acceptance criteria. Section above summarizes.                         |
| `docs/vendor/identity/11_decision-register.md`           | Internal vendor decision register (pre-Round 4). Update pending.                |
| `docs/vendor/identity/12_gap-risk-register.md`           | Internal gap register (pre-Round 4). Update pending.                            |
| `plans/umaxica-immutable-pinwheel.md`                    | Audit ledger. DEC-001~~013 and NR-001~~004 originate here.                      |

---

# Document Status Warnings

- **08_threat-model.md** is DRAFT, owner TBD. Share in RFI as context only; not normative. (DEC-010)
- **notes/oauth2-1-compliance-gap.md** is a stale non-authoritative doc. Do not include in RFI
  resource set. Seal before first SIer contact. Update or archive before RFP. (DEC-001/002)
- **docs/spec/authorization_guide.md** (Pundit version) is stale. Use `docs/authorization_guide.md`
  (ActionPolicy version). (DEC-007)
- **11_decision-register.md** and **12_gap-risk-register.md** predate Round 4 decisions and have not
  been updated with DEC-008~013 or Round 4 GAP findings. Update before RFP.
