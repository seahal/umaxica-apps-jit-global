# Development Cloudflare Tunnel + Access Verification

Verification date: 2026-08-10 (UTC) Scope: development only. Production Tunnel, Access, DNS, and
deployment were not touched. Core was brought into scope late in the session and is covered in its
own section below; the Edge (Next.js and Hono) applications were not. Environment:
`global-devcontainer-core` container, Rails development on `0.0.0.0:3000`.

This note records a one-time verification run. It is evidence of what was observed on the date
above, not a standing contract. The repeatable contract is
`docs/operations/cloudflare-private-origin.md`; the trust-boundary model is
`docs/architecture/cloudflare-request-paths.md`.

## Verified Path

```text
Internet
  |
  v
Cloudflare Access            (umaxica.cloudflareaccess.com)
  |
  v
Cloudflare Tunnel            (cloudflare-tunnel, cloudflare/cloudflared:2025.7.0)
  |
  v
Development host
  |
  v
rootless Podman              (compose project umaxica-apps-global-dc, frontend network)
  |
  v
Rails (core container, port 3000)
```

The connector is defined in `compose.custom.yaml`, attached to the `frontend` network only. The base
`compose.yaml` publishes no host port for `core`; the devcontainer override publishes `3000:3000`
for local development.

Superseded on 2026-08-11 as a description of the connector: it now also joins the external
`umaxica-edge-tunnel` network. The sentence above stands as what was observed on the verification
date. See `research/implementation/2026-08-11-cloudflare-tunnel-edge-network-join.md`.

Superseded on 2026-08-16 as a description of the host publication: the override now publishes
`127.0.0.1:3000:3000` rather than `3000:3000`, so Rails is no longer bound to every host interface.
The tunnel path recorded here is unaffected — the connector reached Rails over the `frontend`
network then and still does — and the `0.0.0.0:3000` in the environment line at the top of this note
refers to the container-side listener, which is unchanged. See
`docs/operations/development-host-port-exposure.md`.

## Measurement Method

Podman DNS resolves the published site names to the `core` container, because `compose.yaml` carries
both the private `*.localhost` aliases and the published site names on the `frontend` network. A
plain `curl https://auth.umaxica.app/` from inside the container therefore never leaves the host and
proves nothing about Cloudflare.

External checks below forced a real round trip through the Cloudflare edge:

```bash
curl --resolve auth.umaxica.app:443:104.21.91.80 https://auth.umaxica.app/
```

Every external response carried `server: cloudflare` and a `cf-ray` value, confirming the request
reached the edge. Local origin checks sent the `Host` header directly to `127.0.0.1:3000`.

## Route Table

`/` answers `302` to `/?ri=jp` on every browser surface. That is the region-selection redirect in
`app/controllers/concerns/preference_global.rb:241`, not a routing fault, so the expected result
column records the post-redirect state.

| Application | Runtime | External FQDN         | Local origin         | Port | Path      | Expected result |
| ----------- | ------- | --------------------- | -------------------- | ---- | --------- | --------------- |
| Auth (app)  | Rails   | `auth.umaxica.app`    | `auth.app.localhost` | 3000 | `/?ri=jp` | 200, `Sign App` |
| Auth (com)  | Rails   | `auth.umaxica.com`    | `auth.com.localhost` | 3000 | `/?ri=jp` | 200, `Sign Com` |
| Auth (org)  | Rails   | `auth.umaxica.org`    | `auth.org.localhost` | 3000 | `/?ri=jp` | 200, `Sign Org` |
| Side (app)  | Rails   | `side-jp.umaxica.app` | `side.app.localhost` | 3000 | `/?ri=jp` | 200, `Side App` |
| Side (com)  | Rails   | `side-jp.umaxica.com` | `side.com.localhost` | 3000 | `/?ri=jp` | 200, `Side Com` |
| Side (org)  | Rails   | `side-jp.umaxica.org` | `side.org.localhost` | 3000 | `/?ri=jp` | 200, `Side Org` |
| Palm (app)  | Rails   | `palm-jp.umaxica.app` | `palm.app.localhost` | 3000 | `/`       | 200, `Palm App` |
| Base (app)  | Rails   | `www.umaxica.app`     | `base.app.localhost` | 3000 | `/?ri=jp` | 200, `Base App` |
| Base (com)  | Rails   | `www.umaxica.com`     | `base.com.localhost` | 3000 | `/?ri=jp` | 200, `Base Com` |
| Base (org)  | Rails   | `www.umaxica.org`     | `base.org.localhost` | 3000 | `/?ri=jp` | 200, `Base Org` |
| Core (app)  | Rails   | `jp.umaxica.app`      | `core.app.localhost` | 3000 | `/?ri=jp` | 200, `Core App` |
| Core (com)  | Rails   | `jp.umaxica.com`      | `core.com.localhost` | 3000 | `/?ri=jp` | 200, `Core Com` |
| Core (org)  | Rails   | `jp.umaxica.org`      | `core.org.localhost` | 3000 | `/?ri=jp` | 200, `Core Org` |

