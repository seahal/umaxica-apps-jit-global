# OWASP ASVS 5.0 checklist review

Date: 2026-09-19
Branch: `feature` (HEAD `88fee5d5f` plus uncommitted avatar-group and ceremony-hardening changes)

## Method and limits

A static review against every ASVS 5.0 chapter (V1–V17), at section level. Each section was checked
by reading the code that owns it and by targeted searches. The review targeted Levels 1 and 2 and
did not score Level 3 requirements individually.

- `bundle exec brakeman` 8.0.6: 0 warnings, no `config/brakeman.ignore`.
- `bundle exec bundle-audit check --update` (advisory DB 2026-09-16, 1245 advisories): no findings.
- No dynamic testing (DAST), penetration testing, or production/deployment configuration was
  inspected. Items that depend on deployment values are marked **Deploy-check**.
- 859 controllers exist; not every controller was read line by line. A **Pass** means that the
  owning mechanism was read and sampled call sites were consistent with it.

Status legend: **Pass**, **Finding** (see below), **Deploy-check**, **N/A**, **Not verified**.

## Findings

| ID | Severity | ASVS | Summary |
|---|---|---|---|
| F1 | Medium (confirm intent) | 8.2, 8.3 | `GroupAvatarMembershipsController#create` attaches any active avatar by `avatar_public_id`; `GroupAvatarMembershipPolicy#create?` checks only that the group belongs to the selected account, not the avatar owner's consent or block state. `role` accepts any string. |
| F2 | Medium | 15.2 | `rails` (8.2.0.alpha), `propshaft`, `flipper`, `flipper-active_record`, and `flipper-ui` are sourced from GitHub `main`. Advisory databases do not cover unreleased revisions, so `bundle-audit` gives no assurance for these gems. Risk accepted for Rails until the 8.2 release (`adr/git-sourced-rails-advisory-risk-acceptance.md`). |
| F3 | Low | 12.3, 13.2 | `config/database.yml` requires `NEON_PGSSLMODE` in production but accepts any value, including `disable`. `Umaxica::Valkey::ResponsibilityUrls` accepts plaintext `redis://`. Transport security depends entirely on deployment values. |
| F4 | Low | 6.5.5 | Email and SMS OTP lifetime is 12 minutes (`SignOtpCeremony::OTP_EXPIRATION_MINUTES`, `SignTelephoneOtpDelivery`); ASVS 5.0 expects out-of-band codes to expire within 10 minutes. |
| F5 | Low | 3.4 | CSP `style-src` and `style-src-elem` allow `https:` in addition to nonces, which permits stylesheets from any HTTPS origin. |
| F6 | Low (availability) | 8.3, 16.5 | Six controllers (`base/{app,com,org}/welcomes`, `auth/{app,com,org}/sign/in/checks`) gate with `allowed_to?`, which does not satisfy `verify_authorized`; the render path raises `UnauthorizedAction` (HTTP 500). Fail-closed; already tracked by in-code TODOs. |
| F7 | Info | 13.4 | Unauthenticated MCP endpoints (`base/*/mcps#create`, `side/*/mcps#create`) disclosed the deployment revision. Resolved 2026-09-19: MCP routes withdrawn (`adr/mcp-endpoint-withdrawal.md`). `GET /revision` is an accepted disclosure. |
| F8 | Low–Medium (revised) | 6.3, 11.5 | Passkey `allowCredentials` padding can be told apart from real credentials: dummies change on every request and are always 43 characters. Account existence with a passkey is therefore disclosed on app and com. Detail: `2026-09-19-passkey-allow-credentials-enumeration-P3W6.md`. |
| F9 | Medium | 6.3 | Email sign-in and sign-up disclose account existence across sessions: a server-side cooldown applies only to registered (sign-in, 30 s) or unregistered (sign-up, 10 s) addresses, while the uniform cooldown is stored in the client session. Reproduced on app. Detail: `2026-09-19-account-enumeration-sign-in-sign-up-J4N7.md`. |

Fixed earlier on 2026-09-19 (see `2026-09-19-ceremony-unverified-payload-hardening-K7Q2.md`): the
ceremony contracts reading unverified JWT payloads (non-object payload caused HTTP 500, pre-verification
transaction lookup, and freshness committer issuer selection).

Follow-up records: F3 in `plans/backlog/backend-transport-tls-enforcement.md`, F4 in
`plans/backlog/out-of-band-otp-lifetime.md`.

## Checklist

### V1 Encoding and Sanitization

