# Core Canonical Public Host

## Status

Accepted (2026-08-09). Supersedes the Open revision of the same date, which recorded the conflict
without resolving it.

## Context

Three different hostnames were treated as the Core surface's public host, in three places that were
all live:

| Hostname                        | Where it appears                                                                                                                                                                    |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `jp.umaxica.app`                | `docs/operations/core-nextjs-zero-cookie-edge-contract.md`, which names it the "Canonical public Core host"                                                                         |
| `core-jp.umaxica.{app,com,org}` | `compose.yaml` `PUBLIC_CORE_*_URL` (since migrated to `jp.umaxica.*`), and the `boot_hosts.core_*` entries in `config/environments/production.rb`                                   |
| `jpx.umaxica.{app,com,org}`     | hardcoded in `config/environments/production.rb` `config.hosts`, and the non-production defaults in `ConfigValues::HostFamilyValues` (`core_service`/`core_corporate`/`core_staff`) |

Production `config.hosts` accepted both the `core-jp.*` and `jpx.*` families, so the ambiguity was
not merely documentary — the origin answered to both.

The three names accumulated in one week without any being retired: `jp.umaxica.app` in documentation
(2026-06-14), `core-jp.*` in `compose.yaml` (2026-06-25), `jpx.*` in Rails code and `config.hosts`
(2026-06-26), and the `PUBLIC_CORE_*` indirection last (2026-06-28/29). Because core was pinned to
the literal `CORE_*_URL` keys three days before the `PUBLIC_*`/`PRIVATE_*` split existed,
`ConfigValues::HostFamilyValues` gained `#base_key`, `#side_key`, and `#auth_key` but no
`#core_key`.

## Decision

### Canonical host

`jp.umaxica.{app,com,org}` is the canonical public Core host family, for all three realms. Deciding
all three now avoids a second revision of this ADR when the corporate and staff surfaces migrate.
`jpx.umaxica.*` and `core-jp.umaxica.*` become legacy and are removed once the migration steps below
complete.

### Workers VPC Host header

The Core Router Worker sends a `Host` from the `PUBLIC_*` family and does **not** set
`X-Forwarded-Host`.

Cloudflare documents that a Workers VPC Service's configured host and port determine routing, and
that the host in the Worker's `fetch()` URL "is not used to route requests, and instead only
populates the `Host` field". The `Host` is therefore a free choice. Choosing `PUBLIC_*` keeps
production `config.hosts` a single family and matches the surface route constraints in
`config/routes/core.rb`, which are `PUBLIC_CORE_*`-derived. Choosing `PRIVATE_*` would force
production `config.hosts` to become a `PUBLIC_* ∪ PRIVATE_*` union solely to admit this one caller.

`X-Forwarded-Host` is excluded because `ActionDispatch::HostAuthorization` checks **both** the raw
`HTTP_HOST` **and** the last value of `X-Forwarded-Host`, rejecting the request if either is
disallowed. A Worker that forwarded a public name in `X-Forwarded-Host` while connecting under a
private `Host` would make a `config.hosts` union mandatory regardless of the family decision. This
constraint is recorded in `docs/architecture/cloudflare-request-paths.md`.

### Path ownership

`config/routes/core.rb` is the source of truth for what Rails answers on the Core host; the edge
route table is derived from it, not the reverse. `/` is owned by Next.js. Rails Core's root action
remains reachable on the `PRIVATE_*` ingress for smoke tests.

## Consequences

- Production `config.hosts` now lists `jp.umaxica.*` alongside the legacy families, so the origin
  answers on the canonical name before the edge publishes it. The Host Authorization surface is
  temporarily wider, not narrower; it narrows when the legacy families are removed.
- `ConfigValues::HostFamilyValues#core_key` resolves `PUBLIC_CORE_*_URL` in preference to
  `CORE_*_URL`. This is the reverse of `#base_key`/`#side_key`/`#auth_key`, and deliberately so:
  `config/routes/core.rb` constrains the surface on `PUBLIC_CORE_*_URL || CORE_*_URL`, so boot
  config must resolve the same host the route constraint accepts. Before this, a deployment that set
  only `PUBLIC_CORE_SERVICE_URL` routed correctly but registered `jpx.umaxica.app` as its
  `core-next-rp` redirect URI.
- `OidcClientStoresStaticClientStore.boot_host_for` maps the `PUBLIC_CORE_*` keys, so the
  `core-next-rp` redirect URIs no longer carry literal `jpx.*` defaults.
- Development Host Authorization is unaffected: `config/environments/development.rb` filters boot
  hosts to `*.localhost`, and `test/config/host_authorization_contract_test.rb` asserts that the
  canonical `jp.umaxica.*` family is rejected in development exactly as the legacy families are.

## Remaining migration steps

These are sequenced deliberately and are not complete:

1. Point `PUBLIC_CORE_*_URL` at `jp.umaxica.*`. Done for `compose.yaml` (all three realms); the
   production environment sets these values outside this repository and is **not** yet migrated.
   Route constraints and redirect URIs follow automatically from the environment value.
2. Migrate the `jpx.*` column defaults on `core_app_client_bridges`, `core_com_visitor_bridges`, and
   `core_org_operator_bridges`, plus the issuer origins in `lib/jit_security_jwt_registry.rb`, the
   allowlist in `app/policies/jump_rt_return_policy.rb`, and the host list in
   `app/models/concerns/core_rp_bridge.rb`. This is a default change plus a data backfill and needs
   its own migration plan.
3. Remove `jpx.umaxica.*` and `core-jp.umaxica.*` from `config/environments/production.rb`.

Until steps 1 and 2 complete, do not remove the legacy Core host entries, and do not enable
`CORE_BROWSER_JWT_COOKIE_ENABLED` — the latter additionally requires the edge cookie-stripping
enforcement described in `docs/operations/core-nextjs-zero-cookie-edge-contract.md`.

### No external identity provider re-registration is required

The Core host rename does not touch any externally registered redirect URI. Google, Apple, and Entra
call back to `/social/{google,apple,entra}/callback`, which are routed only on the Auth and Base
surfaces (`config/routes/auth.rb`, `config/routes/base.rb`) under their `PUBLIC_AUTH_*` and
`PUBLIC_BASE_*` host constraints. `config/routes/core.rb` routes no `social` path at all, and
`config/initializers/omniauth.rb` sets only `callback_path`, never a host.

The `core-next-rp` redirect URIs that this rename does change belong to the **internal** OIDC
relationship — Base is the OP, Core the RP — and are generated from `PUBLIC_CORE_*_URL` by
`app/values/oidc_client_stores_static_client_store.rb`. They require no action outside this
repository. Do not conflate the two.

## Related

- `docs/operations/core-nextjs-zero-cookie-edge-contract.md`
- `docs/architecture/cloudflare-request-paths.md`
- `adr/public-private-url-boundaries.md`
- `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`
