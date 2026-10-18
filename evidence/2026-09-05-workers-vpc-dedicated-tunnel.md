# Dedicated Workers VPC Tunnel for Development

Date: 2026-09-05

Repositories:

- `umaxica-apps-global` at `0c254469595760ee7c3d60a4dbb6164eabb556cd` (working tree, uncommitted)
- `umaxica-apps-edge` at `aad05824` (unchanged so far; see "Blocked")

## Why

The account's single VPC Service `019f5fe0-287f-7040-9f2f-036cb5b21df7`
(`umaxica-apps-edge-cf-workers-vpc`) was bound to tunnel `1d501e9a-62f7-4c0d-ba5e-a26e3f10088f` —
the `Auth` tunnel, which also serves the ten published browser hostnames behind Access. Every
Access, ingress, replica or token change on the browser path therefore also moved the Edge Worker's
only route to Rails.

Two further faults were observed, neither recorded before:

1. `wrangler vpc service list` reports that service's host as **`10.89.2.2`**, a Podman-assigned
   container address, not `core.app.localhost` as `adr/006-development-workers-vpc-transport.md`
   states. That address changes whenever the network is recreated.
2. The reason for (1): on `umaxica-apps-global-dc_frontend`, `getent hosts core.app.localhost`
   answers `::1`. RFC 6761 reserves the `localhost.` domain and glibc resolves anything under it to
   loopback before the container resolver is consulted, so no `*.localhost` alias can serve as a VPC
   Service target. The transport probe in `docs/operations/cloudflare-private-origin.md` returns
   `000`, not `200`, through those names.

## What was created

|                              |                                                          |
| :--------------------------- | :------------------------------------------------------- |
| Tunnel name                  | `umaxica-dev-workers-vpc`                                |
| Tunnel id                    | `03a4a67c-2aca-4f2c-9aeb-d1666f18bc87`                   |
| Account                      | UMAXICA (`c90999d8a4039c63d02b7a7b1545d211`)             |
| Management                   | locally managed (`cloudflared tunnel create`)            |
| Ingress rules                | none — not required for Workers VPC                      |
| Public hostname / Access app | none                                                     |
| Connector service            | `cloudflare-tunnel-workers-vpc` (`compose.yaml`)         |
| Token variable               | `CLOUDFLARED_WORKERS_VPC_TOKEN` in the gitignored `.env` |
| VPC Service target           | `core-workers-vpc.internal:3000`, HTTP                   |

