# Authentication boundary audit

Audit date: 2026-08-11. Scope: the Rails application only. Edge components (Hono, Next.js,
Cloudflare Workers) and Cloudflare Access policy configuration were explicitly out of scope.

This document records the state of the Rails authentication and authorization boundary at the time
of the audit, the responsibility split with Cloudflare Access, the Microsoft Entra ID integration,
and the one finding that required a code change. It is a point-in-time record, not a decision
document; where an accepted ADR governs a behavior, the ADR remains authoritative.

## Authentication architecture

Rails 8.2.0.alpha on Ruby 4.0.6. There is no Devise, Warden, Pundit, or Rodauth. Authentication is
implemented in-repository in `app/controllers/concerns/authentication_base.rb`; authorization is
Action Policy.

The application has three independent trust boundaries — `app` (end user), `org` (staff), and `com`
(public) — with separate actor models (`Client`, `Operator`, `Visitor`), separate databases, and
separate session state. Surface roots inherit `ActionController::Base` directly and compose concerns
rather than inheriting a shared authenticated base; see
`.agents/harnesses/rules/project/controller-inheritance.mdc` and
`docs/architecture/controller-lifecycle.md`.

Access control is deny-by-default and the default is enforced rather than conventional:

- Every surface root sets `AUTHENTICATION_MODE = :deny_all`, and mode resolution falls back to
  `:deny_all` when no declaration matches.
- `skip_before_action` is overridden to raise `SkipNotAllowedError` if any controller attempts to
  skip `enforce_access_policy!`.
- `after_action :verify_private_action_authorized!` fails any `:private` action that never called
  `authorize!`, so a missing authorization call is a test failure rather than a silent allow.
- `app/policies/application_policy.rb` returns `false` from every default rule and returns
  `relation.none` from the default `relation_scope`.

Surface isolation is additionally enforced in the authorization layer: JWT audiences are
per-resource, and `domain_permitted?` derives the permitted surface from the first label of the
`aud` claim.

## Cloudflare Access and Rails: responsibility split

The split matches the intended design and required no change.

Cloudflare Access is perimeter access control for a documented subset of the org surface — `/docs`,
`/help`, `/info`, `/news` — per `adr/org-cloudflare-access-authentication-layer.md`. The `auth/org`,
`base/org`, and `core/org` trees are explicitly outside that scope and continue to authenticate
Operators with the application's own session and token machinery.

Verified during this audit: **no Rails code reads or trusts `CF-Access-Jwt-Assertion`,
`CF_Authorization`, or any other Access-issued assertion.** There is no origin-side Access verifier
under `app/`, `lib/`, `config/`, or `test/`. Rails authentication therefore does not depend on the
edge being present, and behaves identically in development and production. The Cloudflare-named code
under `app/` is Turnstile (bot mitigation), which is unrelated to Access.

Consequently, the presence of Cloudflare Access in development is not a reason to weaken or skip any
Rails authentication test, and none of the existing tests do so.

## Microsoft Entra ID integration

> Updated 2026-08-11 for `adr/org-entra-single-tenant-credential-configuration.md`, which moved the
> org surface to a single tenant configured in Rails credentials with client-secret authentication,
> and reconnected Entra to the app surface's provider registry and adapter interface. At the time of
> the original audit this integration had never completed a sign-in: no connection or identity
> records existed, the credentials present were read by no code, and no certificate credential
> existed for the token exchange.

Entra ID is a sign-in method for the `org` (staff) surface only. It is implemented as a custom
OmniAuth strategy, `lib/omniauth/strategies/umaxica_entra.rb`, subclassing
`OmniAuth::Strategies::OpenIDConnect` from `omniauth_openid_connect`.

Protocol posture, as implemented:

- Authorization code flow with PKCE (S256); `state` and `nonce` are both required (`require_state`,
  `send_nonce`).
- Discovery is disabled. The org surface federates a **single tenant**, whose tenant id and client
  id are named on the `ExternalAuthentication::ProviderRegistry` entry and read from Rails
  credentials, so endpoints are tenant-fixed rather than `common`, `organizations`, or `consumers`.
- Client authentication is `client_secret_post`: the client id and secret go in the token request
  body and no `Authorization` header is sent. The secret lives in Rails encrypted credentials; no
  Entra secret is stored in the database.
- All three Entra credentials (`OMNI_AUTH_ENTRA_ORG_TENANT_ID`, `OMNI_AUTH_ENTRA_ORG_CLIENT_ID`,
  `OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET`) are required at boot outside development and test, and the
  two identifiers must be UUIDs. Validation is presence and shape only and performs no network I/O;
  no credential value reaches an exception or a log.
