# Cloudflare Private Origin Contract

This repository exposes Rails to Cloudflare Tunnel only through the Podman `frontend` network. The
same tunnel supports published browser hostnames and a future Workers VPC Service, but those ingress
paths do not change Rails authentication, authorization, or surface ownership.

The connector is attached only to this compose project's private `frontend` network. The Edge and
Global compose projects must not share a host Podman network. Edge Workers reach Rails through a
Cloudflare Workers VPC Service bound to this tunnel; they never resolve or dial the Rails container
over a cross-project container network.

## Invariants and Verification Gates

The private transport invariant is:

```text
same Podman frontend network
  -> same Podman DNS
  -> private origin alias
  -> Rails listener
  -> HTTP response
```

The gates are intentionally independent:

1. **Private transport**: an ephemeral curl container on the same compose `frontend` network as the
   running connector requests `GET /health/liveness` through every private surface alias and
   requires HTTP `200`. No committed script performs this — `bin/` carries generated binstubs only —
   so it is a manual procedure, written out under "Running the Transport Probe" below.
2. **Host Authorization**: `ruby test/config/host_authorization_contract_test.rb` boots a separate
   Rails development process, constructs the middleware from the effective development settings,
   requests the non-excluded `/` path, accepts the private origins and the published site hostnames,
   and rejects both an unknown host and an Umaxica-owned hostname that no `PUBLIC_*_URL` names.
3. **Surface routing**: the route contract tests recognize non-health application resources for the
   private Host values and assert the matching `app`, `com`, `org`, `net`, or `dev` controller.
4. **Podman DNS aliases**: `podman compose config` must show the private aliases on `core`'s
   `frontend` network and no new host port publication. The connector never needs an inbound host
   port and must not be given one; the only publications in the stack are `core`'s loopback-bound
   `3000`/`3036`. See `docs/operations/development-host-port-exposure.md`.
5. **Workers VPC connector prerequisites**: cloudflared is pinned at the supported `2026.8.2`
   release, runs with QUIC, authenticates with the remotely managed tunnel token from the gitignored
   repository `.env`, and requires outbound UDP port 7844. See "Authenticating the Connector"
   below.
6. **Repository regression checks**: run the focused tests first, then the full Rails suite,
   coverage, and lint checks when the test databases are available.

`/health` is excluded from Rails Host Authorization in production. A successful Gate 1 request
therefore proves transport reachability only. It does not prove that the Host is accepted by
`ActionDispatch::HostAuthorization`, and it does not substitute for Gate 3 routing evidence.

## Development Scope

Development Rails is published through this tunnel under the browser-facing site names, behind
Cloudflare Access. The `core` container therefore carries two sets of `frontend` aliases — the
private `*.localhost` origins and the published site names — and development Host Authorization
accepts both families and nothing else. See the "Development Is Tunnel-Exposed Behind Access"
section of `docs/architecture/cloudflare-request-paths.md` for how each family reaches
`config.hosts`, and for the `FORCE_SECURE_COOKIES` trade-off between the tunnel path and the
plain-`http` local path.

Access is the control that keeps the development surface non-public, and it lives in the Cloudflare
account rather than in this repository — see "External Checks" below.

## Browser Traffic Through Access

Create the Cloudflare Access application before publishing its tunnel hostname. Enable Access
protection for the published route so cloudflared validates the Access assertion before proxying the
request. Rails application authorization remains responsible for every application permission;
Access does not replace it.

The accepted scope and the deferred Rails-side JWT validation decision remain in
`adr/org-cloudflare-access-authentication-layer.md`. Cloudflare documents the deployment ordering in
[Publish a self-hosted application](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/self-hosted-public-app/)
and the tunnel Access options in
[Origin configuration](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/origin-configuration/).

## Workers VPC Traffic

Configure the future VPC Service as HTTP. Its target hostname is a private alias resolvable on the
Podman `frontend` network. Use port `3000` for this development compose stack and port `8080` for
the production image. The Worker binding belongs to the Worker repository, not this Rails
repository.

