# ADR: Org Entra ID Sign-In Migrates to an OmniAuth Strategy

**Status:** Accepted (2026-07-31), partially superseded (2026-08-11)

**Partially superseded by:** `adr/org-entra-single-tenant-credential-configuration.md`. Tenant and
client are no longer resolved per request from an `OrganizationEntraConnection` but read from Rails
credentials for a single tenant; client authentication is a client secret rather than a
certificate-based `private_key_jwt`; and Entra is once again built through
`ExternalAuthentication::ProviderAdapterFactory`, as `EntraProviderAdapter`. The OmniAuth strategy
itself, tenant fixation, disabled Discovery, the provider/surface allow matrix, the `fail!`-versus-
raise handling, and AuthHash minimality are unchanged and still govern.

**Supersedes:** the "OmniAuth is not used on the org surface" decision in
`adr/org-entra-id-sign-in-boundary.md`. Every other decision in that ADR (data model placement,
`tid + oid` lookup key, no email/UPN/name, no JIT provisioning, default-inactive records,
certificate-based `private_key_jwt`, MFA bypass policy) is unchanged and still governs.

## Context

Apple and Google sign-in on the app surface already run through OmniAuth (`omniauth-apple`,
`omniauth-google-oauth2`). Entra ID sign-in on the org surface was hand-built: its own
state/nonce/PKCE generation, its own authorization-URL construction, its own token-exchange
orchestration (`ExternalAuthentication::EntraProviderAdapter`, `OidcRpTokenClient`), and its own
ceremony store (`ExternalAuthenticationOrgEntraCeremonyStore`). This asymmetry -- two providers on a
shared, actively-maintained interface and one on bespoke protocol code -- was flagged as a long-term
maintenance and correctness risk: bespoke OAuth2/OIDC code does not benefit from the gem's own
security fixes and review, and every new edge case is the app's own to find.

The original ADR deliberately deferred this: `omniauth_openid_connect` stayed out of the production
Entra path until its correctness could be demonstrated, specifically because a generic OIDC client's
default token-endpoint authentication (`client_secret` or a plain `jwt_bearer` assertion) cannot
produce the certificate-based `private_key_jwt` with an `x5t#S256` thumbprint that Entra requires --
and the org surface's `OmniAuthNonAppSocialGuard` blocked all `/social/*` traffic on non-app hosts
outright, which would have to change for Entra to use the shared `/social` mount point at all.

## Decision

### Move to a Umaxica-specific OmniAuth strategy, not a generic one

Apple and Google keep their existing dedicated gems unchanged. Entra ID is now
`OmniAuth::Strategies::UmaxicaEntra` (`lib/omniauth/strategies/umaxica_entra.rb`), a subclass of
`omniauth_openid_connect`'s `OmniAuth::Strategies::OpenIDConnect` (gem version `0.8.0`, pinned; see
"Gem version" below). No off-the-shelf Entra-specific OmniAuth gem is used -- none of the available
ones expose the certificate-assertion injection point this app requires, and building that on top of
a generic strategy is more auditable than trusting a third-party Entra wrapper's own security
claims.

Only the following methods are overridden, each because the base gem's behavior is wrong or
insufficient for Entra, not merely different:

| Override                                 | Why the base gem doesn't cover it                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `request_phase` / `callback_phase`       | Tenant and `client_id` are per-`OrganizationEntraConnection`, resolved from a `connection_public_id` param/session reference; the base gem assumes one static issuer configured at boot.                                                                                                                                                                                                                                                                                                                                           |
| `access_token`                           | The base gem only knows `client_secret` or a generic (non-certificate) `jwt_bearer` assertion. Entra requires PS256 + `x5t#S256`.                                                                                                                                                                                                                                                                                                                                                                                                  |
| `verify_id_token!`                       | The base gem's `decode_id_token(...).verify!` is generic OIDC only; Entra-specific claims (`tid`, `oid`, `acct`) require the existing `ExternalSign::Providers::EntraId` verifier.                                                                                                                                                                                                                                                                                                                                                 |
| `uid` / `info` / `extra` / `credentials` | The base gem's `info`/`extra`/`credentials` **block DSL merges every ancestor's block** (`OmniAuth::Strategy.compile_stack` walks `self.class.ancestors`), so a block-based override still additionally evaluates the base class's blocks -- which call `user_info` (the UserInfo endpoint) and expose raw tokens. These four are overridden as **plain instance methods**, which shadow the base method entirely instead of merging with it. This was caught by a contract test, not by inspection -- see "Contract tests" below. |

