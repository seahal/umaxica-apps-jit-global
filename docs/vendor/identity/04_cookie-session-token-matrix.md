---
title: Cookie, Session, and Token Matrix
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

Show who owns each browser/session/token/credential artifact, how it moves, its security attributes,
and which NR-004 critical audit events are bound to it.

# Scope

This matrix covers artifacts evidenced in the repository snapshot at Round 4 of the audit. Includes
Round 4 additions: DPoP-bound token lifecycle, Palm API token TTLs, `__Host-` cookie attributes,
transparent_refresh failure taxonomy, recovery passcode as credential artifact, per-surface session
limits, and NR-004 audit event bindings.

# Non-scope

Not a full cryptographic spec. Does not cover infrastructure-layer TLS or key management.

# Source Evidence

- `app/controllers/concerns/authentication_base.rb` (transparent_refresh, DPoP, cookie lifecycle)
- `app/controllers/concerns/authentication_cookie_store.rb` (set/clear auth cookies)
- `app/controllers/concerns/authentication_cookie_name.rb` (`__Host-` prefix logic)
- `app/controllers/concerns/session_limit_gate.rb` (session limits)
- `app/services/dpop_proof_validator.rb` (DPoP validation)
- `app/services/palm_access_token_authenticator.rb` (Palm bearer-only)
- `app/services/security_token_lifetimes.rb` (TTL constants)
- `app/models/concerns/secret_credential.rb` (recovery passcode)
- `app/services/recovery_passcode_top_up.rb` (TARGET=10, MINIMUM=2)
- `app/models/client_authorization_code.rb` (consumed_at, CODE_TTL=10s)
- `docs/security/session-token-authority.md`
- `docs/security/refresh-token-rotation.md`
- `docs/security/cookie-domain-scope.md`
- `docs/security/logout-sequence.md`
- `docs/security/sign-in-sequence.md`
- `docs/security/sign-up-sequence.md`
- `docs/security/social-callback-boundary.md`
- `docs/security/observability-boundary.md`
- `docs/architecture/dpop.md`
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `adr/security-audit-findings-2026-06-13.md`
- `plans/umaxica-immutable-pinwheel.md` (DEC-001~~013, NR-001~~004)

# Authority Decisions (current)

- Acme owns session and token authority.
- Sign may host UI and ceremony state, but not session/token/protocol authority.
- Cookie transport is host-local; transport ownership does not confer token authority.
- Revocation UI may exist on multiple surfaces; revocation authority is Acme.
- DPoP is opt-in infrastructure. Palm is bearer-only permanently (DEC-006).
- transparent_refresh is FAIL-CLOSED (failure triggers full auth cookie purge) (FACT-024).
- Session limit constants are Acme-owned. SIer MUST NOT change them without a new ADR.

# Column Definitions

| Column              | Meaning                                              |
| ------------------- | ---------------------------------------------------- |
| Artifact            | Named artifact type                                  |
| Class               | token / cookie / credential / ephemeral / state      |
| Owner               | Authority accountable for this artifact              |
| Issuer              | Which component creates/signs this artifact          |
| Consumer            | Which component validates/uses this artifact         |
| Storage/Transport   | Where it lives and how it moves                      |
| Lifetime            | Expiry policy                                        |
| Rotation            | When/how it is replaced                              |
| Revocation          | How it is invalidated before expiry                  |
| Purge Trigger       | What causes immediate removal                        |
| Replay Protection   | Control preventing reuse after first use             |
| SIer                | ✗ prohibited / read-only / IMPL allowed              |
| NR-004 Audit Events | Critical events bound to this artifact (see §NR-004) |
| Log Policy          | What MUST NOT be logged                              |
| Notes (Round 4)     | Round 4 additions or corrections                     |

---

# Section 1: Protocol Tokens (Acme-issued)