Host Authorization accepts both hostname families in development. The private `*.localhost` entries
in `config/environments/development.rb:150-180` all carry an explicit `:3000`, so a bare
`side.app.localhost` without a port is rejected while `side.app.localhost:3000` is accepted. That
asymmetry does not affect the tunnel path, because cloudflared leaves `Host` unmodified and forwards
the published site name.

## Local Origin Results

All ten surfaces returned the correct application and the correct surface. No cross-surface or
cross-application leakage was observed.

| FQDN as `Host`        | Status | `<title>`  |
| --------------------- | ------ | ---------- |
| `auth.umaxica.app`    | 200    | `Sign App` |
| `auth.umaxica.com`    | 200    | `Sign Com` |
| `auth.umaxica.org`    | 200    | `Sign Org` |
| `side-jp.umaxica.app` | 200    | `Side App` |
| `side-jp.umaxica.com` | 200    | `Side Com` |
| `side-jp.umaxica.org` | 200    | `Side Org` |
| `palm-jp.umaxica.app` | 200    | `Palm App` |
| `www.umaxica.app`     | 200    | `Base App` |
| `www.umaxica.com`     | 200    | `Base Com` |
| `www.umaxica.org`     | 200    | `Base Org` |

### Host And Protocol Recognition

Redirect targets mirror the inbound `Host`. No private `*.localhost` origin appeared in a redirect
generated for a published site name.

| Request                                              | Redirect target                   |
| ---------------------------------------------------- | --------------------------------- |
| `Host: auth.umaxica.app`, no forwarded header        | `http://auth.umaxica.app/?ri=jp`  |
| `Host: auth.umaxica.app`, `X-Forwarded-Proto: https` | `https://auth.umaxica.app/?ri=jp` |
| `Host: www.umaxica.app`, `X-Forwarded-Proto: https`  | `https://www.umaxica.app/?ri=jp`  |

Development sets neither `assume_ssl` nor `force_ssl`; the scheme upgrade comes from Rack honouring
`X-Forwarded-Proto`, which is what cloudflared sends. This is the behaviour
`docs/architecture/cloudflare-request-paths.md` relies on for CSRF origin matching over the tunnel.

## Unauthenticated Access Results

Every published Rails hostname redirected to the Access login before reaching the origin.