| Section | Status | Evidence |
|---|---|---|
| 1.1 Architecture | Pass | Rails auto-escaping in ERB; React/Inertia for rendered pages. |
| 1.2 Injection prevention | Pass | No `html_safe`, `raw`, `<%==`, `render inline:`; no `dangerouslySetInnerHTML`/`innerHTML` in `src/` or `app/javascript/`. SQL interpolation only of `table_name` and `to_i` values (`enforcement_case_applicable.rb`, `sign_up_email_pending_guard.rb`). No shell execution. |
| 1.3 Sanitization | Pass | Audit payloads pass through `ChronicleRecordPolicy.sanitize`; CSP reports through `CspViolationReportIntake#sanitize_report`. No user HTML or Markdown rendering. |
| 1.4 Memory safety | N/A | Ruby and TypeScript only. |
| 1.5 Safe deserialization | Pass | No `Marshal.load`, `YAML.unsafe_load`, or `eval`. `constantize` arguments are static class names. |

### V2 Validation and Business Logic

| Section | Status | Evidence |
|---|---|---|
| 2.1 Documentation | Pass | Flow and state rules documented under `docs/security/` (sign-in and sign-up sequences, compensation). |
| 2.2 Input validation | Pass | `params.expect` throughout; no `permit!`. The two `to_unsafe_h` uses read a single, type-checked key. |
| 2.3 Business logic | Finding F1 | Sign-in flows use explicit status transition tables (`*_sign_in_flow.rb`). The avatar group membership is F1. No payment flow present (`stripe` is not referenced from `app/`). |
| 2.4 Anti-automation | Pass | 74 `rate_limit` declarations backed by a dedicated Redis store (`config.x.rate_limit.store`); Cloudflare Turnstile in 43 controllers; 30 s login cooldown. |

### V3 Web Frontend Security

| Section | Status | Evidence |
|---|---|---|
| 3.1 Documentation | Pass | `docs/security/security-headers.md`, `cookie-domain-scope.md`. |
| 3.2 Content interpretation | Pass | Uploads limited to raster images; the MIME type is detected from content by Marcel (no SVG). |
| 3.3 Cookie setup | Pass | Authentication cookies `HttpOnly`, `Secure`, `SameSite=Strict` (`authentication_cookie_service.rb`); session cookie `HttpOnly`, `SameSite=Lax`. |
| 3.4 Security headers | Finding F5 | CSP with nonces, `strict-dynamic`, `object-src 'none'`, `base-uri 'self'`, `frame-ancestors 'self'`, enforced (not report-only); HSTS 365 days with subdomains; COOP/CORP same-origin; Permissions-Policy restrictive; Referrer-Policy `strict-origin-when-cross-origin`, `no-referrer` on ceremony pages. |
| 3.5 Origin separation | Pass | CSRF protection on (the only skip is the CSP report endpoint); no CORS configured; OmniAuth request phase restricted to POST with `omniauth-rails_csrf_protection`. |
| 3.6 External resource integrity | Pass | The only third-party script is Cloudflare Turnstile, which is versionless and cannot carry SRI; it is pinned by CSP host. |
| 3.7 Other | Pass | No `localStorage`/`sessionStorage`/IndexedDB use for sensitive data. |

### V4 API and Web Service

| Section | Status | Evidence |
|---|---|---|
| 4.1 Generic | Pass | `ApiContentNegotiation`; state-changing routes use non-GET verbs. GET `/oidc/logout` renders a confirmation page only. `rails_db` (GET table destroy) is development-only. |
| 4.2 HTTP message validation | Pass | Body-size limits on Apple notifications and CSP reports; `Rack::Timeout` in production. `Rack::MethodOverride` is present (Rails default); verb override still passes CSRF. |
| 4.3 GraphQL | N/A | Not used. |
| 4.4 WebSocket | N/A | No Action Cable mount. The MCP endpoint was withdrawn on 2026-09-19 (F7). |

### V5 File Handling

| Section | Status | Evidence |
|---|---|---|
| 5.1 Documentation | Pass | `ApplicationUploader` documents the storage boundary. |
| 5.2 Upload and content | Pass | `validate_max_size` (5 MB avatar, 10 MB publishing) and `validate_mime_type` using Marcel content detection. No server-side image decoding, so no pixel-flood exposure. |
| 5.3 Storage | Pass | Object keys are `<owner>/<public_id>/<name>/<random hex>`; no user-controlled paths; separate storage per boundary. |
| 5.4 Download | Pass | No `send_file`, no path built from params. |