| Artifact                  | Class     | Owner  | Issuer       | Consumer                              | Storage/Transport                                          | Lifetime                                                                | Rotation                                                   | Revocation                                                   | Purge Trigger                                                                      | Replay Protection                                                                          | SIer           | NR-004 Audit Events                           | Log Policy                                                                                                                | Notes (Round 4)                                                                                                                             |
| ------------------------- | --------- | ------ | ------------ | ------------------------------------- | ---------------------------------------------------------- | ----------------------------------------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------ | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | -------------- | --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Authorization code        | token     | Acme   | Acme         | Core (RP code exchange)               | URL redirect (front-channel)                               | 10 seconds (CODE_TTL)                                                   | One-shot. `consumed_at` set on first use.                  | Consumed on use or TTL expiry                                | Callback completion, timeout                                                       | `consumed_at` check + TTL guard. Reuse → error.                                            | ✗              | —                                             | Do not log raw code value                                                                                                 | Single-use enforced by `consume!` + `consumed_at`. PKCE S256 required. Redirect URI exact match required.                                   |
| Access token (bearer)     | token     | Acme   | Acme         | Core, Base, Palm                      | Bearer header (API) or HttpOnly cookie (browser surface)   | Short-lived (5 min for Palm; surface-specific otherwise)                | Reissued via refresh endpoint                              | Acme revocation endpoint                                     | Expiry, refresh family revocation                                                  | Signature + audience validation. ES384 only.                                               | ✗              | `token_issued`, `token_revoked`               | Do not log raw token value                                                                                                | Palm: access=5min (SecurityTokenLifetimes). SIer MUST NOT modify TTL. Audience is surface-specific.                                         |
| Access token (DPoP-bound) | token     | Acme   | Acme         | Core, Base (DPoP-capable only)        | Bearer + DPoP proof header                                 | Same as bearer access token                                             | Reissued via refresh endpoint (DPoP proof required)        | Acme revocation endpoint                                     | Expiry, refresh family revocation                                                  | cnf.jkt bound. All subsequent calls require DPoP proof. Stateless JTI for per-request API. | ✗              | `token_issued`, `token_revoked`               | Do not log raw token or DPoP key                                                                                          | Palm REJECTS DPoP-bound tokens (cnf.jkt present → 401). Core browser API uses DBSC instead. Once DPoP-bound, DPoP proof is always required. |
| Refresh token             | token     | Acme   | Acme         | Acme refresh endpoint                 | HttpOnly host-local cookie (browser) or server-side (Palm) | 30 days (CLIENT_REFRESH_TOKEN_TTL for Palm; surface-specific otherwise) | Rotation on use. Old token invalidated. Family-ID tracked. | Acme: token family revocation (logout revokes entire family) | Replay detection, logout, idle timeout (8h for Palm), compromise                   | Family/reuse protection. Replay = compromise (ADR).                                        | ✗              | `token_issued` (new refresh), `token_revoked` | Do not log raw token value                                                                                                | Palm: refresh=30days, idle=8h. Refresh replay is treated as compromise and triggers family revocation.                                      |
| ID token                  | token     | Acme   | Acme         | RP callback (validation only)         | Browser redirect / RP validation                           | Protocol-defined short life                                             | Reissued per flow                                          | Expiry, callback completion                                  | State, nonce, claim validation                                                     | ✗                                                                                          | `token_issued` | Do not log raw token value                    | ES384 only. Not accepted as bearer credential at userinfo endpoint.                                                       |
| DPoP proof                | ephemeral | Client | OAuth Client | Acme token endpoint / resource server | HTTP header (`DPoP:`)                                      | Single HTTP request (iat + jti)                                         | Not applicable (one-shot)                                  | Expiry or JTI rejection                                      | JTI stateful for login/refresh (replay=compromise). Stateless for per-request API. | ✗                                                                                          | —              | Do not log DPoP proof payload                 | Ephemeral. Not stored. ath (access token hash) required when access token is present. `htm` and `htu` must match request. |

---

# Section 2: Browser Auth Cookies

