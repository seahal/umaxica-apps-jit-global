---
title: Identity Threat Model
status: draft
audience:
  - SIer
  - security-vendor
  - internal-architecture
  - implementation-team
owner: TBD
last-reviewed: TBD
source-of-truth: current-repository-evidence
confidentiality: internal-vendor-shareable
---

> **DRAFT — CONTEXT ONLY — NOT NORMATIVE** Owner: TBD. Review: not completed. This document must not
> be cited as a normative requirement. Include in vendor packages only with an explicit "context
> only" cover note.

# Purpose

Provide an initial threat model for vendor and security review.

# Scope

This model focuses on identity and control-plane threats visible in the repository snapshot.

# Non-scope

This is not a complete enterprise threat model.

# Source Evidence

- `docs/security/session-token-authority.md`
- `docs/security/refresh-token-rotation.md`
- `docs/security/logout-sequence.md`
- `docs/security/social-callback-boundary.md`
- `docs/security/turnstile.md`
- `docs/security/security-headers.md`
- `docs/security/observability-boundary.md`
- `docs/security/cookie-domain-scope.md`
- `docs/security/sign-in-sequence.md`
- `docs/security/sign-up-sequence.md`

# Protected Assets

- User sessions
- Refresh token families
- Access and ID tokens
- OAuth authorization codes
- RP callback state and nonce values
- Ceremony state
- Social identity bindings
- Passkey and OTP challenge state
- Session-limit state
- Audit and security records
- Browser cookie transport

# Trust Boundaries

- Browser to application server
- Browser to external social provider
- RP surface to Acme Authorization Server
- UI host to authority host
- Cookie transport to server-side token/session validation
- Audit logging to durable security records
- Application logs to non-authoritative operational diagnostics

# Threat Actors

- External attacker
- Automated bot or credential-stuffing actor
- Malicious or confused legitimate user
- Compromised browser session
- Compromised provider account
- Compromised operator
- Insider with limited operational access