State generation/consumption, nonce generation, and PKCE S256 verifier/challenge handling are the
base gem's own mechanism (`session['omniauth.state']`, `'omniauth.nonce'`,
`'omniauth.pkce.verifier'`) and are not reimplemented.

### `fail!` inside nested calls does not halt execution -- raise instead

`OmniAuth::Strategy#fail!` only produces a correct response when it is the _direct return value_ of
a phase method (`request_phase`/`callback_phase`); `OmniAuth::Strategy#call!` uses that return value
as the Rack response. Calling `fail!` from a method nested inside `super`'s call graph
(`access_token`, `verify_id_token!`) does not stop the caller -- execution continues past it, and
the caller (`super`'s own `callback_phase` body) proceeds to build a "successful" AuthHash from
whatever state exists, including `nil`. `UmaxicaEntra::Error` is raised instead from those nested
methods and rescued at the top of `callback_phase`, converting it to `fail!` only once execution has
actually unwound to the phase-level method. This, too, was found by a contract test that exercised
the full `callback_phase`, not by code review.

### private_key_jwt injection

`rack-oauth2`'s `Client#access_token!` (which `openid_connect`'s `Client`, and therefore
`omniauth_openid_connect`, inherits from) accepts a pre-built `client_assertion` directly when
`client_auth_method: :jwt_bearer` is passed -- it does not require the gem to generate the assertion
itself. `access_token` calls the existing, unchanged
`ExternalAuthentication::EntraClientAssertionAdapter` (PS256, `x5t#S256` certificate thumbprint) to
build the assertion and passes it straight through:

```ruby
client.access_token!(
  scope: options.scope,
  client_auth_method: :jwt_bearer,
  client_assertion: assertion,
  code_verifier: verifier,
)
```

No `client_secret` is ever sent. No gem source was copied or monkey-patched to make this work.

### Tenant fixation, no Discovery

`options.issuer`, `options.client_options.{host,port,authorization_endpoint,token_endpoint}` are set
per-request from the resolved `OrganizationEntraConnection#entra_tenant_id` / `#entra_client_id`;
`common`/`organizations`/`consumers` are never used. `options.discovery` is `false` -- Discovery is
a network round trip this single-tenant-per-connection model doesn't need and an extra
tenant-confusion surface it doesn't want.

### Connection resolution, not a new service class

Connection lookup lives inside the strategy (`active_connection_from_params` / `active_connection`)
and the controller (`OmniauthCallbacksController#active_connection`), each a
`OrganizationEntraConnection.find_by(public_id:, status_id: ACTIVE)` -- no new service/adapter class
was introduced for this. The controller re-validates the connection independently of the strategy's
own validation, matching the same trust-boundary-revalidation pattern the legacy
`Auth::Org::Sign::In::Entra::CallbacksController` already used.

### Connection-lookup timing protection

The legacy `Auth::Org::Sign::In::Entra::AuthorizationsController` included `MinimumResponseBudget`
(a Rails controller concern normalizing response time around the connection lookup, so a valid vs.
invalid `connection_public_id` cannot be distinguished by timing). A `Rack`/`OmniAuth::Strategy` is
not an `ActionController` and cannot include that concern. `UmaxicaEntra#request_phase` inlines the
same measure-then-pad pattern (150ms floor, 250ms max sleep --
`test/controllers/auth/credential_timing_protection_contract_test.rb`) directly around the
connection lookup instead.

### Provider/surface allow matrix replaces the blanket guard