| Artifact                             | Class  | Owner        | Issuer                      | Consumer                     | Storage/Transport                                                                                     | Lifetime                              | Rotation                        | Revocation                                                 | Purge Trigger                                                              | Replay Protection                         | SIer | NR-004 Audit Events                  | Log Policy                              | Notes (Round 4)                                                                                                                                                                               |
| ------------------------------------ | ------ | ------------ | --------------------------- | ---------------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------- | ------------------------------- | ---------------------------------------------------------- | -------------------------------------------------------------------------- | ----------------------------------------- | ---- | ------------------------------------ | --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `__Host-` auth cookie (access token) | cookie | Acme         | Acme / surface that sets it | Browser → surface controller | `__Host-` prefixed HttpOnly cookie. Production: Secure, no Domain attribute, path=/. SameSite=Strict. | Short-lived (access token TTL)        | Replaced on transparent refresh | Cleared on logout or purge. Entire set cleared atomically. | transparent_refresh failure (any failure type), logout, session revocation | Cookie binding + access token signature   | ✗    | `session_created`, `session_revoked` | Do not log cookie value or access token | `__Host-` prefix prevents subdomain theft. Partial purge is PROHIBITED — `clear_auth_cookies!` clears all auth cookies atomically. SameSite=Strict prevents CSRF cross-site submission.       |
| `__Host-session` cookie              | cookie | Surface host | Surface that sets it        | Browser → same surface       | `__Host-` prefixed HttpOnly cookie. Production: Secure, SameSite=Lax, partitioned (CHIPS).            | Browser session / configured lifetime | Rotated on auth events          | Cleared on logout or expiry                                | Logout, expiry                                                             | Session binding and reset on login/logout | ✗    | `session_created`, `session_revoked` | Do not log cookie value                 | SameSite=Lax (not Strict) to allow OIDC redirect flows. Partitioned in production (CHIPS). Distinct from auth cookie: auth cookie carries access token, session cookie carries Rails session. |

---

# Section 3: transparent_refresh — Failure Taxonomy

`transparent_refresh_access_token` is FAIL-CLOSED. Any failure triggers `clear_auth_cookies!`.
Partial purge is PROHIBITED. All auth cookies must be cleared atomically on failure.

| Failure Condition                                 | Result                                                  | Auth Cookie State    | Session State |
| ------------------------------------------------- | ------------------------------------------------------- | -------------------- | ------------- |
| Access token expired (valid refresh token exists) | Refresh attempt. On success: new access token + cookie. | Refreshed atomically | Maintained    |
| Refresh token expired or revoked                  | clear_auth_cookies!                                     | Cleared (all)        | Cleared       |
| Refresh token replay detected                     | clear_auth_cookies! (treat as compromise per ADR)       | Cleared (all)        | Cleared       |
| Refresh token family revoked (logout event)       | clear_auth_cookies!                                     | Cleared (all)        | Cleared       |
| Acme token endpoint unreachable / error           | clear_auth_cookies!                                     | Cleared (all)        | Cleared       |
| Malformed or invalid token in cookie              | clear_auth_cookies!                                     | Cleared (all)        | Cleared       |
| DPoP proof missing for DPoP-bound refresh token   | clear_auth_cookies!                                     | Cleared (all)        | Cleared       |
| Idle timeout exceeded                             | clear_auth_cookies!                                     | Cleared (all)        | Cleared       |

**SIer constraint:** SIer MUST NOT modify transparent_refresh behavior, failure handling, or cookie
purge logic.

---

# Section 4: Surface Sessions