### V6 Authentication

| Section | Status | Evidence |
|---|---|---|
| 6.1 Documentation | Pass | `docs/security/authentication-assurance-levels.md`, `credential-abuse-rate-limits.md`. |
| 6.2 Password security | N/A | No user-chosen passwords. Secret credentials are system-generated `SecureRandom.base58(32)` and hashed with Argon2 (`SecretCredential`). |
| 6.3 General | Finding F8 | Rate limits and Turnstile on sign-in; login cooldown; step-up (re-authentication) required for credential changes. Passkey options disclose whether an account has a passkey (F8); email sign-in and sign-up disclose account existence (F9). |
| 6.4 Factor lifecycle and recovery | Pass | `docs/security/mfa-reset-account-recovery.md`; recovery codes are single-use secret credentials. |
| 6.5 General MFA | Finding F4 | TOTP verification through `TotpWindowConsumer` (window consumption prevents replay); passkeys. Out-of-band code lifetime exceeds the 10-minute limit of 6.5.5 (F4). |
| 6.6 Out-of-band | Pass | HOTP codes with random base32 key, 5 attempts, then a 15-minute lockout (`OtpLockable`); verified under `with_lock` and cleared on success. The 12-minute lifetime is recorded under 6.5 (F4). |
| 6.7 Cryptographic authenticators | Pass | WebAuthn; production requires HTTPS origins (`config/initializers/webauthn.rb`); RP ID and origin boundary documented. |
| 6.8 Identity provider | Pass | Google/Apple/Entra via OmniAuth with PKCE; ID token verification in `OidcIdTokenVerifier` (`auth_time`, `max_age`). |

### V7 Session Management

| Section | Status | Evidence |
|---|---|---|
| 7.1 Documentation | Pass | `docs/security/session-limit.md`, `session-token-authority.md`, `refresh-token-rotation.md`. |
| 7.2 Fundamentals | Pass | Access JWT 5 min; every request resolves the session row with `klass.active.find_by(public_id:)` (`AuthenticationCurrentResourceResolver`), so revocation takes effect immediately. |
| 7.3 Timeouts | Pass | Idle: client and visitor 8 h, operator 30 min. Absolute: refresh token 30 days (client/visitor), 8 h (operator) (`SecurityTokenLifetimes`). |
| 7.4 Termination | Pass | `AuthenticationLogoutable`, `AuthenticationLogoutAllSessions`, `AuthenticationSessionRevoker`; `reset_session` at 11 sites. |
| 7.5 Session abuse | Pass | Concurrent session caps (client 2/3, visitor 1/2, operator 1/2); user-visible session lists with revocation. |
| 7.6 Federated re-authentication | Pass | Step-up ceremony with AAL and freshness; RP `auth_time` checked. |

### V8 Authorization

| Section | Status | Evidence |
|---|---|---|
| 8.1 Documentation | Pass | `docs/security/action-policy-conventions.md`. |
| 8.2 General design | Finding F1 | `ApplicationPolicy` denies by default (all rules `false`, `relation_scope` returns `none`); `skip_before_action :enforce_access_policy!` raises at class load. |
| 8.3 Operation level | Findings F1, F6 | `verify_authorized` runs for every `:private` action. Record lookups sampled are scoped to the current actor or followed by `authorize!`. |
| 8.4 Other | Pass | Surface isolation enforced per controller namespace. |

### V9 Self-contained Tokens

| Section | Status | Evidence |
|---|---|---|
| 9.1 Source and integrity | Pass | ES384 fixed; keys looked up per `issuer_id` and `kid`; `crit`/`jku`/`jwk`/`x5u` headers rejected; `typ` supplied by the caller. |
| 9.2 Content | Pass | `iss`, `aud`, `exp`, `iat`, and required claims verified; claim allowlists (`validate_keys!`). |

### V10 OAuth and OIDC

| Section | Status | Evidence |
|---|---|---|
| 10.1 Generic | Pass | PKCE `S256` only (`OidcAuthorizationTransactionable`, `AuthorizationCodeStore`). |
| 10.2 Client | Pass | `state` bound to the session's pending flows and consumed once, 10-minute TTL; `nonce` checked. Apple uses `provider_ignores_state`, compensated by `SocialCallbackGuard` with a single-use server-side state store. |
| 10.3 Resource server | Pass | Access tokens are audience-restricted (`AUTH_JWT_*_AUDIENCES`). |
| 10.4 Authorization server | Pass | Exact `redirect_uri` match; atomic single-use code consumption via Lua script with a replay tombstone; refresh token rotation. |
| 10.5 OIDC client | Pass | ID token signature, `iss`, `aud`, `nonce`, `auth_time` verified. |
| 10.6 OpenID provider | Pass | Discovery profile documented; client assertion `private_key_jwt` validated at boot. |
| 10.7 Consent | N/A | Only first-party static clients (`OidcClientRegistry`). |

