---
title: Identity Normative Baseline
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

Define the exact protocol profile, security baseline, and implementation constraints that govern
Umaxica's identity control plane. This document is the normative reference for SIer scope
discussions, security-vendor assessment setup, and RFP requirement authoring.

**Read this document before** reading the route inventory, flow inventory, or threat model. It
defines what Umaxica is — and what it is not — at the protocol and security control level.

# ⚠ Critical Framing Warning

Umaxica is **not** a generic public OIDC provider. It is a **private first-party identity system**
with a deliberate protocol profile. Do not assume:

- RS256 compatibility
- Third-party dynamic client registration
- Generic OIDC conformance suite pass/fail as a quality gate
- Auth0 / Keycloak / Cognito behavioral defaults
- DPoP as a mandatory baseline
- Email-based social account linking as a supported feature
- Self-service MFA reset as a currently deployed feature
- Completed audit log immutability

Any SIer proposal that assumes these defaults without explicit authorization from the internal
architecture owner will be rejected during technical review.

---

# 1. Document Status

| Field                | Value                                                                      |
| -------------------- | -------------------------------------------------------------------------- |
| Status               | rfi-draft — shareable in RFI with conditions (see §14)                     |
| Owner                | internal-architecture-owner                                                |
| Audience             | SIer, security-vendor, internal-architecture, implementation-team          |
| Confidentiality      | internal-vendor-shareable                                                  |
| Source of truth      | current repository evidence, cross-referenced with audit ledger            |
| Last reviewed        | 2026-06-24 (Round 4 audit)                                                 |
| Related audit ledger | `plans/umaxica-immutable-pinwheel.md` (DECISION DEC-001~~013, NR-001~~004) |

---

# 2. Normative Baseline Definition

## Identity Topology

| Role                                                        | Component | Description                                                                                   |
| ----------------------------------------------------------- | --------- | --------------------------------------------------------------------------------------------- |
| Authorization Server / OpenID Provider / Identity Authority | **Acme**  | The only AS/OP. Issues all OAuth tokens, OIDC ID tokens, and manages session authority.       |
| Credential Ceremony UI / OIDC RP (toward social providers)  | **Sign**  | Hosts authentication ceremonies and delegates social provider flows. Issues no tokens.        |
| OAuth Client / OIDC RP / BFF                                | **Core**  | Exchanges authorization codes, holds tokens server-side, serves HttpOnly cookies to browsers. |
| RP (view surface) / Resource Server (API surface)           | **Base**  | Validates Acme-issued tokens. Issues no tokens.                                               |
| Native API Resource Server                                  | **Palm**  | Accepts Acme-issued bearer tokens. Bearer-only. No DPoP.                                      |

These role assignments are architecture invariants. They cannot be changed by a SIer without a new
accepted ADR.

## Protocol Claim

Umaxica does **not** claim "OAuth 2.1 compliant" or "OpenID Connect certified" as a contractual
assertion. The correct description is:

> **OAuth/OIDC private profile, informed by OAuth 2.1 draft (draft-ietf-oauth-v2-1) and related best
> practices (RFC 9700, RFC 9449, RFC 8705, OpenID Connect Core 1.0).**

This means:

- Umaxica adopts the substance of OAuth 2.1 direction (code + PKCE, no implicit, no ROPC) but does
  not seek public certification against a specific draft version.
- Umaxica's signing algorithm profile (ES384 only) deliberately diverges from OpenID Connect
  conformance expectations (RS256 required).
- All deviations from public standards are intentional and documented in this baseline.

---

# 3. Standards and References Classification

## 3a. Normative / Mandatory

These standards are authoritative for Umaxica's implementation. Non-compliance is a defect.