- The callback is normalized by `ExternalAuthentication::EntraProviderAdapter` into the same
  `CallbackResult`/`VerifiedPrincipal` shape the app surface's Apple and Google adapters produce,
  carrying an `EntraTenantContext` rather than an opaque subject.
- Requested scope is `openid profile` only. The UserInfo endpoint and Microsoft Graph are never
  called.
- `info`, `credentials`, and `extra` are overridden as plain methods so no raw ID token, access
  token, refresh token, email, or UPN can enter the AuthHash. The plain-method override is
  deliberate: the base gem's `info do … end` block DSL merges every ancestor's block, so a block
  override would still evaluate the base class's UserInfo call.
- `OmniAuthSocialProviderHostMatrix` restricts Entra to the org host and the app-surface providers
  to the app host; anything else returns 404.
- The request phase pads to a minimum response budget so a valid and an invalid
  `connection_public_id` are not distinguishable by timing.

ID token validation lives in `app/lib/external_sign_in/providers/entra_id.rb` and checks issuer,
audience, `exp`, `iat` (bounded to a 10-minute ceremony window), `nbf`, `nonce`, `tid`, `oid` (UUID
format), `sub` presence, `ver == "2.0"`, and `acct == "0"`. Signature verification is RS256-only
against tenant JWKS via `EntraJwksCache`. Comparisons use
`ActiveSupport::SecurityUtils.secure_compare`. The Microsoft consumer tenant is rejected outright,
and a missing or non-zero `acct` claim fails closed, so guest and personal-account sign-in are
refused rather than silently accepted.

## Identity mapping

The persistent identifier is the tenant/object pair, not an email address.

`operator_entra_identities` carries a unique index on `(entra_tenant_id, entra_object_id)` — the
`tid` and `oid` claims — and a unique index on `operator_id`, giving at most one Entra identity per
Operator. The `iss` and `sub` claims are stored in `evidence_issuer` and `evidence_subject` as audit
evidence and are never used as lookup keys. Email, UPN, and `preferred_username` are not stored on
the identity record at all.

This is the correct choice and needed no change. `oid` is immutable for the lifetime of the user
object within a tenant, whereas email, UPN, and `preferred_username` are mutable and reassignable;
keying on any of them would let a rename be misread as a different user, or a reassigned address be
misread as the original user. `sub` alone was also rejected because it is pairwise per application,
so it would not survive a client registration change. Actor rows carry no email column; addresses
live in the per-surface `*_emails` tables behind a blind index.

There is no just-in-time provisioning. `ExternalSignIn::OrgEntraResolver` raises
`IdentityNotFoundError` unless a pre-provisioned `OperatorEntraIdentity` exists and is `ACTIVE`; it
never creates records. An unknown Entra user therefore cannot sign in.

Tenant restriction is enforced upstream rather than by a record: the strategy verifies every ID
token against the single configured tenant, so a token from any other tenant is rejected before
identity resolution. Revoking one person's access is an identity-state change. `connection_id` on
the identity is now nullable and unread by sign-in.

## Session, cookie, CSRF, and redirect posture

All verified as already correct; no change was made.

Session cookies (`lib/jit_session_cookie_config.rb`) are `httponly`, `same_site: :lax`, with
`secure`, `partitioned`, and the `__Host-session` name outside development and test, expiring after
14 days. SameSite is **not** weakened to accommodate the OIDC callback: `Lax` already permits the
top-level GET redirect back from Microsoft, which is the only cross-site entry the ceremony needs.

Session fixation is handled at the point of privilege transition — `log_in` calls `reset_session`
before issuing tokens. Logout revokes the current token, clears auth cookies, and calls
`reset_session` in an `ensure` block; bulk logout additionally bumps the session version so
outstanding JWTs fail at refresh.

CSRF protection is declared at `ApplicationController` and again per surface root. The only
`skip_forgery_protection` in application code is the CSP violation report endpoint, which is
expected for a browser-generated report. There is no `skip_before_action :verify_authenticity_token`
anywhere.

Rails 8.2 replaces token-only CSRF verification with `Sec-Fetch-Site` header verification, offering
two strategies: `:header_only` (header alone) and `:header_or_legacy_token` (header first, falling
back to authenticity token verification and emitting a `csrf_token_fallback.action_controller` event
on fallback). `load_defaults "8.2"` selects `:header_only` and also changes
`default_protect_from_forgery_with` from `:null_session` to `:exception`.