| External FQDN         | Status | Location                                                                                   | Result                   |
| --------------------- | ------ | ------------------------------------------------------------------------------------------ | ------------------------ |
| `auth.umaxica.app`    | 302    | `https://umaxica.cloudflareaccess.com/cdn-cgi/access/login/auth.umaxica.app?...[REDACTED]` | PASS                     |
| `auth.umaxica.com`    | 302    | `https://umaxica.cloudflareaccess.com/cdn-cgi/access/login/auth.umaxica.com?...[REDACTED]` | PASS                     |
| `auth.umaxica.org`    | 302    | `https://umaxica.cloudflareaccess.com/cdn-cgi/access/login/auth.umaxica.org?...[REDACTED]` | PASS                     |
| `side-jp.umaxica.app` | 302    | `.../cdn-cgi/access/login/side-jp.umaxica.app?...[REDACTED]`                               | PASS                     |
| `side-jp.umaxica.com` | 302    | `.../cdn-cgi/access/login/side-jp.umaxica.com?...[REDACTED]`                               | PASS                     |
| `side-jp.umaxica.org` | 302    | `.../cdn-cgi/access/login/side-jp.umaxica.org?...[REDACTED]`                               | PASS                     |
| `palm-jp.umaxica.app` | 302    | `.../cdn-cgi/access/login/palm-jp.umaxica.app?...[REDACTED]`                               | PASS, but see Palm below |
| `www.umaxica.app`     | 302    | `.../cdn-cgi/access/login/www.umaxica.app?...[REDACTED]`                                   | PASS                     |
| `www.umaxica.com`     | 302    | `.../cdn-cgi/access/login/www.umaxica.com?...[REDACTED]`                                   | PASS                     |
| `www.umaxica.org`     | 302    | `.../cdn-cgi/access/login/www.umaxica.org?...[REDACTED]`                                   | PASS                     |

The Access login URL carries a signed `meta` assertion as a query parameter. It is redacted here and
must stay redacted in any future copy of this table.

### Origin Isolation Probe

A 302 at the edge does not by itself prove the origin never saw the request. A nonce probe closes
that gap:

1. Request a random path over the external path: `GET https://auth.umaxica.app/<nonce>-external`,
   forced to the Cloudflare edge. Result: `302` to the Access login.
2. Request the sibling path directly at the origin: `GET http://127.0.0.1:3000/<nonce>-local` with
   `Host: auth.umaxica.app`. Result: `404`.
3. Search `log/development.log` for both nonces.

| Nonce              | Occurrences in origin log                                                      |
| ------------------ | ------------------------------------------------------------------------------ |
| `<nonce>-external` | 0                                                                              |
| `<nonce>-local`    | 1 (`ActionController::RoutingError (No route matches [GET] "/<nonce>-local")`) |

The local control proves the log records unrouted paths. The external nonce is absent, so the
unauthenticated request was terminated at Cloudflare Access and never reached Rails. PASS.

Two edge-served responses are not origin traffic and must not be read as an Access bypass:
`/cdn-cgi/trace` (always synthesized at the edge) and `/robots.txt` (Cloudflare Managed robots.txt;
its body differs from the Rails-served `/robots.txt`, confirming the edge answered).

## Authenticated Access Results

An operator authenticated through Access in a browser and reported reaching
`https://auth.umaxica.{app,com,org}` and `https://www.umaxica.{app,com,org}`. That claim was checked
against origin-side records rather than accepted as-is.

Preference audit rows persist the client address. Loopback rows are the verification probes
described above; the public IPv6 rows are browser traffic that arrived through Access and the
tunnel, because nothing else can present a public client address to this origin.

| Table                       | Loopback rows | Public IPv6 client rows | First seen (UTC) | Last seen (UTC) |
| --------------------------- | ------------- | ----------------------- | ---------------- | --------------- |
| `app_preference_chronicles` | 58            | 10                      | 09:10:10         | 12:52:52        |
| `com_preference_chronicles` | not counted   | 26                      | 08:58:38         | 12:55:28        |
| `org_preference_chronicles` | not counted   | 10                      | 08:58:47         | 12:55:35        |

The client address is recorded as `2001:3b0:...[REDACTED]`. All three surfaces — app, com, and org —
received authenticated traffic.

The development log corroborates this with request types `curl` cannot produce:

- `Processing by Rails::PwaController#service_worker as JS`
- `Processing by Auth::Com::CspViolationReportsController#create`
- `Processing by Base::App::CspViolationReportsController#create`
- `Processing by Base::Com::CspViolationReportsController#create`
- `Processing by Base::Org::CspViolationReportsController#create`

Content Security Policy reports and service-worker fetches are emitted by browsers only.

### Side, Measured Against A Recorded Baseline