| Artifact                   | Class | Owner        | Issuer | Consumer           | Storage/Transport                   | Lifetime                  | Rotation                          | Revocation                                          | Purge Trigger                                       | Replay Protection                    | SIer | NR-004 Audit Events                                                    | Log Policy                       | Notes (Round 4)                                                                                                                                                                                                                                                                                                              |
| -------------------------- | ----- | ------------ | ------ | ------------------ | ----------------------------------- | ------------------------- | --------------------------------- | --------------------------------------------------- | --------------------------------------------------- | ------------------------------------ | ---- | ---------------------------------------------------------------------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Acme (IdP) browser session | state | Acme         | Acme   | Browser, RP flows  | Host-local cookie/session transport | Session lifetime          | Rotation on auth events           | Acme                                                | Logout, expiry, compromise, session limit exceeded  | Session binding and reset            | ✗    | `session_created`, `session_revoked`                                   | Do not log raw session           | Session limit enforced by Acme. SIer MUST NOT bypass.                                                                                                                                                                                                                                                                        |
| Core BFF session           | state | Core         | Core   | Browser ↔ Core BFF | Host-local cookie/session transport | BFF session lifetime      | Refreshed via transparent_refresh | Acme for token revocation; Core for session reset   | Logout, expiry, transparent_refresh failure         | Session reset + token validation     | IMPL | `session_created`, `session_revoked`                                   | Do not log raw tokens or cookies | Token authority is Acme. Core session is transport mechanism, not authority.                                                                                                                                                                                                                                                 |
| Base session               | state | Base         | Base   | Browser ↔ Base     | Host-local cookie/session transport | BFF session lifetime      | No direct rotation evidence       | Acme for authoritative token revocation             | Logout, expiry, credential/authenticator transition | Session reset + token validation     | IMPL | `session_created`, `session_revoked`, `credential_security_transition` | Do not log raw tokens or cookies | Token authority is Acme. Base session is transport only. Credential-equivalent changes retain the current session by default, revoke other actor sessions, and clear step-up freshness. Password rotation is disabled for this release (`403 Forbidden`) and remains a blocker for any release that exposes the rotation UI. |
| Sign UI session            | state | Sign UI host | Sign   | Browser            | Host-local cookie/session transport | Ceremony session lifetime | Not token authority               | Not token authority                                 | Logout, expiry, ceremony cleanup                    | Browser session reset on events      | IMPL | —                                                                      | Do not log raw session           | Sign is ceremony UI only. Not session/token authority.                                                                                                                                                                                                                                                                       |
| Palm API session           | state | Palm         | Palm   | Palm native/API    | Server-side (no browser cookie)     | idle=8h; refresh=30days   | On token refresh                  | Acme: entire refresh_token_family revoked on logout | Palm logout, idle timeout, compromise               | Token validation + replay protection | IMPL | `session_created`, `session_revoked`                                   | Do not log raw tokens            | Palm uses bearer token only. No browser cookie. Palm logout revokes entire refresh_token_family. DPoP-bound tokens rejected at Palm.                                                                                                                                                                                         |

---

# Section 5: Session Limits (Acme-enforced)

Session limits are invariants enforced by Acme. SIer MUST NOT change these constants. Changes
require a new ADR.

| Surface        | Active Sessions | Restricted Sessions | Total | Authority |
| -------------- | --------------- | ------------------- | ----- | --------- |
| app (Client)   | 2               | 1                   | 3     | Acme      |
| com (Visitor)  | 1               | 1                   | 2     | Acme      |
| org (Operator) | 1               | 1                   | 2     | Acme      |

**Restricted session:** A session that has exceeded the active limit is downgraded to restricted.
The user must resolve (sign-in limitation UI) before full access is restored.

**SIer constraint:** Session limit constants are defined in Acme. SIer MUST NOT patch, override, or
bypass session limit enforcement. The sign-in limitation UI (sign/in/limitations_controller.rb in
WORKTREE) is a hosted UI surface only; Acme owns the enforcement authority.

---

# Section 6: Credential Artifacts

