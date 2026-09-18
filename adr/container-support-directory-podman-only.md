# Container Support Directory Is `podman/` Only

## Status

Accepted 2026-09-14. Completes Step 3 of `plans/analysis/docker-to-podman-directory-migration.md`
(Steps 1 and 2 done 2026-08-10).

## Decision

`podman/` is the single location for container-support files — build contexts, entrypoints,
supervisor scripts, datastore init, and observability provisioning. The legacy `docker/` directory
is deleted and must not be reintroduced. A file that is needed by the container stack lives under
`podman/`; a path reference that names `docker/` is a defect unless it is a `docker.io` registry
reference or a `# syntax=docker/dockerfile:1` build-frontend directive, neither of which names this
directory.

## Why

Steps 1 and 2 left two trees with the same content while only `podman/` was referenced. A dead
duplicate of build inputs is a correctness hazard: an edit applied to the unreferenced copy looks
applied but changes nothing, and the divergence is invisible until a rebuild produces the old
behavior. One location removes that failure mode. The directory name also matches the engine the
project actually runs (`docs/operations/container-engine-podman-notes.md`).

## What was removed and what it cost

23 tracked files. All but one had an identical counterpart under `podman/`, so their deletion
changes nothing.

The exception is `docker/tailscale/serve/serve.json`:

```json
{ "TCP": { "22": { "TCPForward": "core:2222" } } }
```

It declared the tailnet TCP/22 → `core:2222` forward for the retired Tailscale **sidecar**
container. That sidecar no longer exists; `tailscaled` runs directly in `core`, and the same forward
is now declared imperatively at every start by `.devcontainer/remote-sshd-entrypoint.sh:178`:

```
tailscale serve --bg --tcp=22 tcp://127.0.0.1:2222
```

That command persists its configuration in the `tailscale-core-state` volume, and re-declaring an
identical forward is a no-op, so the entrypoint — not a JSON file — is the source of truth for
tailnet SSH ingress. The JSON was not carried into `podman/` and is not recreated. Consequence: the
sidecar topology can no longer be restored from the repository. Restoring it would require rewriting
the file from the record above or from git history
(`git show 9d89b33e2^:docker/tailscale/serve/serve.json`).

## Consequences

- Remote access over the tailnet depends on `.devcontainer/remote-sshd-entrypoint.sh` alone. A
  change to the SSH port mapping is made there, not in a mounted config file. See
  `docs/operations/remote-codex-over-tailscale.md`.
- Tooling entries that merely _exclude_ `docker/` (`.containerignore`, `.dockerignore`,
  `.rubocop.yml`, `.gitignore`) now name a directory that does not exist. They are inert, not
  broken, and are removed separately so this deletion stays reviewable on its own.
- Deleting the directory does not restart or rebuild anything. Any rebuild that follows must account
  for the tmpfs-backed database volumes being wiped by a Compose restart; the dev and test databases
  are rebuilt afterwards.

## Alternatives rejected

- **Keep `docker/` as a fallback copy.** This is exactly the drift hazard the migration exists to
  end, and Step 2 already proved nothing reads it.
- **Copy `serve.json` into `podman/` first.** It would be an unreferenced file describing a
  container that no longer runs — dead configuration carried forward under a new name.