`OmniAuthNonAppSocialGuard` (host-only, block-everything-on-non-app) is replaced by
`OmniAuthSocialProviderHostMatrix` (`config/initializers/omniauth.rb`): app hosts allow
`apple`/`google` only, the org (staff) host allows `entra` only (restricted to `/social/entra`,
`/social/entra/callback`, `/social/entra/failure` -- prefix-matched safely, so `/social/entrax` is
not accidentally allowed), com hosts allow no external OmniAuth strategy. Unknown providers are
denied on every surface.

Not every `/social/*` path is a provider path: `/social/authentication/{continuation,completion}`
(app-surface social sign-up continuation/completion) share the `/social` prefix but aren't
OmniAuth-strategy-owned. An initial version of this guard treated any first path segment as a
"provider" and denied these as unrecognized, which would have 404'd real app-surface social sign-up
traffic (caught by the existing `test/integration/social_auth_login_test.rb`,
`apple_social_flows_test.rb`, `omniauth_callbacks_test.rb`, and
`acme_social_link_completion_test.rb` suites failing when run end-to-end -- not by this migration's
own new tests, which never exercised that path). The guard now checks the segment against a fixed
`KNOWN_PROVIDERS` list first; anything else falls back to the pre-existing app-only behavior instead
of being denied outright.

### AuthHash minimality

`uid` is `"#{tid}:#{oid}"`. `info` and `credentials` are always `{}`. `extra.raw_info` carries only
`tid`, `oid`, `iss`, `sub`, and `connection_public_id` (an internal reference, not a secret) --
never a raw ID token, access token, or refresh token, and never email/UPN/name. No UserInfo or
Microsoft Graph call is ever made (scope is fixed to `openid profile`).

### Routing

`/social/entra/session/new` (a real Rails `resource :session, only: :new`,
`Auth::Org::Social::SessionsController`) renders a CSRF-protected POST form.
`/social/entra/callback` and `/social/entra/failure` are non-resourceful `get` routes -- OmniAuth
middleware owns the callback path, the same documented exception already used for Apple/Google
(`config/routes/auth.rb`). No `match` route was introduced anywhere in this migration.

`OmniAuth.config.allowed_request_methods = [:post]` is global and already applied to Apple/Google
before this migration; it applies to Entra automatically, with no per-provider override needed.

The application controller's Rails verification strategy is `:header_or_legacy_token` with Origin
checking. OmniAuth's request-phase verifier reads that existing root's configuration rather than
the framework base's header-only default; the global framework default is unchanged. The pinned Rails 8.2 revision
requires `action_name` during fallback instrumentation, which the pinned CSRF gem does not provide;
the gem also raises the deprecated `InvalidAuthenticityToken` alias. `OmniauthRailsCsrfVerifier`
supplies fixed instrumentation metadata and the current `InvalidCrossOriginRequest` exception while
using the inherited, unmodified Rails `verified_request?` predicate. It replaces the request-phase
verifier rather than installing a second verification path. No Origin/header rewriting, exception
suppression, token inference or callback route change is introduced.

An Entra-plus-Passkey Auth result carries recorded authentication evidence to Base before the
sign-in flow is completed. The ORG handoff requires the existing evidence-ready flow predicate and
operator policy; Base alone commits the root. Missing primary evidence, missing/expired MFA and
unverified start requests cannot establish a root.

### Legacy ceremony removed

The legacy `Auth::Org::Sign::In::Entra::{AuthorizationsController,CallbacksController}`,
`Auth::Org::Sign::In::EntrasController`, `ExternalAuthenticationOrgEntraCeremonyStore`,
`ExternalAuthentication::EntraProviderAdapter`, the `/sign/in/entra/*` routes, and their dedicated
tests have been removed. This was gated on a test-based parity check, not a live-traffic comparison:
`test/controllers/auth/org/omniauth/omniauth_callbacks_controller_test.rb` covers every behavior the
legacy suite covered (state/nonce/replay rejection, no-JIT, operator-not-allowed,
authentication-method lock, ceremony-disabled, app/com surface unreachability) plus a real
successful round trip and a query-count budget the legacy suite never had.

