# Development Host Port Exposure

Development containers do not publish services to the host's external network interfaces by default.
Where host access is genuinely required, the publication is restricted to loopback.

This is the standing contract for every Compose file in this repository. It is not advice about a
particular service, and a host firewall is not an acceptable substitute for it.

## The Rule

1. **Prefer no publication at all.** If a service is only consumed by other containers, it gets no
   `ports:` entry. Containers reach it by Compose service name over the shared network
   (`primary:5432`, `valkey:6379`, `kafka:29092`, `tempo:3200`).
2. **If the host genuinely needs it, publish to loopback only.** Write the bind address explicitly:
   `127.0.0.1:3001:3000`, never `3001:3000`. A `ports:` entry with no host address makes Podman bind
   `0.0.0.0`, which places the service on every host interface — LAN, Wi-Fi, Ethernet, and Tailscale
   included.
3. **Host-native datastore access is loopback-only.** PostgreSQL (`primary`, `replica`) and Valkey
   publish only explicit `127.0.0.1` mappings for host-native Rails (`5432`/`5433`, `6379`, and
   `6380`). Containers continue to use Compose DNS names; Kafka remains container-only.

## Container Bind and Host Publication Are Separate Decisions

A process binding `0.0.0.0` _inside_ its container is normal and usually required — it is how the
container becomes reachable on the Podman network at all. It says nothing about host exposure, which
is decided solely by `ports:`.

```text
BINDING=0.0.0.0             ->  Rails listens on the core container's own interfaces.
ports: 127.0.0.1:3001:3000  ->  the host reaches container Rails on host port 3001 only.
ports: 3001:3000            ->  every machine on the LAN reaches it.  <- not allowed
```

`.devcontainer/compose.yaml` therefore keeps `BINDING: "0.0.0.0"` and `VITE_RUBY_HOST: "0.0.0.0"`.
Do not "harden" those to `127.0.0.1`: that would break `cloudflare-tunnel`, the transport probe in
`docs/operations/cloudflare-private-origin.md`, and every container-to-container call, while
changing nothing about host exposure.

## Current Publications

| Service                                | Host publication           | Why                                                                                                                    |
| -------------------------------------- | -------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `core` (Rails, 3000)                   | `127.0.0.1:3001`           | Keeps host port `3000` available for host-native Rails while forwarding host browser traffic to container port `3000`. |
| `core` (Vite, 3036)                    | `127.0.0.1:3036`           | `@vite/client` opens its HMR socket to the dev server from the browser.                                                |
| `primary` (writer)                     | `127.0.0.1:5432`           | Host-native Rails writer; containers use `primary:5432`.                                                               |
| `replica` (reader)                     | `127.0.0.1:5433`           | Host-native Rails reader; containers use `replica:5432`.                                                               |
| `valkey`                               | `127.0.0.1:6379`           | One nonprod Valkey; logical DBs 0/1/2 (dev) and 3/4/5 (test) via responsibility URLs.                                  |
| `loki`, `tempo`, `prometheus`          | none                       | Storage backends behind the Alloy gateway. Reached only by Alloy and Grafana on the `observability` network.            |
| `alloy` (OTLP/HTTP, 4318)              | `127.0.0.1:4318`           | Host-native Rails exports telemetry here; it resolves no Compose DNS name. See "The two observability listeners" below. |
| `alloy` (12345, OTLP/gRPC 4317)        | none                       | The management UI is an unauthenticated control surface; nothing on the host speaks OTLP/gRPC.                          |
| `grafana`                              | `127.0.0.1:13000`          | The developer's own browser. 3000/3001 belong to Rails, so the UI takes 13000.                                          |
| `cloudflare-tunnel`                    | none, and none is possible | The connector is outbound-only.                                                                                        |

### The two observability listeners

Development observability publishes exactly two host ports, both loopback:

```text
127.0.0.1:13000 -> Grafana        (browser UI for this machine only)
127.0.0.1:4318  -> Alloy OTLP/HTTP (telemetry ingress for host-native Rails)
```

Nothing else in the observability group is reachable from the host. Tempo (3200/4317/4318),
Prometheus (9090), Loki (3100) and the Alloy management UI (12345) are consumed over the
`observability` network by service name, and adding a publication for any of them creates an
ingestion or query path that bypasses the single Alloy gateway
(`adr/traces-and-metrics-routing-via-alloy.md`).

