# Migration: `docker/` directory to `podman/`

Move the container-support directory from `docker/` to `podman/` in three steps so that no step both
moves files and switches references at the same time.

## Step 1 — Duplicate (done 2026-08-10)

- `podman/` now holds a full copy of `docker/`. The pre-existing `podman/tools/dcup` was kept.
- `docker/` is unchanged and remains the only referenced location. Nothing changed behavior today.
- Path strings **inside** the copied files still say `docker/`; they are corrected in Step 2.

## Step 2 — Switch references (done 2026-08-10, one day early at the user's request)

Every reference now points at `podman/`. `docker/` is untouched and still present.

- `compose.yaml`: build contexts and bind mounts for `psql-pub`, `psql-sub`, `tempo`, `grafana`,
  `otel-collector`, `prometheus`
- `Containerfile`: `COPY` of `core/entrypoint.sh` and `core/dev-supervisor.sh`
- `.containerignore`, `.dockerignore`: the allow-list block now covers `podman/core/*`; a plain
  `docker/` exclusion was added so the leftover directory stays out of the build context
- `.gitignore`: `podman/core/preferences` rules added alongside the existing `docker/` ones
- `.rubocop.yml`, `.rubocop/custom_exclusions.yml`: `podman/**/*` added to the exclusion lists
- `.devcontainer/dotfiles/bashrc` and `podman/core/preferences/.bashrc`: `HISTFILE` path
- Path strings inside `podman/` (fdw-poc overlay build context and comments, pg-cron-poc README,
  pgadmin `servers.json` comments, remote-control unit template `ExecStart`)
- `docs/experiments/postgres-s3-fdw-poc.md`, `docs/operations/claude-remote-control.md`,
  `docs/operations/container-engine-podman-notes.md`

Left alone deliberately: `# syntax=docker/dockerfile:1` frontend directives, `docker.io` registry
references, and the prose "docker/observability stack" in `docs/srs.md`, none of which name this
directory.

Verified: `podman compose config` exits 0 and resolves the build contexts and bind mounts to
absolute paths under `podman/`. `diff -r docker podman` shows differences only in the path strings
edited above, plus the pre-existing `podman/tools/`. No containers were rebuilt or restarted — that
is the user's check tomorrow morning.

Known pre-existing drift, not introduced here: `docs/experiments/postgres-s3-fdw-poc.md` still names
`fdw-poc/Dockerfile`, but the file in the worktree is `Containerfile`.

## Step 3 — Delete `docker/` (after tomorrow's restart check passes)

Confirm `grep -rIn "docker/" --exclude-dir=.git .` reports no remaining path references into the
directory, then remove `docker/`, and drop the now-redundant `docker/` entries from `.gitignore`,
`.dockerignore`, `.containerignore`, and both RuboCop configs. Note that a Compose restart wipes the
tmpfs-backed database volumes, so the dev and test databases must be rebuilt afterwards.