Side was exercised separately with a before-and-after baseline so the new rows could not be confused
with the verification probes. Baseline taken at 13:13:34 UTC: public-client rows 10 / 26 / 10 for
app / com / org, and 12 `Side::` controller entries in the log, all of them from probes.

An operator then opened the three Side hostnames through Access in a browser. Rows added after the
baseline, all from the same public IPv6 client:

| Surface | Rows added | Occurred at (UTC) |
| ------- | ---------- | ----------------- |
| app     | 4          | 13:14:00          |
| com     | 2          | 13:14:08          |
| org     | 2          | 13:14:15          |

Public-client totals moved 10 → 14, 26 → 28, and 10 → 12. `Side::` controller entries moved 12 → 24,
and the new entries are:

- `Processing by Side::App::RootsController#index as HTML` and
  `Side::App::CspViolationReportsController#create`
- `Processing by Side::Com::RootsController#index as HTML` and
  `Side::Com::CspViolationReportsController#create`
- `Processing by Side::Org::RootsController#index as HTML` and
  `Side::Org::CspViolationReportsController#create`

Each surface answered under its own controller namespace, with `as HTML` rather than the probes'
`as */*`, and each emitted a browser-only Content Security Policy report. The timestamps are
sequential and match three tabs being opened in order. Side app, com, and org therefore each
completed the full path.

### Palm, Browser Surface Only

Palm was also opened through Access in a browser at approximately 13:17 UTC. Palm keeps no
preference chronicle, so the evidence is the log alone. Requests separate cleanly by `Accept`,
because the verification probes sent `*/*` and a browser sends `HTML`:

| Entry                                             | Count | Source                 |
| ------------------------------------------------- | ----- | ---------------------- |
| `Palm::App::RootsController#index as */*`         | 5     | verification probes    |
| `Palm::App::RootsController#index as HTML`        | 4     | browser through Access |
| `Palm::App::CspViolationReportsController#create` | 4     | browser through Access |

Palm's HTML root therefore completes the full path, and the four Content Security Policy reports
confirm a browser rendered the page rather than merely fetching it.

This does **not** clear Palm's API. `Palm::App::Api::V0::ProfilesController#show` was exercised only
by probes without a valid bearer token, all returning `401`. The cookie-rejection defect described
below could not be isolated empirically, because both a cookie-bearing request and a request with no
valid token produce the same `401 authentication_required` response, and no valid token was minted
for this run. The defect is read from the controller source, not measured. Palm's API remains
unverified under Access.

| Surface              | Authenticated result                                            |
| -------------------- | --------------------------------------------------------------- |
| Auth app / com / org | PASS                                                            |
| Base app / com / org | PASS                                                            |
| Side app / com / org | PASS                                                            |
| Palm app, HTML root  | PASS                                                            |
| Palm app, `/api/*`   | NOT VERIFIED — interactive Access is contraindicated, see below |

Audit rows record the surface (app, com, org) but not the application, so the split between Auth and
Base rests on the operator report plus the controller names in the log, not on the audit table
alone. Side is not subject to that ambiguity: its controller namespaces appear in the log directly.

## Negative Test Results

| Test                                         | Observed                                                         | Result |
| -------------------------------------------- | ---------------------------------------------------------------- | ------ |
| `.app` request reaching a `.com` application | Never; each TLD rendered its own surface                         | PASS   |
| `.com` request reaching a `.org` application | Never                                                            | PASS   |
| Auth / Side / Base / Palm confusion          | Never; titles matched the intended application                   | PASS   |
| Unknown host handled as a valid application  | `Host: evil.example.com` → 403 `Blocked hosts: evil.example.com` | PASS   |
| Internal-only surface exposed publicly       | `www.umaxica.net` → 403 at origin, and NXDOMAIN publicly         | PASS   |
| Core reconfigured by accident                | Core was later published deliberately; see the Core section      | N/A    |
| Workers VPC path disturbed                   | No connector, compose, alias, or route change made               | PASS   |
| Docs / News / Help confusion                 | Not applicable; none are published                               | N/A    |