Grafana keeps its upstream container port `3000`; only the host side is 13000, because host `3000`
is host-native Rails and `3001` is Dev Container Rails. Grafana attaches to `observability` alone —
never to `frontend` — so no Cloudflare Tunnel ingress and no Tailscale route can reach it. It is a
local-only UI, and its admin credentials (`GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`, default
`admin`/`admin`) are development-only values that assume exactly this loopback boundary. Overriding
them in the gitignored `.env` is supported; publishing Grafana anywhere else is not.

Host-native Rails reaches the ingress with:

```text
OPEN_TELEMETRY=true
OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318
```

Compose `core` keeps the container-network form instead: `http://alloy:4318`. The two are not
interchangeable — `alloy` does not resolve on the host, and `127.0.0.1` inside a container is the
container itself.

IPv6: rootless Podman publishes these as IPv4 only, so no `::`-bound listener is created. The
loopback form pins the IPv4 side explicitly. If a future service needs IPv6 loopback, write
`[::1]:PORT:PORT` as a second, equally explicit entry — never a bare `PORT:PORT`.

## Kafka

The broker runs two listeners, both on the `backend` network:

```text
CONTROLLER://kafka:29093    KRaft quorum
INTERNAL://kafka:29092      clients and inter-broker traffic
```

There is no `EXTERNAL` listener. The previous `EXTERNAL://0.0.0.0:9092`, advertised as
`localhost:9092`, existed only to back the host publication of 9092. Nothing consumes it: no
`rdkafka`, `racecar`, `ruby-kafka`, or `karafka` dependency exists, and the
`opentelemetry-instrumentation-*` entries in `Gemfile.lock` instrument clients that are not
installed. The healthcheck bootstraps from `kafka:29092`.

Adding a Kafka client later means pointing it at `kafka:29092`. It does not mean restoring the host
publication.

## Cloudflare Tunnel

`cloudflare-tunnel` needs no inbound host port and must never be given one. It dials Cloudflare
outbound over QUIC (UDP 7844) and resolves the Rails origin over Global's private Podman network:

```text
cloudflare-tunnel -> frontend network -> core:3000 (Rails)
```

The Edge Worker reaches Rails through its Cloudflare Workers VPC Service binding; the Edge and
Global compose projects do not share a host Podman network. Tunnel and VPC Service routing live in
the Cloudflare account, not in this repository. The Rails target must name a `frontend` service
address. A target pointing at `host.docker.internal:3000` would route Cloudflare traffic back out
through the host and is not supported by this contract — see
`docs/operations/cloudflare-private-origin.md`.

## Verification

Run on the **host**, not inside a container:

```sh
podman ps --format 'table {{.Names}}\t{{.Ports}}'
sudo ss -lntup | grep -E ':(3000|3001|3036|9092|5432|5433|6379|13000|4318)\b'
```

Expected: `core` shows `127.0.0.1:3001->3000/tcp`, `primary` shows `127.0.0.1:5432->5432/tcp`,
`replica` shows `127.0.0.1:5433->5432/tcp`, `valkey` shows `127.0.0.1:6379->6379/tcp`. The Dev
Container `core` service shows loopback-only Rails publications when the combined config is used. No
line anywhere contains `0.0.0.0`, `*`, or a LAN address for these services. `grafana` shows
`127.0.0.1:13000->3000/tcp` and `alloy` shows `127.0.0.1:4318->4318/tcp`; `tempo`, `prometheus` and
`loki` show no host mapping at all.

```sh
curl -f http://127.0.0.1:13000/api/health   # Grafana answers; the LAN address must not
```

From a second machine on the same LAN, both of these must fail to connect:

```sh
curl --max-time 5 http://<host-lan-ip>:3001/health
curl --max-time 5 http://<host-lan-ip>:3036/
```

The container-network path is gated separately by the transport probe in
`docs/operations/cloudflare-private-origin.md`, whose Gate 4 also requires `podman compose config`
to show no new host port publication.

## Out of Scope

GitHub Actions `services:` blocks in `.github/workflows/` publish `5432` and `6379` on the runner.
That is a different threat model — a single-use runner VM with no LAN neighbours and no persistent
data — and the addresses are runner-local. This contract governs Compose files only, and
`test/tooling/compose_host_port_exposure_test.rb` checks Compose files only.

## Review Checklist

Reject a change that adds any of the following without an entry in the table above:

- a `ports:` value with no explicit host address
- a datastore publication that is not bound to `127.0.0.1`
- any publication of Kafka 9092
- a `network_mode: host` service
- a `--publish`/`-p` flag in a script that omits the bind address
