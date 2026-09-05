# VS Code Dev Containers on Rootless Podman

This repository uses the VS Code Dev Containers extension with rootless Podman. It intentionally has
no project-specific launcher or bootstrap script. VS Code delegates the lifecycle to the standard
Dev Containers CLI.

## One-Time Host Configuration

Install Podman 5 or newer, `podman-compose`, VS Code, and the recommended Dev Containers extension.
Then set these application-scoped VS Code user settings:

```jsonc
{
  "dev.containers.dockerPath": "/usr/bin/podman",
  "dev.containers.dockerComposePath": "/usr/bin/podman-compose",
}
```

These settings belong in **User Settings (JSON)**, not `.vscode/settings.json`. The extension
declares them with `application` scope, so a workspace value does not select the engine used to
create that workspace.

Pin the provider used by `podman compose` in `~/.config/containers/containers.conf`:

```toml
[engine]
compose_providers = ["/usr/bin/podman-compose"]
```

The provider setting is required even when `dev.containers.dockerComposePath` is set. The Dev
Containers CLI can invoke `podman compose`, and Podman otherwise prefers an installed
`docker-compose` provider over `podman-compose`.

## Starting from VS Code

1. Open the repository folder in VS Code as the normal rootless Podman user.
2. Run **Dev Containers: Rebuild and Reopen in Container** from the Command Palette.
3. After the first successful build, use **Dev Containers: Reopen in Container** for routine starts.

VS Code reads `.devcontainer/devcontainer.json`, combines the three declared Compose files,
provisions the configured features, runs the lifecycle commands, and opens `/home/global/workspace`
as user `global`.

## CLI Equivalent

For diagnostics or automation, the equivalent command from the repository root is:

```sh
PODMAN_COMPOSE_PROVIDER=/usr/bin/podman-compose \
devcontainer up \
  --docker-path /usr/bin/podman \
  --docker-compose-path /usr/bin/podman-compose \
  --workspace-folder .
```

To open a CLI shell afterward:

```sh
devcontainer exec --docker-path /usr/bin/podman --workspace-folder . -- bash -l
```

## Why the CLI Selectors Are Required

`--docker-path /usr/bin/podman` selects the engine. The Dev Containers CLI shells out to `docker`
for every lifecycle query. A development host may also have a real Docker installation, so omitting
this flag does not fail loudly; it silently drives the wrong engine, and the resulting container has
none of the rootless properties this project depends on.

`PODMAN_COMPOSE_PROVIDER=/usr/bin/podman-compose` selects the Compose implementation, and it is not
optional. Once the engine is Podman, the CLI invokes the `podman compose` subcommand, which
delegates to an external provider that prefers `docker-compose` when one is installed. Docker
Compose cannot attach this stack's external Podman secrets. This is a security requirement, not a
convenience: see [Container Engine Notes](container-engine-podman-notes.md).

`--docker-compose-path /usr/bin/podman-compose` is kept because the CLI still uses it on the paths
where it invokes a standalone Compose binary rather than the subcommand. It does not substitute for
the environment variable.

None of these have a `devcontainer.json` equivalent. VS Code supplies the two CLI flags from its
application-scoped user settings; the Podman user configuration supplies the provider choice. Keep
the complete command together when using the CLI directly.

`--workspace-folder .` names the folder explicitly. The command must be run from the repository
root.

## What the Configuration Already Does

`devcontainer.json` declares no `initializeCommand`; the stack needs no host-side bootstrap. Service
passwords are fixed development-only literals declared inline in `compose.yaml`, so nothing has to
be provisioned before the first `up`. The one manual prerequisite is the `UID` and `GID` lines in
the gitignored repository-root `.env`, because `$UID` and `$GID` are bash builtins rather than
exported variables and Compose cannot read them directly (see
`docs/operations/development-credential-provisioning.md`). Global and Edge do not share a host
Podman network; the Edge Worker uses Cloudflare Workers VPC to reach this tunnel.
`postCreateCommand` then runs `bundle install && pnpm install`.

The Podman-specific properties are Compose concerns and need no flags: `userns_mode: keep-id`,
`user: !reset null`, the `bind.selinux: Z` labels on the workspace and on the read-only
`/etc/timezone`, `./.github`, `./bin`, and `./.devcontainer` binds, the `DOCKER_UID`/`DOCKER_GID`
build arguments, the stable `container_name` values including `global-devcontainer-core`, the
`host.docker.internal:host-gateway` extra host, and the published ports.

## Dev Container Features

`devcontainer.json` provisions the GitHub CLI, `herdr`, Claude Code, Codex, and Tailscale features.
A feature may be added only when it installs binaries. A feature that declares a `mounts` entry
binding a host path — typically a credential or profile directory under `${localEnv:HOME}` — must
not be used here, for two reasons:

