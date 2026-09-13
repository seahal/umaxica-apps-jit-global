# Podman Compose and Dev Container Coexistence

Verified on 2026-09-08, host Fedora-family Linux 6.12.0, rootless Podman 5.8.2 with podman-compose
1.5.0 as the external Compose provider (`/usr/bin/docker` is a shim that execs `podman`). Dev
Containers CLI from mise Node 26.7.0.

## Symptom

`podman compose up` failed at configuration parse; `devcontainer up` failed at
`docker compose up -d`. Two Compose projects for this repository were alive at once
(`pod_umaxicaappsglobaldc`, `pod_umaxica-apps-global-dc`).

## Cause 1 — null service body

`compose.override.yaml.example` declared `app:` with every setting commented out. podman-compose
1.5.0 raises `TypeError: argument of type 'NoneType' is not iterable` in `normalize_service`; Docker
Compose tolerates the null body. Confirmed directly:
`podman_compose.normalize({'services': {'app': {}}})` returns, a null body raises.

## Cause 2 — divergent project name

The Dev Containers CLI does not read `name:` from the Compose files. It derives the project name
from `devcontainer.json`'s `name` by removing every non-alphanumeric character and passes it
explicitly. Observed in the failing invocation:

    docker compose --project-name umaxicaappsglobaldc -f .../compose.yaml \
      -f .../.devcontainer/compose.yaml -f /tmp/devcontainercli-msvd/... up -d

A bare `podman compose` used `name: umaxica-apps-global-dc` verbatim. The two projects contend for
the hardcoded `global-devcontainer-*` container names and the same published ports, so whichever
entry point started second failed:

    Error: creating container storage: the container name
    "global-devcontainer-primary" is already in use by 72b282b52fed...
    Error: unable to start container "d0bd4da7870c": rootlessport listen tcp
    127.0.0.1:4566: bind: address already in use

## Change

`name:` set to `umaxicaappsglobaldc` in `compose.yaml`, `.devcontainer/compose.yaml` and
`compose.override.yaml.example`; `app: {}` in the example. Documentation naming the project or its
volume prefix updated to match.

## Results

- `podman compose config` — exit 0.
- `podman compose up -d` — exit 0. All twelve shared services created; `core` not started, which is
  correct: it is defined only in `.devcontainer/compose.yaml`, which a bare `up` does not load.
- `devcontainer up --workspace-folder .` against the running stack — Compose `up` succeeded, `core`
  joined the same pod, `bundle install` and `pnpm install` succeeded. Now a single pod
  `pod_umaxicaappsglobaldc` with 13 containers.
- `podman compose up -d` re-run while `core` was up — exit 0, `core` untouched.
- `bin/rails test test/tooling/` — 48 runs, 329 assertions, 0 failures, 0 errors, 0 skips.
  `ComposeLocalOverrideOptionalTest#test_the_example_matches_the_current_schema` caught the
  example's stale project name before the change was complete.
- `podman port -a` — every published port bound to `127.0.0.1`.

## Not resolved

- `devcontainer up` still exits non-zero: `postCreateCommand` fails at `bin/rails db:prepare`.
  `AddPublishingOperatorProvenance` (20260906120000) aborts with
  `PG::UndefinedTable: relation "publishing_info_app_entries" does not exist`. The
  `development_publishing_db` in the persistent `primary-data` volume holds a superseded
  single-family schema (`publishing_entries`, 16 tables) and records two versions no longer present
  in `db/publishing_migrate` (20260801142552, 20260801143622), while the current
  `db/migration_support/publishing_schema.rb` builds twelve `publishing_<surface>_<audience>_*`
  families. This is stale developer database state, not a container defect, and recreating that
  database was left to the developer.
- `cloudflare-tunnel-workers-vpc` exits 255
  (`"cloudflared tunnel run" requires the ID or name of the tunnel`) because
  `CLOUDFLARED_WORKERS_VPC_TOKEN` is absent from the local `.env`. `compose.yaml` documents a
  missing token as leaving a stopped container, so this is expected on a host without that token.
- `docs/operations/devcontainer-cli-podman-startup.md` states that `down` destroys tmpfs-backed
  `primary` and `replica` data. `primary-data` and `replica-data` are persistent named volumes in
  `compose.yaml`; the data survived a `podman pod rm -f` here. Not corrected in this session.