| Artifact             | Class      | Owner | Issuer                       | Consumer                   | Storage/Transport                                                         | Lifetime                                                                          | Rotation                                          | Revocation                                             | Purge Trigger                                                                       | Replay Protection                                                                                                         | SIer                               | NR-004 Audit Events                                                         | Log Policy                                                                                                                         | Notes (Round 4)                                                                                                                                                                                                         |
| -------------------- | ---------- | ----- | ---------------------------- | -------------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------- | ------------------------------------------------------ | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Recovery passcode    | credential | Acme  | Acme                         | User → Sign ceremony       | Server-side. Argon2 digest stored. Plaintext shown once at issuance only. | Single-use (uses_remaining=1). Replaced by top-up service (TARGET=10, MINIMUM=2). | Top-up: new passcodes issued when stock < MINIMUM | Consumed on first successful use. Acme can revoke all. | Expiry, account deletion                                                            | `uses_remaining` decrement + Argon2 verification. **[KNOWN GAP: no rate limit / attempt lockout]**                        | ✗                                  | `recovery_passcode_consumed`, `credential_created`, `credential_destroyed`  | Do not log raw passcode value. Plaintext MUST NOT be logged or stored after display.                                               | **[BLOCKER]** No rate limit / attempt lockout (DEC-005, GAP-NEW-001). 184-bit entropy + Argon2 are current controls. Abuse protection required before production. SIer MUST NOT modify generation entropy or algorithm. |
| TOTP secret          | credential | Acme  | Sign (enrollment)            | Sign ceremony              | Server-side encrypted storage                                             | Valid until removed by user or MFA reset                                          | Replaced on re-enrollment                         | Removed on account action or MFA reset                 | User removal, MFA reset                                                             | Same-window replay PROHIBITED (DEC-011, NR-002). accepted time-step MUST NOT be reused. Replay rejection MUST be audited. | ✗                                  | `mfa_enrolled`, `mfa_removed`, `credential_created`, `credential_destroyed` | Do not log TOTP code or secret                                                                                                     | GQ-04 CLOSED. Hardened policy. SIer MUST implement replay detection if implementing TOTP flow.                                                                                                                          |
| Passkey credential   | credential | Acme  | Sign (WebAuthn registration) | Sign ceremony              | Server-side (public key). Browser: authenticator.                         | Until user removes or authenticator loses key                                     | Not rotated; replaced on re-registration          | User removal or MFA reset                              | User removal, MFA reset, account compromise                                         | WebAuthn challenge uniqueness. Public Auth hosts configure trusted origins in production.                                 | ✗                                  | `mfa_enrolled`, `mfa_removed`, `credential_created`, `credential_destroyed` | Do not log private key or assertion                                                                                                | ES256/ES384. SIer MUST NOT relax WebAuthn origin constraints. SIer MUST NOT modify ceremony challenge generation.                                                                                                       |
| Social identity link | credential | Acme  | Acme (on social callback)    | Acme (identity resolution) | Server-side (uid + provider + sub)                                        | Until explicitly removed                                                          | Not rotated                                       | User removal, account compromise                       | uid+provider primary key. email_verified=false rejected. Email matching PROHIBITED. | ✗                                                                                                                         | `social_linked`, `social_unlinked` | Do not log raw social token or assertion                                    | NR-001. GQ-01 CLOSED. Future explicit linking requires authenticated session + user action + audit + conflict handling + rollback. |

---

# Section 7: Ceremony and Flow State