- It contradicts the credential boundary recorded at the end of `devcontainer.json`: no host
  credential enters the `core` service. Tool authentication happens inside the running container and
  is discarded when the container is recreated.
- The bind source is not created by any hook the Dev Containers CLI runs, so on a host that has
  never used the tool, `podman run` fails with `statfs <path>: no such file or directory` after a
  successful image build. A vendor-namespaced key such as
  `customizations.<vendor>.initializeCommand` does not fix this; neither VS Code nor the CLI
  executes it, and creating the host directory would breach the boundary above anyway.

`ghcr.io/sliekens/devcontainer-features/grok-build` was removed for exactly this reason.

## Safety Contract

Run as the normal rootless Podman user. Never `sudo devcontainer` or `sudo podman` — the container's
security model assumes a user namespace owned by your account. Confirm with
`podman info --format '{{.Host.Security.Rootless}}'`, which must print `true`.

Do not add `--mount`, `--secrets-file`, `--remote-env`, `--config`, or `--override-config`. Each
reaches past the repository's security boundary and injects host state the image is built to
exclude.

If `global-devcontainer-core` exists in Created or Exited state, use **Dev Containers: Rebuild and
Reopen in Container**. Do not use a rebuild path for routine starts because it recreates the Dev
Container.

Do not use `--remove-existing-container` on the CLI recovery path. It issues a bare
`podman rm -f <core>` that ignores the rest of the project. Take the whole project down
first instead, then start it again:

```sh
podman compose --project-name umaxicaappsglobaldc \
  -f compose.yaml -f .devcontainer/compose.override.yml down

devcontainer up \
  --docker-path /usr/bin/podman \
  --docker-compose-path /usr/bin/podman-compose \
  --workspace-folder .
```

`down` destroys the tmpfs-backed `primary` and `replica` data. Rebuild the development and test
databases and re-clone the replica afterwards.

## Related

- [Dev Container CLI](https://github.com/devcontainers/cli#dev-container-cli)
- [Dev Container JSON reference](https://containers.dev/implementors/json_reference/)
- [Podman Compose provider selection](https://docs.podman.io/en/latest/markdown/podman-compose.1.html)
- [Container Engine Notes (Podman / Docker)](container-engine-podman-notes.md)
- [Development Container Targets](development-container-targets.md)
- [Development Host Port Exposure](development-host-port-exposure.md)


## The Compose file contract

```text
compose.yaml                        = the complete standard environment
.devcontainer/compose.override.yml  = tracked; the Dev Container's own overlay
compose.override.yaml               = optional, gitignored, per developer/machine
compose.override.yaml.example       = tracked documentation of the above
compose.remote-access.yaml          = opt-in, tracked, never in dockerComposeFile
```

A fresh clone needs **no local file**:

```bash
git clone https://github.com/seahal/umaxica-apps-jit-global.git
cd umaxica-apps-jit-global

# creating a local override is NOT required

docker compose config
```

then `Dev Containers: Reopen in Container`, or the `devcontainer up` invocation above.

Two rules make that hold, and both are asserted by
`test/tooling/compose_local_override_optional_test.rb`:

1. **Every `dockerComposeFile` entry is a tracked file.** The Dev Containers CLI passes each
   entry to Compose as `-f`, so an entry a clone does not contain fails the whole `up` at
   configuration resolution with a bare `no such file or directory`.
2. **No file on that path uses a required `${VAR:?}` interpolation.** Compose interpolates
   every listed file in full whichever service is named, so one required variable stops
   `devcontainer up` on a machine that never runs that service. This is how the retired
   `compose.custom.yaml` broke clean checkouts: it demanded `CLOUDFLARED_TOKEN` for a
   connector nobody had asked to start. The primary connector is unprofiled so the Dev
   Container lifecycle starts it; a missing token uses `:-` and `restart: on-failure:3`
   rather than `${CLOUDFLARED_TOKEN:?}`. The alternative connector stays behind
   `--profile tunnel-edge`.

The same `-f` also suppresses Compose's auto-discovery of `compose.override.yaml`, so a
developer's local override applies to a bare `docker compose` and to explicit `-f` runs,
not to the editor. Copy `compose.override.yaml.example` only if you want one of the
machine-specific things it documents.

### Migrating from `compose.custom.yaml`

`compose.custom.yaml` is deleted. Its `cloudflare-tunnel` service moved into `compose.yaml`
as an unprofiled sidecar, with `${CLOUDFLARED_TOKEN:-}` instead of `${CLOUDFLARED_TOKEN:?}`.
A Dev Container `up` starts it with the rest of the stack. Recreate it with:

```bash
podman compose -f compose.yaml up -d cloudflare-tunnel
```

If you kept host devices or personal tooling in your own copy, move them to
`compose.override.yaml` (see `compose.override.yaml.example`) and delete the old file. It was
tracked, so `git pull` removes it for you unless you have local modifications.
