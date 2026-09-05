# Cloudflare Request Paths and Trust Boundaries

This document describes every request path that reaches Rails, the trust domain each hop belongs to,
and which component can forge which header. It exists because Cloudflare Tunnel, Cloudflare Access,
and Workers VPC are distinct trust domains that must not be conflated.

## Hostname Families, Routing Targets, and Host Authorization

`PUBLIC_*_URL` and `PRIVATE_*_URL` are the **only two hostname families** (see
`adr/public-private-url-boundaries.md`). `PUBLIC_*` names the site a browser or app sees;
`PRIVATE_*` names the network-side ingress that Cloudflare or AWS connects to. They are not a
development/production split.

A **routing target** is not a hostname family member's role but a separate concept, and both
Cloudflare mechanisms keep the two strictly apart:

- A Tunnel ingress rule's `service:` address is a routing target. `cloudflared` leaves the HTTP
  `Host` header unmodified unless `httpHostHeader` is set, so the origin receives the **browser's**
  hostname, not the `service:` address. `originServerName` affects TLS certificate validation only.
- A Workers VPC Service's configured host and port are the routing target. Cloudflare documents that
  the host in the Worker's `fetch()` URL "is not used to route requests, and instead only populates
  the `Host` field", and that the VPC Service configuration "will always be used to connect and
  route requests to your services, even if a different host or port is present in the URL provided
  to the `fetch()` operation".

Therefore: **Rails Host Authorization evaluates the HTTP `Host` header Rails actually receives —
never the routing target that delivered the request.** A routing target must never be added to
`config.hosts` on the grounds that it "is how the request got here".

`ActionDispatch::HostAuthorization` evaluates **two** values, not one: the raw `HTTP_HOST`, and the
last comma-separated value of `X-Forwarded-Host` when that header is present. A request is rejected
if _either_ is disallowed. Any hop that sets `X-Forwarded-Host` therefore adds a second name that
`config.hosts` must admit. A hop that sets `X-Forwarded-Host` from one family while connecting under
a `Host` from the other makes a `PUBLIC_* ∪ PRIVATE_*` union mandatory regardless of which family
was chosen for `Host` — so a hop must either send both from the same family or omit
`X-Forwarded-Host` entirely.

Which family supplies that `Host` follows from the ingress the listener sits behind:

| Environment | Ingress                                                                  | `Host` Rails receives                                   | `config.hosts` derives from |
| ----------- | ------------------------------------------------------------------------ | ------------------------------------------------------- | --------------------------- |
| Production  | Cloudflare edge → Tunnel                                                 | browser's public hostname                               | `PUBLIC_*`                  |
| Development | Cloudflare edge → Access → Tunnel, **and** direct on the private network | browser's public hostname, or the private ingress alias | `PUBLIC_* ∪ PRIVATE_*`      |

Development is the one environment with two live ingresses, so it is the one environment whose
`config.hosts` is a union. That is a consequence of the rule above, not an exception to it: each
ingress delivers a `Host` from its own family, and Rails must admit the `Host` it actually receives
from each.

`/health` and the three singular text probe paths (`/health/{liveness,readiness,startup}`) are the
deliberate exception: orchestrator and container probes reach the origin directly and carry no
meaningful `Host`, so production excludes those exact paths from Host Authorization
(`lib/health_probe_paths.rb`) rather than allowlisting a probe hostname. The machine JSON endpoints
`/api/v0/health.json` and `/api/v0/revision.json` are reached through the tunnel with a real `Host`
and are deliberately not exempt.

**A third hostname family is not justified.** Every observed request path resolves its `Host` to a
member of one of the two existing families. The Workers VPC path is the only one where the value is
a free choice rather than a consequence, and that choice is between the two existing families — see
"Workers VPC Host Header" below. The historical defect was never a missing family; it was Host
Authorization consuming the wrong family for its environment.

## Development Is Tunnel-Exposed Behind Access