| Artifact                    | Class | Owner                             | Issuer                                    | Consumer                      | Storage/Transport                             | Lifetime                 | Rotation                            | Revocation                               | Purge Trigger                      | Replay Protection                                                                     | SIer | NR-004 Audit Events                            | Log Policy                     | Notes (Round 4)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| --------------------------- | ----- | --------------------------------- | ----------------------------------------- | ----------------------------- | --------------------------------------------- | ------------------------ | ----------------------------------- | ---------------------------------------- | ---------------------------------- | ------------------------------------------------------------------------------------- | ---- | ---------------------------------------------- | ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| OIDC state parameter        | state | RP surface                        | RP surface                                | RP callback                   | URL redirect parameter + session              | Flow lifetime            | Recreated per authorization attempt | RP surface / Acme flow                   | Callback success, timeout, cancel  | State validation                                                                      | IMPL | —                                              | Do not log raw state           | Exact storage host varies by RP surface.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| OIDC nonce                  | state | RP surface                        | RP surface                                | RP callback                   | URL redirect parameter + session              | Flow lifetime            | Recreated per flow                  | RP surface / Acme flow                   | Callback success, timeout, cancel  | Nonce validation                                                                      | IMPL | —                                              | Do not log raw nonce           | Exact storage host varies by RP surface.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| OTP challenge               | state | Sign                              | Sign ceremony host                        | Browser                       | HTML form + short-lived server-side state     | Short-lived              | Reissued on resend                  | Ceremony host / Acme commit path         | Success, expiry, cleanup           | Attempt count + expiry checks                                                         | IMPL | —                                              | Do not log OTP code            | Vendor delivery provider not specified here.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| WebAuthn challenge          | state | Sign                              | Sign ceremony host                        | Browser authenticator         | Challenge state + browser ceremony            | Short-lived              | Reissued per ceremony               | Ceremony host / Acme commit path         | Success, expiry, cleanup           | Challenge uniqueness + replay checks                                                  | IMPL | —                                              | Do not log challenge value     | Exact storage host not fully centralized in one doc.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Social provider state       | state | Sign                              | Sign / provider flow                      | Browser / provider callback   | OAuth/OIDC state parameter + callback session | Flow lifetime            | Reissued per attempt                | Ceremony host / Acme commit path         | Success, expiry, cancel            | Callback state + provider assertion validation                                        | IMPL | `social_linked`, `social_unlinked` (on commit) | Do not log raw state/assertion | Provider-specific storage details not fully centralized.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Ceremony candidate / result | state | Sign (producer) / Acme (consumer) | Sign                                      | Acme commit path              | Short-lived ceremony storage                  | Short-lived (one-shot)   | Recreated per attempt               | Acme commit path                         | Success, cancel, cleanup           | One-shot ceremony result signed JWT. audience=Acme.                                   | ✗    | —                                              | Do not log raw ceremony state  | Signed ceremony result handoff is SIer PROHIBITED. Acme consumes and discards.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Session limitation state    | state | Acme                              | Acme                                      | Browser / RP flow             | Server-side ceremony state                    | Short-lived              | Recreated if user retries           | Acme                                     | Resolution, timeout, completion    | State-bound limitation handling                                                       | ✗    | `session_revoked` (on resolution)              | Do not log raw state           | Per-surface session limits enforced by Acme (see §Session Limits). SIer MUST NOT modify.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| CSRF token                  | state | Surface host                      | Surface host                              | Browser form submit           | Meta/header + form transport                  | Session or form lifetime | Reissued as needed                  | Surface host                             | Session end, form completion       | `Sec-Fetch-Site`, exact trusted origins, and real session-bound legacy token fallback | IMPL | `auth.csrf.rejected` (taxonomy follow-up)      | Do not log raw CSRF value      | `skip_forgery_protection` is prohibited for session-backed application endpoints. Base app/com/org trust only their own surface host by default; cross-surface browser protocol endpoints declare exact trusted origins locally. Trusted origins are exact scheme/host/port matches; suffix, scheme, and port confusion are rejected. A `same-site` unsafe request without `Origin` is rejected. Missing `Sec-Fetch-Site` falls back only to a valid same-session Rails authenticity token. OAuth token exchange, Apple Server Notifications, and OIDC backchannel logout use `ActionController::API` without the browser session CSRF stack and enforce their protocol-specific client or signed-message validation. CSP report intake is the sole explicit create-only CSRF exception and remains bounded, sanitized, rate-limited, unauthenticated telemetry. JSON CSRF rejects return `403 Forbidden`. |
| Preference cookies / tokens | state | Surface host                      | Surface host; Acme for authoritative data | Browser + surface controllers | JS-readable mirrors + host-local transport    | Preference lifetime      | Reissued on preference change       | Surface host / Acme preference authority | Preference reset or account change | CSRF + host scoping                                                                   | IMPL | —                                              | Do not log secrets or tokens   | Exact surface-by-surface scope not centralized.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |

---

# Section 8: MFA Reset Artifact (BLOCKED)

| Artifact                | Class | Owner | Issuer | Consumer        | Storage/Transport                | Lifetime | Rotation    | Revocation                      | Purge Trigger                        | Replay Protection                        | SIer                | NR-004 Audit Events            | Log Policy                   | Notes (Round 4)                                                                                                                                                                                                                                                                       |
| ----------------------- | ----- | ----- | ------ | --------------- | -------------------------------- | -------- | ----------- | ------------------------------- | ------------------------------------ | ---------------------------------------- | ------------------- | ------------------------------ | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| MFA reset token / state | state | Acme  | Acme   | Operator + User | Server-side (72h cooling period) | 72 hours | Not rotated | Acme (on approval or rejection) | Approval, rejection, timeout, expiry | 72h cooling + operator approval required | IMPL (when enabled) | `mfa_reset`, `operator_action` | Do not log reset token value | **[BLOCKER]** MFA reset UI is currently DISABLED (DEC-009). Five prerequisites must be met before UI enablement: Runbook, State Machine, Abuse Protection, Audit Requirements, Acceptance Criteria. This row describes the intended design; current production state has UI disabled. |

---

# Section 9: NR-004 Audit Event Binding

All critical security audit events MUST be append-only at the application boundary (NR-004,
DEC-013).

**[BLOCKER]** Chronicle DB currently has NO database-level immutability constraints. `event_uuid`
UNIQUE index and application-level sanitization are implemented, but update/delete at DB level is
not prevented. Remediation required before production (GAP-002 / RSK-003).

