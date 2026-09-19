# Core Next.js Zero-Cookie Edge Contract

## Purpose

This repository does not currently contain deployable Cloudflare ruleset, Worker, or Terraform
configuration for the Core web edge. The Core browser JWT cookie transport is therefore disabled by
default and must not be enabled in production until the external Cloudflare configuration enforces
this contract and verification evidence is recorded.

## Public Core Host

Canonical public Core host for this boundary, chosen by `adr/core-canonical-public-host.md`:

- `jp.umaxica.app` (and `jp.umaxica.com`, `jp.umaxica.org` for the corporate and staff realms)

Current Rails defaults previously used `www.jp.umaxica.app` in some Core configuration, and the
legacy `jpx.umaxica.*` and `core-jp.umaxica.*` families are still accepted by production Host
Authorization during the cutover.

## Request Routing

The Rails-owned rows below are derived from `config/routes/core.rb`, which is the source of truth
for what Rails answers on the Core host. Every path Rails does not route falls to Next.js.

For `jp.umaxica.app`:

| Path                     | Origin           | Cookie forwarding             |
| ------------------------ | ---------------- | ----------------------------- |
| `/api/v0/*`              | Rails Core       | keep `Cookie`                 |
| `/oidc/*`                | Rails Core       | keep `Cookie`                 |
| `/sign/out`              | Rails Core       | keep `Cookie`                 |
| `/sign/out/complete`     | Rails Core       | keep `Cookie`                 |
| `/.well-known/jwks.json` | Rails Core       | keep `Cookie`                 |
| `/csp-violation-report`  | Rails Core       | keep `Cookie`                 |
| `/health`                | blocked publicly | no public origin              |
| `/health/*`              | blocked publicly | no public origin              |
| `/_next/*`               | Next.js Core     | remove entire `Cookie` header |
| `/` and all other paths  | Next.js Core     | remove entire `Cookie` header |

`/oidc/*` covers `/oidc/authorization`, `/oidc/callback`, and `/oidc/backchannel/logout`.
`/oidc/callback` and `/sign/out*` are the paths that set and clear the credential cookies, so
stripping `Cookie` from them breaks sign-in and sign-out. They must not be allowed to fall into the
"all other paths" row.

### Paths deliberately absent from this table

Earlier revisions routed `/auth/*` and `/sso/*` to Rails Core and `/settings`, `/settings/*` to Base
Rails. None of those exist as Rails paths:

- `auth` is a host family (`auth.umaxica.*`), drawn in `config/routes/auth.rb` under
  `constraints host:`. It is not a path prefix on the Core host.
- `/sso/*` has no route on any surface. `test/integration/routes/core_route_contract_test.rb`
  asserts `/sso/authorize` and `/sso/logout` are unroutable on Core.
- `/settings` and `/settings/*` are defined on the Auth and Side surfaces (`config/routes/auth.rb`,
  `config/routes/side.rb`), not Base. Base owns `/identity/*`, `/accounts`, and `/preference/*`.

The rows were removed rather than left as edge routes pointing at origins that would 404, which also
silently placed the real cookie-bearing Core paths in the Cookie-stripped fallback row.

For `side.jp.umaxica.app`:

| Path        | Origin     | Cookie forwarding             |
| ----------- | ---------- | ----------------------------- |
| `/api/v0/*` | Rails Side | remove entire `Cookie` header |

Selective auth-cookie stripping is not sufficient. The Next.js and Side origins must receive no
`Cookie` header at all.

## Response Header Rules

| Origin          | Response rule                                                     |
| --------------- | ----------------------------------------------------------------- |
| Rails Core/Base | allow `Set-Cookie` only on intended auth/session/preference paths |
| Next.js Core    | remove every `Set-Cookie` header                                  |
| Side            | remove every `Set-Cookie` header                                  |

Next.js toast, flash, and other UI state must use non-cookie state such as client memory, browser
storage, a URL nonce, hydration-time Rails API result, or non-sensitive public state.

## Manual Verification

Before setting `CORE_BROWSER_JWT_COOKIE_ENABLED=1` in production, record evidence for all of these:

1. A request to `https://jp.umaxica.app/_next/...` with a synthetic `Cookie` header reaches the
   Next.js origin without a `Cookie` header.
2. A request to a page route on `https://jp.umaxica.app/...` with a synthetic `Cookie` header
   reaches the Next.js origin without a `Cookie` header.
3. A response from Next.js that attempts to emit `Set-Cookie` reaches the browser without
   `Set-Cookie`.
4. A request to `https://jp.umaxica.app/api/v0/...` reaches Rails Core with the credential cookie
   header intact.
5. Requests to `https://jp.umaxica.app/oidc/callback`, `/sign/out`, `/sign/out/complete`, and
   `/api/v0/preferences/...` reach Rails Core with required cookies intact.
6. A request to `https://side.jp.umaxica.app/api/v0/...` with a synthetic `Cookie` header reaches
   Side without a `Cookie` header, and Side rejects any bypassed request that still contains one.
7. Public requests to `/health` and `/health/*` are blocked at the edge or return only the approved
   no-leak public behavior from `adr/internal-health-endpoint-edge-isolation.md`.

## Cloudflare Access Interaction

Development published `jp.umaxica.{app,com,org}` through Cloudflare Tunnel behind a Cloudflare
Access application on 2026-08-10. Rails Core answers every path on those hostnames today; the
Next.js origin does not exist yet, so the split above is not in force. Evidence:
`notes/implementation/2026-08-10-development-tunnel-access-verification.md`.

Two consequences for the work that implements this contract.

Access issues a `CF_Authorization` cookie scoped to the Core hostname, and the edge forwards it to
whichever origin serves the request. It is therefore covered by the "remove entire `Cookie` header"
rows above, not exempt from them. Verification items 1 and 2 must be run with an Access session
active, not only with a synthetic `Cookie` header, or they will pass while the real cookie still
reaches Next.js.

The `core-jp` application sets `http_only_cookie_attribute` to `false`, which makes
`CF_Authorization` readable by JavaScript on the Core origin, and spans `app`, `com`, and `org` in
one application with one policy and a shared session, so one authenticated session admits a
principal to all three realms.

Both are accepted for development and are not defects there. Both block treating `jp.umaxica.org` as
production-ready: the cookie attribute collides with this boundary's invariant that JavaScript
cannot read credential material, and the shared application prevents governing or revoking staff
access independently of the end-user and corporate realms, which `AGENTS.md` requires to stay
separate. Set `http_only_cookie_attribute` to `true` and give `jp.umaxica.org` its own application
with its own policy before the staff realm carries production traffic. Open, not actioned.

## Production Blocker

`CORE_BROWSER_JWT_COOKIE_ENABLED` must remain unset or false in production until the route table,
request stripping, response stripping, and health blocking above are deployed and verified.