`www.umaxica.net` is rejected by design. The `net` surface is private-only: `compose.yaml` sets
`PRIVATE_BASE_NETWORK_URL=base.net.localhost` and there is no `PUBLIC_BASE_NETWORK_URL`, the route
constraint in `config/routes/base.rb:582` lists only the private names, and `www.umaxica.net` is not
a `frontend` alias. Its `net` routes are health probes and a CSP sink. The 403 is the correct
outcome, not a defect.

`www.umaxica.dev` behaves differently and is also not a Rails fault. The `umaxica.dev` zone is
delegated to Vercel (`ns1.vercel-dns.com`, `ns2.vercel-dns.com`), and an external request returns
`200` with `server: Vercel`. No Cloudflare Access or Tunnel sits in that path, so Rails is never
reached, even though `PUBLIC_BASE_DEVELOPER_URL=www.umaxica.dev` and the origin answers `200` for
that `Host` locally. Publishing the Base developer surface would require moving the hostname onto
the Cloudflare zone and adding a tunnel route.

## Findings Requiring An Operator Decision

These are Cloudflare account changes. They were not made.

### Palm should not carry interactive Access

`palm-jp.umaxica.app` currently sits behind an Access application. Palm is an API surface, not a
browser surface: `config/routes/palm.rb` defines an OIDC RP plus a versioned bearer-token API, and
`app/controllers/palm/app/api/v0/base_controller.rb` documents its endpoints as "bearer-token
resource-server endpoints".

That controller rejects any request carrying a cookie before it evaluates the bearer token:

```ruby
if request.cookie_jar.to_hash.present? || request.headers["Cookie"].to_s.present?
  render_palm_authentication_error("invalid_token")
  return false
end
```

Cloudflare Access issues a `CF_Authorization` cookie and forwards it to the origin. A browser that
successfully passes Access therefore fails Palm's own API authentication. A native iOS or Android
client cannot complete an interactive Access login at all and would receive the login redirect
instead of a JSON error.

Options, in order of preference: remove the interactive Access application from
`palm-jp.umaxica.app`; or keep it and bypass `/api/*`; or replace interactive Access with an Access
service token for machine clients. Palm is held pending that decision.

### `core-jp.umaxica.app` is a published dead end

`core-jp.umaxica.app` resolves through Cloudflare and returns an Access login redirect, but the
origin answers `403 Blocked hosts: core-jp.umaxica.app`. It is in no `config.hosts` entry, and
`test/config/host_authorization_contract_test.rb` asserts that rejection deliberately. It is not the
canonical Core hostname — `adr/core-canonical-public-host.md` names `jp.umaxica.{app,com,org}`,
which were published later in this session and work. `core-jp.umaxica.*` is therefore a legacy name
that still resolves and still fails at the origin. Recorded for the Core work stream; not changed
here.

### Root hostnames return 530

Before Core was published, `umaxica.app`, `umaxica.com`, and `umaxica.org` each returned `301` to
`https://jp.umaxica.<tld>/`, and `umaxica.net` returned `301` to `https://jp.umaxica.app/`, all of
which were NXDOMAIN at the time.

Publishing Core did not fix this. After `jp.umaxica.*` went live, all four apex hostnames returned
`530` instead. The apex needs its own tunnel route or redirect rule; it is not covered by the
`core-jp` Access application or the Core tunnel routes. Unresolved at the end of this session.

## Core

Core was published during this session, after the ten hostnames above. Its canonical hostnames are
`jp.umaxica.{app,com,org}` per `adr/core-canonical-public-host.md`, routed to
`http://core.{app,com,org}.localhost:3000`.

Rails needed no change to accept them. `compose.yaml` already carried the `jp.umaxica.*` aliases and
the `PUBLIC_CORE_*_URL` values, `config/routes/core.rb` already constrained on them, and all three
realms rendered `Core App`, `Core Com`, and `Core Org` correctly at the origin before any tunnel
route existed.

### Rails-Owned Core Paths