| Standard / RFC                                      | Scope                                                                |
| --------------------------------------------------- | -------------------------------------------------------------------- |
| RFC 6749 (OAuth 2.0)                                | Foundation. Grant types restricted per profile below.                |
| RFC 7636 (PKCE)                                     | Required. S256 only.                                                 |
| RFC 6750 (Bearer Token Usage)                       | Required for API transport. Bearer in query string prohibited.       |
| RFC 7517 / RFC 7518 (JWKS / JWA)                    | ES384 / EC P-384 only.                                               |
| RFC 7519 (JWT)                                      | All tokens are signed JWTs.                                          |
| OpenID Connect Core 1.0                             | Authorization code flow with PKCE. ID token issuance and validation. |
| RFC 6819 (OAuth 2.0 Threat Model)                   | Reference for threat classification.                                 |
| RFC 9700 (OAuth 2.0 Security Best Current Practice) | Applied where compatible with private profile.                       |

## 3b. Profile Constraints (Umaxica-specific, binding)

These are Umaxica-specific constraints that deviate from or restrict the base standards.

| Constraint        | Statement                                                                                                                                                           |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Signing algorithm | ES384 only. EC P-384 keys. RS256 is intentionally absent.                                                                                                           |
| Grant types       | Authorization Code + PKCE only. Implicit and ROPC are prohibited.                                                                                                   |
| PKCE              | S256 required. `plain` not supported.                                                                                                                               |
| Client types      | First-party clients only in current scope. Confidential client authentication behavior must be verified per client type. Dynamic client registration not supported. |
| Token issuance    | Acme only. No surface other than Acme may issue tokens.                                                                                                             |
| Social linking    | `provider + uid/sub` as primary key. Email-based auto-linking prohibited.                                                                                           |
| Recovery passcode | Credential artifact, not bearer token. base58(32), ≈184-bit entropy, Argon2, single-use.                                                                            |
| TOTP replay       | Same-window replay prohibited (hardened, beyond RFC 6238 minimum).                                                                                                  |

## 3c. Informative / Reference Only

These are referenced for design rationale but do not create conformance obligations.

| Standard / RFC              | Use                                                                               |
| --------------------------- | --------------------------------------------------------------------------------- |
| RFC 9449 (DPoP)             | DPoP is opt-in infrastructure. Not mandatory for all clients.                     |
| RFC 8705 (mTLS client auth) | Not in current scope.                                                             |
| WebAuthn / FIDO2 (W3C)      | Passkey/passkey registration and authentication. Informative for ceremony design. |
| RFC 6238 (TOTP)             | Reference. Umaxica policy is stricter (same-window replay prohibited).            |
| NIST SP 800-63B             | Informative for AAL level discussion. Not a direct implementation contract.       |

## 3d. Not Claimed / Out of Scope

These are explicitly not part of the Umaxica identity profile. SIer proposals MUST NOT introduce
these without a new accepted ADR.

| Item                                                    | Status                                                                    |
| ------------------------------------------------------- | ------------------------------------------------------------------------- |
| RS256 signing                                           | Not claimed. Not supported.                                               |
| OIDC conformance certification (OP certification suite) | Not claimed. ES384-only profile is incompatible with default RS256 suite. |
| Dynamic client registration (RFC 7591)                  | Not in scope.                                                             |
| Device Authorization Grant (RFC 8628)                   | Not in scope.                                                             |
| CIBA (OpenID Connect Client-Initiated Backchannel Auth) | Not in scope.                                                             |
| Implicit grant                                          | Prohibited by profile.                                                    |
| Resource Owner Password Credentials                     | Prohibited by profile.                                                    |
| DPoP mandatory for all clients                          | Not claimed. Opt-in only.                                                 |
| Email-based social account auto-linking                 | Prohibited (NR-001).                                                      |

## 3e. Deferred

| Item                                          | Status                                                             |
| --------------------------------------------- | ------------------------------------------------------------------ |
| DPoP mandatory enforcement across all flows   | Deferred. Currently opt-in.                                        |
| `after_action :verify_authorized` enforcement | Deferred (FINDING-04, DEC-003).                                    |
| Self-service MFA reset UI                     | Deferred until DEC-009 prerequisites met.                          |
| Audit log DB-level immutability (ChainSeal)   | Deferred. Currently library-only. Short-term remediation required. |
| GQ-06: Telephone-only AAL1 classification     | Open. Decision pending.                                            |

---

# 4. OAuth / OIDC Protocol Profile

## 4a. Authorization Endpoint

