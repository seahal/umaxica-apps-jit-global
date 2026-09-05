# Development Cloudflare Tunnel + Access Verification, Replica Split

Verification date: 2026-09-01 (UTC). Scope: development only, one hostname
(`auth.umaxica.app`). Production Tunnel, Access, DNS, and deployment were not touched. Environment:
`core` container, Rails development on `0.0.0.0:3000`, connector
`umaxica-apps-global-dc_cloudflare-tunnel_1`.

This note records a one-time verification run. It is evidence of what was observed on the date
above, not a standing contract. The repeatable contract is
`docs/operations/cloudflare-private-origin.md`; the trust-boundary model is
`docs/architecture/cloudflare-request-paths.md`. The broad thirteen-hostname run is
`notes/implementation/2026-08-10-development-tunnel-access-verification.md`; this run does not
supersede it and does not repeat its coverage.

## What Prompted The Run

`auth.umaxica.app` returned intermittent `502 Bad gateway` with Cloudflare's diagnostic showing
`Cloudflare: Working` and `Host: Error`. The same hostname had served traffic minutes earlier.

## Root Cause

Tunnel `1d501e9a` carried two connector replicas with different origin reachability:

| Replica    | Container                               | Networks               | Reaches Rails |
| :--------- | :-------------------------------------- | :--------------------- | :------------ |
| `e691fec9` | `umaxica-apps-global-dc_cloudflare-tunnel_1` | this project's `frontend` | yes       |
| `f4762c38` | `umaxica-apps-edge-cloudflare-tunnel-1` | Edge project's networks | no            |

Cloudflare routes a request to any replica of a tunnel, so the same hostname succeeded or returned
`502` depending on which replica received it. This is the exact condition the "External Checks"
section of `docs/operations/cloudflare-private-origin.md` names:

> the tunnel has no replica in a network that cannot reach this Rails origin. Cloudflare may route
> traffic to any connector replica, so every replica for this tunnel must provide the same origin
> reachability.

The invariant was prose only. Nothing in the repository could detect the violation, and nothing
inside `core` can enumerate a tunnel's replicas — `podman` is absent there and the replica list
lives in the Cloudflare account.

## Measurement Method

Counters were read from the connector's own metrics endpoint (`--metrics 0.0.0.0:2000`, no host
port) before and after each browser attempt, and `log/development.log` was read by byte offset from
a baseline taken at the same moment. Pairing the two is what distinguishes "the request never
arrived" from "the request arrived and failed".

## Failing Run, Before The Fix

Browser reported `502`, `Host: Error`, Tokyo, 2026-09-01 15:20:12 UTC.

| Signal                             | Baseline 15:14:21 | After the 502 |
| :--------------------------------- | :---------------- | :------------ |
| `cloudflared_tunnel_total_requests` | 688              | 689           |
| `cloudflared_tunnel_request_errors` | 101              | 101           |
| Rails controller actions logged     | —                 | 0             |

The healthy connector answered `/ready` with `200` and four ready connections throughout, on edge
locations `nrt15`/`nrt10`/`nrt16`/`nrt01`, with an 8 ms RTT. It received none of the failing
requests. Public DNS for `auth.umaxica.app` resolved normally to Cloudflare proxy addresses, so the
failure was neither DNS nor this connector.

`Cloudflare: Working` with `Host: Error` places the failure on the edge-to-origin hop, after Access.
A request stopped by Access returns a login redirect, not a `502`.

## Fix Applied

`podman stop umaxica-apps-edge-cloudflare-tunnel-1`, run from a host terminal by the operator,
leaving one replica on the tunnel. No repository change was needed or made.

## Passing Run, After The Fix

Baseline 15:23:01 UTC; browser session through `https://auth.umaxica.app/` to the sign-in page.

| Signal                              | Baseline | After | Delta |
| :---------------------------------- | -------: | ----: | ----: |
| `cloudflared_tunnel_total_requests` |      690 |   715 |   +25 |
| `cloudflared_tunnel_request_errors` |      101 |   101 |    +0 |
| `response_by_code{200}`             |      328 |   351 |   +23 |
| `response_by_code{301}`             |        3 |     4 |    +1 |
| `response_by_code{302}`             |       10 |    11 |    +1 |

Every request the connector served is accounted for by a response code, and no request produced an
error. Before the fix, `request_errors` had climbed 6 → 41 → 101 while `response_by_code` recorded
no `5xx` — errors with no status code, consistent with requests the connector could not complete
against an origin rather than with application failures. That climb stopped at the fix and did not
resume.

Rails answered fourteen controller actions, all `2xx` or `3xx`:

| # | Action                                       | Result                  |
| -: | :------------------------------------------ | :---------------------- |
| 1 | `Auth::App::RootsController#index`            | 302 Found, 9 ms         |
| 2 | `Auth::App::RootsController#index`            | 301 Moved Permanently   |
| 3 | `Auth::App::Sign::InsController#show`         | 200 OK, 1285 ms         |
| 4–7 | `Auth::App::Web::V0::{Cookies,Themes}Controller#show` | 200 OK, 3–4 ms |
| 8 | `Rails::PwaController#service_worker`          | 200 OK                  |
| 9 | `Auth::App::Sign::InsController#show`         | 200 OK, 22 ms           |
| 10–13 | `Auth::App::Web::V0::{Themes,Cookies}Controller#show` | 200 OK, 3–4 ms |
| 14 | `Rails::PwaController#service_worker`         | 200 OK                  |