**Short-term candidates:** DB trigger blocking update/delete; restricted DB role with no delete
privilege; separate append-only audit table; hash chain / periodic digest; external log sink.

**Long-term:** ChainSeal production deployment.

## Minimum Event → Artifact Binding

| Event                        | Bound Artifact(s)                                    | Notes                                                         |
| ---------------------------- | ---------------------------------------------------- | ------------------------------------------------------------- |
| `token_issued`               | Access token, refresh token, ID token                | Emitted on every issuance.                                    |
| `token_refreshed`            | Refresh token (rotation event)                       | Old token invalidated at same time.                           |
| `token_revoked`              | Access token, refresh token                          | Includes family revocation on logout.                         |
| `session_created`            | Auth cookie, surface session                         | Emitted on login / transparent_refresh success.               |
| `session_revoked`            | Auth cookie, surface session, limitation state       | Emitted on logout, limit exceeded, compromise.                |
| `recovery_passcode_consumed` | Recovery passcode                                    | Emitted on every successful consumption. Single-use enforced. |
| `credential_created`         | TOTP secret, passkey, social link, recovery passcode | Emitted on enrollment or generation.                          |
| `credential_changed`         | Any credential update                                | Emitted on re-enrollment or modification.                     |
| `credential_destroyed`       | Any credential removal                               | Emitted on user removal or account action.                    |
| `mfa_enrolled`               | TOTP, passkey                                        | Subset of credential_created; explicit MFA context.           |
| `mfa_removed`                | TOTP, passkey                                        | Subset of credential_destroyed; explicit MFA context.         |
| `mfa_reset`                  | MFA reset state (when enabled)                       | Operator-approved. 72h cooling.                               |
| `social_linked`              | Social identity link                                 | uid+provider binding created.                                 |
| `social_unlinked`            | Social identity link                                 | uid+provider binding removed.                                 |
| `operator_action`            | Any artifact modified by operator/support            | Includes admin lock/unlock, account recovery override.        |
| `privilege_change`           | Surface session or authorization context             | Emitted on role or permission change.                         |
| `totp_replay_rejected`       | TOTP challenge                                       | Replay rejection (NR-002). Must be audited.                   |

---

# Contradictions (unchanged from original + Round 4 additions)

- `docs/security/logout-sequence.md` shows Sign, Core, and Base as logout ceremony hosts, while
  `docs/security/session-token-authority.md` makes Acme the session authority. The matrix treats the
  former as UI hosting and the latter as authority. **No change from original.**

- `notes/oauth2-1-compliance-gap.md` describes "sign.\* as AS." This is stale non-authoritative
  documentation. The current authority is `adr/acme-sign-core-base-port-boundary.md` (Acme = AS). Do
  not use notes/oauth2-1-compliance-gap.md as a source for this matrix. (DEC-001/002)

# Open Questions (Round 4 updated)

| ID    | Question                                                                                                                                  | Status                                     |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| GQ-06 | Whether telephone OTP alone qualifies as AAL1 for all ceremony purposes                                                                   | OPEN                                       |
| —     | Exact per-surface access token TTL outside Palm (Palm=5min confirmed; app/com/org TTLs should be verified against SecurityTokenLifetimes) | Needs verification                         |
| —     | Whether Core and Base sessions use host-local Rails session or an independent store                                                       | Partially evidenced; not fully centralized |
| —     | Whether all challenge types (OTP, WebAuthn) are stored in the same Rails session or separate cache                                        | Not evidenced in one document              |
| —     | DPoP opt-in adoption process for new flows (who approves, what gates the decision)                                                        | Undocumented                               |

# Related Documents

- `docs/vendor/identity/01_responsibility_matrix.md` (supersedes 02 capability section)
- `docs/vendor/identity/02_responsibility-boundary.md` (simplified predecessor)
- `docs/vendor/identity/05_authentication-flow-inventory.md`
- `docs/vendor/identity/06_failure-taxonomy.md`
- `docs/vendor/identity/09_acceptance-criteria.md`
- `docs/security/session-token-authority.md`
- `docs/security/refresh-token-rotation.md`
- `docs/architecture/dpop.md`
- `plans/umaxica-immutable-pinwheel.md`