Checked at the origin with `Host: jp.umaxica.app`, against the route table in
`docs/operations/core-nextjs-zero-cookie-edge-contract.md`:

| Path                                 | Status | Note                                                    |
| ------------------------------------ | ------ | ------------------------------------------------------- |
| `/`                                  | 302    | region redirect, then Core root                         |
| `/.well-known/jwks.json`             | 200    |                                                         |
| `/robots.txt`                        | 200    |                                                         |
| `/sitemap.xml`                       | 200    | 500 before the fix below                                |
| `/api/v0/session`                    | 503    | `Core browser API is not enabled` — expected, see below |
| `/web/v0/theme`                      | 302    |                                                         |
| `/oidc/authorization`                | 302    |                                                         |
| `/_next/static/...`                  | 404    | correct: falls to Next.js at the edge                   |
| any unrouted page                    | 404    | correct: falls to Next.js at the edge                   |
| `/configuration` on `jp.umaxica.org` | 302    | org-only route                                          |
| `/configuration` on `jp.umaxica.app` | 404    | correctly absent on the app realm                       |

The `/api/v0/session` 503 returns
`{"code":"service_unavailable","message":"Core browser API is not enabled."}`. That is
`CORE_BROWSER_JWT_COOKIE_ENABLED` being unset, which
`adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md` requires as a production
blocker until the edge contract is enforced. It is the intended state, not a fault.

### Access Was Absent At First, And The Origin Was Publicly Reachable

Between the tunnel routes being created and the Access application being created, all three Core
hostnames were reachable from the internet without authentication. This is recorded because it is
the one interval in this session where the perimeter did not hold, and because it shows what the
absence of Access looks like from outside.

During that window an unauthenticated external request to `https://jp.umaxica.app/` returned `302`
to `https://jp.umaxica.app/?ri=jp` — Rails' own region redirect, not an Access login. The response
carried `server-timing: sql.active_record;dur=13.69` and eleven `Set-Cookie` headers, so Rails had
executed queries and issued cookies to an anonymous internet client. A nonce probe confirmed origin
reach directly:

| Host                       | Unauthenticated result | Origin log occurrences |
| -------------------------- | ---------------------- | ---------------------- |
| `jp.umaxica.app/<nonce>`   | 404 from Rails         | 1 — reached the origin |
| `auth.umaxica.app/<nonce>` | 302 to Access login    | 0 — blocked            |

The same method, run at the same time against an Access-protected hostname, produced the opposite
result. That contrast is what identifies the cause as a missing Access application rather than a
tunnel or Rails fault.

After the operator created the `core-jp` Access application, the probe was repeated:

| Host             | Status | `server-timing` present | Location     | Origin log |
| ---------------- | ------ | ----------------------- | ------------ | ---------- |
| `jp.umaxica.app` | 302    | no                      | Access login | 0          |
| `jp.umaxica.com` | 302    | no                      | Access login | 0          |
| `jp.umaxica.org` | 302    | no                      | Access login | 0          |

The disappearance of `server-timing` is itself evidence: the origin no longer generates the
response.

### Authenticated Core Traffic

Browser traffic separates from probe traffic by `Accept`, as elsewhere in this run:

| Realm    | `RootsController#index as HTML` | Content Security Policy reports |
| -------- | ------------------------------- | ------------------------------- |
| Core App | 9                               | 4                               |
| Core Com | 14                              | 7                               |
| Core Org | 6                               | 5                               |

Each realm answered under its own controller namespace, and each emitted browser-only Content
Security Policy reports. No cross-realm confusion was observed.

### Access Application Configuration

`core-jp` covers all three realms through `self_hosted_domains` and `destinations`, with a single
policy. Its settings match the other four applications; see the inventory below. Nothing was changed
in the Cloudflare account.

Two items are carried forward as concerns, both scoped to the `org` realm and to production. Neither
is a development problem, and neither was actioned.

### Core Sitemap Defect, Fixed

