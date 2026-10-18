# Core tunnel `/sign` path rule and IdP entry flow

- Date: 2026-10-02
- Commit: `845f84b281663786c4d4e0f6473fcf3ab2040b74`. The worktree had uncommitted changes to
  `.env.example`, `db/seeds.rb`, and an avatars migration; none of them touch routing or the tunnel
  path, so they did not affect this result. The Cloudflare dashboard change is external to the
  repository.

## Problem observed

`curl -sD- https://jp.umaxica.app/sign` (also `/` and `/health`) returned an empty `HTTP/2 300` with
only Cloudflare headers and no `x-request-id`. `log/development.log` gained no line for a probe
request (`/sign?probe=claude1`). The tunnel connector reported `readyConnections: 4`, and Rails
answered `Host: jp.umaxica.app` / `.org` / `.com` sent directly to `localhost:3000` with 200 on
`/sign?ri=jp`.

Cause: the `jp.umaxica.{app,com,org}` tunnel path rules were
`^/((api/v0|oidc|sign/out)(/.*)?|\.well-known/jwks\.json|csp-violation-report)$`, which excludes
`/sign` and `/sign/callback`.

## Change

The user changed the dashboard path to
`^/((api/v0|oidc|sign)(/.*)?|\.well-known/jwks\.json|csp-violation-report)$`. A local `grep -E`
check matched `/sign`, `/sign/`, `/sign/callback`, `/sign/out`, `/sign/out/edit`, `/api/v0/x`,
`/oidc/backchannel/logout`, `/.well-known/jwks.json`, `/csp-violation-report`, and rejected `/`,
`/signup`, `/signs`, `/health`. The value is recorded in
`docs/architecture/cloudflare-request-paths.md`.

## Result after the change

- `curl -sD- https://jp.umaxica.app/sign` → `HTTP/2 302`, `location: https://jp.umaxica.app/sign?ri=jp`,
  `x-request-id: d4d13052-3963-4bee-9e10-75b50c4b6400`, so the request reached Rails.
- Browser flow in `log/development.log` (app surface):
  1. `Core::App::Sign::EntriesController#show` on `jp.umaxica.app` → 302 to `/sign?ri=jp`, then 200.
  2. `Core::App::Sign::EntriesController#create` → `oidc.sso.pending_flow.created`
     (`client_id: core-app`) and redirect policy `jump` (request `1c31f844-dc51-484b-903f-f3230b5bfdf9`),
     302 to `jump.umaxica.net`.
  3. `Base::App::Oauth::AuthorizationsController#show` on `www.umaxica.app` with
     `redirect_uri=https://jp.umaxica.app/sign/callback` → 303, then 302 to `jump.umaxica.net`.
  4. `Auth::App::Sign::InsController#show` → 303 to `https://auth.umaxica.app/sign/in?ri=jp&transaction_ref=...`,
     then 200. `Auth::App::Sign::InsController#create` → 303 back to `/sign/in?ri=jp`, then 200.
- The org surface (`jp.umaxica.org`) showed the same shape through
  `Core::Org::Sign::EntriesController#create` and `Base::Org::Oauth::AuthorizationsController#show`.

## Not verified

The log after the change contains no sign-up controller request and no `/social/*` (Google, Apple)
request or callback. The flow reached the `auth.umaxica.app` sign-in page, but sign-up through an
IdP and the return to `https://jp.umaxica.app/sign/callback` were not observed.