- **Location:** Acme only (`/oauth/authorize`).
- **Grant type:** Authorization Code with PKCE. No other grant type is supported.
- **PKCE:** S256 required. `plain` not accepted.
- **State:** Required for CSRF protection.
- **Redirect URI:** Exact byte-for-byte match against pre-registered value. No partial, suffix, or
  scheme-mismatch variants accepted.
- **HTTP method:** GET required (POST not guaranteed).
- **SIer constraint:** MUST NOT implement or proxy this endpoint.

## 4b. Token Endpoint

- **Location:** Acme only (`/oauth/token`). Back-channel (server-to-server).
- **Transport:** HTTPS only. No browser session dependency.
- **null_session behavior:** If request context is null_session or required protocol context is
  absent, endpoint MUST return a deterministic OAuth error response (per RFC 6749 §5.2). No tokens
  may be issued. (NR-003, DEC-012)
- **Bearer in query string:** Prohibited. Access tokens MUST NOT appear in query strings.
- **HTTP 307 redirect:** Prohibited on flows that carry credentials.
- **Authorization code:** Single-use. `consumed_at` is set on first use. CODE_TTL = 10 seconds.
  Reuse returns error.
- **PKCE verifier:** Must accompany code exchange. Validated with `secure_compare`.
- **Redirect URI on exchange:** Must match the redirect_uri used in the authorization request.
- **SIer constraint:** MUST NOT implement, proxy, or introduce browser-session dependency.

## 4c. Token Issuance

- **Access token:** Signed JWT. ES384. Audience is surface-specific. Issued by Acme only.
- **Refresh token:** Digest-stored. Family-ID tracked. Rotation on use. Replay = compromise (family
  is revoked on replay detection). (ADR: `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`)
- **ID token:** Signed JWT. ES384. Audience bound to surface. Not accepted as bearer at userinfo.
- **DPoP binding:** Optional at issuance. If client provides DPoP proof, token is bound with
  `cnf.jkt`. Once bound, DPoP proof is required for all subsequent use of that token family.
- **Token TTLs (Palm surface, confirmed from code):**
  - access token: 5 minutes
  - refresh token: 30 days
  - idle timeout: 8 hours
  - Other surfaces: TTL constants defined in `app/services/security_token_lifetimes.rb`. SIer MUST
    NOT modify TTL constants.

## 4d. OIDC Discovery and JWKS

- **Discovery endpoint:** Acme only (`/.well-known/openid-configuration`). Served by BareController.
  Ignores `ri` (region identifier) parameter.
- **JWKS:** EC P-384 keys only (`kty=EC`, `crv=P-384`, `alg=ES384`, `use=sig`).
- **`id_token_signing_alg_values_supported`:** `["ES384"]`. No RS256.
- **Issuer:** `https://www.<surface-host>`. No query or fragment. No `ri` dependency.
- **Key hygiene:** Dev/test/fixture-marked keys are not published outside local Rails environments.
  Production requires deployable key identifiers.

## 4e. Userinfo Endpoint

- **Location:** Acme only (`/oauth/userinfo`).
- **Authentication:** Bearer access token only. No cookie/session fallback. ID tokens not accepted.
- **Scope gates:** `openid` required. `email` scope required for email/email_verified claims.
  `profile` scope required for name claim.
- **Error codes:** Missing/invalid token → 401 with `WWW-Authenticate: Bearer ...`. Insufficient
  scope → 403 with `WWW-Authenticate: Bearer error="insufficient_scope"`.

## 4f. Revocation and Logout

- **Revocation endpoint:** Acme (`/oauth/revoke`).
- **Logout endpoint:** Acme (`/oidc/logout`). UI completion returns to RP or surface-local
  `/sign/out/complete`.
- **Session revocation:** Palm logout revokes entire `refresh_token_family` and device session.
- **Revocation authority:** Acme only. UI on other surfaces initiates; Acme executes.

## 4g. Confidential Client Authentication

- Confidential client type authentication behavior must be verified per client type.
- Client authentication details are not fully consolidated in one document at this time. This is a
  known gap (GAP-NEW-002). SIer MUST NOT assume a specific client authentication method without
  verification against current Acme implementation.