Development Rails **is** published through Cloudflare Tunnel under the browser-facing site names,
with Cloudflare Access as the perimeter in front of them. This is a deliberate, supported access
path, not a leak: reaching development requires passing an Access policy at the Cloudflare edge
before the connector will proxy anything, and Rails authentication and authorization still apply
behind it (see "Trust Domains" below — Access is a perimeter, never Rails' identity system).

Development is therefore reachable two ways, and both must work:

- through the tunnel, where the request carries the browser's public site name, because cloudflared
  leaves `Host` unmodified unless `httpHostHeader` is set;
- directly on the compose `frontend` network through the private `*.localhost` aliases, which is how
  local Edge processes and the transport probe in `docs/operations/cloudflare-private-origin.md`
  reach Rails.

### How the two families reach Host Authorization

`config/environments/development.rb` builds `config.hosts` from the environment rather than a
hardcoded list, so `compose.yaml` stays the single source of hostnames — a new tunnel hostname is
added there, not in Rails config:

1. `compose.yaml` aliases both the private `*.localhost` origins and the published site names to the
   `core` container on the `frontend` network, so a Tunnel ingress rule's `service:` address
   resolves.
2. `development.rb` reads both `PRIVATE_*_URL` and `PUBLIC_*_URL` values into `env_host_keys`.
3. `boot_config` is passed through unfiltered. `ConfigValues::HostFamilyValues` resolves several
   families to browser-facing names in development (`#auth_key`, `#base_key`, `#side_key` fall back
   to `PUBLIC_AUTH_*`/`PUBLIC_BASE_*`/`PUBLIC_SIDE_*_URL`), which is what the other consumers need
   anyway: route constraints, the CSP form-action allowlist, and the OIDC authority all read
   `PUBLIC_*`.

`test/config/host_authorization_contract_test.rb` guards the result in both directions: the
published site names are accepted, and an Umaxica-owned hostname that no `PUBLIC_*_URL` names is
still rejected — admitting the published names must not degrade into admitting the whole `umaxica.*`
domain. It also asserts that every non-`*.localhost` alias in `compose.yaml` is backed by a
`PUBLIC_*_URL` value in the same file, so an alias can never outlive the configuration that makes
Rails accept it.

### Scheme and cookie behaviour on the tunnel path

- **Scheme trust is not a blocker.** `ENV["TRUSTED_PROXIES"]` is unset and development sets neither
  `assume_ssl` nor `force_ssl`, but Rack 3.1's `Rack::Request#scheme` honours the
  `X-Forwarded-Proto: https` that the Cloudflare edge sets and cloudflared passes through without
  gating it on the peer being a trusted proxy. Verified in this repository's development
  environment: a request with `Host: auth.umaxica.com` and `X-Forwarded-Proto: https` yields
  `request.base_url == "https://auth.umaxica.com"` and `request.ssl? == true`, so `Origin` matches
  and non-GET requests pass CSRF.
- **Cookie hardening is partial and deliberate.** `JitSessionCookieConfig.force_secure?` is `false`
  in development, so the session cookie is emitted without `Secure` and without the `__Host-` prefix
  even when it is set over the tunnel on a public domain. `CoreCookieOptions` is per-request
  (`Rails.env.production? || FORCE_SECURE_COOKIES=1 || request.ssl?`) and does mark its cookies
  `Secure` on that path, so the two differ. `FORCE_SECURE_COOKIES=1` is the lever that closes the
  gap, at the cost of the plain-`http` `*.localhost` path: `Secure` cookies are not sent back over
  `http`, so enabling it breaks local sign-in outside the tunnel. Left off so both paths stay
  usable; turn it on for a development session that only uses the tunnel.

## Trust Domains

| Domain            | Purpose                                                | Never used for                                                                                                    |
| ----------------- | ------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| Cloudflare Tunnel | Selected externally reachable Rails ingress            | Service-to-service (Workers / Edge) traffic                                                                       |
| Workers VPC       | Cloudflare Worker / Edge -> Rails, service-to-service  | Public browser traffic, operator access                                                                           |
| Cloudflare Access | Perimeter for explicitly protected hostnames           | Rails' primary identity system — Rails authentication and authorization remain authoritative regardless of Access |

## Request Paths

### 1. Public browser request through Cloudflare

```text
Browser --(HTTPS)--> Cloudflare edge --(QUIC tunnel)--> cloudflared (compose: cloudflare-tunnel)
  --(private `frontend` network)--> core (Rails)
```

- `cloudflared` is the unprofiled `cloudflare-tunnel` service in `compose.yaml` (image
  `cloudflare/cloudflared:2026.8.2`,
  `tunnel --no-autoupdate --protocol auto --metrics 0.0.0.0:2000 run`, and `TUNNEL_TOKEN` resolved from the
  gitignored repository `.env`). A plain Compose `up` and the Dev Container lifecycle both start
  it. The alternative connector stays behind `--profile tunnel-edge`. It is the
  only component on the `frontend` network besides `core` itself.
- The connector is attached only to Global's private `frontend` network. Edge and Global do not
  share a Podman network. An Edge Worker reaches Rails through its Cloudflare Workers VPC Service
  binding and this tunnel, including `remote: true` binding behavior during local Worker
  development.
- `core` never publishes a host port in the base `compose.yaml` — verified by
  `test/unit/security/tunnel_origin_isolation_test.rb`. This is the actual security boundary:
  nothing outside the compose project's private networks can reach Rails directly.
- Headers Cloudflare's edge sets and the client cannot override: `CF-Connecting-IP`, `CF-Ray`,
  `CF-IPCountry`. Headers the client _can_ set and Cloudflare may append to (not replace) if already
  present: `X-Forwarded-For`.
- Rails currently derives `request.remote_ip` from `X-Forwarded-For` via `ActionDispatch::RemoteIp`,
  using the framework default `trusted_proxies` (RFC1918 private ranges) — `config/application.rb`'s
  `TrustedProxiesConfig` machinery is a no-op today because `ENV["TRUSTED_PROXIES"]` is never set
  anywhere in the repo.
- **Verified property, not a desired one**: `ActionDispatch::RemoteIp` does not gate trust on
  whether the immediate peer (`REMOTE_ADDR`) is itself a trusted proxy — it only strips proxy-hop
  IPs found _within_ the `X-Forwarded-For` chain. A request that reached Rails directly, bypassing
  `cloudflared`, could set an arbitrary `X-Forwarded-For` and have it trusted regardless of
  `trusted_proxies` value. See `test/unit/security/tunnel_origin_isolation_test.rb` for the
  reproducible proof (no live infrastructure required). **The real control is network isolation**
  (previous paragraph), not the `trusted_proxies` value itself.
- **Decision**: do not widen `trusted_proxies` to Cloudflare's public IP ranges — there is no
  evidence Rails ever receives a connection directly from those addresses (it only ever sees
  `cloudflared`'s private network address). Do not implement a custom `CF-Connecting-IP` reader
  either: Rails' `ActionDispatch::RemoteIp` has no configurable header name (verified —
  `forwarded_for`/`client_ip` are hardcoded to `X-Forwarded-For`/`Client-Ip` in Rack, not
  configurable), so honoring `CF-Connecting-IP` would require new custom middleware. Given the
  network isolation invariant already holds and is regression-tested, that additional middleware is
  not currently justified — revisit only if a feature specifically needs Cloudflare's more precise
  client-IP header.

### 2. Operator/browser request through Cloudflare Access

```text
Browser --(HTTPS, Access cookie/JWT)--> Cloudflare edge --(Access policy check)-->
  cloudflared --(originRequest.access JWT validation, if configured)--> core (Rails)
```

- Cloudflare Access is a perimeter, not Rails' identity system. Rails authentication and
  authorization (session/credential ceremonies, MFA, passkeys) remain authoritative for every
  request, Access-protected or not.
- `cloudflared` supports validating the Access JWT itself before proxying, via
  `originRequest.access` (`required`, `audTag`, `teamName`) per hostname. This is the preferred
  validation point — it runs before the request reaches Rails at all.
- **The development tunnel hostnames are Access-protected, and that protection lives in the
  Cloudflare account, not in this repository.** This remotely managed connector authenticates with
  the tunnel-scoped token described in `docs/operations/cloudflare-private-origin.md`, so its ingress
  rules and `originRequest.access` blocks are configured in the Cloudflare dashboard; no file here
  can assert they are present. Treat "the Access application exists and the published development
  route enables Access validation" as an external check, in the sense of the "External Checks"
  section of `docs/operations/cloudflare-private-origin.md` — the repository-side controls (network
  isolation, Host Authorization, Rails authentication) do not depend on it, but the confidentiality
  of the development surface does. Record the hostname, `audTag`, and `teamName` here once they are
  settled.
- Rails does not validate `Cf-Access-Jwt-Assertion` itself and should not, unless a specific feature
  needs to consume Access identity/claims directly — none does today. Adding Rails-side validation
  merely for "defense in depth" duplicates the connector-side check without a concrete requirement
  driving it.

### 3. Worker / Edge request through Workers VPC

```text
Cloudflare Worker (fetch()) --(Workers VPC binding)--> VPC Service (bound to a Tunnel ID)
  --(private tunnel connection)--> core (Rails)
```

- Workers VPC binds to a Tunnel-registered VPC Service and proxies an absolute-URL `fetch()` request
  to the target host/port over that tunnel connection — it reuses the same Cloudflare Tunnel
  infrastructure as path 1, not a separate ingress. Workers VPC requires cloudflared `2025.7.0` or
  newer; `compose.yaml` pins the supported `2026.8.2` release because Cloudflare supports
  cloudflared releases for one year.
- This path does not currently exist in the repository — no VPC Service or Worker binding is
  configured. This section documents the intended architecture per your Q5 answer (Workers VPC is a
  distinct, retained trust domain, not a Tunnel replacement) for when that work is scoped.
- Authentication for this path, once implemented, should be evaluated on its own threat model (a
  Worker is a Cloudflare-controlled, non-browser client) rather than reusing the browser-facing
  Access flow.

#### Workers VPC Host header — an explicit design decision

Because the VPC Service configuration alone decides routing, the `Host` the Worker sends is free of
the network path and must be chosen deliberately. It remains a choice **between the two existing
families**; it is not grounds for a third.

- **`PUBLIC_*`** keeps one rule true in production — Rails always sees the public site name — so
  `config.hosts` stays a single family, and the value already matches the surface route constraints,
  which are `PUBLIC_*`-derived.
- **`PRIVATE_*`** would make the `Host` describe the private ingress instead, forcing production
  `config.hosts` to become a `PUBLIC_* ∪ PRIVATE_*` union solely to admit this one caller, and
  splitting the production rule in two.

**Decided** by `adr/core-canonical-public-host.md`: the Worker sends a `Host` from the `PUBLIC_*`
family and does **not** set `X-Forwarded-Host`. The `Host` must be a narrowly allowlisted Umaxica
surface hostname that matches the surface route constraint — for Core that is
`jp.umaxica.{app,com,org}`, the canonical family chosen by the same ADR.

Omitting `X-Forwarded-Host` is part of the decision, not an incidental detail: per the Host
Authorization note above, setting it would add a second name to admit and could force the
`PUBLIC_* ∪ PRIVATE_*` union that choosing `PUBLIC_*` for `Host` exists to avoid.

## Header Trust Summary

| Header                    | Set by                                                    | Forgeable by a direct-access attacker (network isolation intact)? | Forgeable if network isolation is ever broken?                                                 |
| ------------------------- | --------------------------------------------------------- | ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `CF-Connecting-IP`        | Cloudflare edge only                                      | No (Rails doesn't read it)                                        | Yes, trivially — Rails has no way to distinguish a real edge from a direct attacker            |
| `X-Forwarded-For`         | Cloudflare edge (appends), `cloudflared` (passes through) | No — attacker cannot reach `core` at all                          | Yes — `ActionDispatch::RemoteIp` trusts it regardless of peer, per the verified property above |
| `Cf-Access-Jwt-Assertion` | Cloudflare Access, after policy evaluation                | No (Rails doesn't validate it; connector should)                  | Cryptographically signed — not forgeable even with direct access, unlike the IP headers above  |

## Non-Goals of This Document

- Does not implement Workers VPC, and does not configure Access JWT validation for any hostname —
  the connector is remotely managed, so that configuration is not expressible here. Record
  `audTag`/`teamName` above once they are settled.
- Does not add Rails-side `CF-Connecting-IP` support — no feature currently needs it, and adding
  custom middleware for it now would be unjustified scope.