Cloudflare documents that "ingress configurations for locally-managed tunnels are not required for
Workers VPC as routing is handled by the VPC Service configuration"
(<https://developers.cloudflare.com/workers-vpc/configuration/tunnel/>), so this tunnel carries no
ingress and needs no public hostname.

`core-workers-vpc.internal` is a new `frontend` alias on `core`. It is a routing target only: the
Host on the VPC path still comes from the Worker's `fetch()` URL, so the name is deliberately absent
from `config.hosts`.

## Commands

```bash
cloudflared tunnel create umaxica-dev-workers-vpc
cloudflared tunnel token umaxica-dev-workers-vpc      # value written to .env, never printed
podman-compose -f compose.yaml -f .devcontainer/compose.override.yml \
  up -d core cloudflare-tunnel-workers-vpc
```

## Observations

Gate A — Rails itself, inside `core`, `Host: core.app.localhost`:

- `GET /health/` → `200 text/plain`, body `status: ok / startup: ok / liveness: ok / readiness: ok`
- `GET /revision` → `200 text/plain`, body `0c254469595760ee7c3d60a4dbb6164eabb556cd`

Gate B — throwaway `curlimages/curl:8.16.0` on `umaxica-apps-global-dc_frontend`, through the new
alias:

- `http://core-workers-vpc.internal:3000/health/` → `200`
- `http://core-workers-vpc.internal:3000/revision` → `200`, same revision

Gate C — connector `cloudflare-tunnel-workers-vpc`:

- log names `tunnelID=03a4a67c-2aca-4f2c-9aeb-d1666f18bc87`; no other tunnel id appears
- four connections registered, all `protocol=quic`, at `nrt10`, `nrt15`, `nrt16`, `kix04`
- built-in pre-checks all `PASS`, including `UDP Connectivity … QUIC connection successful`, so
  outbound UDP 7844 is available; summary line selects `quic` as primary protocol
- `/ready` → `{"status":200,"readyConnections":4}`
- cloudflared `2026.8.2`; no unsupported-version warning. Two ICMP-proxy warnings appear
  (`ping_group_range`); they concern ICMP only and do not affect the HTTP VPC path.
- `restarts=0`

Repository checks:

- `bin/rails test test/tooling/` — 40 runs, 273 assertions, 0 failures
- `bin/rails test test/config/` — 20 runs, 140 assertions, 0 failures

After the Valkey split, Dev Container startup exposed a stale override entry for the retired
`valkey` service (`global-devcontainer-valkey`). `.devcontainer/compose.override.yml` now overrides
`valkey-cache` and `valkey-rate-limit` by their actual base-service names. A tooling regression test
asserts that the override contains both names, contains no legacy `valkey` service, and keeps each
container name identical to `compose.yaml`. Podman re-validation from this session was blocked by
the environment before Compose parsing (`/run/user/1000/libpod` is read-only); the corrected live
Dev Container recreation is therefore still unverified in this session.

`test_development_compose_aliases_only_private_origins_and_configured_public_site_hosts` initially
failed on the new alias, correctly: it modelled only two alias categories. It now recognises a
third, routing-only category via `ROUTING_ONLY_ALIASES`, and additionally asserts that every name in
that list is still an alias and does **not** appear in `config/environments/development.rb`.
Assertions rose from 110 to 140; nothing was relaxed.

## VPC Service and end-to-end result

The VPC Service was created from the Edge repository once an OAuth session on the UMAXICA account
was available:

|              |                                        |
| :----------- | :------------------------------------- |
| Service name | `umaxica-dev-rails-api`                |
| Service id   | `01a06fd0-89b7-7613-9e1d-f7d07c693273` |
| Type / port  | HTTP, `3000`                           |
| Target       | `core-workers-vpc.internal`            |
| Tunnel       | `03a4a67c-2aca-4f2c-9aeb-d1666f18bc87` |

`wrangler vpc service get` confirms all five fields.

The API token in the Edge repository could not create it — reads succeed, but
`POST /accounts/…/connectivity/directory/services` returns `Authentication error [code: 10000]` even
after the `接続ディレクトリ` admin permission was added. `wrangler login` as `umaxica.com@gmail.com`
(UMAXICA, `connectivity:admin`) was required.

Gate F, run from the Edge repository as `node tools/verify-edge-connectivity.mjs vpc`: the binding
`UMAXICA_APPS_EDGE_CF_WORKERS_VPC` resolved to `01a06fd0-…` as a remote VPC Service, and all fifteen
Rails-backed surfaces answered `200` over it.

Confirmed from this side: 30 `/api/v0/health.json` requests reached Rails (two runs × fifteen
surfaces), each dispatched to its own surface controller — `Info::Org::Api::V0::HealthsController`
for `ORG/INFO`, and so on — so Host-based namespace routing works over the new path. The `Auth`
connector is attached to a network holding no Rails container and cannot have served them.

## Not done

The old VPC Service `019f5fe0-…` and the `Auth` and `Edge` tunnels were left in place. No
configuration in either repository references the old service any more; deleting Cloudflare
resources for tidiness is outside this change.

One incidental observation, not addressed here: the `Auth` connector
(`umaxicaappsglobaldc_cloudflare-tunnel_1`) is running on the legacy `umaxicaappsglobaldc_frontend`
network, which no longer holds a `core` container, so that tunnel currently has no route to Rails.
It is unrelated to the Workers VPC path.