---

# 5. Signing, JWKS, and ID Token Profile

## ES384-Only Private Profile

Umaxica signs all tokens with **ES384** (ECDSA using P-384 curve and SHA-384 digest).

| Property  | Value                    |
| --------- | ------------------------ |
| Algorithm | ES384                    |
| Curve     | P-384                    |
| Key type  | EC                       |
| Key use   | sig                      |
| RS256     | **Intentionally absent** |

**Why ES384 only?** All relying parties (Sign, Core, Base, Palm) are first-party and configured for
ES384. The broad-compatibility argument for RS256 does not apply to this closed first-party system.

**SIer and tool compatibility warning:** Third-party OIDC conformance test suites, SDKs, and reverse
proxies that require RS256 will not work with Umaxica without reconfiguration. SIer MUST NOT propose
introducing RS256 for tool convenience. If RS256 is genuinely required for a specific integration,
it must be implemented end-to-end (key rotation, JWKS publication, ID token signing selection,
client-assertion verification, and tests) under a new ADR — not merely advertised in metadata.

**OIDC conformance suite note:** The OpenID Connect OP certification suite expects RS256 support.
Umaxica does not pass this suite in its default configuration. This is intentional and acceptable
for a closed first-party system.

---

# 6. Token, Session, and Cookie Baseline

The authoritative detail is in `docs/vendor/identity/04_cookie-session-token-matrix.md`. This
section summarizes the binding constraints.

## 6a. Browser Auth Cookie

- Cookie name: `__Host-` prefixed (production).
- Attributes: `HttpOnly`, `Secure`, `SameSite=Strict`, no `Domain` attribute, `path=/`.
- Content: access token (JWT).
- SIer MUST NOT change cookie security attributes.
- SIer MUST NOT split or partially purge auth cookies.

## 6b. Session Cookie

- Cookie name: `__Host-session`.
- Attributes: `HttpOnly`, `Secure`, `SameSite=Lax`, partitioned (CHIPS) in production.
- `SameSite=Lax` (not Strict) is required to allow OIDC redirect flows to set the session cookie
  after a cross-site redirect.
- SIer MUST NOT change these attributes.

## 6c. Transparent Refresh (FAIL-CLOSED)

`transparent_refresh_access_token` is fail-closed. Any failure — including token expiry, revocation,
replay detection, Acme endpoint unreachable, malformed token, missing DPoP proof on a DPoP-bound
token, or idle timeout — triggers `clear_auth_cookies!`. All auth cookies are cleared atomically.
Partial purge is **prohibited**.

SIer MUST NOT modify transparent_refresh behavior or cookie purge logic.

## 6d. Session Limits (Acme-enforced)

| Surface        | Active | Restricted | Total |
| -------------- | ------ | ---------- | ----- |
| app (Client)   | 2      | 1          | 3     |
| com (Visitor)  | 1      | 1          | 2     |
| org (Operator) | 1      | 1          | 2     |

Session limit constants are Acme-owned. Changes require a new ADR. SIer MUST NOT patch, override, or
bypass session limit enforcement.

## 6e. Palm API Token Baseline

| Parameter         | Value                                                                       |
| ----------------- | --------------------------------------------------------------------------- |
| Access token TTL  | 5 minutes                                                                   |
| Refresh token TTL | 30 days                                                                     |
| Idle timeout      | 8 hours                                                                     |
| Token transport   | Bearer only                                                                 |
| DPoP support      | Not supported. DPoP-bound tokens (cnf.jkt present) are explicitly rejected. |
| Logout scope      | Entire `refresh_token_family` revoked on logout. Device session revoked.    |

SIer MUST NOT implement Palm API clients that send DPoP-bound tokens. SIer MUST NOT modify Palm
token TTL constants.

---

# 7. DPoP Profile

DPoP (RFC 9449 Demonstrating Proof of Possession) is **opt-in infrastructure**, not a mandatory
baseline for all clients.

## DPoP Design Principle

> DPoP is maintained as optional infrastructure. New flows must explicitly review and decide whether
> to adopt DPoP. The default for new flows is bearer unless DPoP is approved.