This application loads 8.2 defaults but deliberately and consistently overrides the strategy back to
`:header_or_legacy_token` at every surface root, retaining token fallback for browsers that do not
send `Sec-Fetch-Site`. `config/initializers/csrf_notifications.rb` and
`app/subscribers/csrf_notification_subscriber.rb` subscribe to the fallback and blocked-request
events, which provides the measurement needed to decide when the fallback can be dropped in favor of
`:header_only`. Both are framework features, not local implementations.

Every `allow_other_host: true` redirect site was traced to its target. The targets are
route-helper-generated URLs or `resume_url`, which `acme_resume_url` builds from the configured
`boot_config` host rather than from request input. No open redirect was found. `return_to` values
are carried as signed `pt` tokens and rejected by `unsafe_guard_return_to?` when unsigned.

Secrets: no `.env` file and no `*.key` file is tracked; credentials are committed only in encrypted
`.enc` form; gitleaks runs in CI alongside Brakeman and bundler-audit.
`config/initializers/filter_parameter_logging.rb` already filters `token`, `jwt`, `authorization`,
`cookie`, `state`, `nonce`, `code`, `assertion`, and `jwks`, among others.

`bundle-audit` reported no vulnerabilities against the advisory database as of 2026-08-10.

## Finding

**Unauthenticated OmniAuth failure endpoints logged an attacker-controlled parameter verbatim.
Severity: low. Fixed.**

`GET /social/entra/failure` (org) and `GET /social/failure` (app) are directly reachable without
authentication. On the org surface the controller's `rate_limit` is scoped `only: :omniauth`, so the
failure action was also unthrottled.

Both actions took the `message` request parameter — and, on the app surface, `strategy` — and wrote
it into a log event unchanged. On the org surface the _rendering_ path already reduced the same
parameter to an allowlisted classification via `entra_failure_reason`, so only the logging path
bypassed the allowlist. That contradicted the discipline stated in the same controller and in
`adr/application-logging-boundary.md`, which requires retaining only allowlisted classification
metadata.

This was not a disclosure or an authentication bypass. `JitLogEvent.format` JSON-encodes its
payload, so newline and terminal-escape log injection were already neutralized. The exposure was
unbounded log-write amplification from an unauthenticated endpoint, and a redaction-boundary
violation in which one path bypassed the classification contract that the adjacent path enforced.

The fix classifies before logging, reusing the allowlists that already existed:

- `app/controllers/auth/org/omniauth/omniauth_callbacks_controller.rb` — the failure action now
  classifies once through `entra_failure_reason` and passes that result to both the log and the
  rendered error.
- `app/controllers/auth/app/omniauth/omniauth_callbacks_controller.rb` —
  `classified_failure_message` reduces `message` to a known OmniAuth failure reason or `"other"`,
  and `classified_failure_strategy` reduces `strategy` through
  `SocialIdentifiable.normalize_provider` against
  `ExternalAuthentication::ProviderRegistry.providers` or `"other"`. The raw values are still used
  for the duplicate-callback and translation-key decisions, which need them; only the logged values
  are classified.

Note on residual behavior: Rails' own request logger still echoes the request URL and parameters for
these endpoints, as it does for every endpoint. That is generic framework behavior outside the
application logging boundary and was not changed here.

## Items reviewed and deliberately not changed

- `config/environments/test.rb` defaults `allow_forgery_protection` to false, with per-test opt-in.
  This matches the Rails-generated default for the test environment
  (`railties/.../templates/config/environments/test.rb.tt`) and is not a deviation, so no change was
  warranted. Under the 8.2 verification strategies described below, blanket-enabling it would also
  not be the improvement it appears to be: with `:header_only`, a request with no `Sec-Fetch-Site`
  header over a non-SSL connection verifies successfully, which is exactly the shape of a test
  request, so most tests would pass without exercising anything. Targeted CSRF boundary tests are
  the meaningful coverage, and they exist —
  `test/controllers/protocol_controller_csrf_boundary_test.rb`,
  `test/integration/social_completion_cross_host_csrf_test.rb`,
  `test/integration/csrf_notification_emission_test.rb`, and
  `test/integration/preference_web_csrf_test.rb`.
- The Content-Security-Policy retains a blanket `:https` in `style_src`, `font_src`, and `img_src`
  while `connect_src` is tightly scoped. Narrowing these risks breaking rendering and was out of
  scope for a change driven by this audit.
- The Cloudflare Access and Rails responsibility split was confirmed, not rearranged.
