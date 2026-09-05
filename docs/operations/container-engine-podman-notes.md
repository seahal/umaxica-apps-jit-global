# Container Engine Notes (Podman / Docker)

## Compose provider for the Dev Container

VS Code is the primary entry point. Complete the one-time Podman user settings in
[VS Code Dev Containers on Rootless Podman](devcontainer-cli-podman-startup.md), then run **Dev
Containers: Rebuild and Reopen in Container**.

For diagnostics or automation, use the equivalent standard CLI command from the repository root:

```sh
PODMAN_COMPOSE_PROVIDER=/usr/bin/podman-compose \
devcontainer up \
  --docker-path /usr/bin/podman \
  --docker-compose-path /usr/bin/podman-compose \
  --workspace-folder .
```

`PODMAN_COMPOSE_PROVIDER` is not optional. Once `--docker-path` points at Podman, the Dev Containers
CLI invokes the `podman compose` subcommand, and `podman compose` delegates to an external provider
that prefers `docker-compose` when one is installed. Docker Compose reports
`unsupported external secret` for this stack because it cannot attach external Podman secrets
through the Podman API, and on a host with no running Docker daemon it fails earlier still, against
a missing `podman.sock`. The variable is what pins the provider; `--docker-compose-path` alone does
not, because the subcommand form does not consult it.

This is a security requirement. Do not bind host credential files into the containers. The internal
PostgreSQL passwords are fixed development-only literals declared inline in `compose.yaml`, so no
credential is bound in from the host. Global and Edge intentionally do not share a host Podman
network; Edge reaches the Rails origin through Cloudflare Workers VPC.

`--docker-path` is equally required. Without it the Dev Containers CLI runs lifecycle queries such
as `docker ps` through its default Docker executable, which on a host that also has Docker installed
silently drives the wrong engine. Neither the flags nor the variable have a `devcontainer.json`
equivalent, so none of them can be moved into repository configuration.

There is intentionally no repository launcher. VS Code invokes the standard Dev Containers CLI,
keeping one lifecycle instead of adding a project-specific bootstrap interface. The remaining
Podman-specific properties live in Compose configuration.

If an interrupted start leaves `global-devcontainer-core` in Created or Exited state, use **Dev
Containers: Rebuild and Reopen in Container**. The CLI equivalent is the same `devcontainer up`
command with `--remove-existing-container`.

Compose networks are repository-managed rootless Podman networks. In particular, `outer.external` is
a YAML boolean and is not environment-variable interpolated. Interpolation turns this field into a
string; affected podman-compose releases then fail in network argument construction with
`AttributeError: 'str' object has no attribute 'get'`.

The compose stack at `compose.yaml` is exercised with rootless Podman. Some Compose-compatible
tooling remains useful for static validation, but it is not the supported runtime provider. This
document records the rootless Podman requirements that are easy to miss.

## Restart policies

No service uses `restart: always` or `restart: unless-stopped`. Podman applies no backoff to a
restart policy, so a container that exits immediately on a bad configuration is recreated several
times a second until netns, veth, conmon, and journald churn saturates a CPU — the failure mode
recorded in `notes/implementation/2026-08-23-cloudflare-tunnel-restart-storm.md`. The attempt count
is the only bound Compose can express, so every long-running service declares `on-failure:N`:

| Service                                                                                   | Policy         |
| ----------------------------------------------------------------------------------------- | -------------- |
| `core`, `primary`, `replica`, `valkey-cache`, `valkey-rate-limit`, `alloy`, `loki`, `tempo`, `prometheus`, `grafana` | `on-failure:5` |
| `fakecloud`, `cloudflare-tunnel`                                                          | `on-failure:3` |
| `fdw-poc*`                                                                                | `"no"`         |

Two consequences of that choice:

- **The stack does not come back on its own after a reboot, logout, or session restart.**
  `podman-restart.service` starts only containers whose policy is `always` or `unless-stopped`, so
  enabling it now has nothing to act on. Reopen the Dev Container, or run `podman compose up -d`.
- **The attempt budget is spent per container, not per hour.** Once a container has used its
  attempts it stays stopped, which is the intent: a real misconfiguration must be visible in
  `podman ps` rather than hidden behind an endless loop. Bringing the stack back up resets it.

A failing _healthcheck_ does not trigger a restart. Podman's `--health-on-failure` has no
Compose-file equivalent, so a container that is alive but unhealthy — a replica that has stopped
streaming, for instance — is reported by `podman ps` and repaired by hand.

`core`, `primary`, `replica`, `valkey-cache`, and `valkey-rate-limit` log through a size-capped
`json-file` driver
(`max-size: 10m`, `max-file: 3`) because journald enforces no per-container cap. Their output does
not reach `journalctl`; use `podman logs`, which serves either driver.

`test/tooling/compose_restart_policy_test.rb` holds these as assertions.

## Image UID / GID build args

The `core` image bakes the host's UID/GID at build time via the `DOCKER_UID` and `DOCKER_GID` build
args (sourced from `${UID}` / `${GID}`). Consequences:

- The image is **not portable** across users whose host UID differs from the UID the image was built
  against. Sharing a prebuilt image with another developer whose UID is different requires a
  rebuild.
- Always run `docker compose build` (or `podman compose build`) from the account that will run the
  container. Do not build as root and run rootless.
- When switching accounts on a workstation, rebuild the `core` image rather than reusing the cached
  one.

`compose.yaml` sets `userns_mode: keep-id`, which maps the in-container UID back to the host UID at
runtime. This keeps bind-mount ownership consistent even if the build UID differs slightly from the
runtime UID. The `core` service deliberately carries no `user:` key: pinning one would double-map
under `keep-id` and break ownership.

## PostgreSQL storage

Primary and replica data use named volumes. The no-tmpfs baseline is intentional: explicit tmpfs and
`shm_size` settings are not part of the current stack. Reintroducing either requires workload and
memory-pressure measurements.

## SELinux

On Fedora, RHEL, and other SELinux-enforcing hosts, bind-mounted host paths must be labeled before
the container can read them. The compose file marks read-only config bind mounts with `:z` (shared
label). The workspace bind is labeled `Z` (private) rather than shared, so SELinux does not relabel
the host source tree for other containers.

If a service fails to read a mounted file with "permission denied" on an SELinux host even though
POSIX permissions look correct, relabel manually:

```bash
chcon -Rt container_file_t podman/<service>/
```

## Podman-specific compose settings

`compose.yaml` makes the stack Podman-friendly:

- `userns_mode: keep-id` for UID mapping.
- no `user:` key on `core`, so the in-image UID wins instead of double-mapping.
- no tmpfs mount for the workspace `tmp/` and `log/` paths, because rootless Podman has historically
  been unreliable with them on tmpfs.

Run the stack with the developer overlay layered on the base compose file:

```bash
podman compose -f compose.yaml up
```