`jp.umaxica.{app,com,org}/sitemap.xml` returned `500` on all three realms with
`ActionView::MissingTemplate (Missing template core/app/sitemaps/show ...)`. All three Core sitemaps
controllers existed, but `app/views/core/{app,com,org}/sitemaps/` did not — Core was the only family
of the thirteen sitemaps controllers with no template.

Fixed by adding the three missing templates, identical to the empty urlset every other surface uses.
All thirteen surfaces now return `200 application/xml`. Rails Core serving an empty sitemap is
correct for this boundary: Next.js owns Core's public pages.

`test/integration/static_assets_endpoints_test.rb` listed only six of the thirteen sitemaps
controllers in `SITEMAP_SURFACES`, omitting Core, Auth, and Base app, which is why the defect
survived. All thirteen are now listed. Route contract tests could not have caught this — routing
recognised `/sitemap.xml` correctly and only rendering failed. The added coverage was confirmed to
fail when a template is removed and pass when it is restored.

## Access Application Inventory

Five self-hosted Access applications cover the thirteen Rails hostnames, as configured in the
Cloudflare account on 2026-08-10. Recorded from the operator's configuration export. Identifiers
below are Cloudflare resource IDs, not credentials, and are truncated.

| Application | Hostnames                       | `allowed_idps`         | Policy       | Session |
| ----------- | ------------------------------- | ---------------------- | ------------ | ------- |
| `auth`      | `auth.umaxica.{app,com,org}`    | one IdP (`a6fdf3c0-…`) | `fe92c9ff-…` | 24h     |
| `www`       | `www.umaxica.{app,com,org}`     | empty — all IdPs       | `fe92c9ff-…` | 24h     |
| `core-jp`   | `jp.umaxica.{app,com,org}`      | empty — all IdPs       | `fe92c9ff-…` | 24h     |
| `side-jp`   | `side-jp.umaxica.{app,com,org}` | empty — all IdPs       | `fe92c9ff-…` | 24h     |
| `palm-jp`   | `palm-jp.umaxica.app`           | empty — all IdPs       | `fe92c9ff-…` | 24h     |

All five share these settings: `type: self_hosted`, `auto_redirect_to_identity: false`,
`app_launcher_visible: true`, `enable_binding_cookie: false`, `http_only_cookie_attribute: false`,
`options_preflight_bypass: false`. Each lists its hostnames in both `destinations` (as `public`,
with the owning `zone_name`) and `self_hosted_domains`.

Three observations follow from reading the five together rather than individually.

**All five reference the same policy.** One policy object governs every Rails surface, so there is
currently no way to admit a principal to one surface and not another beyond the application split
itself. The policy body was not visible from the repository; the measurements in this note prove
only that it denies an unauthenticated client, not which principals it admits.

**`auth` is the only application that restricts identity providers.** It names a single IdP; `www`,
`core-jp`, `side-jp`, and `palm-jp` leave `allowed_idps` empty, which admits every IdP configured on
the account. The asymmetry may be deliberate — Auth is the credential gateway — but it means the
corporate and staff realms of Base, Core, and Side accept a broader set of identity sources than
Auth does. Worth confirming against intent.

**Four of the five applications span `app`, `com`, and `org` in one object.** With one policy and a
24h session shared across the three, a single authenticated session admits a principal to all three
realms of that family.

### Carried Forward: The `org` Realm In Production

`http_only_cookie_attribute: false` and the shared-application shape are accepted as-is for
development. The decision on this run is explicit: development does not need them changed, and they
are not treated as defects here.

They do not carry over to production for the `org` realm, which is the one realm intended for
production use.

**Cookie attribute.** With `http_only_cookie_attribute: false`, `CF_Authorization` is readable by
JavaScript on the origin it is scoped to. For `jp.umaxica.org` that collides with
`adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`, which makes "JavaScript
cannot read the access token, refresh handle, or OIDC transaction state" a Core invariant. Set it to
`true` before the staff realm carries production traffic.

