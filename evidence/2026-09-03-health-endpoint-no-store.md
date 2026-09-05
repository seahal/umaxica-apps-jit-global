# Health endpoint cache directive, and the Astro / Hono health request

## What was being verified

Whether this repository's health endpoints meet a requested public HTTP contract for Kubernetes
probes, and whether the same contract could be implemented in an Astro application and a Hono
application. Two of the three applications do not exist here; the third already implements the
endpoints under a different, ADR-pinned contract, and was missing one header.

## Context

- Repository: `umaxica-apps-global`, branch `feature`, revision `4ebec1d9d`
- Host: Linux, ruby 4.0.6, node v24.19.0, pnpm 12.0.0
- Date: 2026-09-03

## Astro and Hono: no such applications

Searched for, and did not find, any Astro or Hono application:

| Search | Result |
| --- | --- |
| `find . -name package.json` (excluding `node_modules`, `vendor`) | exactly one, `./package.json` - React + Inertia + Vite for the Rails app |
| `grep -rlE '"(astro\|hono)"' --include=package.json` | no matches |
| `find . -name "astro.config.*" -o -name "wrangler.*"` | no matches |
| `grep -rli "\bastro\b"` over source and config | no matches |

The absence is deliberate and recorded. `plans/l-hono-ethereal-babbage.md` states that diagnostic
section L (Hono / React Router) "は本プロジェクトに実装がないため対象外", and
`adr/read-only-content-surfaces-in-rails.md` records that Hono and ReactRouter are not owners of
the `docs`, `news`, `help` or `core` public frontend. No health endpoint was implemented for either;
scaffolding two new applications was declined as out of scope by the requester.

## Rails: the endpoints already exist, under a different contract

All four endpoints are implemented on every surface - 29 surfaces x 4 controllers = 116
controllers, plus the shared `HealthCheckRendering` concern and the `Health` service layer in
`app/services/health.rb`. The controller names already match the requested resource convention
(`HealthsController#show`, `Health::StartupsController`, `Health::LivenessesController`,
`Health::ReadinessesController`).

Three differences from the requested contract were found, and the current behaviour is pinned by
`adr/internal-health-endpoint-edge-isolation.md` (accepted 2026-06-14):

| | Requested | Current |
| --- | --- | --- |
| Probe paths | `/health/startups`, `/health/livenesses`, `/health/readinesses` | `/health/startup`, `/health/liveness`, `/health/readiness` |
| Probe format | `text/plain`, body `ok\n` | `application/json` |
| `/health` format | `text/plain` aggregate | HTML; `406` to non-HTML |

Migrating would additionally require editing `lib/health_probe_paths.rb`, whose exact four-path set
is wired into `config.host_authorization` as a DNS-rebinding-defence exemption
(`config/environments/production.rb:213`), the OpenAPI documents, and the Cloudflare edge rule that
blocks these paths publicly and is owned outside this repository. The requester chose to keep the
current contract and fix only the genuine gap below, so no path or format was changed.

## The gap that was real: no cache directive

Neither `HealthCheckRendering` nor any health controller set `Cache-Control`. Measured, by
reverting the fix and reading the assertion diff:

```
GET /health/liveness  ->  Cache-Control: max-age=0, private, must-revalidate
```

Rails' default permits storage. A stored `200` keeps an orchestrator sending traffic to an instance
that has since failed readiness; a stored `503` keeps traffic away from one that has recovered.
The repository already uses `response.set_header("Cache-Control", "no-store")` at roughly twenty
other endpoints, asserted on the wire in their tests, so the fix follows that established pattern
rather than introducing a new one.

## What was changed

- `app/controllers/concerns/health_check_rendering.rb` - added a `before_action
  :disable_health_response_cache` setting `Cache-Control: no-store`. A callback rather than a line
  inside `render_probe` / `render_snapshot`, so it also covers the `406` that a non-HTML request to
  `/health` receives. This reaches all 116 controllers through the concern they already include.
- `test/integration/health_endpoints_test.rb` - two tests: the header on all four endpoints, and
  the header on a stubbed `unready` readiness (`503`) and on the `406`.
- `docs/reference/health-endpoints.md` - a `## Caching` section recording the directive and why.

No path, format, status code, route, controller or ADR was changed.

## Commands run and what was observed

| Command | Observed |
| --- | --- |
| `bin/rails test test/integration/health_endpoints_test.rb` | 22 runs, 1380 assertions, 0 failures, 0 errors, 0 skips |
| the same, with the fix reverted | 22 runs, 1369 assertions, **2 failures** - both new tests, actual `max-age=0, private, must-revalidate` |
| health test set (7 files incl. `health_probe_paths`, `openapi_health_contract`, `edge_health_routes`, `services/health`, 4 controller tests) | 71 runs, 1613 assertions, 0 failures, 0 errors, 0 skips |
| `COVERAGE=true bin/rails test` | 12153 runs, 66765 assertions, 0 failures, 0 errors, 1 skip; 1164.1s; exit 0. Line 99.05% (53512 / 54021), branch 82.19% (7673 / 9335), method 94.62% (9574 / 10118) - every `.simplecov` gate passed |
| `bundle exec rubocop` | 0 offences in 0 files |

Suite count moved 12151 to 12153, matching the two tests added.

## Assessment

PASS for the change that was made. The reverted-fix run is the evidence that the two new tests
fail when the header is absent rather than passing vacuously, and it is also where the pre-fix
value quoted above was measured.

The requested contract was **not** implemented as specified, by the requester's decision: the
probe paths stay singular and the probes stay JSON. The Astro and Hono halves of the request were
not implemented at all, because those applications are not in this repository.

## Limitations

- Only the `auth.app` surface is exercised by the new assertions. The header is set in the one
  concern all 116 controllers include, and `health_endpoints_test.rb` separately asserts that every
  declared surface's controllers include that concern, but the header itself is not re-asserted per
  surface.
- The Cloudflare edge rule that blocks public traffic to `/health*` is owned outside this
  repository and was not inspected; this record does not verify it.
- Nothing was committed; all changes are left in the working tree.

## Follow-up (2026-09-03, later)

A subsequent decision reversed the "keep the current contract" choice recorded above. The
2026-09-03 text+JSON contract makes the probes `text/plain` (`/health` a four-line aggregate,
`/health/{startup,liveness,readiness}` returning `"ok\n"` / 503) and adds a machine family
`/api/v0/health.json` + `/api/v0/revision.json` (`application/json`, `pass/warn/fail`, `406` on a
non-JSON `Accept`). Probe paths stay singular. The `Cache-Control: no-store` directive verified
here is retained on every text and JSON response, including the new `406`. Current contract:
`docs/reference/health-endpoints.md`.