### V11 Cryptography

| Section | Status | Evidence |
|---|---|---|
| 11.1 Inventory | Pass | JWT keyring and HMAC rotation documented (`identifier-hmac-emergency-rotation.md`). |
| 11.2 Implementation | Pass | Standard libraries only (ruby-jwt, OpenSSL, Active Record Encryption). |
| 11.3 Encryption | Pass | Active Record Encryption for email address, TOTP secrets, external subject, candidate data. No custom ciphers. |
| 11.4 Hashing | Pass | Argon2 for secrets; SHA-256 only over high-entropy random tokens. |
| 11.5 Random values | Finding F8 | `SecureRandom` for all secrets, IDs, and OTP keys. |
| 11.6 Public key | Pass | ES384 for issued JWTs; RS256 verification only for Apple. |
| 11.7 In-use data | Not verified | Out of scope for static review. |

### V12 Secure Communication

| Section | Status | Evidence |
|---|---|---|
| 12.1 TLS general | Deploy-check | `force_ssl`, `assume_ssl` (TLS terminated upstream). TLS versions and ciphers are set at the CDN or load balancer and were not inspected. |
| 12.2 External HTTPS | Pass | `OutboundHttp::Connection` enforces HTTPS when `require_https`; no `VERIFY_NONE`; SMTP `openssl_verify_mode: "peer"`. |
| 12.3 Service-to-service | Finding F3 | PostgreSQL and Valkey TLS depend on environment values. |

### V13 Configuration

| Section | Status | Evidence |
|---|---|---|
| 13.1 Documentation | Pass | `docs/security/public-entrypoints.md`. |
| 13.2 Backend communication | Finding F3 | See F3. |
| 13.3 Secret management | Pass | Secrets from Rails credentials and environment; no key or `.env` files tracked; parameter filtering is broad. |
| 13.4 Information leakage | Finding F7 | `consider_all_requests_local = false`; static error pages; Sentry `send_default_pii = false`. Admin tools (Blazer, PgHero, Rails Performance, Swagger, Coverband, rails_db) are development-only gems; Flipper UI and Mission Control use Basic auth with constant-time comparison. |

### V14 Data Protection

| Section | Status | Evidence |
|---|---|---|
| 14.1 Documentation | Pass | `docs/security/withdrawal-privacy-erasure.md`. |
| 14.2 General | Pass | `Cache-Control: no-store` on 44 sensitive responses; PII encrypted at rest; retention purge job. Short-lived tokens in URLs (jump token 30 s, unsubscribe token) with a strict referrer policy. |
| 14.3 Client-side | Pass | No browser storage of sensitive data; authentication cookies are `HttpOnly`. |

### V15 Secure Coding and Architecture

| Section | Status | Evidence |
|---|---|---|
| 15.1 Documentation | Pass | ADRs and `docs/architecture/`. |
| 15.2 Architecture and dependencies | Finding F2 | `bundle-audit` clean for released gems. |
| 15.3 Defensive coding | Pass | Mass assignment restricted by `params.expect`; type checks on untrusted token payloads (fixed today). |
| 15.4 Concurrency | Pass | `with_lock` around OTP verification; atomic Redis Lua for code consumption; advisory locks for sign-up. |

### V16 Security Logging and Error Handling

| Section | Status | Evidence |
|---|---|---|
| 16.1 Documentation | Pass | `adr/application-logging-boundary.md`, `docs/security/observability-boundary.md`. |
| 16.2 General logging | Pass | Structured `JitLogEvent`; lograge. No `params` or request data interpolated into log strings. |
| 16.3 Security events | Pass | `AuthenticationAuditWriter`, `Chronicle` records, JWT anomaly and CSRF notifications. |
| 16.4 Log protection | Deploy-check | Log storage and access control are platform concerns (Cloud Run / Sentry). |
| 16.5 Error handling | Finding F6 | No blanket `rescue_from StandardError`; errors fail closed. |

### V17 WebRTC

| Section | Status | Evidence |
|---|---|---|
| 17.x | N/A | WebRTC is not used. |
