# Cloudflare Tunnel Edge Network Join Implementation Notes

## Context

- Original plan/spec: session plan "join cloudflare-tunnel to the external Edge network"
  (2026-08-11), derived from an operator investigation of persistent 502s on Edge-bound ingress.
- Related decisions/docs/plans: `docs/operations/cloudflare-private-origin.md`,
  `docs/architecture/cloudflare-request-paths.md`,
  `notes/implementation/2026-08-10-development-tunnel-access-verification.md`. The Edge-side
  decision record that left this join as Rails-side work lives in the Edge repository, not here.
- Implementation date: 2026-08-11

## Evidence That Prompted The Change

Reported from the host: `umaxicaappsglobaldc_cloudflare-tunnel_1` was on
`umaxicaappsglobaldc_frontend`; `umaxicaappsedgedc_core_1` was on `umaxicaappsedgedc_default` and
`umaxica-edge-tunnel`. No shared network, therefore no DNS resolution from the connector to the Edge
origin, therefore 502 on every Edge ingress rule. Nothing was misconfigured — the network join had
never been made.

## Decisions Made During Implementation

- Decision: write `frontend` out explicitly alongside `edge-tunnel` in the connector's service-level
  `networks:` list, and say why in a comment.
  - Why: a service-level `networks:` list in an overlay file replaces the base list rather than
    merging with it. Listing only `edge-tunnel` would detach the connector from the private
    `*.localhost` Rails origins and break every ingress rule that works today.
  - Alternatives considered: relying on merge semantics. Rejected — the semantics are the trap.
  - Follow-up needed: none.

- Decision: declare the network as `external: true` with `name: umaxica-edge-tunnel` rather than
  letting this project create it.
  - Why: the network is created and owned by the Edge compose project. A non-external declaration
    would create a second, empty network under this project's name and leave the connector exactly
    as unable to reach Edge Core as before, but with the appearance of being wired up.
  - Alternatives considered: none viable for cross-project reachability.
  - Follow-up needed: the ordering constraint below.

- Decision: accept that the connector now fails to start when the Edge stack is down, and document
  it as intended behaviour.
  - Why: `external: true` means podman fails the `up` loudly when the network is absent. The
    alternative — a connector that silently comes up able to reach only Rails — is a silent
    fallback, which `.agents/harnesses/rules/generic/no-silent-fallback.mdc` forbids. Note that
    `compose.custom.yaml` is in `.devcontainer/devcontainer.json`'s `dockerComposeFile` array, so
    this affects `devcontainer up` as well, not only manual connector recreation.
  - Alternatives considered: none.
  - Follow-up needed: none.

- Decision: add the network-membership assertions to
  `test/unit/security/development_container_contract_test.rb` rather than a new file.
  - Why: that file is already the home for compose-configuration contracts and already parses
    `compose.custom.yaml`. `test/unit/security/tunnel_origin_isolation_test.rb` is about `core` not
    publishing a host port, which is a different property.
  - Alternatives considered: extending the isolation test. Rejected as off-topic there.
  - Follow-up needed: none.

- Decision: do not pre-emptively change `bin/tunnel-origin-check`.
  - Why: its network discovery (`bin/tunnel-origin-check:51-63`) filters the connector's networks by
    the `com.docker.compose.network` label equal to `frontend` and assumes exactly one match. If the
    Edge-owned network carries that same label value, the shell variable holds two lines and the
    probe fails. Whether it does is an observation about the Edge project, unverifiable from here
    and unverified at the time of writing. Speculatively narrowing the filter would be a change made
    without evidence.
  - Alternatives considered: adding a `com.docker.compose.project` match now.
  - Follow-up needed: if the probe fails after the connector is recreated, narrow the filter by also
    matching `com.docker.compose.project`.

## Risk Recorded But Not Resolved

Podman registers a service name as a network alias, so `core` is expected to resolve on both
`frontend` (Rails) and `umaxica-edge-tunnel` (Edge Core) once the connector joins both, making it an
ambiguous, resolution-order-dependent address. Tunnel ingress rules must therefore name unambiguous
addresses: the `*.localhost` aliases for Rails, and the Edge project's own alias or container name
for Edge. Ingress configuration is token-managed in the Cloudflare account and cannot be inspected
or corrected from this repository.

## Contradictions And Stale Guidance Found

- `docs/operations/cloudflare-private-origin.md` opened by stating the connector reaches Rails only
  over `frontend`, phrased so that it also read as "the connector is on `frontend` only". Kept the
  Rails-scoped claim, which is still true, and added the connector's second attachment plus the two
  new external checks.
- `docs/architecture/cloudflare-request-paths.md:141-144` said the connector is the only component
  on `frontend` besides `core` — still accurate, so it was kept and extended rather than replaced.
- `notes/implementation/2026-08-10-development-tunnel-access-verification.md` records "attached to
  the `frontend` network only". That note is dated evidence, not a contract, so the observation was
  left intact and a supersession pointer was added instead of rewriting it.

## Verification

Run in this session:

- `bin/rails test test/unit/security/development_container_contract_test.rb test/unit/security/tunnel_origin_isolation_test.rb`
  — 12 runs, 117 assertions, 0 failures, 0 errors, 0 skips, with the new network-membership test
  included.

Not run in this session, and why:

- `podman compose ... config`, `podman network inspect umaxica-edge-tunnel`, and
  `bin/tunnel-origin-check` — `podman` is not on `PATH` inside the development container. These are
  host-side commands and were handed to the operator.
- Live Edge reachability through the tunnel and the Access unauthenticated-302 check — both depend
  on the connector being recreated on the host first.

## Operator Steps Handed Over

Container network membership is fixed at creation, so `restart` cannot apply this change. The
recreate must pass all three compose files, so that `core` is never resolved without the
devcontainer override, and must pass `--no-deps`, because `cloudflare-tunnel` declares
`depends_on: core` and recreating `core` would destroy the running development container:

```bash
podman compose \
  -f compose.yaml \
  -f .devcontainer/compose.override.yml \
  -f compose.custom.yaml \
  up -d --force-recreate --no-deps cloudflare-tunnel
```

Success criterion:

```bash
podman network inspect umaxica-edge-tunnel --format '{{range .Containers}}{{.Name}} {{end}}'
```

must list `umaxicaappsglobaldc_cloudflare-tunnel_1` alongside `umaxicaappsedgedc_core_1`.
