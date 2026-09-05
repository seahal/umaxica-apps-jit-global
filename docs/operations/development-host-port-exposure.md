# Development Host Port Exposure

Development containers do not publish services to the host's external network interfaces by default.
Where host access is genuinely required, the publication is restricted to loopback.

This is the standing contract for every Compose file in this repository. It is not advice about a
particular service, and a host firewall is not an acceptable substitute for it.

## The Rule

1. **Prefer no publication at all.** If a service is only consumed by other containers, it gets no
   `ports:` entry. Containers reach it by Compose service name over the shared network
   (`primary:5432`, `valkey-cache:6379`, `valkey-rate-limit:6379`, `kafka:29092`, `tempo:3200`).
2. **If the host genuinely needs it, publish to loopback only.** Write the bind address explicitly:
   `127.0.0.1:3000:3000`, never `3000:3000`. A `ports:` entry with no host address makes Podman bind
   `0.0.0.0`, which places the service on every host interface — LAN, Wi-Fi, Ethernet, and Tailscale
   included.
3. **Never publish a datastore.** PostgreSQL (`primary`, `replica`), Valkey, and Kafka are
   container-only. Convenience is not a reason to add `5432:5432`, `6379:6379`, or `9092:9092`; use
   `podman compose exec` for a shell against them.

## Container Bind and Host Publication Are Separate Decisions

A process binding `0.0.0.0` _inside_ its container is normal and usually required — it is how the
container becomes reachable on the Podman network at all. It says nothing about host exposure, which
is decided solely by `ports:`.

```text
BINDING=0.0.0.0             ->  Rails listens on the core container's own interfaces.
ports: 127.0.0.1:3000:3000  ->  the host reaches it only from the host itself.
ports: 3000:3000            ->  every machine on the LAN reaches it.  <- not allowed
```

`compose.yaml` therefore keeps `BINDING: "0.0.0.0"` and `VITE_RUBY_HOST: "0.0.0.0"`. Do not "harden"
those to `127.0.0.1`: that would break `cloudflare-tunnel`, the transport probe in
`docs/operations/cloudflare-private-origin.md`, and every container-to-container call, while
changing nothing about host exposure.

## Current Publications

| Service                                | Host publication           | Why                                                                                                                 |
| -------------------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `core` (Rails, 3000)                   | `127.0.0.1:3000`           | The browser opens the documented `http://<service>.<surface>.localhost:3000` origins, which resolve to `127.0.0.1`. |
| `core` (Vite, 3036)                    | `127.0.0.1:3036`           | `@vite/client` opens its HMR socket to the dev server from the browser.                                             |
| `primary`, `replica`                   | none                       | Reached as `primary:5432` / `replica:5432`.                                                                         |
| `valkey-cache`                         | none                       | Reached as `valkey-cache:6379`.                                                                                     |
| `valkey-rate-limit`                    | none                       | Reached as `valkey-rate-limit:6379`.                                                                                |
| `loki`, `tempo`, `prometheus`, `alloy` | none                       | Reached only by each other and by Grafana on the `observability` network.                                           |
| `grafana`                              | none                       | See "Grafana has no host publication" below.                                                                        |
| `cloudflare-tunnel`                    | none, and none is possible | The connector is outbound-only.                                                                                     |

### Grafana has no host publication

The observability group runs on every `up` since 2026-08-31, but Grafana still publishes no host
port, so `http://localhost:3000` does not reach it -- that port belongs to Rails. Reach the UI
through the container instead, or add a loopback publication if it is wanted day to day. Grafana is
not a datastore, so a `127.0.0.1`-bound publication would not violate the never-publish rule above;
it simply has not been added.

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
sudo ss -lntup | grep -E ':(3000|3036|9092|5432|6379)\b'
```

Expected: `primary`, `replica`, `valkey-cache`, `valkey-rate-limit`, and `kafka` show a bare
container port with no `->`
mapping. `core` shows `127.0.0.1:3000->3000/tcp` and `127.0.0.1:3036->3036/tcp`. No line anywhere
contains `0.0.0.0:3000`, `0.0.0.0:3036`, `0.0.0.0:9092`, `*:3000`, `*:3036`, or `*:9092`.

From a second machine on the same LAN, both of these must fail to connect:

```sh
curl --max-time 5 http://<host-lan-ip>:3000/health
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
- any publication of 5432, 6379, or 9092
- a `network_mode: host` service
- a `--publish`/`-p` flag in a script that omits the bind address