## DPoP Enforcement Map

| Endpoint / Surface                   | DPoP Status                                                                              |
| ------------------------------------ | ---------------------------------------------------------------------------------------- |
| Token endpoint (code exchange)       | Optional. Client opts in by including DPoP proof.                                        |
| Token endpoint (refresh)             | Required if token is DPoP-bound.                                                         |
| Userinfo endpoint                    | Optional for bearer; required if token is DPoP-bound.                                    |
| General resource server (Acme, Base) | Optional for bearer; required if DPoP-bound token is presented.                          |
| Palm API                             | **Not supported.** DPoP-bound tokens (cnf.jkt present) are explicitly rejected with 401. |
| Core browser API                     | **Not applicable.** Uses HttpOnly cookie + DBSC device binding instead.                  |

## DPoP Token Binding Rule

Once a token is DPoP-bound (`cnf.jkt` present in JWT claims), **all subsequent API calls** using
that token or its refreshed descendants require a valid DPoP proof. The client cannot downgrade a
DPoP-bound token to bearer.

## DPoP Proof Validation Requirements

When DPoP is used, the proof must include:

- `htm` (HTTP method) matching the request
- `htu` (HTTP URI) matching the request
- `iat` within the acceptable clock skew window
- `jti` (JWT ID) for replay protection
- `ath` (access token hash) when an access token is present

JTI replay protection is **stateful** for login and refresh endpoints (replay = compromise). It is
stateless for per-request API calls.

## DPoP and SIer

- SIer MAY implement DPoP-capable clients for non-Palm surfaces with explicit internal approval.
- SIer MUST NOT implement DPoP for Palm API clients.
- SIer MUST NOT assume DPoP is required without explicit per-flow review and approval.
- "DPoP mandatory" is NOT part of this RFI/RFP baseline unless separately approved by the internal
  architecture owner.

---

# 8. Credential Ceremony Baseline

## Authority Separation

| Boundary                | Rule                                                                                               |
| ----------------------- | -------------------------------------------------------------------------------------------------- |
| Ceremony UI             | Sign owns all authentication ceremony UI.                                                          |
| Authority               | Acme owns session authority, token issuance, and result processing.                                |
| Social callback         | Social provider callbacks land on Sign. Sign validates and sends a signed ceremony result to Acme. |
| Ceremony result handoff | One-shot signed JWT. Audience = Acme. SIer MUST NOT intercept, proxy, or alter this handoff.       |

## Social Identity Linking (NR-001)

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

SIer MUST NOT implement any social linking flow that uses email address as the linking key.

---

# 9. Authenticator and Credential Baseline

## Passkey / WebAuthn

- ES256 / ES384.
- Public Auth hosts must configure WebAuthn trusted origins in production. Relaxing origin
  constraints is prohibited.
- SIer MUST NOT modify challenge generation or origin validation.

## TOTP (NR-002)

```
A successfully accepted TOTP code MUST NOT be accepted again for the same credential
and ceremony purpose within the same time-step.
The system MUST distinguish verification failure from already-used replay.
Replay rejection MUST be audited.
The implementation SHOULD avoid permanent lockout caused by accidental duplicate submission.
```

Status: GQ-04 CLOSED (DEC-011). Hardened policy. SIer MUST implement replay detection if
implementing any TOTP flow.

## Recovery Passcode

| Property   | Value                                                                                 |
| ---------- | ------------------------------------------------------------------------------------- |
| Class      | Credential artifact (not bearer token)                                                |
| Generation | `SecureRandom.base58(32)` ≈ 184-bit entropy                                           |
| Storage    | Argon2 digest. Plaintext shown once at issuance. Never stored or logged in plaintext. |
| Use policy | Single-use (`uses_remaining=1`).                                                      |
| Stock      | Target=10, Minimum=2 per actor (top-up service).                                      |
| Rate limit | **[KNOWN GAP]** No rate limit or attempt lockout currently implemented.               |

SIer MUST NOT modify entropy or algorithm. SIer MUST NOT implement a recovery passcode flow without
rate limiting; if implementing, rate limiting specification must be reviewed and approved first
(DEC-005).