The VPC Service target selects the private route. The hostname in the Worker's `fetch()` URL remains
the origin Host/SNI, so it must be a narrowly allowlisted Umaxica surface hostname and must match
the surface route constraint. See Cloudflare's
[VPC Services configuration](https://developers.cloudflare.com/workers-vpc/configuration/vpc-services/).

Cloudflare documents cloudflared `2025.7.0` or newer, QUIC via `--protocol auto` or `quic`, and
outbound UDP 7844 for Workers VPC tunnels. This connector uses `auto` so a UDP blip falls back to
HTTP/2 instead of exiting. Do not pin `http2`. Cloudflare supports cloudflared releases only for one
year, so this repository pins the current supported `2026.8.2` release. See
[Connect with Cloudflare Tunnel](https://developers.cloudflare.com/workers-vpc/configuration/tunnel/).

Access and Workers VPC are separate route types. Based on that separation, this repository does not
require `CF-Access-*` headers on the VPC path. This is an operational inference to confirm in the
Cloudflare account before rollout, not a Rails authentication bypass.

## Authenticating the Connector

The Cloudflare account holds two remotely managed development tunnels, and a connector runs exactly
one of them. Compose defines one connector service per tunnel. The primary connector is part of the
default stack so the Dev Container lifecycle starts it. The alternative connector stays behind a
profile:

| Service                  | Profile                         | Token variable           |
| :----------------------- | :------------------------------ | :----------------------- |
| `cloudflare-tunnel`      | none (starts with the stack)    | `CLOUDFLARED_TOKEN`      |
| `cloudflare-tunnel-edge` | `tunnel-edge`                   | `CLOUDFLARED_EDGE_TOKEN` |

`cloudflare-tunnel-edge` merges `cloudflare-tunnel`'s definition through a YAML anchor, so the two
differ only in the edge profile and token; the pinned release, the QUIC command, the `frontend`
attachment, and the crash-loop caps are shared by construction.
`test/tooling/compose_local_override_optional_test.rb` is the guard.

Each service reads its tunnel's scoped connector token from the repository-local `.env` and passes
it to cloudflared as `TUNNEL_TOKEN`. Neither is an account API key. Each authorizes a connector to
run one tunnel, so both are still secrets and must not be committed, logged, or pasted into a
command argument.

Retrieve a token in the Cloudflare dashboard:

1. Go to **Networking > Tunnels**.
2. Open the tunnel you want this machine to connect.
3. Select **Add a replica**.
4. Copy only the `eyJ...` token from the displayed installation command.
5. Store it in the repository root `.env` and restrict the file mode:

```dotenv
CLOUDFLARED_TOKEN=<paste the first tunnel's token here>
CLOUDFLARED_EDGE_TOKEN=<paste the second tunnel's token here>
```

```bash
chmod 600 .env
```

If `.env` already contains other settings, add or replace only the token lines. Never commit `.env`;
the repository, Docker, and container build ignore files all exclude it.

Both variables use `${VAR:-}` rather than `${VAR:?}`: Compose interpolates the whole file whichever
service is named, so a required variable would stop `up core` on a machine that never runs a tunnel.
A connector started without a token exits within milliseconds, and `restart: on-failure:3` bounds
that into a visible, stopped container rather than a restart storm. Read `podman logs` for the
connector when a tunnel does not come up.

The primary connector starts with `devcontainer up` and with a plain Compose `up`. The alternative
connector is opt-in. Run these from a host terminal, not from inside `core`:

```bash
devcontainer up --workspace-folder .         # starts cloudflare-tunnel
podman compose --profile tunnel-edge up -d   # alternative tunnel
```

Starting both is supported: the two connectors then serve their own tunnels over the same
private `*.localhost` origins on `frontend`. Nothing in Rails changes with the choice of tunnel —
the ingress rules and published hostnames live in the Cloudflare account, and Rails Host
Authorization accepts the same two hostname families either way.

Do not leave a standalone `docker run ... tunnel run --token ...` connector running for either
tunnel at the same time. Inspect `docker ps` and `podman ps` on the host before switching to the
Compose sidecar.

To rotate or revoke the connector credential, refresh the token in the Cloudflare dashboard, replace
only that tunnel's token value in `.env`, and recreate its connector. Removing the local value
alone does not revoke a copied token at Cloudflare:

```bash
podman compose -f compose.yaml \
  up -d --force-recreate --no-deps cloudflare-tunnel
podman compose -f compose.yaml --profile tunnel-edge \
  up -d --force-recreate --no-deps cloudflare-tunnel-edge
```

The connector reaches Rails directly over `frontend`. It has no `host.docker.internal` alias, no
Edge project network, and no supported route back through a host-published application port. Keep
the Cloudflare VPC Service pointed at an unambiguous Rails service address on `frontend`.

## Running the Transport Probe

Run this from a host terminal: `podman` is not on `PATH` inside `core`. Start `core` and whichever
connector this session uses first.

Nothing is executed inside the cloudflared container — that image carries no shell, curl, or wget.
Every request comes from a throwaway curl container attached to the connector's own network, so a
`200` is evidence that the connector's network position reaches Rails, not merely that Rails is up.

Take the connector's network from its compose labels rather than assuming a project name:

```bash
cid=$(podman ps -q --filter label=com.docker.compose.service=cloudflare-tunnel)
net=$(podman inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$cid")
```

Gate the connector before reading anything into an origin result. A container id alone proves
nothing: `ps -q` still reports one between restarts, so a crash-looping connector otherwise reads as
a Rails or DNS fault instead.

```bash
podman inspect -f '{{.State.Status}} restarts={{.RestartCount}}' "$cid"   # want: running restarts=0
podman run --rm --network "$net" docker.io/curlimages/curl:8.16.0 \
  -sS --max-time 5 http://cloudflare-tunnel:2000/ready                    # want: {"status":200,...}
```

Then request `/health/liveness` through each private alias. Under the 2026-09-03 text health
contract both `/health` and `/health/liveness` return `text/plain` `200` (they no longer negotiate
on `Accept`), so either works; `/health/liveness` is the narrower, dependency-free probe and stays
the recommended target. Leave `Host` to curl — it sends `<alias>:3000`, which is the form
`config.hosts` carries for the private origins.

The alias list is the `frontend` `aliases:` block of the `core` service in `compose.yaml`; that
block is the single source, so read it there rather than copying the names into a second list that
can drift:

```bash
aliases=$(podman inspect -f '{{range .NetworkSettings.Networks}}{{range .Aliases}}{{println .}}{{end}}{{end}}' \
  "$(podman ps -q --filter label=com.docker.compose.service=core)" | grep '\.localhost$')

for a in $aliases; do
  podman run --rm --network "$net" docker.io/curlimages/curl:8.16.0 \
    -sS -o /dev/null --max-time 5 -w "%{http_code} $a\n" "http://$a:3000/health/liveness"
done
```

Every line must read `200`. Pin the curl tag, or a digest, rather than tracking `latest`.

A `403` is Host Authorization, not transport: the alias resolved and Rails answered, but no
`config.hosts` entry admits that name. Fix it in `config/environments/development.rb` or remove the
alias; do not read it as a connector fault.

The health endpoints are excluded from Host Authorization in production, so this gate proves
transport only — see the note under "Invariants and Verification Gates" and run Gates 2 and 3 for
the rest.

## External Checks

Repository checks cannot prove these Cloudflare-account and network controls:

- outbound UDP 7844 is allowed from the connector environment;
- the Access application exists before its published hostname, including the development hostnames;
- the published route enables Access validation;
- the VPC Service target, port, and Worker binding match this contract;
- the Edge Worker uses the intended VPC Service binding, with `remote: true` for local development
  when the request must traverse Cloudflare;
- the tunnel has no replica in a network that cannot reach this Rails origin. Cloudflare may route
  traffic to any connector replica, so every replica for this tunnel must provide the same origin
  reachability.

Treat each as blocked until verified in the deployment environment. Do not infer them from a local
`/health` response.

The second and third items were verified for development on 2026-08-10 against the ten published
Rails hostnames: every unauthenticated external request returned an Access login redirect, a nonce
probe confirmed no such request reached the origin, and authenticated browser traffic was observed
arriving at Rails from a public client address. Evidence is in
`notes/implementation/2026-08-10-development-tunnel-access-verification.md`. That run covers
development only; the first and fourth items remain unverified, and production remains blocked on
all four. A dated verification run is evidence, not a substitute for re-checking after any account
change.

That run also found that `palm-jp.umaxica.app` currently carries an interactive Access application.
Palm is a bearer-token API surface whose authenticator rejects any request carrying a cookie, and
Access forwards its `CF_Authorization` cookie to the origin, so interactive Access breaks both
browser and native clients there. Resolve that before treating Palm as published.

The Docs, Help, and News families are not published through the tunnel. `PUBLIC_DOCS_*_URL` names a
private `*.localhost` origin and no `PUBLIC_HELP_*`/`PUBLIC_NEWS_*` value is set, so the former
`docs-jp.`/`help-jp.`/`news-jp.umaxica.*` aliases named hostnames that nothing configured and that
Host Authorization would reject; they are removed rather than left dangling. This also retires the
pre-existing spelling mismatch between those aliases and the `docs.jp.umaxica.app` route
constraints. Publishing any of the three means choosing the canonical hostname, setting the matching
`PUBLIC_*_URL`, and adding the alias — in that order.
