# HTTP Cache Policy for Rails Controllers

This is the normative implementation reference for `Cache-Control` on controller responses. The
decision and its reasoning are in `adr/global-and-publishing-default-no-store-policy.md`; this page
records the current rules and inventory. Static and fingerprinted assets served by Propshaft or Vite
are outside it.

## Policy by ownership

| Ownership  | Default             | Cache opt-in                 |
| ---------- | ------------------- | ---------------------------- |
| Global     | `no-store`          | action-local explicit opt-in |
| Publishing | `no-store`          | action-local explicit opt-in |
| Regional   | outside this policy | regional contract            |
| Core       | outside this policy | existing contract            |
| Palm       | outside this policy | existing contract            |
| Warp       | outside this policy | existing contract            |

## Directive vocabulary

- `no-store`: no cache may store the representation.
- `no-cache`: the representation may be stored, but must be revalidated with the origin before
  reuse.
- `private`: may be stored by a private (browser) cache, not by a shared cache.
- `public`: may be stored by shared caches when the rest of the response permits it.

## Rules

1. Every in-scope policy root declares, once:

   ```ruby
   include ::DefaultNoStore

   prepend_before_action :apply_default_no_store
   ```

   Subclasses inherit it and do not repeat it. `DefaultNoStore` itself registers nothing.

2. `apply_default_no_store` is the first `before_action` on every controller under a policy root,
   and the FQDN availability gate is the first one after it. A subclass that prepends its own
   callback and calls `ensure_fqdn_gate_first!` (directly, or through a concern such as
   `OidcRpLogoutLauncher`) re-prepends `apply_default_no_store` immediately afterwards.

3. An action that needs caching opts in from inside the action with `fresh_when`, `stale?`,
   `expires_in`, `expires_now`, or `http_cache_forever`. Typical shapes:

   ```ruby
   # Shared-cacheable public content, revalidated by validator.
   fresh_when(weak_etag: record.cache_key_with_version, last_modified: record.updated_at, public: true)

   # Freshness lifetime.
   expires_in 5.minutes, public: true

   # Browser-private revalidation (for example a future Xper Experience API):
   # `Cache-Control: no-cache, private` with a weak ETag.
   fresh_when(weak_etag: payload, cache_control: { no_cache: true, extras: ["private"] })
   ```

4. `skip_before_action :apply_default_no_store` is forbidden.
5. New code does not opt into caching by writing `response.headers["Cache-Control"]`,
   `response.set_header("Cache-Control", ...)`, or `response.cache_control[...]`. Rails merges such
   a header with the default `no_store` when the response is committed, and `no-store` wins. Writing
   a stricter value directly (an existing protocol-specific `no-store` contract) remains harmless.
6. A response whose body varies by the signed-in subject never opts into `public`. If it is cached
   at all it is `private`, and it carries `Vary` for whatever selects the representation.
7. Read-only public content may be cacheable, and the Publishing entries API is: it emits `ETag` and
   `Last-Modified`, answers conditional requests with `304`, and carries a public `max-age`. Under
   this policy that cacheability exists because the entries actions opt in, not because the surface
   is public.

`test/security/invariants/default_no_store_policy_invariant_test.rb` enforces rules 1, 2, and 4, and checks
that excluded roots do not carry the policy. It does not assert that excluded roots never send
`no-store`; several do for their own reasons.

## Policy-root inventory

A policy root is a surface-local `ApplicationController` or `BareController` that inherits directly
from `ActionController::Base`, plus `Auth::RedirectOnlyController` (the Auth-owned root of
redirect-only controllers that inherit the repository-wide `ApplicationController`), plus every
`ActionController::API` controller in an in-scope namespace, which is a standalone root of its own.
Subclass counts are from the 2026-10-01 inventory and drift as controllers are added.