## MFA Reset

MFA reset UI is currently **DISABLED** (`create` action redirects with "reset_unavailable").
`docs/security/mfa-reset-account-recovery.md` describes the intended design (72h cooling, operator
approval), but this is not yet deployed as a user-facing UI.

SIer scope for MFA reset requires all five DEC-009 prerequisites to be met first:

1. Account Recovery Runbook
2. MFA Reset State Machine (all states, transitions, rejection paths)
3. Abuse Protection (cooling period, rate limit, operator approval workflow)
4. Audit Requirements (all event classes defined)
5. Acceptance Criteria (verifiable deliverables)

SIer MUST NOT enable or implement MFA reset UI without these prerequisites being reviewed and
approved by the internal architecture owner.

---

# 10. Authorization Baseline

## Framework

| Property                          | Value                                                                        |
| --------------------------------- | ---------------------------------------------------------------------------- |
| Policy framework                  | ActionPolicy 0.7.6                                                           |
| Authoritative guide               | `docs/authorization_guide.md` (ActionPolicy version)                         |
| Stale / non-authoritative         | `docs/spec/authorization_guide.md` (Pundit version — do not use)             |
| Default policy                    | `ApplicationPolicy`: all actions return `false` (deny-all)                   |
| Audience gating                   | Domain/audience gating enforced at policy layer                              |
| `enforce_access_policy!`          | Cannot be skipped (`skip_before_action` raises `SkipNotAllowedError`)        |
| `after_action :verify_authorized` | **DEFERRED** (FINDING-04, DEC-003). Risk owner: internal architecture owner. |

## SIer Authorization Requirements

- Every new controller action MUST call `authorize!`.
- Every new policy MUST have tests covering:
  - owner-allows case
  - non-owner-denies case
- Test coverage evidence for authorization is SIer's responsibility.
- SIer MUST NOT shadow ApplicationPolicy methods (see FINDING-01 for the exact failure mode).
- SIer MUST NOT use `permit!`, `skip_authorization`, or any authorization bypass.

---

# 11. Audit and Logging Baseline

## Current Chronicle State

| Control                        | Status                                                              |
| ------------------------------ | ------------------------------------------------------------------- |
| Audit system                   | Chronicle (application-level, purpose-built)                        |
| event_uuid                     | UNIQUE index. Duplicate prevention.                                 |
| Retention policies             | Implemented (ephemeral / security / compliance / permanent)         |
| Application-level sanitization | Implemented (tokens, cookies, OTP, passcodes removed from payloads) |
| DB-level immutability          | **Absent.** UPDATE/DELETE not prevented at DB level.                |
| ChainSeal (tamper-evidence)    | Library exists. **NOT production-deployed.**                        |

## NR-004: Audit Log Integrity Requirement (DEC-013)

```
Critical security audit events MUST be append-only at the application boundary.
Update/delete of critical audit events MUST be prevented or detectable.
Operator/admin access to audit records MUST be logged.
Audit event mutation, if technically possible, MUST leave independent evidence.
Token, cookie, OTP, passcode, private key, secret values MUST NOT be logged.
Audit retention and export policy MUST be documented.
```

**[BLOCKER]** DB-level immutability is currently absent. Application-level sanitization and
`event_uuid` UNIQUE alone are insufficient for NR-004. Remediation is required before production.

Remediation candidates (short-term): DB trigger blocking UPDATE/DELETE; separate append-only audit
table; restricted DB role with no DELETE privilege; hash chain/periodic digest; external log sink
replication.

Long-term hardening: ChainSeal production deployment.

## Minimum Critical Audit Event Class

Any SIer-implemented flow that touches the following MUST emit Chronicle audit events:

| Category             | Events                                                       |
| -------------------- | ------------------------------------------------------------ |
| Token lifecycle      | token_issued, token_refreshed, token_revoked                 |
| Session lifecycle    | session_created, session_revoked                             |
| Credential lifecycle | credential_created, credential_changed, credential_destroyed |
| MFA lifecycle        | mfa_enrolled, mfa_removed, mfa_reset                         |
| Social identity      | social_linked, social_unlinked                               |
| Recovery             | recovery_passcode_consumed                                   |
| Replay / abuse       | totp_replay_rejected                                         |
| Operator             | operator_action, privilege_change                            |