**Realm separation.** `AGENTS.md` treats `app`, `com`, and `org` as independent trust boundaries and
calls cross-surface leakage a security defect. Today one session and one policy span all three, so a
principal admitted to the staff realm is simultaneously admitted to the end-user and corporate
realms. Production needs `*.umaxica.org` split into its own Access application with its own policy,
so staff access can be governed — and revoked — independently. This applies to `auth`, `www`,
`core-jp`, and `side-jp` alike, not only Core.

Neither item is scheduled. Both are prerequisites for treating the `org` realm as production-ready,
not for the development reference implementation this note records.

## Verification Matrix

| External FQDN         | Tunnel | Unauthenticated Access | Authenticated Access  | Application |
| --------------------- | ------ | ---------------------- | --------------------- | ----------- |
| `auth.umaxica.app`    | PASS   | PASS                   | PASS                  | PASS        |
| `auth.umaxica.com`    | PASS   | PASS                   | PASS                  | PASS        |
| `auth.umaxica.org`    | PASS   | PASS                   | PASS                  | PASS        |
| `www.umaxica.app`     | PASS   | PASS                   | PASS                  | PASS        |
| `www.umaxica.com`     | PASS   | PASS                   | PASS                  | PASS        |
| `www.umaxica.org`     | PASS   | PASS                   | PASS                  | PASS        |
| `side-jp.umaxica.app` | PASS   | PASS                   | PASS                  | PASS        |
| `side-jp.umaxica.com` | PASS   | PASS                   | PASS                  | PASS        |
| `side-jp.umaxica.org` | PASS   | PASS                   | PASS                  | PASS        |
| `palm-jp.umaxica.app` | PASS   | PASS                   | PASS (HTML root only) | PASS        |
| `jp.umaxica.app`      | PASS   | PASS                   | PASS                  | PASS        |
| `jp.umaxica.com`      | PASS   | PASS                   | PASS                  | PASS        |
| `jp.umaxica.org`      | PASS   | PASS                   | PASS                  | PASS        |

"Tunnel PASS" means an authenticated request was observed arriving at the origin from a public
client address. All thirteen hostnames meet that bar. Two qualifications: Palm's row covers its HTML
root only, and its `/api/*` routes were not verified under Access with its Access configuration
contraindicated regardless; and the Core rows record the state after the `core-jp` Access
application was created, having been unprotected for an interval earlier in the session.

## Known Exclusions

- Production deployment, production Tunnel, production Access policy, and production DNS.
- Core shared-FQDN routing. `jp.umaxica.{app,com,org}` are published and serve Rails Core on every
  path, which is not the end state. The edge route table in
  `docs/operations/core-nextjs-zero-cookie-edge-contract.md` splits those hostnames between Rails
  Core and Next.js Core with `Cookie` stripped on the Next.js rows, and none of that edge
  configuration exists yet. Adding Access also introduces a `CF_Authorization` cookie on the same
  origin, which the Next.js rows must strip along with everything else once that origin exists.
- The `Next.js` and `Hono` edge applications. That repository is not present in this environment,
  and `info.umaxica.*`, `docs-jp.umaxica.*`, `news-jp.umaxica.*`, and `help-jp.umaxica.*` are all
  NXDOMAIN, so there was nothing published to test.
- The apex hostnames. `umaxica.{app,com,org,net}` return `530` and were not fixed.
- The `core-jp` Access policy body and its `http_only_cookie_attribute` / single-application
  concerns. Recorded in the Core section; no Cloudflare account change was made.
- `bin/tunnel-origin-check` and any connector-side inspection. `podman` is not available inside the
  development container, so the connector-to-origin leg was not probed directly from the connector's
  network position.
- Workers VPC. Nothing on that path was exercised or changed.
- Palm's `/api/*` routes under Access. Isolating the cookie-rejection defect requires a valid bearer
  token, which this run did not mint.

## Secrets

No tunnel token, Cloudflare API token, Access assertion, JWT, `Authorization` header, cookie,
session identifier, OAuth token, API key, or credential is recorded in this note. Access login URLs
are truncated to `?...[REDACTED]`, and the browser client address is truncated to
`2001:3b0:...[REDACTED]`.