| Policy root                          | Plane      | Subclasses | Representative routes                          |
| ------------------------------------ | ---------- | ---------- | ---------------------------------------------- |
| `Xper::{App,Com,Org}::ApplicationController` | Global | 1 each | `/` |
| `Xper::{App,Com,Org}::BareController`        | Global | 10 each | `/health`, `/revision`, `/robots.txt`, `/sitemap.xml` |
| `Auth::App::ApplicationController`   | Global     | 60         | `/`, `/sign/in`, `/preference`                 |
| `Auth::Com::ApplicationController`   | Global     | 44         | `/`, `/sign/in`                                |
| `Auth::Org::ApplicationController`   | Global     | 36         | `/`, `/sign/in`                                |
| `Auth::{App,Com,Org}::BareController` | Global    | 11 each    | `/health`, `/revision`, `/edge/v0/token/check` |
| `Auth::RedirectOnlyController`       | Global     | 8          | `/iam`, `/billings`, `/accounts` (redirects)    |
| `Base::App::ApplicationController`   | Global     | 71         | `/`, `/configuration`, dashboard pages         |
| `Base::Com::ApplicationController`   | Global     | 59         | `/`, `/configuration`                          |
| `Base::Org::ApplicationController`   | Global     | 70         | `/`, `/iam`, `/support`                        |
| `Base::{Dev,Net}::ApplicationController` | Global | 1 each     | `/`                                            |
| `Base::{App,Com,Org}::BareController` | Global    | 17–18      | `/health`, `/revision`, `/robots.txt`, `/edge/v0/token/*` |
| `Base::{Dev,Net}::BareController`    | Global     | 8 each     | `/health`, `/revision`                         |
| `Edit::Org::ApplicationController`   | Publishing | 40         | `/`, `/publishing/*/entries`                   |
| `Edit::Org::BareController`          | Publishing | 9          | `/health`, `/revision`                         |
| `Guid::Net::BareController`          | Global     | 10         | `/`, `/api/v0/resources/:guid`, `/health`      |
| `{Info,Docs,News,Help}::{App,Com,Org}::BareController` | Publishing | 10 each | `/`, `/api/v0/entries`, `/health` |

Publishing management controllers inherit `Edit::Org::ApplicationController` and public Publishing
delivery controllers inherit the surface-local `BareController`; neither re-declares the policy.

### Excluded roots

| Root                                                                 | Reason                             |
| -------------------------------------------------------------------- | ---------------------------------- |
| `Core::*::ApplicationController`, `Core::*::BareController`, `Core::*::Api::V0::BaseController`, `Core::*::Oidc::Backchannel::LogoutsController` | Regional (`core`) |
| `Palm::App::ApplicationController`, `Palm::App::BareController`, `Palm::App::Api::V0::BaseController` | Regional (`palm`) |
| `Warp::{App,Com,Org}::ApplicationController`, `Warp::{App,Com,Org}::BareController` | Regional (`side`, now Warp) |
| Repository-wide `ApplicationController`                              | Shared by mounted engines and `UnknownHostsController`; no surface owns it |
| Mounted engine and framework controllers (Blazer, Mission Control, PgHero, Rails Performance, Active Storage, Action Mailbox, `Rails::PwaController`) | Not application surfaces |

### Standalone API roots

These Global `ActionController::API` controllers inherit no surface root, so each declares the
policy itself. Their existing protocol headers are kept:

- `Base::App::Oauth::TokensController`: also sends `no-store` and `Pragma: no-cache` after every
  action (`BaseOauthEndpoint#set_oauth_cache_headers`); the default adds `no-store` to responses
  halted before the action, such as rate-limit rejections.
- `Auth::App::Apple::NotificationsController`: previously sent `no-store` only on success; the
  default covers its error statuses.
- `Edit::Org::Oidc::Backchannel::LogoutsController`: previously sent no directive.

## Explicit cacheable actions

| Action                                                          | Contract                                                   |
| --------------------------------------------------------------- | ---------------------------------------------------------- |
| Publishing `/api/v0/entries` and `/api/v0/entries/:public_id` (`PublishingContentRendering`) | `expires_in` public `max-age`, `stale?` with `ETag` and `Last-Modified` |
| JWKS documents (`AuthenticationJwksRendering`)                  | `expires_in 1.hour, public: true`                          |
| Base dashboard avatar images                                    | `stale?` with `ETag`, private                              |
| `/sitemap.xml` on surfaces that include `Sitemap`               | `expires_in 5.minutes, public: true` with `s-maxage=600` and `Surrogate-Control` |

## Existing explicit `no-store` contracts

These were in place before the default and are kept unchanged: health and revision responses
(`HealthCheckRendering`, `ApplicationRevisionRendering`, `MachineJsonNegotiation`), edge token
check and refresh endpoints, OIDC callback and sign entry (`OidcCallback`, `OidcRpSignEntry`), DBSC
registration, jump-return verification, authentication-mode switch guard, MCP, sign-up checkpoint
pages, sign-out notice, ceremony admission, secret-credential pages
(`SignSettingsSecretCredentialCacheControl`, which also sends `Pragma: no-cache` and
`Expires: 0`), Base org IAM and support pages, root pages that set `private, no-store`, the GUID
resolver, the request body size limit middleware response, and
`AuthenticationBase#apply_authenticated_page_cache_policy!`.
