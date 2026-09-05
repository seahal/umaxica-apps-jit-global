# Dev Container Cloudflare Tunnel sidecar

## Context

- Original plan/spec: none; reported as "the development-container tunnel sidecar does not start".
- Related decisions/docs: `docs/architecture/cloudflare-request-paths.md`,
  `docs/operations/cloudflare-private-origin.md`,
  `notes/implementation/2026-08-23-cloudflare-tunnel-restart-storm.md`.
- Implementation date: 2026-09-03.

## Decisions Made During Implementation

- Decision: remove `profiles: [tunnel]` from `cloudflare-tunnel` in `compose.yaml`.
  - Why: the Dev Containers CLI starts unprofiled services in the merged Compose files and
    never enables `tunnel`. The sidecar therefore did not exist on `frontend` even when
    `CLOUDFLARED_TOKEN` was set. Rails was reachable locally; the connector was not running.
  - Alternatives considered: `COMPOSE_PROFILES=tunnel` in `.env` (local-only, easy to miss);
    `initializeCommand` on the host (contradicts the no-bootstrap rule);
    `!reset` of `profiles` in `.devcontainer/compose.override.yml` (the overlay is a
    read-only bind inside `core`, and `!reset` already breaks the Dev Containers YAML parser).
  - Follow-up needed: recreate the Compose project from the host so the sidecar is created.
    This session cannot start sibling containers from inside `core`.

- Decision: keep `cloudflare-tunnel-edge` behind `--profile tunnel-edge`.
  - Why: a connector runs one tunnel. The second tunnel remains opt-in.

- Decision: leave empty-token behaviour as `${CLOUDFLARED_TOKEN:-}` plus `restart: on-failure:3`.
  - Why: that is the bound that replaced the 2026-08-23 restart storm. Starting the sidecar
    without a token now exits three times and stays stopped instead of blocking `up`.

## Deviations From Plan

- `.devcontainer/compose.override.yml` still comments that the connector is profile-gated.
  That file is mounted read-only in this environment and was not edited.

- Decision: `cloudflare-tunnel` command uses `--no-autoupdate --protocol auto` instead of
  `--protocol quic`.
  - Why: pinning QUIC disables HTTP/2 fallback. After UDP 7844 drops, cloudflared 2026.8.2
    can log `no more connections active and exiting` and return nil (exit 0). Compose
    `restart: on-failure:3` does not recreate exit 0, so the sidecar stays stopped until a
    human `up`s it. Workers VPC documents `auto` or `quic`. `unless-stopped` is still
    forbidden: Podman has no backoff and that policy is the 2026-08-23 storm.
  - Alternatives considered: `restart: unless-stopped` (storm); raising `--retries`
    significantly (Cloudflare documents against it); wrapping the distroless image (new
    image, out of scope).
  - Follow-up needed: none if `auto` keeps the process up through transport loss. If the
    container still exits 0 in the field, recovery needs a host-side unit with `RestartSec`,
    which Compose cannot express.

## Review Notes

- Tests run: `bin/rails test test/tooling/compose_local_override_optional_test.rb` (after the
  compose change).
- Tests not run: full suite; live `podman compose up` of the sidecar (no Podman inside `core`).
- Documentation promotion: `docs/operations/cloudflare-private-origin.md`,
  `docs/architecture/cloudflare-request-paths.md`,
  `docs/operations/devcontainer-cli-podman-startup.md`.