| Threat                            | Target Asset                   | Entry Point                                      | Existing Controls                                                         | Missing / Open Controls                                      | Detection                               | Response                                     | Severity |
| --------------------------------- | ------------------------------ | ------------------------------------------------ | ------------------------------------------------------------------------- | ------------------------------------------------------------ | --------------------------------------- | -------------------------------------------- | -------- |
| Account takeover                  | User session, tokens           | Sign-in, social login, OTP, passkey              | Session/token authority separation, Turnstile, rate limits, step-up flows | Exact per-flow brute-force hardening is not centralized here | Audit logs, failure telemetry           | Reject, lock, require step-up or re-auth     | High     |
| Social account linking takeover   | Social identity binding        | Social callback / linking UI                     | Explicit linking policy, provider subject as key                          | Full test matrix for edge cases                              | Linking audit events                    | Fail closed or require safe confirmation     | High     |
| Authorization code replay         | OAuth code                     | RP callback                                      | RP callback validation, protocol state handling                           | Exact replay storage details not centralized                 | Callback failures, replay signals       | Reject callback and restart auth             | High     |
| Token replay                      | Access token, refresh token    | API, refresh path                                | Refresh rotation, family revoke, signature/audience validation            | Exact cross-surface replay visibility                        | Token failure telemetry                 | Revoke, quarantine, require re-auth          | High     |
| Refresh token theft/reuse         | Refresh token family           | Cookie theft, server compromise                  | Rotation and family revoke                                                | Exact binding controls per surface                           | Reuse detection                         | Revoke family, clear cookies, step-up        | High     |
| Session hijack                    | Browser session                | Cookie theft, XSS, browser compromise            | Host-only cookie transport, session reset on login/logout                 | Session theft detection beyond basic logging                 | Session anomaly signals                 | Revoke session, invalidate related tokens    | High     |
| Session fixation                  | Browser session                | Login boundary                                   | `reset_session` on login/logout in sequence docs                          | Residual fixation exposure in compatibility paths            | Login boundary audit                    | Regenerate session, reject stale state       | High     |
| Login CSRF                        | Auth session commitment        | Login forms / RP flows                           | CSRF protection, browser-origin checks                                    | Exact flow coverage for every mutation is not centralized    | CSRF failures                           | Reject request                               | High     |
| Standard CSRF                     | Session or credential mutation | Browser forms                                    | CSRF defense and same-origin form handling                                | Some routes may need explicit review if added                | CSRF telemetry                          | Reject and preserve state                    | High     |
| XSS/CSP bypass                    | Browser session, tokens        | Browser-rendered pages                           | CSP, Permissions-Policy, output encoding patterns                         | Exact CSP coverage for every page not summarized here        | CSP violation reports                   | Block, investigate, rotate if needed         | High     |
| Open redirect                     | Return targets                 | Login/logout completion and RP redirect handling | Safe return-target decisions and route contracts                          | Exact allowlist is not consolidated here                     | Redirect anomaly logs                   | Reject unsafe target                         | Medium   |
| OAuth mix-up                      | OAuth code / tokens            | RP authorization/callback mismatch               | RP-local callback validation and discovery stability                      | Exact client registry details not centralized                | Callback validation failure             | Reject and restart auth                      | High     |
| redirect_uri abuse                | OAuth authorization endpoint   | `/oauth/authorize`                               | Acme authority, route contract coverage                                   | Exact runtime policy details not centralized here            | Authorization failure signals           | Reject request                               | High     |
| OTP brute force                   | OTP challenge                  | OTP form submission                              | Turnstile, rate limiting, lockout, expiry                                 | Exact attempt counts per flow vary                           | OTP failure telemetry                   | Lock, expire, require restart                | High     |
| OTP enumeration                   | Account/contact state          | OTP entry points                                 | Safe failure copy, flow separation                                        | Full copy review required per surface                        | Failure pattern analysis                | Return generic safe next step                | Medium   |
| passkey/WebAuthn challenge replay | WebAuthn challenge             | Browser authenticator flow                       | Short-lived challenge state and ceremony boundary                         | Exact replay store is not centralized                        | Challenge mismatch telemetry            | Reject and reissue challenge                 | High     |
| credential stuffing               | Sign-in forms                  | Browser sign-in routes                           | Turnstile, rate limits, session limits                                    | Exact provider-specific throttles may vary                   | Failure spikes, challenge spikes        | Throttle, lock, challenge, revoke            | High     |
| rate-limit bypass                 | High-volume auth endpoints     | Repeated requests                                | Rate limiting and edge controls                                           | Cross-surface consistency not fully documented here          | Request rate telemetry                  | Throttle or block                            | High     |
| social provider outage            | Social login/signup            | Social callback / provider redirect              | Flow-specific fallback and cancel paths                                   | Exact UX for outages may vary                                | Provider callback failures              | Offer restart or alternate factor            | Medium   |
| email/SMS provider outage         | OTP delivery                   | OTP resend / challenge delivery                  | Flow-specific resend and timeout behavior                                 | Vendor-specific delivery resiliency not centralized          | Delivery failures                       | Retry or alternate factor                    | Medium   |
| signing key compromise            | OIDC/OAuth signing keys        | Authority host compromise                        | Key rotation docs and JWT authority separation                            | Incident-specific runbook is fragmented                      | Signature failures, key rotation events | Rotate keys, invalidate impacted tokens      | Critical |
| stale JWKS/key rotation           | JWKS / discovery               | RP validation                                    | Discovery route stability test                                            | Rollback and distribution timing not centralized here        | Validation failures                     | Refresh metadata, rotate, reject stale trust | High     |
| compromised operator              | Administrative actions         | Settings, support, revocation                    | Role separation and explicit routes                                       | Operator action runbook missing in vendor package            | Audit records, operator logs            | Revoke privileges, investigate               | High     |
| log leakage                       | Application logs               | Logs, debug output                               | Logging boundary guidance, no raw token logging                           | Consistent redaction enforcement across all call sites       | Log scanning                            | Redact, rotate exposed secrets               | High     |
| PII leakage                       | Logs, pages, callbacks         | UI and diagnostics                               | Safe failure copy, logging boundary                                       | Exact field allowlist not centralized here                   | DLP / review                            | Remove sensitive output, notify if required  | High     |
| IDOR/BOLA/authorization bypass    | Session and resource access    | UI, API, RP routes                               | Pundit and authority boundaries                                           | Full route-by-route authorization review not in this package | Authorization failure logs              | Deny and audit                               | High     |
| tenant/surface boundary confusion | Cross-surface requests         | Shared vocabulary and redirects                  | Surface separation in routes and docs                                     | Historical vocabulary can mislead reviewers                  | Unexpected cross-host requests          | Reject and document                          | Medium   |

# Missing / Open Controls

- Consolidated incident/key rotation/rollback runbook for identity is not yet part of this vendor
  package.
- Exact route-by-route control coverage is distributed across docs and tests rather than
  centralized.
- Some controls are documented as current practice, but not every one has a single canonical
  evidence file.

# Detection and Logging Expectations

- Record security-relevant events in durable audit/security records where the repository already
  does so.
- Do not rely on application logs as the authoritative record for identity events.
- Do not log raw tokens, cookies, or sensitive challenge values.

# Response Expectations

- Fail closed on ambiguous or invalid identity evidence.
- Revoke or quarantine impacted session/token families when replay or compromise is detected.
- Offer safe next actions to legitimate users without exposing attacker-useful details.

# Open Questions

- Whether the package should later be expanded with per-incident operational playbooks.

# Related Documents

- `docs/vendor/identity/04_cookie-session-token-matrix.md`
- `docs/vendor/identity/06_failure-taxonomy.md`
- `docs/vendor/identity/09_acceptance-criteria.md`