Reusable pieces the new strategy already depends on were kept unchanged:
`EntraClientAssertionAdapter`, `ExternalSignIn::Providers::EntraId`,
`ExternalSignIn::OrgEntraResolver`, `OrganizationEntraConnection`, `OperatorEntraIdentity`, the JWKS
cache, and the shared session/BAN/lock/audit concerns.

**Still required before this is live for real Entra sign-ins:**
`https://<staff-host>/social/entra/callback` must be registered as a Redirect URI on the Entra app
registration (an out-of-repo console change); the old `/sign/in/entra/callback` Redirect URI can be
removed from the app registration once that is done and confirmed working.

`ExternalAuthenticationEntraRedirectUri::CALLBACK_PATH` now points at `/social/entra/callback` (the
only remaining path); the `/sign/in/entra/callback` constant was removed with the controller that
used it. `ExternalAuthentication::ProviderAdapterFactory` no longer has an `:entra_oidc` branch --
Entra is not built by that factory at all, since the new strategy calls
`EntraClientAssertionAdapter` directly rather than going through
`ExternalAuthentication::EntraProviderAdapter`.

### Gem version

`omniauth_openid_connect` is pinned at `0.8.0` (already in `Gemfile`/`Gemfile.lock`, resolving
`openid_connect 2.5.0` and `rack-oauth2 2.3.0`). A version bump is not automatic on `bundle update`;
it requires re-running the strategy contract tests below against the new resolved versions and
recording the result here, because a gem update could silently change `access_token`'s internal
parameter handling (the exact seam this migration depends on) or the `info`/`extra`/`credentials`
merge behavior described above.

### Contract tests (what gates further changes)

`test/lib/omniauth/strategies/umaxica_entra_test.rb`: connection resolution
(found/missing/inactive), tenant-fixed endpoint configuration (no Discovery, no
`common`/`organizations`), PKCE/state/nonce presence in the authorization URL, `private_key_jwt`
injection (`client_auth_method`, assertion header/claims, `code_verifier`), `verify_id_token!`
delegation to the existing Entra verifier, AuthHash minimality, and the `fail!`-inside-nested-calls
fix above.

`test/controllers/auth/org/omniauth/omniauth_callbacks_controller_test.rb`: full request-phase →
callback-phase round trip against a real `OrganizationEntraConnection` and a real signed ID token
(only the token-endpoint HTTP POST is stubbed), state replay rejection, no-JIT rejection,
app-surface providers rejected on the org host, GET rejected on the request path.

`test/controllers/auth/org/omniauth/omniauth_callback_query_count_test.rb`: real
`ActiveSupport::Notifications`-based SQL counts for the callback's connection/identity/operator
resolution -- 3 `OrganizationEntraConnection` SELECTs (strategy validation + controller
re-validation + the resolver's own pre-existing eager-load, none of them looped), exactly 1
`OperatorEntraIdentity` SELECT, at most 2 `Operator` SELECTs, and zero Graph/UserInfo calls.

`test/unit/security/entra_omniauth_secret_filtering_test.rb`: `code`, `id_token`, `access_token`,
`refresh_token`, `client_assertion`, `client_secret`, `code_verifier`, `nonce`, `state`,
`private_key_pem`, `certificate_pem` are all filtered from
`Rails.application.config.filter_parameters`.

Any future `omniauth_openid_connect`/`openid_connect`/`rack-oauth2` version bump must re-run all of
the above before merging.

## Consequences

- Apple/Google are unaffected; they keep `omniauth-apple`/`omniauth-google-oauth2`.
- `OmniAuthNonAppSocialGuard` no longer exists; `OmniAuthSocialProviderHostMatrix` is the new, more
  precise guard.
- The org surface now runs OmniAuth, scoped to exactly one allow-listed strategy.
- The legacy Entra ceremony remains the production path in every practical sense (it is what real
  Entra sign-ins use) until the cutover steps above are completed; this ADR covers only the new,
  parallel path's correctness.
- No new service class was introduced for connection resolution, per project convention.