## Logging Prohibitions (Absolute)

The following MUST NEVER appear in application logs, audit logs, or error messages:

- Raw access token, refresh token, or ID token values
- Cookie values
- OTP codes
- Recovery passcode plaintext
- TOTP secrets
- Private key material
- Authorization headers verbatim
- Full request parameter payloads containing the above

---

# 12. Explicitly Not Claimed

The following capabilities are **not** part of the Umaxica identity baseline. SIer proposals that
include these will be rejected unless a separate ADR or architecture decision approves them.

| Capability                                 | Status                                                          |
| ------------------------------------------ | --------------------------------------------------------------- |
| Generic public OIDC provider compatibility | Not claimed. Closed first-party system.                         |
| RS256 / RS512 signing                      | Not supported. ES384 only.                                      |
| Third-party dynamic client registration    | Not in scope.                                                   |
| DPoP mandatory for all clients             | Not claimed. Opt-in only.                                       |
| Email-based social account auto-linking    | Prohibited (NR-001).                                            |
| OIDC conformance certification             | Not claimed. Private profile deviates from test suite defaults. |
| Self-service MFA reset (production)        | Not currently deployed. DEC-009 prerequisites required.         |
| Completed audit log immutability           | Not yet implemented. Short-term remediation required.           |
| Telephone-only AAL1 classification         | Open question (GQ-06). Decision pending.                        |
| Implicit grant                             | Prohibited.                                                     |
| Resource Owner Password Credentials grant  | Prohibited.                                                     |
| Device Authorization Grant                 | Not in scope.                                                   |
| CIBA                                       | Not in scope.                                                   |

---

# 13. Normative Requirements (NR-001 — NR-004, verbatim)

These requirements are binding on all SIer-implemented capability and on any internal implementation
that touches the affected boundary. They are reproduced here verbatim from the audit ledger (Round
4).

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

GQ-01 CLOSED for initial release (DEC-008). Future explicit linking = DEFERRED.

## NR-002: TOTP Replay Prevention

```
A successfully accepted TOTP code MUST NOT be accepted again for the same credential
and ceremony purpose within the same time-step.
The system MUST distinguish verification failure from already-used replay.
Replay rejection MUST be audited.
The implementation SHOULD avoid permanent lockout caused by accidental duplicate submission.
```

GQ-04 CLOSED (DEC-011). Hardened policy.

## NR-003: Token Endpoint null_session Behavior

```
Token endpoint MUST authenticate and validate the OAuth client / authorization code / PKCE
independently of browser session state.
If request context becomes null_session or lacks required protocol context, the endpoint
MUST return a deterministic OAuth error and MUST NOT issue tokens.
This behavior MUST be covered by request tests.
```

GQ-05 CLOSED (DEC-012). Fail-closed.

## NR-004: Audit Log Integrity

```
Critical security audit events MUST be append-only at the application boundary.
Update/delete of critical audit events MUST be prevented or detectable.
Operator/admin access to audit records MUST be logged.
Audit event mutation, if technically possible, MUST leave independent evidence.
Token, cookie, OTP, passcode, private key, secret values MUST NOT be logged.
Audit retention and export policy MUST be documented.
```

DEC-013. **[BLOCKER]** Implementation method not yet selected.

---

# 14. Conformance and Verification Strategy

## What "Conformance" Means for Umaxica

| Category                     | Approach                                                                                                                    |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| OAuth/OIDC protocol behavior | Verify against route contract tests and token/cookie matrix. Use standard OAuth tools where compatible with ES384.          |
| Private profile deviations   | Document each deviation (see §3b). Security vendor must verify Umaxica-specific behavior, not assume generic OIDC defaults. |
| Authorization model          | Verify ActionPolicy coverage. Confirm authorize! is called and deny-all default is effective.                               |
| Session/cookie security      | Verify `__Host-` prefix, SameSite, HttpOnly, Secure attributes against the cookie matrix.                                   |
| Audit log integrity          | Verify Chronicle event emission and identify immutability gap. Recommend remediation approach.                              |
| Transparent refresh          | Verify FAIL-CLOSED behavior under each failure condition in the failure taxonomy.                                           |
| Social linking               | Verify uid+provider primary key. Verify email_verified=false rejection. Confirm no email-matching path exists.              |
| TOTP replay                  | Verify same-window replay is rejected and audited.                                                                          |