The first render took 1285 ms against 22 ms for the second, which is development-mode first-render
cost, not a tunnel measurement.

Two redirect targets were logged:

```text
Redirected to https://auth.umaxica.app/?ri=jp
Redirected to https://auth.umaxica.app/sign/in?ri=jp
```

These are the strongest evidence in the run. Rails built absolute URLs on the browser-facing
hostname over `https`, which means the request reached `ActionDispatch` carrying
`Host: auth.umaxica.app` and was treated as secure — the tunnel path, not the private
`*.localhost` path. `Auth::App::Sign::InsController#show` rendering `200` means Access admitted the
session and Rails served its own sign-in surface behind it.

## Defects Found While Preparing The Run

### `/health` is not a usable transport probe

> Superseded by the 2026-09-03 text+JSON health contract: `/health` and the probes now return
> `text/plain` `200` without content negotiation, so the `406` behaviour recorded below no longer
> exists. See `docs/reference/health-endpoints.md`. The rest of this section is kept as the
> record of what was observed on 2026-09-01.

`app/controllers/concerns/health_check_rendering.rb:22` answers `head :not_acceptable` unless the
request negotiates HTML. Measured against the running server:

```text
GET /health   Accept: */*         -> 406
GET /health   Accept: application/json -> 406
GET /health   Accept: text/html    -> 200
GET /health/liveness  Accept: */*  -> 200
```

The deleted `bin/tunnel-origin-check` sent no `Accept` header and required `200`, so it would report
`FAIL` on every host if run today. `docs/operations/cloudflare-private-origin.md` was corrected to
probe `/health/liveness`, which is JSON-only and needs no negotiation. Whether `/health` regressed
or the probe was always wrong was not determined.

The concern's own comment — "Snapshot endpoint (/health): HTML for browsers, JSON when requested" —
contradicts the code it sits above: requesting JSON yields `406`. Not changed here.

### Three `frontend` aliases are rejected by Host Authorization

`GET /health/liveness` through each private alias, with the natural `Host: <alias>:3000`:

```text
base, auth, core, docs, help, news, palm, side, info  (*.app.localhost)  -> 200
edge.app.localhost, edge.com.localhost, edge.org.localhost              -> 403 Blocked hosts
```

`PUBLIC_EDGE_{SERVICE,CORPORATE,STAFF}_URL` are set to those three names, but `PUBLIC_EDGE_*` is not
in `env_host_keys` (`config/environments/development.rb:202`) and `edge.*` is absent from the
hardcoded `localhost_tunnel_hosts` list, so nothing admits them. They are `core` aliases, so they
resolve to Rails and Rails rejects them. This is the dangling-alias class that
`docs/operations/cloudflare-private-origin.md` describes as having been cleaned up for the
`docs-jp.`/`help-jp.`/`news-jp.` names. Not changed here; the Edge surface is a separate work
stream.

## The Access Log Is Not Persisted

`log/development.log` carries `Processing by` and `Completed` lines only. It has no `Started` line,
no request path, no client address, and no timestamp.

Per `adr/application-logging-boundary.md`, Lograge owns request-completion logging.
`config/initializers/lograge.rb:10` sends it to `ActiveSupport::Logger.new($stdout)`, and the running
server's stdout is a terminal (`/proc/<puma>/fd/1 -> /dev/pts/2`). The JSON access log — which is
where `host`, `request_id`, path, and status live — is therefore written to whichever terminal
started the server and is stored nowhere.

The consequence for verification: the 2026-08-10 style of evidence, "authenticated browser traffic
was observed arriving at Rails from a public client address", **cannot be reproduced from files**.
This run establishes hostname and scheme from the redirect targets, and arrival from the connector
counters, but no client address was recorded. Anyone repeating this must capture the server terminal
or route Lograge to a file first.

## Known Exclusions

- Production Tunnel, Access policy, and DNS.
- Every hostname except `auth.umaxica.app`. The other twelve from the 2026-08-10 matrix were not
  re-run.
- The unauthenticated case. No nonce probe was run this time; the 2026-08-10 run covers it.
- Gate 1 of the private-origin contract as written. The alias sweep above was run from inside `core`
  against `127.0.0.1:3000`, not from an ephemeral container on the connector's own network, because
  `podman` is absent from `core`. It proves Host Authorization, not the connector's network
  position.
- Outbound UDP 7844 and the Workers VPC binding, both still unverified as of this run.
- The client address, for the reason above.

## Follow-Up

- Make the replica-reachability invariant detectable. It is prose in "External Checks", it was
  violated, and the violation cost two debugging sessions. A check needs the Cloudflare API; it
  cannot be a repository test alone.
- Decide whether the Edge tunnel should run from this project's `cloudflare-tunnel-edge` service
  (`--profile tunnel-edge`, `CLOUDFLARED_EDGE_TOKEN`, added in `289cb9f36`) rather than from the
  Edge project. `CLOUDFLARED_EDGE_TOKEN` is absent from `.env`, so that path is configured but
  unused. Doing so keeps every replica on `frontend` by construction.
- Route Lograge to a file in development, or accept that access-log evidence requires capturing a
  terminal.
- Resolve the three `edge.*.localhost` aliases: admit them in `config.hosts` or remove them.
- Reconcile `HealthCheckRendering#render_snapshot` with its comment.

## Secrets

No tunnel token, Cloudflare API token, Access assertion, JWT, `Authorization` header, cookie,
session identifier, or API key is recorded in this note. Connector and replica identifiers, edge
location codes, and the tunnel identifier are not credentials. No client address was available to
redact.