## Route Contract Tests

Route contract tests exist at:

- `test/integration/routes/acme_route_contract_test.rb`
- `test/integration/routes/sign_route_contract_test.rb`
- `test/integration/routes/core_route_contract_test.rb`
- `test/integration/routes/base_route_contract_test.rb`
- `test/integration/routes/palm_route_contract_test.rb`
- `test/integration/routes/oidc_discovery_route_stability_test.rb`
- `test/integration/routes/route_target_contract_test.rb`

These are regression guards. SIer MUST NOT break these tests.

## Conformance Suite Compatibility Note

OpenID Foundation conformance tests require RS256 support. Umaxica does not provide RS256. Security
vendors should configure OIDC test tools to use ES384 or conduct targeted protocol verification
rather than running full conformance suites against standard defaults.

---

# 15. RFI / RFP Usage Warning

## RFI Stage

This document may be shared with SIer in RFI with the following conditions:

1. Share as `rfi-draft`. State clearly that this is not yet a finalized, owner-reviewed document.
2. Include the ⚠ Critical Framing Warning (§0) verbatim in any covering note.
3. `notes/oauth2-1-compliance-gap.md` **MUST NOT** be included in the RFI resource set. It is a
   stale non-authoritative note that describes a superseded AS attribution model. Seal before first
   SIer contact (DEC-001).
4. `docs/vendor/identity/08_threat-model.md` is shareable in RFI as **context only / not normative /
   subject to internal approval** (DEC-010).
5. `docs/spec/authorization_guide.md` **MUST NOT** be included. Use `docs/authorization_guide.md`
   (DEC-007).

## RFP Stage

Before using this document in an RFP:

1. `owner` must be a named person or team, not `internal-architecture-owner`.
2. `last-reviewed` must be updated to reflect the RFP review date.
3. `status` must be updated from `rfi-draft` to `rfp-approved` or equivalent.
4. `notes/oauth2-1-compliance-gap.md` must be updated or archived (DEC-002).
5. `08_threat-model.md` must have owner confirmed and internal review completed (DEC-010).
6. MFA reset prerequisites (DEC-009) must be met or formally deferred with owner acceptance.
7. Audit log integrity implementation method must be selected and documented (DEC-013).
8. `11_decision-register.md` and `12_gap-risk-register.md` must be updated with DEC-008~013.

---

# Related Documents

| Document                                                   | Relationship                                                          |
| ---------------------------------------------------------- | --------------------------------------------------------------------- |
| `docs/vendor/identity/01_responsibility_matrix.md`         | Capability ownership per component. Read together with this baseline. |
| `docs/vendor/identity/04_cookie-session-token-matrix.md`   | Full artifact-level detail for §6 (tokens, cookies, sessions).        |
| `docs/vendor/identity/07_social-linking-policy.md`         | NR-001 source document.                                               |
| `docs/vendor/identity/08_threat-model.md`                  | DRAFT. Context only in RFI. Not normative until owner-reviewed.       |
| `docs/vendor/identity/09_acceptance-criteria.md`           | Acceptance evidence requirements for SIer deliverables.               |
| `docs/architecture/dpop.md`                                | Authoritative DPoP design document.                                   |
| `docs/security/oidc-discovery-profile.md`                  | ES384 private profile rationale.                                      |
| `adr/acme-sign-core-base-port-boundary.md`                 | ADR confirming Acme as sole AS.                                       |
| `adr/security-audit-findings-2026-06-13.md`                | Security findings FINDING-01~04.                                      |
| `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md` | Refresh replay = compromise decision.                                 |
| `plans/umaxica-immutable-pinwheel.md`                      | Full audit ledger. DEC-001~~013 and NR-001~~004 originate here.       |
